"""Targeted Qt 5 regression test for Cerbo/DWD cloud icon mappings."""

import os
import sys
import tempfile
from pathlib import Path


os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt5.QtCore import QObject, QUrl
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQuick import QQuickView


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from preview_qml import prepare_app


application = QGuiApplication.instance() or QGuiApplication([])
with tempfile.TemporaryDirectory(prefix="camper-weather-icon-") as directory:
    app_file = prepare_app(Path(directory))
    view = QQuickView()
    view.setSource(QUrl.fromLocalFile(str(app_file)))
    if view.status() == QQuickView.Error:
        raise AssertionError("\n".join(error.toString() for error in view.errors()))
    root = view.rootObject()
    if root is None:
        raise AssertionError("CamperMain root object was not created")
    edge_panels = root.findChild(QObject, "v2EdgePanelsHost")
    if edge_panels is None:
        raise AssertionError("V2EdgePanels was not instantiated")

    cases = (
        ({"icon": "cloudy"}, "backend icon cloudy"),
        ({"icon": "partly-cloudy"}, "backend icon partly-cloudy"),
        ({"icon": "overcast"}, "backend icon overcast"),
        ({"ww": 1}, "DWD ww 1"),
        ({"ww": 2}, "DWD ww 2"),
        ({"ww": 3}, "DWD ww 3"),
    )
    for weather_item, label in cases:
        actual = edge_panels.weatherIcon(weather_item)
        if actual != "weatherCloud":
            raise AssertionError(f"{label} expected weatherCloud, got {actual!r}")

print("SYNC weather icons: cloudy/partly-cloudy/overcast and DWD ww 1/2/3 map to weatherCloud")
