#!/bin/sh

# Rewrites only the visibility expression of the existing Camper loader.
# The output is prepared beside Root.qml and moved into place atomically.
TARGET="$1"
TMP="$2"

if [ -z "$TARGET" ] || [ -z "$TMP" ] || [ ! -f "$TARGET" ]; then
    exit 20
fi

awk '
BEGIN {
    in_loader = 0
    skipping_visibility = 0
    replaced = 0
}
{
    if ($0 ~ /^[[:space:]]*id:[[:space:]]*camperControlLoader[[:space:]]*$/) {
        in_loader = 1
    }

    if (in_loader && !skipping_visibility && $0 ~ /^[[:space:]]*visible:[[:space:]]*active/) {
        print "        visible: active"
        print "                 && !ViewController.qrvc"
        print "                 && viewContainer.fullScreenViewActive === 0"
        print "                 && !root.fullScreenPopupActive"
        print "                 && !root.hasActivePopup"
        print "                 && !ViewController.transparentWindowPopupShown"
        print "                 && !root.fullScreenTransparentPopupStacked"
        print "                 && !(ViewManager.activeViewItem && ViewManager.activeViewItem.transparentWindow)"
        skipping_visibility = 1
        replaced++
        next
    }

    if (skipping_visibility) {
        if ($0 ~ /^[[:space:]]*source:[[:space:]]*active/) {
            skipping_visibility = 0
            print $0
        }
        next
    }

    print $0
}
END {
    if (replaced != 1 || skipping_visibility) {
        exit 42
    }
}
' "$TARGET" > "$TMP" || {
    rm -f "$TMP"
    exit 21
}

if ! grep -q "!root.hasActivePopup" "$TMP" \
   || ! grep -q "!ViewController.transparentWindowPopupShown" "$TMP" \
   || ! grep -q "ViewManager.activeViewItem.transparentWindow" "$TMP"; then
    rm -f "$TMP"
    exit 22
fi

mv "$TMP" "$TARGET" || {
    rm -f "$TMP"
    exit 23
}

exit 0
