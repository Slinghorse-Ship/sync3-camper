"""Contract and fixture checks for the bounded SYNC installer app swap."""

from __future__ import annotations

import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INSTALLER_PATH = ROOT / "SyncMyMod/autoinstall.sh"
installer = INSTALLER_PATH.read_text(encoding="utf-8")


for forbidden in (
    'APP_BACKUP="${TRANSACTION_DIR}/app"',
    'cp -R "${APP_DIR}/." "$APP_BACKUP/"',
    'mkdir -p "$APP_BACKUP"',
):
    if forbidden in installer:
        raise AssertionError(f"Installer still creates an unbounded full-app backup: {forbidden}")

required = (
    'APP_STAGE="${APP_DIR}.camper-new"',
    'APP_OLD="${APP_DIR}.camper-old"',
    'mv "$APP_DIR" "$APP_OLD"',
    'mv "$APP_STAGE" "$APP_DIR"',
    'APP_SWAP_STARTED=1',
    'if [ "$APP_SWAP_STARTED" -eq 1 ]',
    'mv "$APP_OLD" "$APP_DIR"',
    'rm -Rf "$LEGACY_APP_BACKUP"',
    'rm -f "$LEGACY_APPS_BACKUP" "$LEGACY_ROOT_BACKUP" "$LEGACY_STATUS_BACKUP"',
    'write_install_log "failed" "$rollback_reason"',
    'write_install_log "success" "none"',
)
for token in required:
    if token not in installer:
        raise AssertionError(f"Bounded/atomic installer token missing: {token}")

if installer.index('rm -Rf "$LEGACY_APP_BACKUP"') < installer.index('original_backup_invalid'):
    raise AssertionError("Legacy backups are deleted before the original Ford pair is validated")

log_block = installer.split("write_install_log() {", 1)[1].split("\n}", 1)[0]
if ' > "$INSTALL_LOG"' not in log_block or '>> "$INSTALL_LOG"' in log_block:
    raise AssertionError("Installer diagnostic log must be bounded and overwritten")
if "sed -n '1,4p'" not in log_block:
    raise AssertionError("Installer storage diagnostics are not line-bounded")

# Run the exact app-stage/app-swap block in a temporary POSIX fixture.  This
# validates the QNX-compatible primitive set (mkdir/cp/rm/chmod/mv) and proves
# the old app is a rename on /fs/mp, not a recursive /fs/rwdata copy.
shell = shutil.which("sh")
if shell:
    swap_block = installer.split('mark_step "app-stage"', 1)[1]
    swap_block = 'mark_step "app-stage"' + swap_block.split(
        'mv "$TMP_JSON" "$APPS_JSON" || rollback_installation "apps_json_activate"', 1
    )[0] + 'mv "$TMP_JSON" "$APPS_JSON" || rollback_installation "apps_json_activate"'

    with tempfile.TemporaryDirectory(prefix="camper-sync-swap-") as temporary:
        base = Path(temporary)
        app_dir = base / "Camper"
        app_stage = base / "Camper.camper-new"
        app_old = base / "Camper.camper-old"
        app_source = base / "usb-payload"
        apps_json = base / "apps.json"
        tmp_json = base / "apps.new.json"
        app_dir.mkdir()
        app_source.mkdir()
        (app_dir / "generation.txt").write_text("old", encoding="ascii")
        (app_source / "generation.txt").write_text("new", encoding="ascii")
        (app_source / "uninstall.sh").write_text("#!/bin/sh\n", encoding="ascii")
        apps_json.write_text("old-json", encoding="ascii")
        tmp_json.write_text("new-json", encoding="ascii")

        assignments = {
            "APP_DIR": app_dir,
            "APP_STAGE": app_stage,
            "APP_OLD": app_old,
            "APP_SOURCE": app_source,
            "APPS_JSON": apps_json,
            "TMP_JSON": tmp_json,
        }
        fixture = ["set -eu", "mark_step() { :; }", "rollback_installation() { exit 97; }"]
        fixture.extend(f"{name}={shlex.quote(str(path))}" for name, path in assignments.items())
        fixture.extend(("HAD_APP=1", "APP_SWAP_STARTED=0", swap_block))
        subprocess.run([shell, "-c", "\n".join(fixture)], check=True)

        if (app_dir / "generation.txt").read_text(encoding="ascii") != "new":
            raise AssertionError("Atomic fixture did not activate the staged app")
        if (app_old / "generation.txt").read_text(encoding="ascii") != "old":
            raise AssertionError("Atomic fixture did not retain the rename-based rollback app")
        if apps_json.read_text(encoding="ascii") != "new-json":
            raise AssertionError("Atomic fixture did not activate apps.json")

        rollback_function = installer.split("rollback_installation() {", 1)[1].split("\n}", 1)[0]
        rollback_block = 'rm -Rf "$APP_STAGE"' + rollback_function.split(
            'rm -Rf "$APP_STAGE"', 1
        )[1].split('    rm -Rf "$ORIGINAL_STAGE"', 1)[0]
        rollback_fixture = ["set -eu"]
        rollback_fixture.extend(f"{name}={shlex.quote(str(path))}" for name, path in assignments.items())
        rollback_fixture.extend(("HAD_APP=1", "APP_SWAP_STARTED=1", rollback_block))
        subprocess.run([shell, "-c", "\n".join(rollback_fixture)], check=True)

        if (app_dir / "generation.txt").read_text(encoding="ascii") != "old":
            raise AssertionError("Atomic fixture rollback did not restore the previous app")
        if app_old.exists():
            raise AssertionError("Atomic fixture rollback left a second app directory behind")

print("SYNC installer storage: bounded rwdata, atomic /fs/mp app swap, rollback and diagnostics contracted")
