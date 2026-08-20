"""Build and inspect the deterministic V2-only SYNC USB archive."""

import importlib.util
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("camper_sync_release", ROOT / "tools/build_release.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)

LEGACY_V1_FILES = {
    "BatteryDetails.qml",
    "DimmerOverlay.qml",
    "EnergySolarDetails.qml",
    "LineIcon.qml",
    "MaxxFanDetails.qml",
    "MetricCard.qml",
    "ModernTile.qml",
    "ModernToggle.qml",
    "TemperatureDetails.qml",
    "VehicleLightCard.qml",
    "VehicleLights.qml",
    "VehicleLights.png",
    "VehicleLightsLeft-v2.png",
    "VehicleLightsLeft-v3.png",
}

installer = (ROOT / "SyncMyMod/autoinstall.sh").read_text(encoding="utf-8")
for filename in LEGACY_V1_FILES:
    if filename not in installer:
        raise AssertionError(f"Upgrade cleanup does not remove legacy V1 file {filename}")

with tempfile.TemporaryDirectory(prefix="camper-sync-release-") as directory:
    first = Path(directory) / "first.zip"
    second = Path(directory) / "second.zip"
    first_hash = MODULE.build(first)
    second_hash = MODULE.build(second)
    if first_hash != second_hash or first.read_bytes() != second.read_bytes():
        raise AssertionError("V2 release archive is not deterministic")

    with zipfile.ZipFile(first) as archive:
        entries = set(archive.namelist())
        app_prefix = MODULE.APP_ROOT.as_posix() + "/"
        app_files = {name.removeprefix(app_prefix) for name in entries if name.startswith(app_prefix)}
        expected = set(MODULE.V2_APP_PAYLOAD)
        if app_files != expected:
            missing = sorted(expected - app_files)
            extra = sorted(app_files - expected)
            raise AssertionError(f"V2 app payload mismatch; missing={missing}, extra={extra}")
        leaked = LEGACY_V1_FILES & app_files
        if leaked:
            raise AssertionError("V1 files leaked into release: " + ", ".join(sorted(leaked)))
        vehicle_assets = {name for name in app_files if name.startswith("VehicleLights") and name.endswith(".png")}
        if vehicle_assets != {"VehicleLightsLeft.png", "VehicleLightsRight.png"}:
            raise AssertionError("Release contains obsolete vehicle assets: " + ", ".join(sorted(vehicle_assets)))
        if not {"DONTINDX.MSA", "SyncMyMod/autoinstall.sh"}.issubset(entries):
            raise AssertionError("USB release root payload is incomplete")

print(f"SYNC V2-only ZIP: {len(MODULE.V2_APP_PAYLOAD)} app files, deterministic, no V1 payload")
