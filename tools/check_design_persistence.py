"""Qt 5 smoke-test that stale V1 settings cannot reactivate the old shell."""

import json
import os
import tempfile
import time
from pathlib import Path


os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt5.QtCore import QObject, QUrl
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQuick import QQuickView

from preview_qml import prepare_app


def load_view(app_file: Path) -> QQuickView:
    view = QQuickView()
    view.setSource(QUrl.fromLocalFile(str(app_file)))
    if view.status() == QQuickView.Error:
        raise AssertionError("\n".join(error.toString() for error in view.errors()))
    if view.rootObject() is None:
        raise AssertionError("CamperMain root object was not created")
    return view


def read_saved(config_file: Path, timeout: float = 2.0) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        application.processEvents()
        try:
            text = config_file.read_text(encoding="utf-8")
            if text:
                return json.loads(text)
        except (OSError, json.JSONDecodeError):
            pass
        time.sleep(0.02)
    raise AssertionError("Local V2 config was not readable")


application = QGuiApplication.instance() or QGuiApplication([])
with tempfile.TemporaryDirectory(prefix="camper-v2-persistence-") as directory:
    app_file = prepare_app(Path(directory))
    config_file = app_file.parent / "preview-config.json"
    config_file.write_text(
        json.dumps({"designVersion": "v1", "baseUrl": "172.24.24.1", "showExternalWifiTile": False}),
        encoding="utf-8",
    )

    first = load_view(app_file)
    root = first.rootObject()
    shell = root.findChild(QObject, "modernShell")
    if shell is None or not shell.property("visible"):
        raise AssertionError("A stale V1 setting prevented the V2 shell from loading")
    root.persistLocalSettings()
    saved = read_saved(config_file)
    if "designVersion" in saved:
        raise AssertionError("V2-only local settings persisted the obsolete designVersion key")
    if saved.get("showExternalWifiTile") is not False:
        raise AssertionError("Non-design local settings were not retained")
    first.setSource(QUrl())

    second = load_view(app_file)
    shell = second.rootObject().findChild(QObject, "modernShell")
    if shell is None or not shell.property("visible"):
        raise AssertionError("V2 shell was not restored after local settings reload")
    second.setSource(QUrl())

print("SYNC Qt 5 V2-only persistence: stale V1 config ignored")
