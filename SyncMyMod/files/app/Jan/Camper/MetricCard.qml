import QtQuick 2.6
import AL2HMIBridge 1.0 as AL2HMIBridge

Rectangle {
    id: root

    property bool dayMode: AL2HMIBridge.globalSource.dayMode

    property string caption: "WERT"
    property string value: "–"
    property string detail: ""
    property color valueColor: visual.text
    property color accentColor: valueColor

    CamperStyle { id: visual; dayMode: root.dayMode }

    radius: 14
    color: visual.panel
    border.color: visual.border

    Rectangle { x: 0; y: 13; width: 4; height: parent.height - 26; radius: 2; color: root.accentColor }
    Rectangle { x: 13; y: 1; width: parent.width - 26; height: 1; color: visual.muted; opacity: 0.24 }

    Text {
        x: 12
        y: 10
        text: root.caption
        color: root.accentColor
        font.pixelSize: 10
        font.bold: true
    }

    Text {
        x: 12
        y: 29
        text: root.value
        color: root.valueColor
        font.pixelSize: 26
        font.bold: true
    }

    Text {
        x: 12
        y: 61
        width: parent.width - 24
        elide: Text.ElideRight
        text: root.detail
        color: visual.muted
        font.pixelSize: 9
    }
}
