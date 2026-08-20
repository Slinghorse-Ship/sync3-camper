"""Static resource and command-origin contract for the SYNC API client."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod/files/app/Jan/Camper"
api = (QML / "ApiClient.qml").read_text(encoding="utf-8")
main = (QML / "CamperMain.qml").read_text(encoding="utf-8")
shell = (QML / "ModernShell.qml").read_text(encoding="utf-8")

checks = {
    "every local command is labelled with SYNC origin": 'body.origin = "sync"' in api,
    "Starlink is not blocked in the local client": (
        'body.origin = "sync"' in api
        and 'origin === "vrm"' not in api
        and 'origin == "vrm"' not in api
        and 'number:5,id:"starlink"' in (QML / "V2EnergyPage.qml").read_text(encoding="utf-8")
    ),
    "one bounded command queue serializes POST requests": all(
        token in api
        for token in (
            "property int commandQueueLimit: 8",
            "if (queued.length >= commandQueueLimit)",
            "function startNextCommand()",
            "property bool commandActive: false",
            "property var activeCommandRequest: null",
        )
    ),
    "poll settings and commands share one busy gate": (
        "return requestActive || commandActive || settingsRequestActive" in api
        and "if (networkRequestActive()) return" in api
        and api.count("if (xhr !== root.active") == 3
    ),
    "all request classes have four-second watchdogs": (
        "id: pollWatchdog" in api
        and "id: commandWatchdog" in api
        and "id: settingsWatchdog" in api
        and api.count("interval: 4000") == 3
    ),
    "follow-up polling is capped at five": (
        "Math.min(5, root.commandFollowupsRemaining + 5)" in api
        and "root.commandFollowupsRemaining -= 1" in api
    ),
    "rapid dim and speed intents are coalesced": (
        'action === "dim" || action === "speed"' in api
        and "queued[index] = body" in api
    ),
    "V2 has one shared clock timer": (
        main.count("interval: 1000; repeat: true; running: true") == 1
        and "interval: 1000; repeat: true; running: true" not in shell
        and "now: root.now" in main
    ),
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC API resource contract failed: " + ", ".join(failed))

print(f"SYNC API resource contract: {len(checks)} checks passed")
