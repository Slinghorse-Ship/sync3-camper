"""SYNC settings expose the Cerbo-owned AUTOTERM cold protection contract."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "SyncMyMod/files/app/Jan/Camper/CamperMain.qml").read_text(encoding="utf-8")
SETTINGS = (ROOT / "SyncMyMod/files/app/Jan/Camper/SettingsPanel.qml").read_text(encoding="utf-8")
CLIMATE = (ROOT / "SyncMyMod/files/app/Jan/Camper/V2ClimatePage.qml").read_text(encoding="utf-8")
SHELL = (ROOT / "SyncMyMod/files/app/Jan/Camper/ModernShell.qml").read_text(encoding="utf-8")


for token in (
    "property bool coldProtectionEnabled: false",
    "property int coldProtectionStartTemperature: 3",
    "property int coldProtectionStopTemperature: 5",
    "property int coldProtectionPower: 4",
    "var cold = remoteConfig.coldProtection || ({})",
    "function toggleColdProtection()",
    "function changeColdProtection(name, direction)",
    "coldProtection: {",
    'sensor: "floor"',
):
    if token not in MAIN:
        raise AssertionError(f"SYNC cold-protection backend binding missing: {token}")

for token in (
    'objectName: "v2ColdProtectionSwitch"',
    'text: "AUTOTERM-KÄLTESCHUTZ"',
    '"KÄLTESCHUTZ EIN"',
    '"KÄLTESCHUTZ AUS"',
    'key: "startTemperature"',
    'key: "stopTemperature"',
    'key: "power"',
    "Ruuvi B7B8 · Boden",
    "sichere Vorgabe 3 / 5 °C · Stufe 4",
):
    if token not in SETTINGS:
        raise AssertionError(f"SYNC cold-protection settings UI missing: {token}")

for forbidden in (
    "function acknowledgeEvent(",
    "host.acknowledgeEvent(",
    "BESTÄTIGEN",
    "unacknowledgedCount",
):
    if forbidden in MAIN + SETTINGS:
        raise AssertionError(f"SYNC messages still require acknowledgement: {forbidden}")

if "MELDUNGEN · LETZTE 25 GESPEICHERT" not in SETTINGS:
    raise AssertionError("SYNC settings do not explain the 25-message retention")

for token in (
    'property string climateControlMode:',
    'function setControlMode(mode)',
    'model: [{label:"Aus",mode:"off"},{label:"Manuell",mode:"manual"},{label:"Automatik",mode:"auto"}]',
    'patch: { climateAutomation: { controlMode: mode } }',
    'view.climateControlMode === "auto" ? visual.green : visual.border',
):
    if token not in CLIMATE:
        raise AssertionError(f"SYNC three-way climate control missing: {token}")
if "controlMode: controlMode" not in SHELL or "enabled: controlMode === \"auto\"" not in SHELL:
    raise AssertionError("Home target adjustment does not preserve the selected climate mode")
if "view.automation.enabled === true ? visual.green" in CLIMATE:
    raise AssertionError("Climate page still paints stale enabled state green")

print("SYNC cold protection, three-way climate, and acknowledgement-free 25-message settings contract: OK")
