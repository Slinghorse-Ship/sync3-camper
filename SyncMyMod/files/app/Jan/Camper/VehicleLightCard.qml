import QtQuick 2.6

Rectangle {
    id: card
    property string title: "LICHT"
    property string iconKind: "workLight"
    property int channel: 0
    property bool lightOn: false
    property int dimming: 0
    property int previewDimming: dimming
    property bool dayMode: false
    property color primaryText: dayMode ? "#20252a" : "#f4f8fb"
    property color secondaryText: dayMode ? "#59636c" : "#91a1af"
    signal toggleRequested(int channel, bool enabled)
    signal dimRequested(int channel, int value)
    signal dimmerRequested(string title, string iconKind, int channel, bool enabled, int value)

    width: 154; height: 112; radius: 12
    color: lightOn ? (dayMode ? "#d9edf9" : "#132f43") : (dayMode ? "#ffffff" : "#151f28")
    border.color: lightOn ? "#19a7ff" : (dayMode ? "#c8cdd2" : "#2b3946")
    border.width: lightOn ? 2 : 1

    LineIcon { x: 54; y: 8; width: 46; height: 46; kind: card.iconKind; lineColor: card.lightOn ? "#19a7ff" : card.secondaryText; strokeWidth: 2.1 }
    Text { x: 8; y: 58; width: 138; elide: Text.ElideRight; text: card.title; color: card.lightOn ? "#19a7ff" : card.primaryText; font.pixelSize: card.title.length > 17 ? 9 : 10; font.bold: true; horizontalAlignment: Text.AlignHCenter }
    Text { x: 8; y: 78; width: 138; text: card.dimming + " %"; color: card.lightOn ? "#19a7ff" : card.secondaryText; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter }
    MouseArea { anchors.fill: parent; onClicked: card.toggleRequested(card.channel, !card.lightOn) }
    Rectangle {
        x: 12; y: 102; width: 130; height: 5; radius: 3
        color: card.dayMode ? "#d8e0e5" : "#2a3945"
        Rectangle { width: parent.width * Math.max(0, Math.min(100, card.dimming)) / 100; height: parent.height; radius: 3; color: card.lightOn ? "#19a7ff" : card.secondaryText }
        MouseArea {
            x: -8; y: -12; width: parent.width + 16; height: 29
            onClicked: card.dimmerRequested(card.title, card.iconKind, card.channel, card.lightOn, card.dimming)
        }
    }
}
