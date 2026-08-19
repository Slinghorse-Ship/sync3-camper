import QtQuick 2.6

Item {
    id: overlay
    visible: false
    enabled: visible
    z: 500

    property string lightTitle: "LICHT"
    property string iconKind: "cabinLight"
    property int channel: 0
    property bool lightOn: false
    property int level: 0
    property int initialLevel: 0
    property bool dayMode: false
    property color accentColor: "#31c9f4"
    property color textColor: dayMode ? "#172028" : "#f4f8fb"
    property color mutedColor: dayMode ? "#64717b" : "#91a1af"
    property color sheetColor: dayMode ? "#ffffff" : "#08131c"
    property color innerColor: dayMode ? "#edf2f5" : "#142331"

    signal toggleRequested(int channel, bool enabled)
    signal dimRequested(int channel, int value)

    function clamp(value) { return Math.max(0, Math.min(100, Math.round(Number(value)))) }
    function open(title, kind, selectedChannel, enabled, currentLevel) {
        lightTitle = title
        iconKind = kind
        channel = Number(selectedChannel)
        lightOn = enabled === true
        level = clamp(currentLevel)
        initialLevel = level
        visible = true
    }
    function close() { visible = false }
    function levelFromX(mouseX) { return clamp((mouseX / sliderTouch.width) * 100) }
    function commit(value) {
        level = clamp(value)
        initialLevel = level
        if (channel > 0) dimRequested(channel, level)
    }

    Rectangle {
        anchors.fill: parent
        color: overlay.dayMode ? "#b8dce4e8" : "#d9070c12"
        MouseArea { anchors.fill: parent; onClicked: overlay.close() }
    }

    Rectangle {
        id: sheet
        x: 8; y: 34; width: 784; height: 322; radius: 22
        color: overlay.sheetColor
        border.color: overlay.lightOn ? overlay.accentColor : (overlay.dayMode ? "#c8d2d8" : "#294050")
        border.width: 2

        MouseArea { anchors.fill: parent }

        Rectangle { x: 342; y: 9; width: 100; height: 5; radius: 3; color: overlay.dayMode ? "#aebbc3" : "#405363" }

        LineIcon {
            x: 28; y: 28; width: 42; height: 42
            kind: overlay.iconKind
            lineColor: overlay.lightOn ? overlay.accentColor : overlay.mutedColor
            strokeWidth: 2.2
        }
        Text {
            x: 82; y: 28; width: 360; height: 42
            verticalAlignment: Text.AlignVCenter
            text: overlay.lightTitle
            color: overlay.lightOn ? overlay.accentColor : overlay.textColor
            font.pixelSize: 20; font.bold: true
        }
        Rectangle {
            x: 598; y: 22; width: 108; height: 52; radius: 15
            color: overlay.lightOn ? (overlay.dayMode ? "#dff4ed" : "#153c33") : overlay.innerColor
            border.color: overlay.lightOn ? "#35d2a1" : (overlay.dayMode ? "#c8d2d8" : "#314655")
            Text { anchors.centerIn: parent; text: overlay.lightOn ? "AN" : "AUS"; color: overlay.lightOn ? "#35d2a1" : overlay.textColor; font.pixelSize: 16; font.bold: true }
            MouseArea {
                anchors.fill: parent
                onClicked: if (overlay.channel > 0) {
                    overlay.toggleRequested(overlay.channel, !overlay.lightOn)
                    overlay.lightOn = !overlay.lightOn
                }
            }
        }
        Rectangle {
            x: 720; y: 22; width: 48; height: 52; radius: 15
            color: closeTouch.pressed ? overlay.innerColor : "transparent"
            border.color: overlay.dayMode ? "#c8d2d8" : "#314655"
            Text { anchors.centerIn: parent; text: "\u00d7"; color: overlay.textColor; font.pixelSize: 28 }
            MouseArea { id: closeTouch; anchors.fill: parent; onClicked: overlay.close() }
        }

        Text {
            x: 28; y: 88; width: 728; height: 58
            horizontalAlignment: Text.AlignHCenter
            text: overlay.level + " %"
            color: overlay.textColor
            font.pixelSize: 43; font.bold: true
        }

        Rectangle {
            id: sliderTrack
            x: 62; y: 166; width: 660; height: 58; radius: 29
            color: overlay.innerColor
            border.color: overlay.dayMode ? "#c8d2d8" : "#294050"
            Rectangle {
                x: 4; y: 4; height: 50; radius: 25
                width: Math.max(50, (sliderTrack.width - 8) * overlay.level / 100)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#14b8d4" }
                    GradientStop { position: 1.0; color: overlay.accentColor }
                }
            }
            Rectangle {
                width: 50; height: 50; radius: 25; y: 4
                x: 4 + (sliderTrack.width - 58) * overlay.level / 100
                color: overlay.dayMode ? "#ffffff" : "#071018"
                border.color: overlay.accentColor; border.width: 4
            }
            MouseArea {
                id: sliderTouch
                anchors.fill: parent
                preventStealing: true
                onPressed: overlay.level = overlay.levelFromX(mouse.x)
                onPositionChanged: if (pressed) overlay.level = overlay.levelFromX(mouse.x)
                onReleased: overlay.commit(overlay.level)
            }
        }

        Repeater {
            model: [0, 25, 50, 75, 100]
            delegate: Rectangle {
                property int preset: modelData
                x: 91 + index * 124; y: 249; width: 106; height: 48; radius: 16
                color: overlay.level === preset ? overlay.accentColor : overlay.innerColor
                border.color: overlay.level === preset ? overlay.accentColor : (overlay.dayMode ? "#c8d2d8" : "#314655")
                Text { anchors.centerIn: parent; text: preset + "%"; color: overlay.level === preset ? "#041017" : overlay.textColor; font.pixelSize: 14; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: overlay.commit(preset) }
            }
        }
    }
}
