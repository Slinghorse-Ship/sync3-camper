import os
import shutil
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_APP = ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper"
IMPORTS = ROOT / "tests" / "qml-imports"
DAY_MODE = "--day" in sys.argv
OUTPUT = ROOT / "reference" / ("CamperControl-v2.9-day.png" if DAY_MODE else "CamperControl-v2.9-night.png")

TEMP_DIRECTORY = tempfile.TemporaryDirectory(prefix="camper-qml-render-")
RENDER_APP = Path(TEMP_DIRECTORY.name) / "Camper"
shutil.copytree(SOURCE_APP, RENDER_APP)
for qml_file in RENDER_APP.glob("*.qml"):
    qml_text = qml_file.read_text(encoding="utf-8")
    qml_text = qml_text.replace("import AL2HMIBridge 1.0 as AL2HMIBridge\n", "")
    qml_text = qml_text.replace("property bool dayMode: AL2HMIBridge.globalSource.dayMode", "property bool dayMode: " + ("true" if DAY_MODE else "false"))
    qml_file.write_text(qml_text, encoding="utf-8")
APP = RENDER_APP / "Camper.qml"

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt5.QtCore import QTimer, QUrl
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQuick import QQuickView


application = QGuiApplication(sys.argv)
view = QQuickView()
view.engine().addImportPath(str(IMPORTS))
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.setSource(QUrl.fromLocalFile(str(APP)))
view.resize(800, 480)
view.show()


def capture():
    image = view.grabWindow()
    if image.isNull() or not image.save(str(OUTPUT)):
        print("Unable to capture QML view", file=sys.stderr)
        application.exit(1)
        return
    print(OUTPUT)
    application.quit()


QTimer.singleShot(1200, capture)
raise SystemExit(application.exec_())
