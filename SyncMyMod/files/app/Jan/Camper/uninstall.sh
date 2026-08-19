#!/bin/sh

MODNAME="CAMPER_CONTROL_QML"

rm -Rf /fs/rwdata/fmods/mods/camper
if [ -f /fs/mp/etc/installed_mods.txt ]; then
    sed -i "/^${MODNAME}$/d" /fs/mp/etc/installed_mods.txt
fi

exit 0
