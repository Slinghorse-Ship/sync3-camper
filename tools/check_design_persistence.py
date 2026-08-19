"""Qt 5 smoke-test for saving and restoring the SYNC V1/V2 selection."""

import json
import os
import tempfile
import time
from pathlib import Path


os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt5.QtCore import QUrl
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
    last_error = None
    while time.monotonic() < deadline:
        application.processEvents()
        try:
            text = config_file.read_text(encoding="utf-8")
            if text:
                return json.loads(text)
        except (OSError, json.JSONDecodeError) as error:
            last_error = error
        time.sleep(0.02)
    raise AssertionError("Local design config was not readable") from last_error


application = QGuiApplication.instance() or QGuiApplication([])
with tempfile.TemporaryDirectory(prefix="camper-design-persistence-") as directory:
    app_file = prepare_app(Path(directory))
    config_file = app_file.parent / "preview-config.json"

    first = load_view(app_file)
    first.rootObject().setDesignVersion("v1")
    saved = read_saved(config_file)
    if saved.get("designVersion") != "v1":
        raise AssertionError("V1 was not written to the local config")
    first.setSource(QUrl())

    second = load_view(app_file)
    if second.rootObject().property("designVersion") != "v1":
        raise AssertionError("V1 was not restored from the local config")
    second.rootObject().setDesignVersion("v2")
    saved = read_saved(config_file)
    if saved.get("designVersion") != "v2":
        raise AssertionError("V2 was not written to the local config")
    second.setSource(QUrl())

    third = load_view(app_file)
    if third.rootObject().property("designVersion") != "v2":
        raise AssertionError("V2 was not restored from the local config")
    third.setSource(QUrl())

print("SYNC Qt 5 design persistence: V1 and V2 passed")
