"""Smoke-test the production QML URL canonicalization with Qt itself."""

import os
import sys
from pathlib import Path

from PyQt5.QtCore import QUrl
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQuick import QQuickView


os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

app = QGuiApplication(sys.argv)
qml = Path(__file__).resolve().parents[1] / "SyncMyMod/files/app/Jan/Camper/ApiClient.qml"
view = QQuickView()
view.setSource(QUrl.fromLocalFile(str(qml)))
if view.status() == QQuickView.Error:
    raise SystemExit("\n".join(error.toString() for error in view.errors()))

root = view.rootObject()
cases = {
    "https://venus.local:1881/dashboard/camper": "http://venus.local:1880/camper/api/v2",
    "https://172.24.24.1:1880/camper/api/v1": "http://172.24.24.1:1880/camper/api/v2",
    "venus.local": "http://venus.local:1880/camper/api/v2",
    "http://einstein:9999/anything": "http://einstein:1880/camper/api/v2",
}
for source, expected in cases.items():
    actual = root.cleanBaseUrl(source)
    if actual != expected:
        raise AssertionError(f"{source!r}: expected {expected!r}, got {actual!r}")

print(f"QML URL normalization: {len(cases)} cases passed")
