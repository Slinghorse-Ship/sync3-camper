import QtQuick 2.6
import AL2HMIBridge 1.0 as AL2HMIBridge

Rectangle {
    id: root

    property bool dayMode: AL2HMIBridge.globalSource.dayMode

    property string label: "BUTTON"
    property int fontSize: 12
    property bool active: false
    property color accentColor: visual.green
    signal clicked()

    CamperStyle { id: visual; dayMode: root.dayMode }

    radius: 10
    color: !enabled ? visual.disabled : (touch.pressed ? visual.pressed : (active ? visual.selectedGreen : visual.panel))
    border.color: active ? accentColor : (touch.pressed ? visual.muted : visual.border)
    border.width: active ? 2 : 1
    opacity: enabled ? 1 : 0.5

    Rectangle {
        x: 8; y: 5; width: parent.width - 16; height: 1; radius: 1
        color: root.active ? root.accentColor : visual.muted
        opacity: touch.pressed ? 0 : 0.28
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: visual.text
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
