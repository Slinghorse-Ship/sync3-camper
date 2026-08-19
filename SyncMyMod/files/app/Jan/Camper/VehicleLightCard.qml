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
    property color primaryText: visual.text
    property color secondaryText: visual.muted
    signal toggleRequested(int channel, bool enabled)
    signal dimRequested(int channel, int value)
    signal dimmerRequested(string title, string iconKind, int channel, bool enabled, int value)

    CamperStyle { id: visual; dayMode: card.dayMode }

    width: 154; height: 112; radius: 12
    color: lightOn ? visual.selectedBlue : visual.panel
    border.color: lightOn ? visual.blue : visual.border
    border.width: lightOn ? 2 : 1

    LineIcon { x: 54; y: 8; width: 46; height: 46; kind: card.iconKind; lineColor: card.lightOn ? visual.blue : card.secondaryText; strokeWidth: 2.1 }
    Text { x: 8; y: 58; width: 138; elide: Text.ElideRight; text: card.title; color: card.lightOn ? visual.blue : card.primaryText; font.pixelSize: card.title.length > 17 ? 9 : 10; font.bold: true; horizontalAlignment: Text.AlignHCenter }
    Text { x: 8; y: 78; width: 138; text: card.dimming + " %"; color: card.lightOn ? visual.blue : card.secondaryText; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter }
    MouseArea { anchors.fill: parent; onClicked: card.toggleRequested(card.channel, !card.lightOn) }
    Rectangle {
        x: 12; y: 102; width: 130; height: 5; radius: 3
        color: visual.border
        Rectangle { width: parent.width * Math.max(0, Math.min(100, card.dimming)) / 100; height: parent.height; radius: 3; color: card.lightOn ? visual.blue : card.secondaryText }
        MouseArea {
            x: -8; y: -12; width: parent.width + 16; height: 29
            onClicked: card.dimmerRequested(card.title, card.iconKind, card.channel, card.lightOn, card.dimming)
        }
    }
}
