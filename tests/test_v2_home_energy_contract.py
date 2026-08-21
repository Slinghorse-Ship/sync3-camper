"""Static contract for the V2-only Home energy summary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod/files/app/Jan/Camper"

shell = (QML / "ModernShell.qml").read_text(encoding="utf-8")
preview = (ROOT / "tools/preview_qml.py").read_text(encoding="utf-8")
runtime = (ROOT / "tools/check_v2_runtime.py").read_text(encoding="utf-8")

home = shell[shell.index('visible: shell.currentPage === 0'):shell.index('visible: shell.currentPage === 1')]

checks = {
    "Home uses the Cerbo DC total with an honest battery-net fallback": (
        "function homePowerText()" in shell
        and "if (valid(energy.dcSystemPower)) return fmt(energy.dcSystemPower, 0, \" W\")" in shell
        and "return signed(battery.power, 0, \" W\")" in shell
        and "function homePowerLabel()" in shell
        and 'return valid(battery.power) ? "Batterie netto" : "DC-Verbrauch"' in shell
        and "shell.homePowerText()" in home
        and "shell.homePowerLabel()" in home
    ),
    "solar total excludes the separate INDEVOLT source": (
        "function totalSolarPower()" in shell
        and "valid(solar.power)" in shell
        and "valid(energy.totalSolarPower)" in shell
        and "indevolt" not in shell[shell.index("function totalSolarPower()"):shell.index("function comfortHumidity()")]
        and "shell.totalSolarPower()" in home
    ),
    "battery flow is compact at the SOC gauge": (
        'objectName: "v2BatteryFlow"' in home
        and "shell.batteryFlowText(shell.battery.power)" in home
        and "shell.batteryFlowColor(shell.battery.power)" in home
        and home.count('objectName: "v2BatteryFlow"') == 1
    ),
    "battery-flow semantics cover charging discharging rest and unavailable": all(
        token in shell
        for token in (
            'return "↑ Lädt +" + power.toFixed(0) + " W"',
            'return "↓ Entlädt " + Math.abs(power).toFixed(0) + " W"',
            'return "Ruhe"',
            'if (!valid(value)) return "–"',
            "Math.abs(power) <= batteryFlowDeadband",
        )
    ),
    "time-to-go is real snapshot data with charging override": (
        "shell.battery.timeToGoSeconds" in home
        and "shell.timeToGo(shell.battery.timeToGoSeconds, shell.battery.power)" in home
        and 'return "Lädt"' in shell
        and 'toFixed(1).replace(".", ",") + " Tage"' in shell
        and 'return Math.floor(hours) + " h"' in shell
        and "timeToGoSeconds" in preview
    ),
    "runtime cases explicitly cover both signs zero null and time horizons": all(
        token in runtime
        for token in (
            '(52, "↑ Lädt +52 W")',
            '(-52, "↓ Entlädt 52 W")',
            '(0, "Ruhe")',
            '(None, "–")',
            '((90 * 3600, -52), "3,8 Tage")',
            '((17 * 3600, 52), "Lädt")',
        )
    ),
    "preview keeps corrected solar battery and DC fields independent": all(
        token in preview
        for token in (
            "totalSolarPower: 312",
            "dcSystemPower: 156",
            "power: -138",
            "solar: { name: \"VICTRON SOLAR\", power: 312",
            "indevolt: { online: true",
            "solarPower: 174",
        )
    ),
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC V2 Home energy contract failed: " + ", ".join(failed))

print(f"SYNC V2 Home energy contract: {len(checks)} checks passed")
