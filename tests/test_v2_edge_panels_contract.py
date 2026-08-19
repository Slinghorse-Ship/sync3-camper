"""Static contract for the V2-only SYNC edge panels."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod/files/app/Jan/Camper"

main = (QML / "CamperMain.qml").read_text(encoding="utf-8")
shell = (QML / "ModernShell.qml").read_text(encoding="utf-8")
panels = (QML / "V2EdgePanels.qml").read_text(encoding="utf-8")
installer = (ROOT / "SyncMyMod/autoinstall.sh").read_text(encoding="utf-8")
preview = (ROOT / "tools/preview_qml.py").read_text(encoding="utf-8")
readme = (ROOT / "README.md").read_text(encoding="utf-8")
app_entry = (ROOT / "SyncMyMod/files/other/app-entry.json").read_text(encoding="utf-8")
wrapper = (QML / "Camper.qml").read_text(encoding="utf-8")


checks = {
    "edge host is instantiated only by the V2 shell": (
        shell.count("V2EdgePanels {") == 1
        and "V2EdgePanels" not in main
        and 'visible: root.designVersion === "v1"' in main
    ),
    "weather comes only from the shared snapshot": (
        "weather: shell.snapshot.weather || ({})" in shell
        and "property var weather" in panels
        and not any(token in panels for token in ("XMLHttpRequest", "http://", "https://", "DWD"))
    ),
    "favorites come only from backend-resolved quick access": (
        "snapshot.ui && snapshot.ui.quickAccess" in shell
        and "fallbackQuick" not in shell
        and "findLight" not in shell
        and "favorites: shell.quickItems()" in shell
    ),
    "favorite commands fail closed on capability": all(
        token in panels
        for token in (
            "item.available === true",
            "command.target",
            "command.action",
            "api.command(command.target, command.action, command.value, extra)",
            "enabled: parent.actionable",
        )
    ),
    "one activePanel property makes drawers mutually exclusive": (
        "property int activePanel: 0" in panels
        and "activePanel = -1" in panels
        and "activePanel = 1" in panels
        and panels.count("property int activePanel") == 1
    ),
    "drawers share one scrim and one close control": (
        panels.count("id: scrim") == 1
        and panels.count("objectName: \"v2EdgePanelClose\"") == 1
        and "onClicked: panels.close()" in panels
    ),
    "both invisible edge swipe targets are at least 44 pixels": (
        'objectName: "v2LeftEdgeSwipe"' in panels
        and 'objectName: "v2RightEdgeSwipe"' in panels
        and panels.count("width: 44; height: parent.height") == 2
        and "56) panels.openFavorites()" in panels
        and "56) panels.openWeather()" in panels
        and 'objectName: "v2EdgeHandle"' not in panels
        and "id: edgeHandle" not in panels
    ),
    "visible favorite and close targets meet 44 pixel minimum": (
        "width: 312; height: 68" in panels
        and "width: 44; height: 44" in panels
        and "width: 48\n        height: 48" in panels
    ),
    "weather is read only": "panels.activate" not in panels[panels.index("id: weatherPanel"):],
    "preview contains resolved quick access and weather fixtures": (
        "quickAccess: [" in preview
        and "weather: {" in preview
        and 'EDGE_PANEL in ("favorites", "weather")' in preview
    ),
    "installer requires the edge panel payload": '"${APP_SOURCE}/V2EdgePanels.qml"' in installer,
    "release version is consistent": all(
        "3.12.0" in text
        for text in (installer, readme, app_entry, wrapper, shell, preview)
    ),
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC V2 edge-panel contract failed: " + ", ".join(failed))

print(f"SYNC V2 edge-panel contract: {len(checks)} checks passed")
