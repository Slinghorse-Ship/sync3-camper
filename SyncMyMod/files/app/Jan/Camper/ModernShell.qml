import QtQuick 2.6

Item {
    id: shell
    objectName: "modernShell"
    property var host
    property var api
    property var snapshot: ({})
    property bool dayMode: false
    property var quickAccessIds: []
    property var favoriteIds: []
    property int currentPage: 0
    property double now: new Date().getTime()

    property var system: snapshot.system || ({})
    property var energy: snapshot.energy || ({})
    property var battery: energy.battery || ({})
    property var solar: energy.solar || ({})
    property var indevolt: energy.indevolt || ({})
    property var water: snapshot.water || ({})
    property var fresh: water.fresh || ({})
    property var climate: snapshot.climate || ({})
    property var temperatureSensors: climate.temperatureSensors || ({})
    property var automation: climate.automation || ({})
    property var heater: climate.heater || ({})
    property var fan: climate.fan || ({})
    property var lights: snapshot.lights || ({})
    property var operations: snapshot.operations || ({})
    readonly property real batteryFlowDeadband: 5

    CamperStyle { id: visual; dayMode: shell.dayMode }

    function valid(value) { return value !== null && value !== undefined && value !== "" && isFinite(Number(value)) }
    function fmt(value, digits, suffix) { return valid(value) ? Number(value).toFixed(digits) + (suffix || "") : "–" + (suffix || "") }
    function signed(value, digits, suffix) { return valid(value) ? (Number(value) > 0 ? "+" : "") + Number(value).toFixed(digits) + (suffix || "") : "–" + (suffix || "") }
    function title() { return ["Home", "Licht", "Klima", "Energie", "Wasser", "System"][currentPage] || "Camper" }
    function timeToGo(value, batteryPower) {
        if (valid(batteryPower) && Number(batteryPower) > batteryFlowDeadband) return "Lädt"
        if (!valid(value) || Number(value) < 0) return "–"
        var hours = Number(value) / 3600
        if (hours >= 24) return (hours / 24).toFixed(1).replace(".", ",") + " Tage"
        return Math.floor(hours) + " h"
    }
    function batteryFlowText(value) {
        if (!valid(value)) return "–"
        var power = Number(value)
        if (Math.abs(power) <= batteryFlowDeadband) return "Ruhe"
        if (power > 0) return "↑ Lädt +" + power.toFixed(0) + " W"
        return "↓ Entlädt " + Math.abs(power).toFixed(0) + " W"
    }
    function batteryFlowColor(value) {
        if (!valid(value) || Math.abs(Number(value)) <= batteryFlowDeadband) return visual.muted
        return Number(value) > 0 ? visual.green : visual.orange
    }
    function totalSolarPower() {
        if (valid(solar.power)) return Number(solar.power)
        if (valid(energy.totalSolarPower)) return Number(energy.totalSolarPower)
        return null
    }
    function homePowerText() {
        if (valid(energy.dcSystemPower)) return fmt(energy.dcSystemPower, 0, " W")
        return signed(battery.power, 0, " W")
    }
    function homePowerLabel() {
        if (valid(energy.dcSystemPower)) return "DC-Verbrauch"
        return valid(battery.power) ? "Batterie netto" : "DC-Verbrauch"
    }
    function comfortHumidity() {
        var comfort = temperatureSensors.comfort || ({}), ceiling = temperatureSensors.ceiling || ({}), floor = temperatureSensors.floor || ({})
        if (valid(comfort.humidity)) return Number(comfort.humidity)
        if (valid(ceiling.humidity) && valid(floor.humidity)) return (Number(ceiling.humidity) + Number(floor.humidity)) / 2
        if (valid(ceiling.humidity)) return Number(ceiling.humidity)
        if (valid(floor.humidity)) return Number(floor.humidity)
        return null
    }
    function quickItems() {
        var items = snapshot.ui && snapshot.ui.quickAccess
        return items && items.length ? items.slice(0, 4) : []
    }
    function favoriteItems() {
        var items = snapshot.ui && snapshot.ui.favorites
        return items && items.length ? items.slice(0, 4) : []
    }
    function favoriteOptions() {
        var options = snapshot.ui && snapshot.ui.quickAccessOptions
        return options && options.length ? options : []
    }
    function quickIcon(item) {
        var kinds = { "bulb":"cabinLight", "right-light":"sideRight", "down-light":"rearLight", "left-light":"sideLeft", "lightbar":"lightBar", "warningbar":"warningBar", "highbeam":"highBeam", "outlet":"outlet", "pump":"pump", "satellite":"satellite", "fan":"fan", "plug":"plug", "heater":"flame", "battery":"battery", "home":"home" }
        return kinds[item.icon] || "energy"
    }
    function activateQuick(item) {
        var action = item && item.command
        if (!item || item.available !== true || !action || !action.target || !action.action) return
        var extra = ({})
        for (var key in action) if (key !== "target" && key !== "action" && key !== "value") extra[key] = action[key]
        api.command(action.target, action.action, action.value, extra)
    }
    function patchAutomationTarget(delta) {
        var target = Math.max(10, Math.min(30, Number(automation.targetTemperature || 20) + delta))
        var controlMode = ["off", "manual", "auto"].indexOf(String(automation.controlMode || "")) >= 0
                ? String(automation.controlMode) : (automation.enabled === true ? "auto" : "manual")
        api.command("settings", "patch", null, { patch: { climateAutomation: {
            enabled: controlMode === "auto",
            controlMode: controlMode,
            mode: automation.mode || "auto",
            targetTemperature: target,
            hysteresis: Math.max(.5, Math.min(5, Number(automation.hysteresis || 1))),
            fanSpeed: Math.max(10, Math.min(100, Math.round(Number(automation.fanSpeed || 50) / 10) * 10))
        } } })
    }
    function deviceCountText() {
        var devices = operations.devices || []
        if (!devices.length) return "Keine Gerätedaten"
        var online = 0
        for (var i = 0; i < devices.length; ++i) if (devices[i].online === true) ++online
        return online + " / " + devices.length
    }

    Rectangle {
        id: screen
        anchors.fill: parent
        radius: 0
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: shell.dayMode ? "#f8fafb" : "#0d1722" }
            GradientStop { position: 1.0; color: shell.dayMode ? "#edf2f4" : "#080c12" }
        }
    }

    Item {
        x: 7; y: 7; width: 786; height: 50
        Image { x: 10; y: 5; width: 63; height: 40; source: shell.dayMode ? "transit-line-symbol-light.png" : "transit-line-symbol-dark.png"; fillMode: Image.PreserveAspectFit; smooth: true }
        Text { x: 80; y: 13; width: 385; text: shell.title(); color: visual.text; font.pixelSize: 19; font.bold: true }
        Rectangle {
            objectName: "v2ClockStatus"
            x: 602; y: 10; width: 76; height: 30; radius: 15
            color: shell.api.connected ? visual.selectedGreen : (shell.dayMode ? "#f8e8e9" : "#321d22")
            Rectangle { x: 10; y: 11; width: 7; height: 7; radius: 4; color: shell.api.connected ? visual.green : visual.red }
            Text { x: 25; y: 8; width: 44; text: Qt.formatTime(new Date(shell.now), "hh:mm"); color: shell.api.connected ? visual.green : visual.red; font.pixelSize: 10; font.bold: true }
        }
        Rectangle { x: 688; y: 6; width: 38; height: 38; radius: 12; color: visual.inner
            V2Icon { anchors.centerIn: parent; width: 20; height: 20; kind: "sunMoon"; lineColor: visual.text; strokeWidth: 1.8 }
            MouseArea { anchors.fill: parent; onClicked: shell.host.dayMode = !shell.host.dayMode }
        }
        Rectangle { x: 741; y: 2; width: 42; height: 42; radius: 12
            color: closeArea.pressed ? (shell.dayMode ? "#f4d8da" : "#49242b") : visual.inner
            border.color: shell.dayMode ? "#d75b64" : "#e47780"
            border.width: 1
            V2Icon { anchors.centerIn: parent; width: 21; height: 21; kind: "close"; lineColor: visual.red; strokeWidth: 2.0 }
            MouseArea { id: closeArea; anchors.fill: parent; onClicked: shell.host.requestClose() }
        }
        Rectangle { x: 0; y: 49; width: 786; height: 1; color: visual.border; opacity: .55 }
    }

    Item {
        x: 19; y: 65; width: 762; height: 326; visible: shell.currentPage === 0
        Rectangle {
            x: 0; y: 0; width: 440; height: 184; radius: 17; color: visual.panel; border.color: visual.border
            V2Gauge { x: 15; y: 40; width: 106; height: 106; dayMode: shell.dayMode; value: Number(shell.battery.soc || 0); primaryText: shell.fmt(shell.battery.soc, 0, "%"); secondaryText: shell.fmt(shell.battery.voltage, 2, " V") + " · " + shell.timeToGo(shell.battery.timeToGoSeconds, shell.battery.power) }
            Text { objectName: "v2BatteryFlow"; x: 15; y: 151; width: 106; height: 14; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: shell.batteryFlowText(shell.battery.power); color: shell.batteryFlowColor(shell.battery.power); font.pixelSize: 8; font.bold: true }
            Text { x: 138; y: 15; text: "Energie"; color: visual.text; font.pixelSize: 14; font.bold: true }
            Rectangle { x: 138; y: 49; width: 138; height: 119; radius: 12; color: visual.inner
                V2Icon { x: 11; y: 11; width: 21; height: 21; kind: "solar"; lineColor: visual.blue; strokeWidth: 1.7 }
                Text { x: 10; y: 48; text: shell.fmt(shell.totalSolarPower(), 0, " W"); color: visual.text; font.pixelSize: 20; font.bold: true }
                Text { x: 10; y: 79; text: "Solar gesamt"; color: visual.muted; font.pixelSize: 9 }
                MouseArea { anchors.fill: parent; onClicked: { shell.currentPage = 3; energyPage.pane = 2 } }
            }
            Rectangle { x: 284; y: 49; width: 141; height: 119; radius: 12; color: visual.inner
                V2Icon { x: 11; y: 11; width: 21; height: 21; kind: "battery"; lineColor: visual.blue; strokeWidth: 1.7 }
                Text { x: 10; y: 48; text: shell.homePowerText(); color: visual.text; font.pixelSize: 20; font.bold: true }
                Text { x: 10; y: 79; text: shell.homePowerLabel(); color: visual.muted; font.pixelSize: 9 }
            }
        }

        Rectangle {
            x: 449; y: 0; width: 313; height: 184; radius: 17; color: visual.panel; border.color: visual.border
            Text { x: 14; y: 13; text: "Klimaautomatik"; color: visual.text; font.pixelSize: 14; font.bold: true }
            Text { x: 14; y: 48; text: shell.fmt(shell.climate.roomTemperature, 1, "°"); color: visual.text; font.pixelSize: 37; font.bold: true }
            Text { x: 218; y: 59; width: 80; horizontalAlignment: Text.AlignRight; text: shell.valid(shell.comfortHumidity()) ? shell.fmt(shell.comfortHumidity(), 0, " % rF") : ""; color: visual.muted; font.pixelSize: 9 }
            Rectangle { x: 14; y: 96; width: 137; height: 28; radius: 9; color: visual.inner
                V2Icon { x: 7; y: 6; width: 16; height: 16; kind: "flame"; lineColor: visual.orange; strokeWidth: 1.6 }
                Text { x: 30; y: 8; text: "Autoterm"; color: visual.text; font.pixelSize: 9; font.bold: true }
            }
            Rectangle { x: 159; y: 96; width: 139; height: 28; radius: 9; color: visual.inner
                V2Icon { x: 7; y: 6; width: 16; height: 16; kind: "fan"; lineColor: visual.blue; strokeWidth: 1.6 }
                Text { x: 30; y: 8; text: "MaxxFan"; color: visual.text; font.pixelSize: 9; font.bold: true }
            }
            Rectangle { x: 14; y: 135; width: 46; height: 36; radius: 11; color: visual.inner
                Text { anchors.centerIn: parent; text: "−"; color: visual.text; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: shell.patchAutomationTarget(-1) }
            }
            Text { x: 69; y: 139; width: 174; horizontalAlignment: Text.AlignHCenter; text: shell.fmt(shell.automation.targetTemperature, 0, "°"); color: visual.text; font.pixelSize: 20; font.bold: true }
            Text { x: 69; y: 161; width: 174; horizontalAlignment: Text.AlignHCenter; text: "Ziel"; color: visual.muted; font.pixelSize: 8 }
            Rectangle { x: 252; y: 135; width: 46; height: 36; radius: 11; color: visual.inner
                Text { anchors.centerIn: parent; text: "+"; color: visual.text; font.pixelSize: 20 }
                MouseArea { anchors.fill: parent; onClicked: shell.patchAutomationTarget(1) }
            }
        }

        Rectangle {
            x: 0; y: 193; width: 762; height: 133; radius: 17; color: visual.panel; border.color: visual.border
            Text { x: 11; y: 10; text: "Schnellzugriff"; color: visual.text; font.pixelSize: 12; font.bold: true }
            Text { x: 675; y: 10; width: 76; horizontalAlignment: Text.AlignRight; text: "Anpassen"; color: visual.blue; font.pixelSize: 9; font.bold: true }
            MouseArea { x: 664; y: 0; width: 98; height: 38; onClicked: shell.host.openSettings() }
            Repeater {
                model: shell.quickItems()
                delegate: Rectangle {
                    property var quick: modelData
                    x: 10 + index * 187; y: 36; width: 180; height: 86; radius: 14
                    opacity: quick.available === true ? 1 : .45
                    color: quick.active === true ? visual.selectedBlue : visual.inner
                    border.width: quick.active === true ? 2 : 1; border.color: quick.active === true ? visual.blue : visual.border
                    Rectangle { x: 10; y: 25; width: 36; height: 36; radius: 11; color: quick.active === true ? visual.blue : visual.disabled
                        V2Icon { anchors.centerIn: parent; width: 22; height: 22; kind: shell.quickIcon(quick); lineColor: quick.active === true ? "#ffffff" : visual.muted; strokeWidth: 1.7 }
                    }
                    Text { x: 55; y: 35; width: 116; elide: Text.ElideRight; text: quick.name || "Schnellzugriff"; color: quick.active === true ? visual.blue : visual.text; font.pixelSize: 10; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: quick.available === true; onClicked: shell.activateQuick(quick) }
                }
            }
        }
    }

    V2LightsPage { x: 19; y: 65; width: 762; height: 326; visible: shell.currentPage === 1; host: shell.host; api: shell.api; snapshot: shell.snapshot; dayMode: shell.dayMode }
    V2ClimatePage { x: 19; y: 65; width: 762; height: 326; visible: shell.currentPage === 2; api: shell.api; snapshot: shell.snapshot; dayMode: shell.dayMode }
    V2EnergyPage { id: energyPage; x: 19; y: 65; width: 762; height: 326; visible: shell.currentPage === 3; api: shell.api; snapshot: shell.snapshot; dayMode: shell.dayMode }

    Item {
        x: 19; y: 65; width: 762; height: 326; visible: shell.currentPage === 4
        Rectangle { x: 0; y: 0; width: 376; height: 326; radius: 17; color: visual.panel; border.color: visual.border
            Text { x: 16; y: 15; text: "Frischwasser"; color: visual.text; font.pixelSize: 14; font.bold: true }
            V2Gauge { x: 111; y: 71; width: 154; height: 154; dayMode: shell.dayMode; value: Number(shell.fresh.level || 0); primaryText: shell.fmt(shell.fresh.level, 0, "%"); secondaryText: shell.valid(shell.fresh.remainingLitres) ? shell.fmt(shell.fresh.remainingLitres, 0, " Liter") : "Nicht verfügbar"; accentColor: visual.blue; opacity: shell.valid(shell.fresh.level) ? 1 : .45 }
        }
        Rectangle { x: 385; y: 0; width: 377; height: 326; radius: 17; color: shell.water.pump && shell.water.pump.on === true ? visual.selectedBlue : visual.panel; border.width: shell.water.pump && shell.water.pump.on === true ? 2 : 1; border.color: shell.water.pump && shell.water.pump.on === true ? visual.blue : visual.border
            Rectangle { x: 144; y: 83; width: 88; height: 88; radius: 25; color: shell.water.pump && shell.water.pump.on === true ? visual.blue : visual.disabled
                V2Icon { anchors.centerIn: parent; width: 53; height: 53; kind: "pump"; lineColor: shell.water.pump && shell.water.pump.on === true ? "#ffffff" : visual.muted; strokeWidth: 2 }
            }
            Text { x: 20; y: 202; width: 337; horizontalAlignment: Text.AlignHCenter; text: "Wasserpumpe"; color: visual.text; font.pixelSize: 17; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: shell.api.command("waterPump", "set", !(shell.water.pump && shell.water.pump.on)) }
        }
    }

    Item {
        x: 19; y: 65; width: 762; height: 326; visible: shell.currentPage === 5
        Repeater {
            model: [{x:0,title:"Verbindungen"},{x:257,title:"Camper"},{x:514,title:"Ford / SYNC"}]
            delegate: Rectangle { x: modelData.x; y: 0; width: 248; height: 326; radius: 17; color: visual.panel; border.color: visual.border
                Text { x: 14; y: 15; text: modelData.title; color: visual.text; font.pixelSize: 14; font.bold: true }
            }
        }
        Column {
            x: 14; y: 57; width: 220; spacing: 8
            Rectangle { width: 220; height: 62; radius: 12; color: visual.inner
                Rectangle { x: 12; y: 27; width: 8; height: 8; radius: 4; color: shell.api.connected ? visual.green : visual.red }
                Text { x: 31; y: 14; text: "Node-RED"; color: visual.text; font.pixelSize: 10; font.bold: true }
                Text { x: 31; y: 35; text: shell.api.connected ? "Verbunden" : "Keine Verbindung"; color: shell.api.connected ? visual.green : visual.red; font.pixelSize: 8 }
            }
            Rectangle { width: 220; height: 62; radius: 12; color: visual.inner
                V2Icon { x: 10; y: 20; width: 24; height: 24; kind: "network"; lineColor: visual.muted; strokeWidth: 1.8 }
                Text { x: 43; y: 14; text: "Geräte"; color: visual.text; font.pixelSize: 10; font.bold: true }
                Text { x: 43; y: 35; text: shell.deviceCountText(); color: visual.muted; font.pixelSize: 8 }
            }
        }
        Column {
            x: 271; y: 57; width: 220; spacing: 8
            Rectangle { width: 220; height: 62; radius: 12; color: visual.inner
                Text { x: 14; y: 14; text: "Schnellzugriff"; color: visual.text; font.pixelSize: 10; font.bold: true }
                Text { x: 14; y: 35; text: "4 Plätze"; color: visual.muted; font.pixelSize: 8 }
                MouseArea { anchors.fill: parent; onClicked: shell.host.openSettings() }
            }
            Rectangle { width: 220; height: 62; radius: 12; color: visual.inner
                Text { x: 14; y: 14; text: "Darstellung"; color: visual.text; font.pixelSize: 10; font.bold: true }
                Text { x: 14; y: 35; text: shell.dayMode ? "Hell" : "Dunkel"; color: visual.muted; font.pixelSize: 8 }
                MouseArea { anchors.fill: parent; onClicked: shell.host.dayMode = !shell.host.dayMode }
            }
            Rectangle { width: 220; height: 62; radius: 12; color: visual.selectedBlue; border.color: visual.blue
                Text { anchors.centerIn: parent; text: "Einstellungen"; color: visual.blue; font.pixelSize: 10; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: shell.host.openSettings() }
            }
        }
        Column {
            x: 528; y: 57; width: 220; spacing: 8
            Rectangle { width: 220; height: 62; radius: 12; color: visual.inner
                Text { x: 14; y: 14; text: "Kanten-Gesten"; color: visual.text; font.pixelSize: 10; font.bold: true }
                Text { x: 14; y: 35; text: "Links Favoriten · rechts Wetter & Tide"; color: visual.muted; font.pixelSize: 8 }
            }
            Rectangle { width: 220; height: 62; radius: 12; color: visual.inner
                Text { x: 14; y: 14; text: "CamperControl"; color: visual.text; font.pixelSize: 10; font.bold: true }
                Text { x: 14; y: 35; text: "v3.12.1"; color: visual.muted; font.pixelSize: 8 }
            }
            Rectangle { width: 220; height: 62; radius: 12; color: visual.inner
                Text { anchors.centerIn: parent; text: "App schließen"; color: visual.text; font.pixelSize: 10; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: shell.host.requestClose() }
            }
        }
    }

    Rectangle {
        x: 17; y: 401; width: 766; height: 64; radius: 18; color: visual.panel; border.color: visual.border
        Repeater {
            model: [
                {label:"Home",icon:"home"},{label:"Licht",icon:"light"},{label:"Klima",icon:"climate"},
                {label:"Energie",icon:"energy"},{label:"Wasser",icon:"water"},{label:"System",icon:"settings"}
            ]
            delegate: Rectangle {
                x: 5 + index * 126; y: 5; width: index === 5 ? 126 : 123; height: 54; radius: 13
                color: shell.currentPage === index ? visual.selectedBlue : "transparent"
                V2Icon { x: (parent.width - 21) / 2; y: 7; width: 21; height: 21; kind: modelData.icon; lineColor: shell.currentPage === index ? visual.blue : visual.muted; strokeWidth: 1.8 }
                Text { x: 0; y: 34; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: shell.currentPage === index ? visual.blue : visual.muted; font.pixelSize: 8; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: shell.currentPage = index }
            }
        }
    }

    V2EdgePanels {
        id: edgePanels
        anchors.fill: parent
        z: 200
        api: shell.api
        host: shell.host
        favoriteIds: shell.favoriteIds
        favoriteOptions: shell.favoriteOptions()
        favorites: shell.favoriteItems()
        weather: shell.snapshot.weather || ({})
        dayMode: shell.dayMode
    }

}
