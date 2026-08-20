"""Static contract for the V2-only SYNC runtime and release."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod/files/app/Jan/Camper"

main = (QML / "CamperMain.qml").read_text(encoding="utf-8")
shell = (QML / "ModernShell.qml").read_text(encoding="utf-8")
settings = (QML / "SettingsPanel.qml").read_text(encoding="utf-8")
builder = (ROOT / "tools/build_release.py").read_text(encoding="utf-8")

legacy_types = (
    "BatteryDetails {",
    "DimmerOverlay {",
    "EnergySolarDetails {",
    "LineIcon {",
    "MaxxFanDetails {",
    "MetricCard {",
    "ModernTile {",
    "TemperatureDetails {",
    "VehicleLightCard {",
    "VehicleLights {",
)

checks = {
    "runtime always instantiates one modern shell": main.count("ModernShell {") == 1,
    "runtime exposes V2 page through the modern shell": "property alias page: modernShell.currentPage" in main,
    "no design selector remains": all(
        token not in main + shell + settings
        for token in ("property string designVersion", "setDesignVersion(", 'label: "V1"')
    ),
    "stale V1 config is ignored and not persisted": (
        "saved.designVersion" not in main
        and "designVersion:" not in main
        and "Frühere designVersion-Werte" in main
    ),
    "no V1 QML type is referenced": not any(token in main + shell for token in legacy_types),
    "one production ApiClient remains shared": main.count("ApiClient {") == 1 and "api: api" in main,
    "settings show fixed V2 state": 'text: "Transit Horizon V2"' in settings and 'text: "V2"' in settings,
    "release builder has an explicit V2 allowlist": "V2_APP_PAYLOAD = (" in builder,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC V2-only contract failed: " + ", ".join(failed))

print(f"SYNC V2-only contract: {len(checks)} checks passed")
