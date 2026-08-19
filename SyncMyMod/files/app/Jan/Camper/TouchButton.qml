import QtQuick 2.6
import AL2HMIBridge 1.0 as AL2HMIBridge

Rectangle {
    id: root

    property bool dayMode: AL2HMIBridge.globalSource.dayMode

    property string label: "BUTTON"
    property int fontSize: 12
    property bool active: false
    property color accentColor: "#32d4a0"
    signal clicked()

    radius: 10
    color: !enabled ? (dayMode ? "#dde1e4" : "#18212a") : (touch.pressed ? (dayMode ? "#ccd6df" : "#3b4b59") : (active ? (dayMode ? "#d9edf9" : "#185844") : (dayMode ? "#ffffff" : "#222e38")))
    border.color: active ? (dayMode ? "#0067b9" : accentColor) : (touch.pressed ? (dayMode ? "#6d879b" : "#627485") : (dayMode ? "#b9c1c8" : "#344451"))
    border.width: active ? 2 : 1
    opacity: enabled ? 1 : 0.5

    Rectangle {
        x: 8; y: 5; width: parent.width - 16; height: 1; radius: 1
        color: root.active ? (root.dayMode ? "#0067b9" : root.accentColor) : (root.dayMode ? "#aab2b9" : "#536370")
        opacity: touch.pressed ? 0 : 0.28
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.dayMode ? "#20252a" : "#f4f8fb"
        font.pixelSize: root.fontSize
        font.bold: true
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
