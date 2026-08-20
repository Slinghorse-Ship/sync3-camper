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
    "original_pair_valid() {",
    "ensure_canonical_original() {",
    "cleanup_known_legacy_backups() {",
    'LEGACY_PREVIOUS_APP="${LEGACY_CAMPER_DIR}/app.previous"',
    'LEGACY_APPS_BEFORE="${LEGACY_CAMPER_DIR}/apps.json.before"',
    'LEGACY_CONFIG="${LEGACY_CAMPER_DIR}/config.json"',
    'LEGACY_STATUSBAR_ROOT="${LEGACY_STATUSBAR_DIR}/Root.qml.before"',
    'clear_known_app_dir "$LEGACY_APP_BACKUP"',
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

if installer.rindex('ensure_canonical_original || rollback_installation "$ORIGINAL_ERROR"') > installer.rindex(
    'cleanup_known_legacy_backups || rollback_installation "$CLEANUP_ERROR"'
):
    raise AssertionError("Legacy backups are cleaned before the original Ford pair is validated")
if "rvc-on-demand" in installer:
    raise AssertionError("Installer cleanup must never reference the foreign rvc-on-demand directory")
if "LEGACY_CONFIG" in function_text("cleanup_known_legacy_backups"):
    raise AssertionError("Legacy cleanup may not unlink the persistent Camper config")

log_block = function_text("write_install_log")
if ' > "$INSTALL_LOG"' not in log_block or '>> "$INSTALL_LOG"' in log_block:
    raise AssertionError("Installer diagnostic log must be bounded and overwritten")
if "storage_probe=skipped_during_install" not in log_block:
    raise AssertionError("Installer logging may still perform a blocking storage probe")

shell = shutil.which("sh")
if shell:
    helpers = "\n\n".join(
        function_text(name)
        for name in (
            "clear_known_app_dir",
            "copy_release_app",
            "clear_transaction_dir",
            "clear_original_stage",
            "files_equal",
            "original_pair_valid",
            "stage_original_pair",
            "ensure_canonical_original",
            "clear_legacy_statusbar_dir",
            "cleanup_known_legacy_backups",
        )
    )

    with tempfile.TemporaryDirectory(prefix="camper-sync-bounded-") as temporary:
        base = Path(temporary)

        # Exact layout from the real File Viewer photos.
        mods = base / "fmods/mods"
        camper = mods / "camper"
        complete = mods / "camper-complete"
        statusbar = mods / "camper-statusbar"
        rvc = mods / "rvc-on-demand"
        transaction = complete / "transaction"
        original = complete / "original"
        original_stage = complete / "original.new"
        ford = base / "ford"
        for directory in (camper, complete, statusbar, rvc, ford):
            directory.mkdir(parents=True, exist_ok=True)

        shutil.copytree(APP_SOURCE, camper / "app.previous")
        shutil.copytree(APP_SOURCE, complete / "app.transaction")
        shutil.copytree(APP_SOURCE, transaction / "app")
        (camper / "apps.json.before").write_text("old-apps", encoding="ascii")
        (camper / "config.json").write_text('{"keep":true}', encoding="ascii")
        (complete / "Root.qml.transaction").write_text("FORD ROOT ORIGINAL", encoding="ascii")
        (complete / "StatusBarDriverTemperature.qml.transaction").write_text("FORD STATUS ORIGINAL", encoding="ascii")
        (complete / "apps.json.transaction").write_text("old-apps-2", encoding="ascii")
        (complete / "install-last.log").write_text("old-log", encoding="ascii")
        (transaction / "apps.json").write_text("attempt-apps", encoding="ascii")
        (transaction / "Root.qml").write_text("camperControlLoader", encoding="ascii")
        (transaction / "StatusBarDriverTemperature.qml").write_text("CamperState.camperOpen", encoding="ascii")
        (statusbar / "Root.qml.before").write_text("STATUSBAR ROOT ORIGINAL", encoding="ascii")
        (statusbar / "StatusBarDriverTemperature.qml.before").write_text("STATUSBAR STATUS ORIGINAL", encoding="ascii")
        (statusbar / "restore-statusbar-root.sh").write_text("#!/bin/sh\n", encoding="ascii")
        (rvc / "camera_icon_position").write_text("123", encoding="ascii")
        (ford / "Root.qml").write_text("camperControlLoader", encoding="ascii")
        (ford / "StatusBarDriverTemperature.qml").write_text("CamperState.camperOpen", encoding="ascii")

        photo_assignments = {
            "BACKUP_DIR": complete,
            "TRANSACTION_DIR": transaction,
            "ORIGINAL_DIR": original,
            "ORIGINAL_STAGE": original_stage,
            "LEGACY_APP_BACKUP": complete / "app.transaction",
            "LEGACY_APPS_BACKUP": complete / "apps.json.transaction",
            "LEGACY_ROOT_BACKUP": complete / "Root.qml.transaction",
            "LEGACY_STATUS_BACKUP": complete / "StatusBarDriverTemperature.qml.transaction",
            "LEGACY_CAMPER_DIR": camper,
            "LEGACY_PREVIOUS_APP": camper / "app.previous",
            "LEGACY_APPS_BEFORE": camper / "apps.json.before",
            "LEGACY_CONFIG": camper / "config.json",
            "LEGACY_STATUSBAR_DIR": statusbar,
            "LEGACY_STATUSBAR_ROOT": statusbar / "Root.qml.before",
            "LEGACY_STATUSBAR_STATUS": statusbar / "StatusBarDriverTemperature.qml.before",
            "LEGACY_STATUSBAR_RESTORE": statusbar / "restore-statusbar-root.sh",
            "ROOT_TARGET": ford / "Root.qml",
            "STATUS_TARGET": ford / "StatusBarDriverTemperature.qml",
        }
        photo_script = ["set -eu", helpers]
        photo_script.extend(f"{name}={shlex.quote(str(path))}" for name, path in photo_assignments.items())
        photo_script.extend(
            (
                "ROOT_MODE=installed",
                "ORIGINAL_SOURCE=unset",
                "ORIGINAL_ERROR=original_backup_missing",
                "CLEANUP_ERROR=legacy_cleanup_failed",
                "ensure_canonical_original",
                "cleanup_known_legacy_backups",
                '[ "$ORIGINAL_SOURCE" = camper_complete_transaction ]',
            )
        )
        subprocess.run([shell, "-c", "\n".join(photo_script)], check=True, timeout=3)

        if (original / "Root.qml").read_text(encoding="ascii") != "FORD ROOT ORIGINAL":
            raise AssertionError("Canonical Root.qml was not migrated from the validated complete pair")
        if (original / "StatusBarDriverTemperature.qml").read_text(encoding="ascii") != "FORD STATUS ORIGINAL":
            raise AssertionError("Canonical statusbar file was not migrated with its matching Root.qml")
        if (camper / "config.json").read_text(encoding="ascii") != '{"keep":true}':
            raise AssertionError("Photo-fixture cleanup modified the persistent Camper config")
        if (rvc / "camera_icon_position").read_text(encoding="ascii") != "123":
            raise AssertionError("Photo-fixture cleanup touched rvc-on-demand")
        if any(path.exists() for path in (
            camper / "app.previous",
            camper / "apps.json.before",
            complete / "app.transaction",
            transaction,
            complete / "Root.qml.transaction",
            complete / "StatusBarDriverTemperature.qml.transaction",
            complete / "apps.json.transaction",
            statusbar,
        )):
            raise AssertionError("Known photo-fixture legacy backups were not removed")
        canonical_ford_files = sorted(
            path.relative_to(mods).as_posix()
            for path in mods.rglob("*")
            if path.is_file() and path.name in {"Root.qml", "StatusBarDriverTemperature.qml", "Root.qml.before", "StatusBarDriverTemperature.qml.before", "Root.qml.transaction", "StatusBarDriverTemperature.qml.transaction"}
        )
        if canonical_ford_files != [
            "camper-complete/original/Root.qml",
            "camper-complete/original/StatusBarDriverTemperature.qml",
        ]:
            raise AssertionError(f"Expected exactly one canonical Ford pair, got {canonical_ford_files}")

        # If camper-complete has no usable pair, the known camper-statusbar
        # .before pair is the bounded fallback and is copied as one pair.
        fallback = base / "statusbar-fallback"
        fallback_original = fallback / "complete/original"
        fallback_stage = fallback / "complete/original.new"
        fallback_statusbar = fallback / "camper-statusbar"
        fallback_original.parent.mkdir(parents=True)
        fallback_statusbar.mkdir(parents=True)
        (fallback_statusbar / "Root.qml.before").write_text("FALLBACK ROOT", encoding="ascii")
        (fallback_statusbar / "StatusBarDriverTemperature.qml.before").write_text("FALLBACK STATUS", encoding="ascii")
        fallback_assignments = {
            "ORIGINAL_DIR": fallback_original,
            "ORIGINAL_STAGE": fallback_stage,
            "LEGACY_ROOT_BACKUP": fallback / "missing-root",
            "LEGACY_STATUS_BACKUP": fallback / "missing-status",
            "LEGACY_STATUSBAR_ROOT": fallback_statusbar / "Root.qml.before",
            "LEGACY_STATUSBAR_STATUS": fallback_statusbar / "StatusBarDriverTemperature.qml.before",
            "TRANSACTION_DIR": fallback / "missing-transaction",
            "ROOT_TARGET": ford / "Root.qml",
            "STATUS_TARGET": ford / "StatusBarDriverTemperature.qml",
        }
        fallback_script = ["set -eu", helpers]
        fallback_script.extend(f"{name}={shlex.quote(str(path))}" for name, path in fallback_assignments.items())
        fallback_script.extend(
            (
                "ROOT_MODE=installed",
                "ORIGINAL_SOURCE=unset",
                "ORIGINAL_ERROR=original_backup_missing",
                "ensure_canonical_original",
                '[ "$ORIGINAL_SOURCE" = camper_statusbar_before ]',
            )
        )
        subprocess.run([shell, "-c", "\n".join(fallback_script)], check=True, timeout=2)
        if (fallback_original / "Root.qml").read_text(encoding="ascii") != "FALLBACK ROOT":
            raise AssertionError("Statusbar .before fallback was not migrated")

        # A present but empty/corrupt file is not a validated Ford restore pair.
        empty_original = base / "empty-original"
        empty_original.mkdir()
        (empty_original / "Root.qml").write_bytes(b"")
        (empty_original / "StatusBarDriverTemperature.qml").write_text("FORD STATUS", encoding="ascii")
        empty_script = "\n".join(
            (
                "set -eu",
                function_text("original_pair_valid"),
                "if original_pair_valid "
                f"{shlex.quote(str(empty_original / 'Root.qml'))} "
                f"{shlex.quote(str(empty_original / 'StatusBarDriverTemperature.qml'))}; then exit 91; fi",
            )
        )
        subprocess.run([shell, "-c", empty_script], check=True, timeout=2)

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
