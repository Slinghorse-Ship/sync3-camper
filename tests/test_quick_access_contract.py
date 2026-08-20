"""Static contract for backend-resolved, freely assignable home shortcuts."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod/files/app/Jan/Camper"

main = (QML / "CamperMain.qml").read_text(encoding="utf-8")
shell = (QML / "ModernShell.qml").read_text(encoding="utf-8")
settings = (QML / "SettingsPanel.qml").read_text(encoding="utf-8")

checks = {
    "generic defaults": '"switch:water_pump", "switch:starlink", "switch:dc_outlets_left", "light:inside_main"' in main,
    "v5 settings source": "remoteConfig.ui.quickAccessIds" in main,
    "legacy lights migrate": '"switch:high_beam_manual" : "light:" + legacyQuick[quickIndex]' in main,
    "catalog drives settings": "snapshot.ui.quickAccessOptions" in main,
    "generic ids are saved": "ui: { quickAccessIds: quickAccessIds }" in main,
    "snapshot drives home": "snapshot.ui && snapshot.ui.quickAccess" in shell,
    "Home never consumes favorites": (
        "function quickItems()" in shell
        and "snapshot.ui && snapshot.ui.quickAccess" in shell[
            shell.index("function quickItems()"):shell.index("function favoriteItems()")
        ]
        and "favorites" not in shell[shell.index("function quickItems()"):shell.index("function favoriteItems()")]
    ),
    "backend command is used": "action.target, action.action, action.value, extra" in shell,
    "unavailable shortcuts disabled": "enabled: quick.available === true" in shell,
    "settings explain all types": "Licht, 12 V, Wasserpumpe, Geräte und Szenen" in settings,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC quick-access contract failed: " + ", ".join(failed))

print(f"SYNC quick-access contract: {len(checks)} checks passed")
