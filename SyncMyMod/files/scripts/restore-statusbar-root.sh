#!/bin/sh

PATH=/fs/rwdata/dev:$PATH

MODNAME="CAMPER_CONTROL_STATUSBAR_ROOT"
BACKUP_DIR="/fs/rwdata/fmods/mods/camper-statusbar"
ROOT_TARGET="/fs/mp/fordhmi/qml/Root.qml"
STATUS_TARGET="/fs/mp/fordhmi/qml/hmihome/StatusBarDriverTemperature.qml"
BRIDGE_DIR="/fs/mp/fordhmi/qml/hmicustomapps/camperbridge"

if [ ! -f "${BACKUP_DIR}/Root.qml.before" ] || [ ! -f "${BACKUP_DIR}/StatusBarDriverTemperature.qml.before" ]; then
    echo "CamperControl restore backups are missing."
    exit 1
fi

if ! remount_rw.sh; then
    echo "Unable to remount /fs/mp read-write."
    exit 1
fi

if ! cp "${BACKUP_DIR}/Root.qml.before" "$ROOT_TARGET" || ! cp "${BACKUP_DIR}/StatusBarDriverTemperature.qml.before" "$STATUS_TARGET"; then
    remount_ro.sh
    echo "Unable to restore original QML files."
    exit 1
fi

rm -Rf "$BRIDGE_DIR"
if [ -f /fs/mp/etc/installed_mods.txt ]; then
    sed -i "/^${MODNAME}$/d" /fs/mp/etc/installed_mods.txt
fi

remount_ro.sh
sync
sync
sync
echo "CamperControl statusbar/root integration restored."
exit 0
