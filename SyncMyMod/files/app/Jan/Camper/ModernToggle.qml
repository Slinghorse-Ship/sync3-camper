import QtQuick 2.6

Rectangle {
    id: toggle
    property bool checked: false
    property color accentColor: "#35bdf5"
    signal clicked()
    width: 58
    height: 30
    radius: 15
    color: checked ? accentColor : "#33414d"
    border.color: checked ? accentColor : "#60707d"

    Rectangle {
        x: toggle.checked ? 31 : 3
        y: 3
        width: 24
        height: 24
        radius: 12
        color: "#f8fbfd"
    }
    MouseArea { anchors.fill: parent; onClicked: toggle.clicked() }
}
