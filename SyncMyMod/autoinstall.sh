#!/bin/sh

PATH=/fs/rwdata/dev:$PATH

FANCYNAME="CamperControl App + Ford Integration"
VERSION="3.11.1"
AUTHOR="CamperControl"
APP_MODNAME="CAMPER_CONTROL_QML"
ROOT_MODNAME="CAMPER_CONTROL_STATUSBAR_ROOT"
MODTOOLS="FMODS_TOOLS"
MIN_MODTOOLS_VERSION="3.3"
DEPENDENCY="CUSTOM_APPS_LOADER"

FILES_DIR="/fs/usb0/SyncMyMod/files"
APP_SOURCE="${FILES_DIR}/app/Jan/Camper"
APP_DIR="/fs/mp/fordhmi/qml/hmicustomapps/apps/Jan/Camper"
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
BACKUP_DIR="/fs/rwdata/fmods/mods/camper-complete"
APP_BACKUP="${BACKUP_DIR}/app.transaction"
DISPLAY="/fs/tmpfs/status"
POPUP="/tmp/popup.txt"

ROOT_MODE=""
STATUS_TOUCH_MODE=""
HAD_APP=0
HAD_BRIDGE=0
HAD_APP_MARKER=0
HAD_ROOT_MARKER=0

output() {
    echo "${1}" > "$DISPLAY"
    sleep "${2}"
}

progress() {
    echo "PROGRESS ${1}" > "$DISPLAY"
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

restore_markers() {
    if [ -f /fs/mp/etc/installed_mods.txt ]; then
        if [ "$HAD_APP_MARKER" -eq 0 ]; then sed -i "/^${APP_MODNAME}$/d" /fs/mp/etc/installed_mods.txt; fi
        if [ "$HAD_ROOT_MARKER" -eq 0 ]; then sed -i "/^${ROOT_MODNAME}$/d" /fs/mp/etc/installed_mods.txt; fi
    fi
}

rollback_installation() {
    if [ -f "${BACKUP_DIR}/apps.json.transaction" ]; then cp "${BACKUP_DIR}/apps.json.transaction" "$APPS_JSON"; fi
    if [ "$HAD_APP" -eq 1 ] && [ -d "$APP_BACKUP" ]; then
        rm -Rf "$APP_DIR"
        mkdir -p "$APP_DIR"
        cp -R "${APP_BACKUP}/." "$APP_DIR/"
    elif [ "$HAD_APP" -eq 0 ]; then
        rm -Rf "$APP_DIR"
    fi
    if [ -f "${BACKUP_DIR}/Root.qml.transaction" ]; then cp "${BACKUP_DIR}/Root.qml.transaction" "$ROOT_TARGET"; fi
    if [ -f "${BACKUP_DIR}/StatusBarDriverTemperature.qml.transaction" ]; then cp "${BACKUP_DIR}/StatusBarDriverTemperature.qml.transaction" "$STATUS_TARGET"; fi
    if [ "$HAD_BRIDGE" -eq 0 ]; then rm -Rf "$BRIDGE_DIR"; fi
    restore_markers
    remount_ro.sh
    sync; sync; sync
    displayMessage "Installation failed. App and Ford QML were restored."
}

if [ ! -f /fs/rwdata/dev/mods_tools.txt ] || ! grep -q "${MODTOOLS}" /fs/rwdata/dev/mods_tools.txt; then displayMessage "FMods Tools not found. Installation aborted."; fi
LINE=$(grep "$MODTOOLS" /fs/rwdata/dev/mods_tools.txt)
MODS_TOOLS_VERSION=$(echo "$LINE" | awk -F'_' '{print $NF}')
if ! version_at_least "$MODS_TOOLS_VERSION" "$MIN_MODTOOLS_VERSION"; then displayMessage "FMods Tools 3.3 or higher is required."; fi
if [ ! -f /fs/mp/etc/installed_mods.txt ] || ! grep -q "${DEPENDENCY}" /fs/mp/etc/installed_mods.txt; then displayMessage "Custom Apps Loader 2.3 not found. Install it first."; fi
if [ ! -f "$APPS_JSON" ] || [ ! -f "$ROOT_TARGET" ] || [ ! -f "$STATUS_TARGET" ]; then displayMessage "Required Ford HMI files are missing. Installation aborted."; fi

if [ ! -f "${APP_SOURCE}/Camper.qml" ] \
   || [ ! -f "${APP_SOURCE}/CamperMain.qml" ] \
   || [ ! -f "${APP_SOURCE}/ModernShell.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2Icon.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2Gauge.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2LightsPage.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2EnergyPage.qml" ] \
   || [ ! -f "${APP_SOURCE}/V2ClimatePage.qml" ] \
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
jq '.apps = (((.apps // []) | map(select(.appId != "com.jan.camper" and .appId != null))) + [{"appId":"com.jan.camper","appName":"Camper","appFile":"Jan/Camper/Camper.qml","appIcon":"Jan/Camper/Icon","appVersion":"3.11.1","appHideTitle":true}])' "$APPS_JSON" > "$TMP_JSON"
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
output "Creating transaction backups..." 1
mkdir -p "$BACKUP_DIR" || rollback_installation
cp "$APPS_JSON" "${BACKUP_DIR}/apps.json.transaction" || rollback_installation
rm -Rf "$APP_BACKUP"
if [ "$HAD_APP" -eq 1 ]; then
    mkdir -p "$APP_BACKUP" || rollback_installation
    cp -R "${APP_DIR}/." "$APP_BACKUP/" || rollback_installation
fi
if [ "$ROOT_MODE" != "installed" ]; then cp "$ROOT_TARGET" "${BACKUP_DIR}/Root.qml.transaction" || rollback_installation; fi
if [ "$ROOT_MODE" = "fresh" ] || [ "$STATUS_TOUCH_MODE" = "upgrade" ]; then cp "$STATUS_TARGET" "${BACKUP_DIR}/StatusBarDriverTemperature.qml.transaction" || rollback_installation; fi
cp "$RESTORE_SOURCE" "${BACKUP_DIR}/restore-statusbar-root.sh" || rollback_installation
chmod +x "${BACKUP_DIR}/restore-statusbar-root.sh"

progress 43
output "Installing Camper app..." 2
mkdir -p "$APP_DIR" || rollback_installation
cp -R "${APP_SOURCE}/." "$APP_DIR/" || rollback_installation
chmod +x "$APP_DIR/uninstall.sh" || rollback_installation
mv "$TMP_JSON" "$APPS_JSON" || rollback_installation

if [ "$ROOT_MODE" = "fresh" ]; then
    progress 58
    output "Installing Camper bridge..." 1
    mkdir -p "$BRIDGE_DIR" || rollback_installation
    cp "${BRIDGE_SOURCE}/CamperState.qml" "${BRIDGE_DIR}/CamperState.qml" || rollback_installation
    cp "${BRIDGE_SOURCE}/qmldir" "${BRIDGE_DIR}/qmldir" || rollback_installation
    progress 70
    output "Integrating global Root.qml..." 2
    if ! (cd / && patch --batch --forward --ignore-whitespace -p0 < "$ROOT_PATCH" >/fs/tmpfs/camper_root_patch.log 2>&1); then rollback_installation; fi
    progress 82
    output "Adding Camper statusbar button..." 2
    if ! (cd / && patch --batch --forward --ignore-whitespace -p0 < "$STATUS_PATCH" >/fs/tmpfs/camper_status_patch.log 2>&1); then rollback_installation; fi
elif [ "$ROOT_MODE" = "upgrade" ]; then
    progress 72
    output "Updating camera priority..." 2
    if ! sh "$CAMERA_UPDATE_SCRIPT" "$ROOT_TARGET" "/fs/tmpfs/CamperRoot.qml.new" >/fs/tmpfs/camper_camera_update.log 2>&1; then rollback_installation; fi
else
    progress 72
    output "Ford integration is already current..." 1
fi

if [ "$STATUS_TOUCH_MODE" = "upgrade" ]; then
    progress 86
    output "Separating Camper and camera touch areas..." 2
    if ! sh "$STATUS_TOUCH_UPDATE_SCRIPT" "$STATUS_TARGET" "/fs/tmpfs/CamperStatus.qml.new" >/fs/tmpfs/camper_status_touch.log 2>&1; then rollback_installation; fi
    if ! mv "/fs/tmpfs/CamperStatus.qml.new" "$STATUS_TARGET"; then rollback_installation; fi
fi

progress 90
if ! grep -q "^${APP_MODNAME}$" /fs/mp/etc/installed_mods.txt; then echo "$APP_MODNAME" >> /fs/mp/etc/installed_mods.txt || rollback_installation; fi
if ! grep -q "^${ROOT_MODNAME}$" /fs/mp/etc/installed_mods.txt; then echo "$ROOT_MODNAME" >> /fs/mp/etc/installed_mods.txt || rollback_installation; fi

progress 96
output "Setting RO permissions to FS..." 1
remount_ro.sh
sync; sync; sync
progress 100
output "App and Ford integration installed. Remove USB to reboot." 2
installationTerminated
