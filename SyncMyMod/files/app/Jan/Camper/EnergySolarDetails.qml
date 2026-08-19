import QtQuick 2.6

Item {
    id: view

    property bool dayMode: false
    property var solar: ({})
    property var indevolt: ({})
    property var orion: ({})
    property var chargers: solar.chargers || []
    signal backRequested()
    signal orionCommandRequested(bool enabledState)
    signal indevoltGridCommandRequested(bool enabledState)

    property color panelColor: dayMode ? "#ffffff" : "#111a21"
    property color innerColor: dayMode ? "#f0f3f5" : "#0d151b"
    property color textColor: dayMode ? "#172028" : "#f3f7f9"
    property color mutedColor: dayMode ? "#63707a" : "#84939e"
    property color lineColor: dayMode ? "#cbd3d8" : "#293842"
    property color solarColor: "#f4c94c"
    property color greenColor: "#35d2a1"

    function fmt(value, digits, suffix) {
        if (value === null || value === undefined || value === "" || !isFinite(Number(value))) return "–"
        return Number(value).toFixed(digits) + (suffix || "")
    }
    function stateName(value) {
        var names = { 0: "Aus", 2: "Fehler", 3: "Bulk", 4: "Absorption", 5: "Float", 6: "Lagerung", 7: "Ausgleich", 252: "Externe Steuerung" }
        return names[Number(value)] || (value === null || value === undefined ? "Keine Daten" : "Status " + value)
    }

    Rectangle {
        x: 10; y: 8; width: 780; height: 56; radius: 13
        color: view.panelColor; border.color: view.lineColor
        TouchButton { x: 8; y: 9; width: 76; height: 38; label: "ZURÜCK"; onClicked: view.backRequested() }
        Text { x: 98; y: 8; text: "ENERGIEQUELLEN"; color: view.textColor; font.pixelSize: 15; font.bold: true }
        Text { x: 98; y: 31; text: view.chargers.length + " Victron MPPT · INDEVOLT SOLAR " + (view.indevolt.online ? "online" : "offline") + " · ORION " + (view.orion.on ? "ein" : "aus") + (view.indevolt.gridConnection && view.indevolt.gridConnection.available ? " · CAMPERNETZ " + (view.indevolt.gridConnection.on ? "frei" : "getrennt") : ""); color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Text { x: 532; y: 9; width: 108; horizontalAlignment: Text.AlignRight; text: view.fmt(view.solar.power, 0, " W"); color: view.solarColor; font.pixelSize: 20; font.bold: true }
        Text { x: 532; y: 34; width: 108; horizontalAlignment: Text.AlignRight; text: "VICTRON"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
        Text { x: 654; y: 9; width: 112; horizontalAlignment: Text.AlignRight; text: view.fmt(Number(view.solar.power || 0) + Number(view.indevolt.solarPower || 0), 0, " W"); color: view.textColor; font.pixelSize: 20; font.bold: true }
        Text { x: 654; y: 34; width: 112; horizontalAlignment: Text.AlignRight; text: "GESAMT"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
    }

    Rectangle {
        x: 10; y: 72; width: 478; height: 342; radius: 13
        color: view.innerColor; border.color: view.lineColor
        Text { x: 14; y: 12; text: "VICTRON SMARTSOLAR MPPT"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Text { visible: view.chargers.length === 0; anchors.centerIn: parent; text: "Keine MPPT-Daten verfügbar"; color: view.mutedColor; font.pixelSize: 13 }
        Flickable {
            x: 10; y: 34; width: 458; height: 298; clip: true
            contentWidth: width; contentHeight: mpptColumn.height; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: mpptColumn; width: 458; spacing: 7
                Repeater {
                    model: view.chargers
                    delegate: Rectangle {
                        property var charger: modelData
                        width: 458; height: 88; radius: 11
                        color: charger.online ? (view.dayMode ? "#fff8d9" : "#242314") : view.panelColor
                        border.color: charger.online ? view.solarColor : view.lineColor
                        Rectangle { x: 0; y: 13; width: 4; height: 62; radius: 2; color: charger.online ? view.solarColor : view.mutedColor }
                        Text { x: 14; y: 9; width: 245; elide: Text.ElideRight; text: charger.name || "SmartSolar MPPT"; color: view.textColor; font.pixelSize: 13; font.bold: true }
                        Text { x: 14; y: 30; width: 245; elide: Text.ElideRight; text: "Instanz " + charger.instance + (charger.serial ? " · " + charger.serial : ""); color: view.mutedColor; font.pixelSize: 8 }
                        Text { x: 14; y: 58; width: 245; elide: Text.ElideRight; text: view.stateName(charger.state); color: charger.online ? view.greenColor : view.mutedColor; font.pixelSize: 10; font.bold: true }
                        Text { x: 267; y: 8; width: 82; horizontalAlignment: Text.AlignRight; text: view.fmt(charger.power, 0, " W"); color: view.solarColor; font.pixelSize: 20; font.bold: true }
                        Text { x: 267; y: 35; width: 82; horizontalAlignment: Text.AlignRight; text: "LEISTUNG"; color: view.mutedColor; font.pixelSize: 8 }
                        Text { x: 359; y: 10; width: 84; horizontalAlignment: Text.AlignRight; text: view.fmt(charger.pvVoltage, 1, " V"); color: view.textColor; font.pixelSize: 15; font.bold: true }
                        Text { x: 359; y: 33; width: 84; horizontalAlignment: Text.AlignRight; text: "PV"; color: view.mutedColor; font.pixelSize: 8 }
                        Text { x: 267; y: 61; width: 176; horizontalAlignment: Text.AlignRight; text: "Heute " + view.fmt(charger.yieldTodayKwh, 2, " kWh"); color: view.mutedColor; font.pixelSize: 9 }
                    }
                }
            }
        }
    }

    Rectangle {
        x: 496; y: 72; width: 294; height: 342; radius: 13
        color: view.innerColor; border.color: view.lineColor
        Text { x: 14; y: 12; text: "ORION XS · LICHTMASCHINE"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Rectangle { x: 14; y: 31; width: 266; height: 112; radius: 11; color: view.orion.on ? (view.dayMode ? "#e2f5ef" : "#143027") : view.panelColor; border.color: view.orion.online ? view.greenColor : view.lineColor }
        Text { x: 27; y: 41; text: view.orion.online ? view.orion.stateText || "BEREIT" : "NICHT ERREICHBAR"; color: view.orion.online ? view.greenColor : view.mutedColor; font.pixelSize: 9; font.bold: true }
        Text { x: 27; y: 62; width: 160; text: view.fmt(view.orion.power, 0, " W"); color: view.textColor; font.pixelSize: 21; font.bold: true }
        Text { x: 27; y: 91; width: 164; text: "LIMA  " + view.fmt(view.orion.inputVoltage, 1, " V") + " · " + view.fmt(view.orion.inputPower, 0, " W"); color: view.mutedColor; font.pixelSize: 8; font.bold: true }
        Text { x: 27; y: 111; width: 164; text: "→ BORD  " + view.fmt(view.orion.voltage, 1, " V") + " · " + view.fmt(view.orion.current, 1, " A"); color: view.mutedColor; font.pixelSize: 8; font.bold: true }
        TouchButton { x: 201; y: 48; width: 66; height: 44; label: view.orion.on ? "AUS" : "EIN"; active: view.orion.on === true; enabled: view.orion.online === true; onClicked: view.orionCommandRequested(!view.orion.on) }
        Text { x: 14; y: 155; text: "INDEVOLT SOLAR"; color: view.mutedColor; font.pixelSize: 9; font.bold: true }
        Rectangle { x: 14; y: 174; width: 266; height: 154; radius: 11; color: view.indevolt.online ? (view.dayMode ? "#fff8d9" : "#2d2914") : view.panelColor; border.color: view.indevolt.online ? view.solarColor : view.lineColor }
        Text { x: 27; y: 185; text: view.indevolt.online ? "ONLINE" : "NICHT ERREICHBAR"; color: view.indevolt.online ? view.greenColor : view.mutedColor; font.pixelSize: 9; font.bold: true }
        TouchButton { visible: view.indevolt.gridConnection && view.indevolt.gridConnection.available; x: 166; y: 181; width: 100; height: 36; label: view.indevolt.gridConnection && view.indevolt.gridConnection.on ? "TRENNEN" : "FREIGEBEN"; active: view.indevolt.gridConnection && view.indevolt.gridConnection.on === true; onClicked: view.indevoltGridCommandRequested(!(view.indevolt.gridConnection && view.indevolt.gridConnection.on)) }
        Text { x: 27; y: 208; width: 142; text: view.fmt(view.indevolt.solarPower, 0, " W"); color: view.solarColor; font.pixelSize: 25; font.bold: true }
        Text { x: 27; y: 240; text: "SOLARLEISTUNG"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
        Text { x: 27; y: 263; width: 105; text: view.fmt(view.indevolt.soc, 0, " %"); color: view.textColor; font.pixelSize: 16; font.bold: true }
        Text { x: 27; y: 286; text: "SOC"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
        Text { x: 145; y: 263; width: 107; horizontalAlignment: Text.AlignRight; text: view.fmt(view.indevolt.batteryPower, 0, " W"); color: view.textColor; font.pixelSize: 16; font.bold: true }
        Text { x: 145; y: 286; width: 107; horizontalAlignment: Text.AlignRight; text: "BATTERIE"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
        Text { x: 27; y: 307; width: 225; text: view.indevolt.gridConnection && view.indevolt.gridConnection.available ? "Campernetz " + view.fmt(view.indevolt.gridConnection.voltage, 1, " V") + " · " + view.fmt(view.indevolt.gridConnection.power, 0, " W") : "AC Ausgang " + view.fmt(view.indevolt.acOutputPower, 0, " W") + " · Eingang " + view.fmt(view.indevolt.acInputPower, 0, " W"); color: view.indevolt.gridConnection && view.indevolt.gridConnection.on ? view.greenColor : view.mutedColor; font.pixelSize: 8; font.bold: view.indevolt.gridConnection && view.indevolt.gridConnection.available }
    }
}
