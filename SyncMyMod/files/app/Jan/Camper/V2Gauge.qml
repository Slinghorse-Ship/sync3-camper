import QtQuick 2.6

Item {
    id: gauge
    property real value: 0
    property string primaryText: "–"
    property string secondaryText: ""
    property bool dayMode: false
    property color accentColor: "#36b8ff"

    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: gauge; onValueChanged: parent.requestPaint(); onDayModeChanged: parent.requestPaint(); onAccentColorChanged: parent.requestPaint() }
        onPaint: {
            var c = getContext("2d")
            c.clearRect(0, 0, width, height)
            var radius = Math.min(width, height) / 2 - 7
            var start = -Math.PI / 2
            c.lineWidth = 8
            c.lineCap = "round"
            c.strokeStyle = gauge.dayMode ? "#dce5e9" : "#26343f"
            c.beginPath(); c.arc(width / 2, height / 2, radius, 0, Math.PI * 2); c.stroke()
            c.strokeStyle = gauge.accentColor
            c.beginPath(); c.arc(width / 2, height / 2, radius, start, start + Math.PI * 2 * Math.max(0, Math.min(100, gauge.value)) / 100); c.stroke()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 3
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: gauge.primaryText; color: gauge.dayMode ? "#10161a" : "#f3f7fa"; font.pixelSize: 29; font.bold: true }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: gauge.secondaryText; color: gauge.dayMode ? "#60717b" : "#8da0ad"; font.pixelSize: 8 }
    }
}
