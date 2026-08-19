#!/bin/sh

# Atomically prepares a status-bar copy for upgrades through CamperControl
# 3.9.7. The obsolete RVC shortcut (icon, touch/drag handler and camera
# command helpers) is removed completely. This does not touch Root.qml, where
# the real rear/front camera and parking overlays are managed.
SOURCE="$1"
OUTPUT="$2"

if [ -z "$SOURCE" ] || [ -z "$OUTPUT" ] || [ ! -f "$SOURCE" ]; then
    exit 20
fi

awk '
function braces(line,    opened, closed, copy) {
    copy=line; opened=gsub(/\{/, "", copy)
    copy=line; closed=gsub(/\}/, "", copy)
    return opened-closed
}
function emit_block() {
    print "    // CamperControl: independent overlay in the former RVC shortcut position."
    print "    Item {"
    print "        id: camperShortcutItem"
    print "        objectName: \"StatusBarCamperShortcut\""
    print "        parent: root.parent"
    print "        x: parent ? root.mapToItem(parent, camperStoredX(), 0).x : 0"
    print "        y: parent ? root.mapToItem(parent, 0, 0).y : 0"
    print "        width: 60"
    print "        height: 54"
    print "        z: 1000"
    print "        visible: ViewManager.activeDomain !== HmiGui.CalmDomain"
    print ""
    print "        function camperStoredX() {"
    print "            var xhr = new XMLHttpRequest()"
    print "            xhr.open(\"GET\", \"file:///fs/rwdata/fmods/mods/rvc-on-demand/camera_icon_position\", false)"
    print "            xhr.send()"
    print "            var value = Number(xhr.responseText)"
    print "            return isNaN(value) ? 0 : value"
    print "        }"
    print ""
    print "        HmiImage {"
    print "            anchors.fill: parent"
    print "            source: UiTheme.palette.image(\"statusBarHomeButton_pressed\")"
    print "            opacity: camperTouchArea.pressed ? 1 : 0"
    print "        }"
    print ""
    print "        Image {"
    print "            anchors.centerIn: parent"
    print "            width: 46"
    print "            height: 46"
    print "            source: \"file:///fs/mp/fordhmi/qml/hmicustomapps/apps/Jan/Camper/Icon.png\""
    print "            fillMode: Image.PreserveAspectFit"
    print "        }"
    print ""
    print "        Timer {"
    print "            id: camperOpenTimer"
    print "            interval: 10"
    print "            repeat: false"
    print "            onTriggered: CamperBridge.CamperState.camperOpen = true"
    print "        }"
    print ""
    print "        MouseArea {"
    print "            id: camperTouchArea"
    print "            anchors.fill: parent"
    print "            preventStealing: true"
    print "            propagateComposedEvents: false"
    print "            onClicked: {"
    print "                CamperBridge.CamperState.camperOpen = false"
    print "                camperOpenTimer.restart()"
    print "            }"
    print "        }"
    print "    }"
}
function consume_block(first,    depth, line) {
    depth=braces(first)
    while (depth > 0 && (getline line) > 0) depth+=braces(line)
    return depth
}
BEGIN { rvc_removed=0; helper_removed=0; camper_seen=0 }
{
    if ($0 ~ /^[[:space:]]*Item[[:space:]]*\{[[:space:]]*$/) {
        first=$0
        if ((getline second) <= 0) { print first; next }
        if (second ~ /^[[:space:]]*id:[[:space:]]*rvcShortcutItem[[:space:]]*$/) {
            depth=braces(first)+braces(second)
            while (depth > 0 && (getline line) > 0) depth+=braces(line)
            emit_block()
            rvc_removed++
            next
        }
        print first
        print second
        next
    }
    if ($0 ~ /^[[:space:]]*function[[:space:]]+(setStatus|readPosition|writePosition)[[:space:]]*\(/) {
        if (consume_block($0) != 0) exit 43
        helper_removed++
        next
    }
    if ($0 ~ /id:[[:space:]]*camperShortcutItem/) camper_seen++
    print
}
END {
    if (rvc_removed != 1 || helper_removed != 3 || camper_seen != 0) exit 42
}
' "$SOURCE" > "$OUTPUT" || {
    rm -f "$OUTPUT"
    exit 21
}

if grep -q "id: rvcShortcutItem\|id: rvcIcon\|camera_manager enable\|function setStatus\|function readPosition\|function writePosition" "$OUTPUT" \
   || ! grep -q 'objectName: "StatusBarCamperShortcut"' "$OUTPUT" \
   || ! grep -q "parent: root.parent" "$OUTPUT" \
   || ! grep -q "width: 60" "$OUTPUT" \
   || ! grep -q "height: 54" "$OUTPUT" \
   || ! grep -q "width: 46" "$OUTPUT" \
   || ! grep -q "height: 46" "$OUTPUT" \
   || ! grep -q "camperOpenTimer.restart()" "$OUTPUT" \
   || ! grep -q "propagateComposedEvents: false" "$OUTPUT"; then
    rm -f "$OUTPUT"
    exit 22
fi

exit 0
