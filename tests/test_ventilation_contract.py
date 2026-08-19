"""Static contract for the Cerbo relay ventilation controls in SYNC."""

from pathlib import Path


qml = (
    Path(__file__).resolve().parents[1]
    / "SyncMyMod/files/app/Jan/Camper/TemperatureDetails.qml"
).read_text(encoding="utf-8")

assert 'manualOn: manualOn === undefined' in qml
assert 'RELAIS 1 · ABLUFT' in qml
assert 'view.ventilation.exhaustOn ? "EIN" : "AUS"' in qml
assert 'RELAIS 2 · ZULUFT' in qml
assert 'view.ventilation.supplyOn ? "EIN" : "AUS"' in qml
assert 'view.ventilation.manualOn ? "MANUELL AUS" : "MANUELL EIN"' in qml
assert '!view.ventilation.manualOn' in qml

print("SYNC ventilation contract: passed")
