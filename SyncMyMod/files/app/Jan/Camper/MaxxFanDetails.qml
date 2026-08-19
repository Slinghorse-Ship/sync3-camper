import QtQuick 2.6

Item {
    id: view

    property bool dayMode: false
    property var fan: ({})
    signal backRequested()
    signal commandRequested(string action, var value)

    property color panelColor: dayMode ? "#ffffff" : "#111a21"
    property color innerColor: dayMode ? "#f0f3f5" : "#0d151b"
    property color textColor: dayMode ? "#172028" : "#f3f7f9"
    property color mutedColor: dayMode ? "#63707a" : "#84939e"
    property color lineColor: dayMode ? "#cbd3d8" : "#293842"
    property color blueColor: dayMode ? "#0074bd" : "#36c3fa"
    property color greenColor: "#35d2a1"

    function fmt(value, digits, suffix) {
        if (value === null || value === undefined || value === "" || !isFinite(Number(value))) return "–"
        return Number(value).toFixed(digits) + (suffix || "")
    }

    Rectangle {
        x: 10; y: 8; width: 780; height: 56; radius: 13
        color: view.panelColor; border.color: view.fan.online ? view.greenColor : view.lineColor
        TouchButton { x: 8; y: 9; width: 76; height: 38; label: "ZURÜCK"; onClicked: view.backRequested() }
        LineIcon { x: 98; y: 10; width: 35; height: 35; kind: "fan"; lineColor: view.fan.on ? view.blueColor : view.mutedColor; strokeWidth: 2 }
        Text { x: 143; y: 8; text: view.fan.name || "MAXXFAN"; color: view.textColor; font.pixelSize: 15; font.bold: true }
        Text { x: 143; y: 31; text: "VanTurtle WLAN-Steuerung · STAR-Power CH " + Number(view.fan.powerChannel || 6); color: view.mutedColor; font.pixelSize: 9 }
        Rectangle { x: 502; y: 22; width: 9; height: 9; radius: 5; color: view.fan.online ? view.greenColor : "#ef6e76" }
        Text { x: 520; y: 18; text: view.fan.online ? "VERBUNDEN" : "NICHT VERBUNDEN"; color: view.fan.online ? view.greenColor : "#ef6e76"; font.pixelSize: 9; font.bold: true }
        TouchButton { x: 650; y: 9; width: 116; height: 38; label: view.fan.on ? "AUSSCHALTEN" : "EINSCHALTEN"; active: view.fan.on === true; onClicked: view.commandRequested("set", !view.fan.on) }
    }

    Rectangle {
        x: 10; y: 72; width: 246; height: 342; radius: 13
        color: view.innerColor; border.color: view.lineColor
        Text { x: 14; y: 13; text: "STATUS"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Text { x: 14; y: 42; text: view.fmt(view.fan.speed, 0, " %"); color: view.fan.on ? view.blueColor : view.textColor; font.pixelSize: 36; font.bold: true }
        Text { x: 14; y: 87; text: view.fan.on ? "LÜFTER AKTIV" : "LÜFTER AUS"; color: view.fan.on ? view.greenColor : view.mutedColor; font.pixelSize: 10; font.bold: true }
        Rectangle { x: 14; y: 116; width: 218; height: 1; color: view.lineColor }
        Text { x: 14; y: 136; text: "Richtung"; color: view.mutedColor; font.pixelSize: 9 }
        Text { x: 126; y: 132; width: 106; horizontalAlignment: Text.AlignRight; text: view.fan.mode === "reverse" ? "RÜCKWÄRTS" : "VORWÄRTS"; color: view.textColor; font.pixelSize: 11; font.bold: true }
        Text { x: 14; y: 171; text: "Automatik"; color: view.mutedColor; font.pixelSize: 9 }
        Text { x: 126; y: 167; width: 106; horizontalAlignment: Text.AlignRight; text: view.fan.autoHold ? "AKTIV" : "AUS"; color: view.fan.autoHold ? view.greenColor : view.textColor; font.pixelSize: 11; font.bold: true }
        Text { x: 14; y: 206; text: "Versorgung"; color: view.mutedColor; font.pixelSize: 9 }
        Text { x: 126; y: 202; width: 106; horizontalAlignment: Text.AlignRight; text: view.fan.powered ? "BEREIT" : "CH 6 AUS"; color: view.fan.powered ? view.greenColor : "#ef6e76"; font.pixelSize: 11; font.bold: true }
        Rectangle { x: 14; y: 235; width: 218; height: 1; color: view.lineColor }
        Text { x: 14; y: 253; text: "Spannung"; color: view.mutedColor; font.pixelSize: 9 }
        Text { x: 126; y: 249; width: 106; horizontalAlignment: Text.AlignRight; text: view.fmt(view.fan.voltage, 1, " V"); color: view.textColor; font.pixelSize: 11; font.bold: true }
        Text { x: 14; y: 280; text: "Strom"; color: view.mutedColor; font.pixelSize: 9 }
        Text { x: 126; y: 276; width: 106; horizontalAlignment: Text.AlignRight; text: view.fmt(view.fan.current, 1, " A"); color: view.textColor; font.pixelSize: 11; font.bold: true }
        Text { x: 14; y: 307; text: "Leistung"; color: view.mutedColor; font.pixelSize: 9 }
        Text { x: 126; y: 303; width: 106; horizontalAlignment: Text.AlignRight; text: view.fmt(view.fan.power, 1, " W"); color: view.textColor; font.pixelSize: 11; font.bold: true }
    }

    Rectangle {
        x: 264; y: 72; width: 526; height: 342; radius: 13
        color: view.innerColor; border.color: view.lineColor
        Text { x: 14; y: 13; text: "LÜFTERSTUFE"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        TouchButton { x: 14; y: 35; width: 54; height: 46; label: "−"; onClicked: view.commandRequested("speed", Math.max(0, Number(view.fan.speed || 0) - 10)) }
        Text { x: 77; y: 45; width: 96; horizontalAlignment: Text.AlignHCenter; text: view.fmt(view.fan.speed, 0, " %"); color: view.textColor; font.pixelSize: 20; font.bold: true }
        TouchButton { x: 182; y: 35; width: 54; height: 46; label: "+"; onClicked: view.commandRequested("speed", Math.min(100, Number(view.fan.speed || 0) + 10)) }
        Repeater {
            model: [10, 30, 50, 70, 100]
            delegate: TouchButton {
                x: 250 + index * 51; y: 35; width: 46; height: 46
                label: modelData + "%"; active: Number(view.fan.speed || 0) === modelData
                onClicked: view.commandRequested("speed", modelData)
            }
        }

        Rectangle { x: 14; y: 96; width: 498; height: 1; color: view.lineColor }
        Text { x: 14; y: 113; text: "LUFTRICHTUNG"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        TouchButton { x: 14; y: 135; width: 236; height: 47; label: "VORWÄRTS"; active: view.fan.mode !== "reverse"; onClicked: view.commandRequested("mode", "forward") }
        TouchButton { x: 262; y: 135; width: 250; height: 47; label: "RÜCKWÄRTS"; active: view.fan.mode === "reverse"; onClicked: view.commandRequested("mode", "reverse") }

        Rectangle { x: 14; y: 198; width: 498; height: 1; color: view.lineColor }
        Text { x: 14; y: 215; text: "HAUBE & AUTOMATIK"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        TouchButton { x: 14; y: 237; width: 236; height: 48; label: "HAUBE UMSCHALTEN"; active: Number(view.fan.lid) === 1; onClicked: view.commandRequested("lid", true) }
        TouchButton { x: 262; y: 237; width: 250; height: 48; label: view.fan.autoHold ? "AUTOMATIK AUS" : "AUTOMATIK AN"; active: view.fan.autoHold === true; onClicked: view.commandRequested("auto", !view.fan.autoHold) }
        Text { x: 14; y: 302; width: 498; text: view.fan.calibrating ? "Kalibrierung läuft" : (view.fan.calibrated ? "Controller kalibriert" : "Controller noch nicht kalibriert"); color: view.fan.calibrated ? view.greenColor : view.mutedColor; font.pixelSize: 10; font.bold: true }
    }
}
