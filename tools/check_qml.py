import os
import shutil
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_APP = ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper" / "Camper.qml"
APP = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 and sys.argv[1] != "--without-sync" else DEFAULT_APP
IMPORTS = ROOT / "tests" / "qml-imports"

temporary_directory = None
if "--without-sync" in sys.argv:
    temporary_directory = tempfile.TemporaryDirectory(prefix="camper-qml-check-")
    source_directory = ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper"
    target_directory = Path(temporary_directory.name) / "Camper"
    shutil.copytree(source_directory, target_directory)
    main_file = target_directory / "CamperMain.qml"
    for qml_file in target_directory.glob("*.qml"):
        qml_text = qml_file.read_text(encoding="utf-8")
        qml_text = qml_text.replace("import AL2HMIBridge 1.0 as AL2HMIBridge\n", "")
        qml_text = qml_text.replace("property bool dayMode: AL2HMIBridge.globalSource.dayMode", "property bool dayMode: false")
        qml_file.write_text(qml_text, encoding="utf-8")
    APP = main_file

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt5.QtCore import QUrl
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQml import QQmlComponent, QQmlEngine


application = QGuiApplication(sys.argv)
engine = QQmlEngine()
engine.addImportPath(str(IMPORTS))
component = QQmlComponent(engine, QUrl.fromLocalFile(str(APP)))

if component.isError():
    for error in component.errors():
        print(error.toString())
    raise SystemExit(1)

instance = component.create()
if instance is None:
    for error in component.errors():
        print(error.toString())
    raise SystemExit(1)

print(f"QML OK: {APP}")
instance.deleteLater()
engine.deleteLater()
