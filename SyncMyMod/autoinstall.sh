#!/bin/sh

PATH=/fs/rwdata/dev:$PATH

FANCYNAME="CamperControl App + Ford Integration"
VERSION="3.12.1"
AUTHOR="CamperControl"
APP_MODNAME="CAMPER_CONTROL_QML"
ROOT_MODNAME="CAMPER_CONTROL_STATUSBAR_ROOT"
MODTOOLS="FMODS_TOOLS"
MIN_MODTOOLS_VERSION="3.3"
DEPENDENCY="CUSTOM_APPS_LOADER"

FILES_DIR="/fs/usb0/SyncMyMod/files"
APP_SOURCE="${FILES_DIR}/app/Jan/Camper"
APP_DIR="/fs/mp/fordhmi/qml/hmicustomapps/apps/Jan/Camper"
APP_STAGE="${APP_DIR}.camper-new"
APP_OLD="${APP_DIR}.camper-old"
APPS_JSON="/fs/mp/fordhmi/qml/hmicustomapps/apps.json"
TMP_JSON="/fs/tmpfs/camper_apps.json"
ROOT_TARGET="/fs/mp/fordhmi/qml/Root.qml"
STATUS_TARGET="/fs/mp/fordhmi/qml/hmihome/StatusBarDriverTemperature.qml"
BRIDGE_SOURCE="${FILES_DIR}/camperbridge"
BRIDGE_DIR="/fs/mp/fordhmi/qml/hmicustomapps/camperbridge"
ROOT_PATCH="${FILES_DIR}/patches/Root.patch"
STATUS_PATCH="${FILES_DIR}/patches/StatusBarDriverTemperature.patch"
STATUS_TOUCH_UPDATE_SCRIPT="${FILES_DIR}/scripts/update-statusbar-touch.sh"
CAMERA_PATCH="${FILES_DIR}/patches/RootCameraClose.patch"
CAMERA_PATCH_QRVC="${FILES_DIR}/patches/RootCameraCloseQrvc.patch"
CAMERA_PATCH_PARK="${FILES_DIR}/patches/RootParkingOverlay.patch"
CAMERA_PATCH_ALL="${FILES_DIR}/patches/RootParkingAll.patch"
CAMERA_PATCH_SELECTED=""
CAMERA_UPDATE_SCRIPT="${FILES_DIR}/scripts/update-camera-priority.sh"
ROOT_EXPECTED="${FILES_DIR}/reference/Root.qml.expected"
STATUS_EXPECTED="${FILES_DIR}/reference/StatusBarDriverTemperature.qml.expected"
RESTORE_SOURCE="${FILES_DIR}/scripts/restore-statusbar-root.sh"
RELEASE_MANIFEST="${FILES_DIR}/release-manifest.cksum"
USB_ROOT="/fs/usb0"
BACKUP_DIR="/fs/rwdata/fmods/mods/camper-complete"
TRANSACTION_DIR="${BACKUP_DIR}/transaction"
ORIGINAL_DIR="${BACKUP_DIR}/original"
ORIGINAL_STAGE="${BACKUP_DIR}/original.new"
LEGACY_APP_BACKUP="${BACKUP_DIR}/app.transaction"
LEGACY_APPS_BACKUP="${BACKUP_DIR}/apps.json.transaction"
LEGACY_ROOT_BACKUP="${BACKUP_DIR}/Root.qml.transaction"
LEGACY_STATUS_BACKUP="${BACKUP_DIR}/StatusBarDriverTemperature.qml.transaction"
INSTALL_LOG="${BACKUP_DIR}/install-last.log"
LEGACY_CAMPER_DIR="/fs/rwdata/fmods/mods/camper"
LEGACY_PREVIOUS_APP="${LEGACY_CAMPER_DIR}/app.previous"
LEGACY_APPS_BEFORE="${LEGACY_CAMPER_DIR}/apps.json.before"
LEGACY_CONFIG="${LEGACY_CAMPER_DIR}/config.json"
LEGACY_STATUSBAR_DIR="/fs/rwdata/fmods/mods/camper-statusbar"
LEGACY_STATUSBAR_ROOT="${LEGACY_STATUSBAR_DIR}/Root.qml.before"
LEGACY_STATUSBAR_STATUS="${LEGACY_STATUSBAR_DIR}/StatusBarDriverTemperature.qml.before"
LEGACY_STATUSBAR_RESTORE="${LEGACY_STATUSBAR_DIR}/restore-statusbar-root.sh"
DISPLAY="/fs/tmpfs/status"
POPUP="/tmp/popup.txt"

ROOT_MODE=""
STATUS_TOUCH_MODE=""
HAD_APP=0
HAD_BRIDGE=0
HAD_APP_MARKER=0
HAD_ROOT_MARKER=0
TRANSACTION_READY=0
APP_SWAP_STARTED=0
INSTALL_STEP="preflight"
ORIGINAL_SOURCE="unset"
ORIGINAL_ERROR="original_backup_missing"
CLEANUP_ERROR="legacy_cleanup_failed"

output() {
    echo "${1}" > "$DISPLAY"
    sleep "${2}"
}

progress() {
    echo "PROGRESS ${1}" > "$DISPLAY"
}

# Keep exactly one short diagnostic snapshot.  No storage probes or walkers:
# filesystem probes can block indefinitely on a damaged or full APIM volume.
write_install_log() {
    log_state="$1"
    log_reason="$2"
    [ -d "$BACKUP_DIR" ] || mkdir -p "$BACKUP_DIR" 2>/dev/null || return 0
    {
        echo "state=${log_state}"
        echo "step=${INSTALL_STEP}"
        echo "reason=${log_reason}"
        echo "original_source=${ORIGINAL_SOURCE}"
        echo "storage_probe=skipped_during_install"
    } > "$INSTALL_LOG" 2>/dev/null
}

mark_step() {
    INSTALL_STEP="$1"
    write_install_log "running" "none"
}

# App payloads are flat and positively enumerated.  Fixed-list unlink + rmdir
# is bounded even if an old backup contains an unexpected directory/FIFO.  It
# then fails fast instead of recursively walking unknown data.
clear_known_app_dir() {
    clear_dir="$1"
    [ -e "$clear_dir" ] || return 0
    [ -d "$clear_dir" ] || return 1
    rm -f \
        "$clear_dir/ApiClient.qml" \
        "$clear_dir/BatteryDetails.qml" \
        "$clear_dir/Camper.qml" \
        "$clear_dir/CamperMain.qml" \
        "$clear_dir/CamperStyle.qml" \
        "$clear_dir/DimmerOverlay.qml" \
        "$clear_dir/EnergySolarDetails.qml" \
        "$clear_dir/Icon_active.png" \
        "$clear_dir/Icon_activepressed.png" \
        "$clear_dir/Icon.png" \
        "$clear_dir/Icon.svg" \
        "$clear_dir/LineIcon.qml" \
        "$clear_dir/MaxxFanDetails.qml" \
        "$clear_dir/MetricCard.qml" \
        "$clear_dir/ModernShell.qml" \
        "$clear_dir/ModernTile.qml" \
        "$clear_dir/ModernToggle.qml" \
        "$clear_dir/SettingsPanel.qml" \
        "$clear_dir/TemperatureDetails.qml" \
        "$clear_dir/TouchButton.qml" \
        "$clear_dir/transit-line-symbol-dark.png" \
        "$clear_dir/transit-line-symbol-light.png" \
        "$clear_dir/uninstall.sh" \
        "$clear_dir/V2ClimatePage.qml" \
        "$clear_dir/V2EdgePanels.qml" \
        "$clear_dir/V2EnergyPage.qml" \
        "$clear_dir/V2Gauge.qml" \
        "$clear_dir/V2Icon.qml" \
        "$clear_dir/V2LightsPage.qml" \
        "$clear_dir/VehicleLightCard.qml" \
        "$clear_dir/VehicleLightOverlay.qml" \
        "$clear_dir/VehicleLights.png" \
        "$clear_dir/VehicleLights.qml" \
        "$clear_dir/VehicleLightsLeft-v2.png" \
        "$clear_dir/VehicleLightsLeft-v3.png" \
        "$clear_dir/VehicleLightsLeft.png" \
        "$clear_dir/VehicleLightsRight.png" || return 1
    rmdir "$clear_dir" 2>/dev/null
}

copy_release_app() {
    copy_source="$1"
    copy_target="$2"
    [ ! -e "$copy_target" ] || return 1
    mkdir "$copy_target" || return 1
    cp \
        "$copy_source/ApiClient.qml" \
        "$copy_source/Camper.qml" \
        "$copy_source/CamperMain.qml" \
        "$copy_source/CamperStyle.qml" \
        "$copy_source/Icon.png" \
        "$copy_source/Icon_active.png" \
        "$copy_source/Icon_activepressed.png" \
        "$copy_source/ModernShell.qml" \
        "$copy_source/SettingsPanel.qml" \
        "$copy_source/TouchButton.qml" \
        "$copy_source/transit-line-symbol-dark.png" \
        "$copy_source/transit-line-symbol-light.png" \
        "$copy_source/uninstall.sh" \
        "$copy_source/V2ClimatePage.qml" \
        "$copy_source/V2EdgePanels.qml" \
        "$copy_source/V2EnergyPage.qml" \
        "$copy_source/V2Gauge.qml" \
        "$copy_source/V2Icon.qml" \
        "$copy_source/V2LightsPage.qml" \
        "$copy_source/VehicleLightOverlay.qml" \
        "$copy_source/VehicleLightsLeft.png" \
        "$copy_source/VehicleLightsRight.png" \
        "$copy_target/" || return 1
}

clear_transaction_dir() {
    [ -e "$TRANSACTION_DIR" ] || return 0
    [ -d "$TRANSACTION_DIR" ] || return 1
    if [ -e "${TRANSACTION_DIR}/app" ]; then
        clear_known_app_dir "${TRANSACTION_DIR}/app" || return 1
    fi
    rm -f \
        "${TRANSACTION_DIR}/apps.json" \
        "${TRANSACTION_DIR}/Root.qml" \
        "${TRANSACTION_DIR}/StatusBarDriverTemperature.qml" || return 1
    rmdir "$TRANSACTION_DIR" 2>/dev/null
}

clear_original_stage() {
    [ -e "$ORIGINAL_STAGE" ] || return 0
    [ -d "$ORIGINAL_STAGE" ] || return 1
    rm -f "${ORIGINAL_STAGE}/Root.qml" "${ORIGINAL_STAGE}/StatusBarDriverTemperature.qml" || return 1
    rmdir "$ORIGINAL_STAGE" 2>/dev/null
}

original_pair_valid() {
    pair_root="$1"
    pair_status="$2"
    [ -f "$pair_root" ] && [ -s "$pair_root" ] || return 1
    [ -f "$pair_status" ] && [ -s "$pair_status" ] || return 1
    grep -q "camperControlLoader" "$pair_root" && return 1
    grep -q "CamperState.camperOpen" "$pair_status" && return 1
    return 0
}

stage_original_pair() {
    pair_root="$1"
    pair_status="$2"
    pair_source="$3"
    original_pair_valid "$pair_root" "$pair_status" || return 1
    clear_original_stage || return 1
    mkdir "$ORIGINAL_STAGE" || return 1
    cp "$pair_root" "${ORIGINAL_STAGE}/Root.qml" || return 1
    cp "$pair_status" "${ORIGINAL_STAGE}/StatusBarDriverTemperature.qml" || return 1
    original_pair_valid "${ORIGINAL_STAGE}/Root.qml" "${ORIGINAL_STAGE}/StatusBarDriverTemperature.qml" || return 1
    files_equal "$pair_root" "${ORIGINAL_STAGE}/Root.qml" || return 1
    files_equal "$pair_status" "${ORIGINAL_STAGE}/StatusBarDriverTemperature.qml" || return 1
    mv "$ORIGINAL_STAGE" "$ORIGINAL_DIR" || return 1
    ORIGINAL_SOURCE="$pair_source"
    return 0
}

# Keep one and only one canonical pre-Camper Ford pair.  Candidate sources are
# tried without modifying them; redundant copies are removed only afterwards.
ensure_canonical_original() {
    ORIGINAL_ERROR="original_backup_missing"
    if [ -e "$ORIGINAL_DIR" ]; then
        if original_pair_valid "${ORIGINAL_DIR}/Root.qml" "${ORIGINAL_DIR}/StatusBarDriverTemperature.qml"; then
            ORIGINAL_SOURCE="canonical"
            return 0
        fi
        ORIGINAL_ERROR="canonical_original_invalid"
        return 1
    fi

    if [ "$ROOT_MODE" = "fresh" ]; then
        stage_original_pair "$ROOT_TARGET" "$STATUS_TARGET" "live_fresh_ford" && return 0
    fi
    stage_original_pair "$LEGACY_ROOT_BACKUP" "$LEGACY_STATUS_BACKUP" "camper_complete_transaction" && return 0
    stage_original_pair "$LEGACY_STATUSBAR_ROOT" "$LEGACY_STATUSBAR_STATUS" "camper_statusbar_before" && return 0
    stage_original_pair "${TRANSACTION_DIR}/Root.qml" "${TRANSACTION_DIR}/StatusBarDriverTemperature.qml" "bounded_transaction" && return 0
    return 1
}

clear_legacy_statusbar_dir() {
    [ -e "$LEGACY_STATUSBAR_DIR" ] || return 0
    [ -d "$LEGACY_STATUSBAR_DIR" ] || return 1
    rm -f "$LEGACY_STATUSBAR_ROOT" "$LEGACY_STATUSBAR_STATUS" "$LEGACY_STATUSBAR_RESTORE" || return 1
    rmdir "$LEGACY_STATUSBAR_DIR" 2>/dev/null
}

# Photo-verified legacy layout.  config.json and the independent camera mod are
# deliberately outside every unlink path used here.
cleanup_known_legacy_backups() {
    CLEANUP_ERROR="camper_previous_app_unexpected_content"
    clear_known_app_dir "$LEGACY_PREVIOUS_APP" || return 1
    CLEANUP_ERROR="camper_complete_app_unexpected_content"
    clear_known_app_dir "$LEGACY_APP_BACKUP" || return 1
    CLEANUP_ERROR="transaction_unexpected_content"
    clear_transaction_dir || return 1
    CLEANUP_ERROR="legacy_small_backup_cleanup"
    rm -f \
        "$LEGACY_APPS_BEFORE" \
        "$LEGACY_APPS_BACKUP" \
        "$LEGACY_ROOT_BACKUP" \
        "$LEGACY_STATUS_BACKUP" || return 1
    CLEANUP_ERROR="camper_statusbar_unexpected_content"
    clear_legacy_statusbar_dir || return 1
    CLEANUP_ERROR="none"
    return 0
}

clear_bridge_dir() {
    [ -e "$BRIDGE_DIR" ] || return 0
    [ -d "$BRIDGE_DIR" ] || return 1
    rm -f "${BRIDGE_DIR}/CamperState.qml" "${BRIDGE_DIR}/qmldir" || return 1
    rmdir "$BRIDGE_DIR" 2>/dev/null
}

displayMessage() {
    echo "${1}" > "$POPUP"
    utserviceutility popup "$POPUP"
    exit 0
}

installationTerminated() {
    while [ -e /fs/usb0 ]; do sleep 1; done
    output "REBOOT" 3
    exit 0
}

version_at_least() {
    awk -v have="$1" -v need="$2" 'BEGIN {
        split(have, h, "."); split(need, n, ".");
        for (i = 1; i <= 4; i++) {
            hv = h[i] + 0; nv = n[i] + 0;
            if (hv > nv) exit 0;
            if (hv < nv) exit 1;
        }
        exit 0;
    }'
}

files_equal() {
    if command -v cmp >/dev/null 2>&1; then
        cmp -s "$1" "$2"
        return $?
    fi
    [ "$(cksum < "$1")" = "$(cksum < "$2")" ]
}

verify_release_payload() {
    [ -f "$RELEASE_MANIFEST" ] || return 1
    expected_count=$(sed -n 's/^# CamperControl payload entries=//p' "$RELEASE_MANIFEST")
    case "$expected_count" in
        ''|*[!0-9]*) return 1 ;;
    esac
    checked_count=0
    while IFS=' ' read -r expected_crc expected_size relative_path; do
        case "$expected_crc" in \#*) continue ;; esac
        case "$expected_crc" in ''|*[!0-9]*) return 1 ;; esac
        case "$expected_size" in ''|*[!0-9]*) return 1 ;; esac
        case "$relative_path" in
            DONTINDX.MSA|SyncMyMod/*) ;;
            *) return 1 ;;
        esac
        case "/${relative_path}/" in *'/../'*|*'/./'*|*'//'* ) return 1 ;; esac
        payload_file="${USB_ROOT}/${relative_path}"
        [ -f "$payload_file" ] || return 1
        checksum=$(cksum "$payload_file") || return 1
        set -- $checksum
        [ "$1" = "$expected_crc" ] && [ "$2" = "$expected_size" ] || return 1
        checked_count=$((checked_count + 1))
    done < "$RELEASE_MANIFEST"
    [ "$checked_count" -eq "$expected_count" ]
}

restore_markers() {
    if [ -f /fs/mp/etc/installed_mods.txt ]; then
        if [ "$HAD_APP_MARKER" -eq 0 ]; then sed -i "/^${APP_MODNAME}$/d" /fs/mp/etc/installed_mods.txt; fi
        if [ "$HAD_ROOT_MARKER" -eq 0 ]; then sed -i "/^${ROOT_MODNAME}$/d" /fs/mp/etc/installed_mods.txt; fi
    fi
}

rollback_installation() {
    rollback_reason="${1:-unspecified}"
    write_install_log "failed" "$rollback_reason"
    output "ERROR ${INSTALL_STEP}: ${rollback_reason}" 1
    if [ "$TRANSACTION_READY" -eq 1 ]; then
        if [ -f "${TRANSACTION_DIR}/apps.json" ]; then cp "${TRANSACTION_DIR}/apps.json" "$APPS_JSON"; fi
        if [ -f "${TRANSACTION_DIR}/Root.qml" ]; then cp "${TRANSACTION_DIR}/Root.qml" "$ROOT_TARGET"; fi
        if [ -f "${TRANSACTION_DIR}/StatusBarDriverTemperature.qml" ]; then cp "${TRANSACTION_DIR}/StatusBarDriverTemperature.qml" "$STATUS_TARGET"; fi
        if [ "$HAD_BRIDGE" -eq 0 ]; then clear_bridge_dir; fi
        restore_markers
    fi
    clear_known_app_dir "$APP_STAGE"
    if [ "$APP_SWAP_STARTED" -eq 1 ]; then
        clear_known_app_dir "$APP_DIR"
        if [ "$HAD_APP" -eq 1 ] && [ -d "$APP_OLD" ]; then mv "$APP_OLD" "$APP_DIR"; fi
    fi
    clear_original_stage
    remount_ro.sh
    displayMessage "Installation failed at ${INSTALL_STEP} (${rollback_reason}). Previous version restored."
}

if [ ! -f /fs/rwdata/dev/mods_tools.txt ] || ! grep -q "${MODTOOLS}" /fs/rwdata/dev/mods_tools.txt; then displayMessage "FMods Tools not found. Installation aborted."; fi
LINE=$(grep "$MODTOOLS" /fs/rwdata/dev/mods_tools.txt)
MODS_TOOLS_VERSION=$(echo "$LINE" | awk -F'_' '{print $NF}')
if ! version_at_least "$MODS_TOOLS_VERSION" "$MIN_MODTOOLS_VERSION"; then displayMessage "FMods Tools 3.3 or higher is required."; fi
if [ ! -f /fs/mp/etc/installed_mods.txt ] || ! grep -q "${DEPENDENCY}" /fs/mp/etc/installed_mods.txt; then displayMessage "Custom Apps Loader 2.3 not found. Install it first."; fi
if [ ! -f "$APPS_JSON" ] || [ ! -f "$ROOT_TARGET" ] || [ ! -f "$STATUS_TARGET" ]; then displayMessage "Required Ford HMI files are missing. Installation aborted."; fi
if ! verify_release_payload; then displayMessage "Camper USB payload is incomplete or damaged. No changes made."; fi

if [ ! -f "${APP_SOURCE}/Camper.qml" ] \
   || [ ! -f "${APP_SOURCE}/CamperMain.qml" ] \
   || [ ! -f "${APP_SOURCE}/ModernShell.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2Icon.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2Gauge.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2LightsPage.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2EnergyPage.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2ClimatePage.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2EdgePanels.qml" ] \
   || [ ! -f "${APP_SOURCE}/VehicleLightOverlay.qml" ] \
   || [ ! -f "${APP_SOURCE}/Icon.png" ] \
   || [ ! -f "${APP_SOURCE}/Icon_active.png" ] \
   || [ ! -f "${APP_SOURCE}/Icon_activepressed.png" ] \
   || [ ! -f "${APP_SOURCE}/VehicleLightsLeft.png" ] \
   || [ ! -f "${APP_SOURCE}/VehicleLightsRight.png" ] \
   || [ ! -f "${APP_SOURCE}/transit-line-symbol-dark.png" ] \
   || [ ! -f "${APP_SOURCE}/transit-line-symbol-light.png" ]; then
    displayMessage "Camper app payload is incomplete. Installation aborted."
fi
if [ ! -f "$ROOT_PATCH" ] || [ ! -f "$STATUS_PATCH" ] || [ ! -f "$STATUS_TOUCH_UPDATE_SCRIPT" ] || [ ! -f "$CAMERA_UPDATE_SCRIPT" ] || [ ! -f "$ROOT_EXPECTED" ] || [ ! -f "$STATUS_EXPECTED" ] || [ ! -f "$RESTORE_SOURCE" ] || [ ! -f "${BRIDGE_SOURCE}/CamperState.qml" ] || [ ! -f "${BRIDGE_SOURCE}/qmldir" ]; then
    displayMessage "Ford integration payload is incomplete. Installation aborted."
fi

if [ -d "$APP_DIR" ]; then HAD_APP=1; fi
if [ -d "$BRIDGE_DIR" ]; then HAD_BRIDGE=1; fi
if grep -q "^${APP_MODNAME}$" /fs/mp/etc/installed_mods.txt; then HAD_APP_MARKER=1; fi
if grep -q "^${ROOT_MODNAME}$" /fs/mp/etc/installed_mods.txt; then HAD_ROOT_MARKER=1; fi

# Supported states: original Ford files, older Camper integration, or current integration.
if grep -q "camperControlLoader" "$ROOT_TARGET" \
   && grep -q "viewContainer.fullScreenViewActive === 0" "$ROOT_TARGET" \
   && grep -q "!root.hasActivePopup" "$ROOT_TARGET" \
   && grep -q "CamperState.camperOpen" "$STATUS_TARGET" \
   && [ -f "${BRIDGE_DIR}/CamperState.qml" ] && [ -f "${BRIDGE_DIR}/qmldir" ]; then
    ROOT_MODE="installed"
elif grep -q "camperControlLoader" "$ROOT_TARGET" \
   && grep -q "active: CamperBridge.CamperState.camperOpen" "$ROOT_TARGET" \
   && grep -q "CamperState.camperOpen" "$STATUS_TARGET" \
   && [ -f "${BRIDGE_DIR}/CamperState.qml" ] && [ -f "${BRIDGE_DIR}/qmldir" ]; then
    ROOT_MODE="upgrade"
elif files_equal "$ROOT_TARGET" "$ROOT_EXPECTED" \
   && files_equal "$STATUS_TARGET" "$STATUS_EXPECTED" \
   && [ ! -e "$BRIDGE_DIR" ]; then
    ROOT_MODE="fresh"
else
    displayMessage "Ford Root/Statusbar differs from supported versions. No changes made."
fi

# The current button replaces the complete obsolete RVC status shortcut and
# opens only after the completed click. Upgrade every older, uniquely marked
# Camper block through the bounded copy transformer; never rewrite an unknown
# status bar. Camera and parking overlays live in Root.qml and are untouched.
if grep -q 'objectName: "StatusBarCamperShortcut"' "$STATUS_TARGET" \
   && grep -q "parent: root.parent" "$STATUS_TARGET" \
   && grep -q "root.mapToItem(parent, camperStoredX(), 0)" "$STATUS_TARGET" \
   && grep -q "width: 60" "$STATUS_TARGET" \
   && grep -q "height: 54" "$STATUS_TARGET" \
   && grep -q "camperOpenTimer.restart()" "$STATUS_TARGET" \
   && ! grep -q "id: rvcShortcutItem" "$STATUS_TARGET" \
   && ! grep -q "camera_manager enable" "$STATUS_TARGET"; then
    STATUS_TOUCH_MODE="current"
elif grep -q "id: camperShortcutItem" "$STATUS_TARGET" \
     && grep -q "CamperBridge.CamperState.camperOpen" "$STATUS_TARGET"; then
    STATUS_TOUCH_MODE="upgrade"
    if ! sh "$STATUS_TOUCH_UPDATE_SCRIPT" "$STATUS_TARGET" "/fs/tmpfs/CamperStatus.qml.check" >/fs/tmpfs/camper_status_touch_test.log 2>&1; then
        displayMessage "Camper button touch-area update is unsupported. No changes made."
    fi
    rm -f /fs/tmpfs/CamperStatus.qml.check
elif [ "$ROOT_MODE" = "fresh" ]; then
    STATUS_TOUCH_MODE="fresh"
else
    displayMessage "Camper button status is unsupported. No changes made."
fi

if [ "$ROOT_MODE" = "fresh" ]; then
    if ! (cd / && patch --batch --forward --ignore-whitespace --dry-run -p0 < "$ROOT_PATCH" >/fs/tmpfs/camper_root_patch_test.log 2>&1); then displayMessage "Root.qml patch test failed. No changes made."; fi
    if ! (cd / && patch --batch --forward --ignore-whitespace --dry-run -p0 < "$STATUS_PATCH" >/fs/tmpfs/camper_status_patch_test.log 2>&1); then displayMessage "Statusbar patch test failed. No changes made."; fi
elif [ "$ROOT_MODE" = "upgrade" ]; then
    if ! grep -q "id: camperControlLoader" "$ROOT_TARGET" \
       || ! grep -q "visible: active" "$ROOT_TARGET" \
       || ! grep -q "source: active" "$ROOT_TARGET"; then
        displayMessage "Camera priority structure is unsupported. No changes made."
    fi
fi

if ! jq empty "$APPS_JSON" >/dev/null 2>&1; then displayMessage "apps.json is invalid. Installation aborted without changes."; fi
jq '.apps = (((.apps // []) | map(select(.appId != "com.jan.camper" and .appId != null))) + [{"appId":"com.jan.camper","appName":"Camper","appFile":"Jan/Camper/Camper.qml","appIcon":"Jan/Camper/Icon","appVersion":"3.12.1","appHideTitle":true}])' "$APPS_JSON" > "$TMP_JSON"
if ! jq empty "$TMP_JSON" >/dev/null 2>&1; then rm -f "$TMP_JSON"; displayMessage "Unable to prepare apps.json. Installation aborted without changes."; fi

instutility &
sleep 2
output "DEV ${FANCYNAME} v${VERSION} - ${AUTHOR}" 2
progress 12
output "All compatibility checks passed..." 1

progress 20
output "Setting RW permissions to FS..." 1
if ! remount_rw.sh; then displayMessage "Unable to remount /fs/mp read-write. No changes made."; fi

progress 30
output "30/1 Checking rollback paths..." 1
mkdir -p "$BACKUP_DIR" || rollback_installation "backup_dir_create"

# Recover a completed same-filesystem swap if power was lost before the old
# directory was removed.  Never recurse through the app just to make a backup.
if [ ! -d "$APP_DIR" ] && [ -d "$APP_OLD" ]; then
    mv "$APP_OLD" "$APP_DIR" || rollback_installation "stale_app_restore"
    HAD_APP=1
fi

# The original Ford pair is a separate, write-once restore contract.  Establish
# it before deleting legacy 3.x backups or writing the bounded transaction.
progress 32
output "30/2 Checking original Ford restore pair..." 1
mark_step "original-backup"
ensure_canonical_original || rollback_installation "$ORIGINAL_ERROR"

# A successful original migration makes all old full-app and *.transaction
# copies obsolete.  Camper config and the independent camera mod remain intact.
progress 34
output "30/3 Cleaning known legacy backup files..." 1
mark_step "legacy-cleanup"
cleanup_known_legacy_backups || rollback_installation "$CLEANUP_ERROR"

progress 37
output "30/4 Replacing small transaction snapshot..." 1
mark_step "transaction-backup"
clear_transaction_dir || rollback_installation "transaction_unexpected_content"
mkdir -p "$TRANSACTION_DIR" || rollback_installation "transaction_create"
cp "$APPS_JSON" "${TRANSACTION_DIR}/apps.json" || rollback_installation "transaction_apps_copy"
cp "$ROOT_TARGET" "${TRANSACTION_DIR}/Root.qml" || rollback_installation "transaction_root_copy"
cp "$STATUS_TARGET" "${TRANSACTION_DIR}/StatusBarDriverTemperature.qml" || rollback_installation "transaction_status_copy"
TRANSACTION_READY=1
cp "$RESTORE_SOURCE" "${BACKUP_DIR}/restore-statusbar-root.sh" || rollback_installation "restore_script_copy"
chmod +x "${BACKUP_DIR}/restore-statusbar-root.sh" || rollback_installation "restore_script_mode"

progress 43
output "Staging Camper app on Ford filesystem..." 2
mark_step "app-stage"
clear_known_app_dir "$APP_STAGE" || rollback_installation "app_stage_unexpected_content"
copy_release_app "$APP_SOURCE" "$APP_STAGE" || rollback_installation "app_stage_copy"
# 3.12 is V2-only.  Clean the candidate before its atomic directory swap.
rm -f \
    "$APP_STAGE/BatteryDetails.qml" \
    "$APP_STAGE/DimmerOverlay.qml" \
    "$APP_STAGE/EnergySolarDetails.qml" \
    "$APP_STAGE/LineIcon.qml" \
    "$APP_STAGE/MaxxFanDetails.qml" \
    "$APP_STAGE/MetricCard.qml" \
    "$APP_STAGE/ModernTile.qml" \
    "$APP_STAGE/ModernToggle.qml" \
    "$APP_STAGE/TemperatureDetails.qml" \
    "$APP_STAGE/VehicleLightCard.qml" \
    "$APP_STAGE/VehicleLights.qml" \
    "$APP_STAGE/VehicleLights.png" \
    "$APP_STAGE/VehicleLightsLeft-v2.png" \
    "$APP_STAGE/VehicleLightsLeft-v3.png" || rollback_installation "app_stage_v1_cleanup"
chmod +x "$APP_STAGE/uninstall.sh" || rollback_installation "app_stage_mode"

mark_step "app-swap"
clear_known_app_dir "$APP_OLD" || rollback_installation "app_old_unexpected_content"
if [ "$HAD_APP" -eq 1 ]; then
    mv "$APP_DIR" "$APP_OLD" || rollback_installation "app_old_activate"
fi
APP_SWAP_STARTED=1
mv "$APP_STAGE" "$APP_DIR" || rollback_installation "app_candidate_activate"
mv "$TMP_JSON" "$APPS_JSON" || rollback_installation "apps_json_activate"

if [ "$ROOT_MODE" = "fresh" ]; then
    progress 58
    output "Installing Camper bridge..." 1
    mark_step "bridge-install"
    mkdir -p "$BRIDGE_DIR" || rollback_installation "bridge_create"
    cp "${BRIDGE_SOURCE}/CamperState.qml" "${BRIDGE_DIR}/CamperState.qml" || rollback_installation "bridge_state_copy"
    cp "${BRIDGE_SOURCE}/qmldir" "${BRIDGE_DIR}/qmldir" || rollback_installation "bridge_qmldir_copy"
    progress 70
    output "Integrating global Root.qml..." 2
    mark_step "root-integration"
    if ! (cd / && patch --batch --forward --ignore-whitespace -p0 < "$ROOT_PATCH" >/fs/tmpfs/camper_root_patch.log 2>&1); then rollback_installation "root_patch"; fi
    progress 82
    output "Adding Camper statusbar button..." 2
    mark_step "statusbar-integration"
    if ! (cd / && patch --batch --forward --ignore-whitespace -p0 < "$STATUS_PATCH" >/fs/tmpfs/camper_status_patch.log 2>&1); then rollback_installation "statusbar_patch"; fi
elif [ "$ROOT_MODE" = "upgrade" ]; then
    progress 72
    output "Updating camera priority..." 2
    mark_step "camera-priority"
    if ! sh "$CAMERA_UPDATE_SCRIPT" "$ROOT_TARGET" "/fs/tmpfs/CamperRoot.qml.new" >/fs/tmpfs/camper_camera_update.log 2>&1; then rollback_installation "camera_priority_update"; fi
else
    progress 72
    output "Ford integration is already current..." 1
fi

if [ "$STATUS_TOUCH_MODE" = "upgrade" ]; then
    progress 86
    output "Separating Camper and camera touch areas..." 2
    mark_step "statusbar-touch"
    if ! sh "$STATUS_TOUCH_UPDATE_SCRIPT" "$STATUS_TARGET" "/fs/tmpfs/CamperStatus.qml.new" >/fs/tmpfs/camper_status_touch.log 2>&1; then rollback_installation "statusbar_touch_transform"; fi
    if ! mv "/fs/tmpfs/CamperStatus.qml.new" "$STATUS_TARGET"; then rollback_installation "statusbar_touch_activate"; fi
fi

progress 90
mark_step "mod-markers"
if ! grep -q "^${APP_MODNAME}$" /fs/mp/etc/installed_mods.txt; then echo "$APP_MODNAME" >> /fs/mp/etc/installed_mods.txt || rollback_installation "app_marker"; fi
if ! grep -q "^${ROOT_MODNAME}$" /fs/mp/etc/installed_mods.txt; then echo "$ROOT_MODNAME" >> /fs/mp/etc/installed_mods.txt || rollback_installation "root_marker"; fi

progress 96
output "Setting RO permissions to FS..." 1
mark_step "finalize"
# The new directory is live.  Old app data was only a same-filesystem rename,
# never a second persistent copy in /fs/rwdata.
clear_known_app_dir "$APP_OLD"
APP_SWAP_STARTED=0
clear_known_app_dir "$APP_STAGE"
clear_transaction_dir
remount_ro.sh
INSTALL_STEP="complete"
write_install_log "success" "none"
progress 100
output "App and Ford integration installed. Remove USB to reboot." 2
installationTerminated
