import QtQuick 2.6

Rectangle {
    id: tile
    property bool dayMode: false
    property string icon: "power"
    property string caption: ""
    property string value: ""
    property string detail: ""
    property bool active: false
    property color accentColor: "#45c9fa"
    signal clicked()
    radius: 14
    color: active ? (dayMode ? "#dff3fb" : "#102a38") : (dayMode ? "#ffffff" : "#111b23")
    border.color: active ? accentColor : (dayMode ? "#cbd3d9" : "#2c3b46")

    LineIcon { x: 12; y: 10; width: 46; height: 46; kind: tile.icon; lineColor: tile.active ? tile.accentColor : (tile.dayMode ? "#53626d" : "#c7d0d7"); strokeWidth: 2.2 }
    Text { x: 62; y: 12; width: parent.width - 74; elide: Text.ElideRight; text: tile.caption; color: tile.dayMode ? "#5c6871" : "#8e9ca7"; font.pixelSize: 9; font.bold: true }
    Text { x: 62; y: 29; width: parent.width - 74; elide: Text.ElideRight; text: tile.value; color: tile.active ? tile.accentColor : (tile.dayMode ? "#182027" : "#f1f6f9"); font.pixelSize: 19; font.bold: true }
    Text { x: 14; y: parent.height - 22; width: parent.width - 28; elide: Text.ElideRight; text: tile.detail; color: tile.dayMode ? "#66727b" : "#82919d"; font.pixelSize: 9 }
    MouseArea { anchors.fill: parent; onClicked: tile.clicked() }
}
