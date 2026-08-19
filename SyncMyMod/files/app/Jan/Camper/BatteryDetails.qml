import QtQuick 2.6

Item {
    id: view

    property bool dayMode: false
    property var battery: ({})
    signal backRequested()

    property color panelColor: dayMode ? "#ffffff" : "#111a21"
    property color innerColor: dayMode ? "#f0f3f5" : "#0d151b"
    property color textColor: dayMode ? "#172028" : "#f3f7f9"
    property color mutedColor: dayMode ? "#63707a" : "#84939e"
    property color lineColor: dayMode ? "#cbd3d8" : "#293842"
    property color greenColor: "#35d2a1"
    property color blueColor: "#36c3fa"

    function fmt(value, digits, suffix) {
        if (value === null || value === undefined || value === "" || !isFinite(Number(value))) return "–"
        return Number(value).toFixed(digits) + (suffix || "")
    }
    function signed(value, digits, suffix) {
        if (value === null || value === undefined || !isFinite(Number(value))) return "–"
        var number = Number(value)
        return (number > 0 ? "+" : "") + number.toFixed(digits) + (suffix || "")
    }
    function duration(seconds) {
        if (seconds === null || seconds === undefined || !isFinite(Number(seconds))) return "–"
        var hours = Math.floor(Number(seconds) / 3600)
        var minutes = Math.floor((Number(seconds) % 3600) / 60)
        return hours + " h " + minutes + " min"
    }

    Rectangle {
        x: 10; y: 8; width: 780; height: 56; radius: 13; color: view.panelColor; border.color: view.lineColor
        TouchButton { x: 8; y: 9; width: 76; height: 38; label: "ZURÜCK"; onClicked: view.backRequested() }
        Text { x: 98; y: 8; text: "SMARTSHUNT BATTERIEN"; color: view.textColor; font.pixelSize: 15; font.bold: true }
        Text { x: 98; y: 31; text: "Hauptbatterie und Messung 2 / Starterbatterie"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Rectangle { x: 686; y: 22; width: 8; height: 8; radius: 4; color: view.battery.online ? view.greenColor : "#e05e68" }
        Text { x: 703; y: 18; width: 63; text: view.battery.online ? "ONLINE" : "OFFLINE"; color: view.battery.online ? view.greenColor : "#e05e68"; font.pixelSize: 9; font.bold: true }
    }

    Rectangle {
        x: 10; y: 72; width: 244; height: 342; radius: 13; color: view.innerColor; border.color: view.lineColor
        Text { x: 16; y: 15; text: "AUFBAUBATTERIE"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Rectangle { x: 36; y: 49; width: 172; height: 172; radius: 86; color: view.panelColor; border.color: view.greenColor; border.width: 5 }
        Text { x: 36; y: 91; width: 172; horizontalAlignment: Text.AlignHCenter; text: view.fmt(view.battery.soc, 0, " %"); color: view.greenColor; font.pixelSize: 35; font.bold: true }
        Text { x: 36; y: 139; width: 172; horizontalAlignment: Text.AlignHCenter; text: "LADEZUSTAND"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Text { x: 36; y: 169; width: 172; horizontalAlignment: Text.AlignHCenter; text: view.fmt(view.battery.voltage, 2, " V"); color: view.textColor; font.pixelSize: 18; font.bold: true }
        Text { x: 16; y: 250; width: 212; horizontalAlignment: Text.AlignHCenter; text: view.signed(view.battery.power, 0, " W"); color: view.textColor; font.pixelSize: 24; font.bold: true }
        Text { x: 16; y: 285; width: 212; horizontalAlignment: Text.AlignHCenter; text: view.signed(view.battery.current, 1, " A"); color: view.mutedColor; font.pixelSize: 14; font.bold: true }
        Text { x: 16; y: 316; width: 212; horizontalAlignment: Text.AlignHCenter; text: "SmartShunt · Instanz 277"; color: view.mutedColor; font.pixelSize: 8 }
    }

    Rectangle {
        x: 262; y: 72; width: 528; height: 112; radius: 13
        color: view.battery.starterVoltage !== null && view.battery.starterVoltage !== undefined ? (view.dayMode ? "#e1f2fb" : "#102b39") : view.innerColor
        border.color: view.battery.starterVoltage !== null && view.battery.starterVoltage !== undefined ? view.blueColor : view.lineColor; border.width: 2
        LineIcon { x: 18; y: 22; width: 54; height: 54; kind: "battery"; lineColor: view.blueColor; strokeWidth: 2.2 }
        Text { x: 88; y: 19; text: "MESSUNG 2 · STARTERBATTERIE"; color: view.mutedColor; font.pixelSize: 10; font.bold: true }
        Text { x: 88; y: 43; text: view.fmt(view.battery.starterVoltage, 2, " V"); color: view.blueColor; font.pixelSize: 30; font.bold: true }
        Text { x: 88; y: 82; text: view.battery.starterVoltage !== null && view.battery.starterVoltage !== undefined ? "SmartShunt AUX-Eingang" : "Kein Messwert – AUX-Konfiguration am SmartShunt prüfen"; color: view.mutedColor; font.pixelSize: 9 }
    }

    Rectangle {
        x: 262; y: 192; width: 528; height: 222; radius: 13; color: view.innerColor; border.color: view.lineColor
        Text { x: 16; y: 13; text: "BATTERIE"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Repeater {
            model: [
                { title: "SPANNUNG", value: view.fmt(view.battery.voltage, 2, " V") },
                { title: "STROM", value: view.signed(view.battery.current, 1, " A") },
                { title: "LEISTUNG", value: view.signed(view.battery.power, 0, " W") },
                { title: "VERBRAUCHT", value: view.fmt(view.battery.consumedAh, 1, " Ah") },
                { title: "RESTZEIT", value: view.duration(view.battery.timeToGoSeconds) },
                { title: "KAPAZITÄT", value: view.fmt(view.battery.installedCapacityAh, 0, " Ah") }
            ]
            delegate: Rectangle {
                property int column: index % 3
                property int row: Math.floor(index / 3)
                x: 14 + column * 169; y: 38 + row * 84; width: 159; height: 74; radius: 10
                color: view.panelColor; border.color: view.lineColor
                Text { x: 11; y: 11; text: modelData.title; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
                Text { x: 11; y: 32; width: 137; elide: Text.ElideRight; text: modelData.value; color: view.textColor; font.pixelSize: 17; font.bold: true }
            }
        }
    }
}
