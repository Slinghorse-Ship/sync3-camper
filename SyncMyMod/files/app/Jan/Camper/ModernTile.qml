import QtQuick 2.6

Rectangle {
    id: tile
    property bool dayMode: false
    property string icon: "power"
    property string caption: ""
    property string value: ""
    property string detail: ""
    property bool active: false
    property color accentColor: visual.blue
    signal clicked()
    CamperStyle { id: visual; dayMode: tile.dayMode }
    radius: 14
    color: active ? visual.selectedBlue : visual.panel
    border.color: active ? accentColor : visual.border

    LineIcon { x: 12; y: 10; width: 46; height: 46; kind: tile.icon; lineColor: tile.active ? tile.accentColor : visual.muted; strokeWidth: 2.2 }
    Text { x: 62; y: 12; width: parent.width - 74; elide: Text.ElideRight; text: tile.caption; color: visual.muted; font.pixelSize: 9; font.bold: true }
    Text { x: 62; y: 29; width: parent.width - 74; elide: Text.ElideRight; text: tile.value; color: visual.text; font.pixelSize: 19; font.bold: true }
    Text { x: 14; y: parent.height - 22; width: parent.width - 28; elide: Text.ElideRight; text: tile.detail; color: visual.muted; font.pixelSize: 9 }
    MouseArea { anchors.fill: parent; onClicked: tile.clicked() }
}
