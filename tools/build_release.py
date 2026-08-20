#!/usr/bin/env python3
"""Build the deterministic, V2-only CamperControl USB release archive."""

from __future__ import annotations

import argparse
import hashlib
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERSION = "3.12.0"
APP_ROOT = Path("SyncMyMod/files/app/Jan/Camper")
MANIFEST_PATH = Path("SyncMyMod/files/release-manifest.cksum")
V2_APP_PAYLOAD = (
    "ApiClient.qml",
    "Camper.qml",
    "CamperMain.qml",
    "CamperStyle.qml",
    "Icon.png",
    "Icon_active.png",
    "Icon_activepressed.png",
    "ModernShell.qml",
    "SettingsPanel.qml",
    "TouchButton.qml",
    "transit-line-symbol-dark.png",
    "transit-line-symbol-light.png",
    "uninstall.sh",
    "V2ClimatePage.qml",
    "V2EdgePanels.qml",
    "V2EnergyPage.qml",
    "V2Gauge.qml",
    "V2Icon.qml",
    "V2LightsPage.qml",
    "VehicleLightOverlay.qml",
    "VehicleLightsLeft.png",
    "VehicleLightsRight.png",
)


def release_files() -> list[tuple[Path, Path]]:
    files: list[tuple[Path, Path]] = [(ROOT / "DONTINDX.MSA", Path("DONTINDX.MSA"))]
    sync_root = ROOT / "SyncMyMod"
    app_source = ROOT / APP_ROOT
    for source in sorted(sync_root.rglob("*")):
        if not source.is_file() or app_source in source.parents:
            continue
        files.append((source, source.relative_to(ROOT)))
    for name in V2_APP_PAYLOAD:
        source = app_source / name
        if not source.is_file():
            raise FileNotFoundError(f"V2 release payload is incomplete: {source}")
        files.append((source, APP_ROOT / name))
    return sorted(files, key=lambda pair: pair[1].as_posix())


def posix_cksum(data: bytes) -> int:
    """Return the CRC emitted by the POSIX/QNX ``cksum`` utility."""

    crc = 0
    for byte in data:
        crc ^= byte << 24
        for _ in range(8):
            crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF if crc & 0x80000000 else (crc << 1) & 0xFFFFFFFF
    length = len(data)
    while length:
        byte = length & 0xFF
        crc ^= byte << 24
        for _ in range(8):
            crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF if crc & 0x80000000 else (crc << 1) & 0xFFFFFFFF
        length >>= 8
    return (~crc) & 0xFFFFFFFF


def release_manifest(files: list[tuple[Path, Path]]) -> bytes:
    lines = [f"# CamperControl payload entries={len(files)}"]
    for source, relative in files:
        data = source.read_bytes()
        lines.append(f"{posix_cksum(data)} {len(data)} {relative.as_posix()}")
    return ("\n".join(lines) + "\n").encode("ascii")


def build(destination: Path) -> str:
    destination.parent.mkdir(parents=True, exist_ok=True)
    files = release_files()
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for source, relative in files:
            info = zipfile.ZipInfo(relative.as_posix(), date_time=(2026, 8, 20, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (0o755 if source.suffix == ".sh" else 0o644) << 16
            archive.writestr(info, source.read_bytes())
        manifest_info = zipfile.ZipInfo(MANIFEST_PATH.as_posix(), date_time=(2026, 8, 20, 0, 0, 0))
        manifest_info.compress_type = zipfile.ZIP_DEFLATED
        manifest_info.external_attr = 0o644 << 16
        archive.writestr(manifest_info, release_manifest(files))
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    return digest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "dist" / f"CamperControl-SYNC3-v{VERSION}.zip",
    )
    args = parser.parse_args()
    target = args.output.resolve()
    digest = build(target)
    print(f"ZIP={target}")
    print(f"SHA256={digest}")
    print(f"FILES={len(release_files()) + 1}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
