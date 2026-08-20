"""Bounded cleanup, atomic swap and rollback fixtures for the SYNC installer."""

from __future__ import annotations

import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INSTALLER_PATH = ROOT / "SyncMyMod/autoinstall.sh"
APP_SOURCE = ROOT / "SyncMyMod/files/app/Jan/Camper"
installer = INSTALLER_PATH.read_text(encoding="utf-8")


def function_text(name: str) -> str:
    marker = f"{name}() {{"
    if marker not in installer:
        raise AssertionError(f"Installer helper is missing: {name}")
    return marker + installer.split(marker, 1)[1].split("\n}\n", 1)[0] + "\n}"


for forbidden in (
    'APP_BACKUP="${TRANSACTION_DIR}/app"',
    "rm -Rf",
    "cp -R",
    "df -k",
    "find ",
    "sync; sync",
):
    if forbidden in installer:
        raise AssertionError(f"Installer still contains a potentially unbounded operation: {forbidden}")

required = (
    'APP_STAGE="${APP_DIR}.camper-new"',
    'APP_OLD="${APP_DIR}.camper-old"',
    'mv "$APP_DIR" "$APP_OLD"',
    'mv "$APP_STAGE" "$APP_DIR"',
    "clear_known_app_dir() {",
    "copy_release_app() {",
    "clear_transaction_dir() {",
    'clear_known_app_dir "$LEGACY_APP_BACKUP"',
    'rm -f "$LEGACY_APPS_BACKUP" "$LEGACY_ROOT_BACKUP" "$LEGACY_STATUS_BACKUP"',
    'write_install_log "failed" "$rollback_reason"',
    'write_install_log "success" "none"',
    'output "ERROR ${INSTALL_STEP}: ${rollback_reason}" 1',
    'output "30/1 Checking rollback paths..." 1',
    'output "30/2 Checking original Ford restore pair..." 1',
    'output "30/3 Cleaning known legacy backup files..." 1',
    'output "30/4 Replacing small transaction snapshot..." 1',
)
for token in required:
    if token not in installer:
        raise AssertionError(f"Bounded/atomic installer token missing: {token}")

if installer.index('clear_known_app_dir "$LEGACY_APP_BACKUP"') < installer.index("original_backup_invalid"):
    raise AssertionError("Legacy backups are cleaned before the original Ford pair is validated")

log_block = function_text("write_install_log")
if ' > "$INSTALL_LOG"' not in log_block or '>> "$INSTALL_LOG"' in log_block:
    raise AssertionError("Installer diagnostic log must be bounded and overwritten")
if "storage_probe=skipped_during_install" not in log_block:
    raise AssertionError("Installer logging may still perform a blocking storage probe")

shell = shutil.which("sh")
if shell:
    helpers = "\n\n".join(
        function_text(name)
        for name in ("clear_known_app_dir", "copy_release_app", "clear_transaction_dir")
    )

    with tempfile.TemporaryDirectory(prefix="camper-sync-bounded-") as temporary:
        base = Path(temporary)

        # A complete legacy app backup and the bad 3.12 transaction/app shape
        # must both clear in fixed time using only the positive file list.
        legacy = base / "app.transaction"
        shutil.copytree(APP_SOURCE, legacy)
        transaction = base / "transaction"
        shutil.copytree(APP_SOURCE, transaction / "app")
        for name in ("apps.json", "Root.qml", "StatusBarDriverTemperature.qml"):
            (transaction / name).write_text(name, encoding="ascii")
        cleanup_script = "\n".join(
            (
                "set -u",
                helpers,
                f"TRANSACTION_DIR={shlex.quote(str(transaction))}",
                f"clear_known_app_dir {shlex.quote(str(legacy))}",
                "clear_transaction_dir",
            )
        )
        subprocess.run([shell, "-c", cleanup_script], check=True, timeout=2)
        if legacy.exists() or transaction.exists():
            raise AssertionError("Known legacy/transaction payload was not fully removed")

        # Unexpected nested content must fail fast and remain untouched; it may
        # never trigger recursive traversal or delete an unknown Ford file.
        poison = base / "poison"
        (poison / "unknown-subdirectory").mkdir(parents=True)
        (poison / "unknown-subdirectory" / "keep.txt").write_text("keep", encoding="ascii")
        poison_script = "\n".join(
            ("set -u", function_text("clear_known_app_dir"), f"clear_known_app_dir {shlex.quote(str(poison))}")
        )
        result = subprocess.run([shell, "-c", poison_script], timeout=2)
        if result.returncode == 0 or not (poison / "unknown-subdirectory" / "keep.txt").is_file():
            raise AssertionError("Unexpected cleanup content did not fail closed")

        # Execute the exact app-stage/app-swap block against an upgrade fixture.
        app_dir = base / "Camper"
        app_stage = base / "Camper.camper-new"
        app_old = base / "Camper.camper-old"
        apps_json = base / "apps.json"
        tmp_json = base / "apps.new.json"
        app_dir.mkdir()
        (app_dir / "Camper.qml").write_text("old-generation", encoding="ascii")
        apps_json.write_text("old-json", encoding="ascii")
        tmp_json.write_text("new-json", encoding="ascii")

        swap_block = installer.split('mark_step "app-stage"', 1)[1]
        swap_block = 'mark_step "app-stage"' + swap_block.split(
            'mv "$TMP_JSON" "$APPS_JSON" || rollback_installation "apps_json_activate"', 1
        )[0] + 'mv "$TMP_JSON" "$APPS_JSON" || rollback_installation "apps_json_activate"'
        assignments = {
            "APP_DIR": app_dir,
            "APP_STAGE": app_stage,
            "APP_OLD": app_old,
            "APP_SOURCE": APP_SOURCE,
            "APPS_JSON": apps_json,
            "TMP_JSON": tmp_json,
        }
        fixture = ["set -eu", helpers, "mark_step() { :; }", "rollback_installation() { exit 97; }"]
        fixture.extend(f"{name}={shlex.quote(str(path))}" for name, path in assignments.items())
        fixture.extend(("HAD_APP=1", "APP_SWAP_STARTED=0", swap_block))
        subprocess.run([shell, "-c", "\n".join(fixture)], check=True, timeout=3)

        if "old-generation" in (app_dir / "Camper.qml").read_text(encoding="utf-8"):
            raise AssertionError("Atomic fixture did not activate the staged app")
        if (app_old / "Camper.qml").read_text(encoding="ascii") != "old-generation":
            raise AssertionError("Atomic fixture did not retain the rename-based rollback app")
        if apps_json.read_text(encoding="ascii") != "new-json":
            raise AssertionError("Atomic fixture did not activate apps.json")

        rollback_function = function_text("rollback_installation")
        rollback_block = 'clear_known_app_dir "$APP_STAGE"' + rollback_function.split(
            'clear_known_app_dir "$APP_STAGE"', 1
        )[1].split('    clear_original_stage', 1)[0]
        rollback_fixture = ["set -eu", function_text("clear_known_app_dir")]
        rollback_fixture.extend(f"{name}={shlex.quote(str(path))}" for name, path in assignments.items())
        rollback_fixture.extend(("HAD_APP=1", "APP_SWAP_STARTED=1", rollback_block))
        subprocess.run([shell, "-c", "\n".join(rollback_fixture)], check=True, timeout=2)

        if (app_dir / "Camper.qml").read_text(encoding="ascii") != "old-generation":
            raise AssertionError("Atomic fixture rollback did not restore the previous app")
        if app_old.exists():
            raise AssertionError("Atomic fixture rollback left a second app directory behind")

print("SYNC installer: bounded cleanup, fail-fast poison fixture, atomic swap/rollback and visible diagnostics passed")
