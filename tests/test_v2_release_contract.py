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
restore_script = (ROOT / "SyncMyMod/files/scripts/restore-statusbar-root.sh").read_text(encoding="utf-8")
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
        if MODULE.MANIFEST_PATH.as_posix() not in entries:
            raise AssertionError("USB release has no device-verifiable payload manifest")

        manifest_lines = archive.read(MODULE.MANIFEST_PATH.as_posix()).decode("ascii").splitlines()
        manifest_entries = {}
        expected_count = int(manifest_lines[0].removeprefix("# CamperControl payload entries="))
        for line in manifest_lines[1:]:
            crc, size, name = line.split(" ", 2)
            manifest_entries[name] = (int(crc), int(size))
        covered_entries = entries - {MODULE.MANIFEST_PATH.as_posix()}
        if set(manifest_entries) != covered_entries or expected_count != len(covered_entries):
            raise AssertionError("Release manifest does not cover every other ZIP entry exactly once")
        for name, (expected_crc, expected_size) in manifest_entries.items():
            payload = archive.read(name)
            if len(payload) != expected_size or MODULE.posix_cksum(payload) != expected_crc:
                raise AssertionError(f"Release manifest checksum mismatch for {name}")

if "verify_release_payload" not in installer or 'cksum "$payload_file"' not in installer:
    raise AssertionError("Device installer does not verify the complete release manifest")
if 'BACKUP_DIR="/fs/rwdata/fmods/mods/camper-complete/original"' not in restore_script:
    raise AssertionError("Restore script does not use the installer original-backup contract")
if any(token in restore_script for token in ("camper-statusbar", ".before")):
    raise AssertionError("Restore script still references the obsolete backup contract")
if not all(token in installer for token in (
    "TRANSACTION_DIR=", "ORIGINAL_DIR=", "ORIGINAL_STAGE=", "TRANSACTION_READY=0",
    'if [ "$TRANSACTION_READY" -eq 1 ]', "TRANSACTION_READY=1",
    'mv "$ORIGINAL_STAGE" "$ORIGINAL_DIR"', "clear_transaction_dir() {",
    'clear_transaction_dir || rollback_installation "transaction_unexpected_content"',
)):
    raise AssertionError("Installer does not separate ephemeral rollback from write-once originals")

print(f"SYNC V2-only ZIP: {len(MODULE.V2_APP_PAYLOAD)} app files, deterministic, fully manifested, no V1 payload")
