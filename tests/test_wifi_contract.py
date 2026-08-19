"""Static contract checks for the SYNC external-WLAN command path."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod/files/app/Jan/Camper"

main = (QML / "CamperMain.qml").read_text(encoding="utf-8")
settings = (QML / "SettingsPanel.qml").read_text(encoding="utf-8")
preview = (ROOT / "tools/preview_qml.py").read_text(encoding="utf-8")

checks = {
    "command includes ConnMan service": 'service: servicePath' in main,
    "empty service rejected": 'if (!name || !servicePath) return' in main,
    "selected service retained": 'property string selectedWifiService: ""' in settings,
    "manual SSID resolves only scanned service": 'selectedWifiService = panel.serviceForSsid(text)' in settings,
    "connect disabled without service": 'panel.selectedWifiService.length > 0' in settings,
    "search-first hint present": 'ZUERST SUCHEN' in settings,
    "preview validates ConnMan path": 'wifiService.indexOf("/net/connman/service/") === 0' in preview,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("WLAN contract failed: " + ", ".join(failed))

print(f"SYNC WLAN contract: {len(checks)} checks passed")
