"""Contract for the persistent SYNC design V1/V2 selector."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper"

main = (QML / "CamperMain.qml").read_text(encoding="utf-8")
settings = (QML / "SettingsPanel.qml").read_text(encoding="utf-8")

checks = {
    "upgrade default remains modern V2": 'property string designVersion: "v2"' in main,
    "only supported saved values load": 'saved.designVersion === "v1" || saved.designVersion === "v2"' in main,
    "local payload persists design": "designVersion: designVersion" in main,
    "selector validates V1 and V2": 'selected !== "v1" && selected !== "v2"' in main,
    "selector persists immediately": "persistLocalSettings()" in main.split("function setDesignVersion", 1)[1].split("function loadRemoteSettings", 1)[0],
    "V2 shell is conditional": 'visible: root.designVersion === "v2"' in main,
    "V1 button uses shared host": 'host.setDesignVersion("v1")' in settings,
    "V2 button uses shared host": 'host.setDesignVersion("v2")' in settings,
    "one production ApiClient": main.count("ApiClient {") == 1,
    "modern shell receives shared ApiClient": "api: api" in main,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC design selector contract failed: " + ", ".join(failed))

print(f"SYNC design selector contract: {len(checks)} checks passed")
