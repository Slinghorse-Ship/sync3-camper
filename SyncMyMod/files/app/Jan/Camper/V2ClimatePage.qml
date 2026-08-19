import QtQuick 2.6

Item {
    id: view
    objectName: "v2ClimatePage"
    property var api
    property var snapshot: ({})
    property bool dayMode: false
    property var climate: snapshot.climate || ({})
    property var automation: climate.automation || ({})
    property var heater: climate.heater || ({})
    property var fan: climate.fan || ({})
    property bool runtimeOpen: false
    property bool fanDragging: false
    property int pendingFanSpeed: 0

    CamperStyle { id: visual; dayMode: view.dayMode }

    function valid(value) { return value !== null && value !== undefined && value !== "" && isFinite(Number(value)) }
    function fmt(value, digits, suffix) { return valid(value) ? Number(value).toFixed(digits) + (suffix || "") : "–" + (suffix || "") }
    function patchAutomation(enabled, target) {
        api.command("settings", "patch", null, { patch: { climateAutomation: {
            enabled: enabled,
            mode: automation.mode || "auto",
            targetTemperature: Math.max(10, Math.min(30, Number(target))),
            hysteresis: Math.max(.5, Math.min(5, Number(automation.hysteresis || 1))),
            fanSpeed: Math.max(10, Math.min(100, Math.round(Number(automation.fanSpeed || 50) / 10) * 10))
        } } })
    }
    function heaterMode(mode) { api.command("heater", "setting", mode, { key: "mode" }) }
    function setRuntime(minutes) { api.command("heater", "setting", minutes, { key: "duration" }); runtimeOpen = false }
    function fanSpeedFromX(position, widthValue) { pendingFanSpeed = Math.max(0, Math.min(100, Math.round(position * 100 / Math.max(1, widthValue)))) }
    function commitFanSpeed() { api.command("maxxfan", "speed", pendingFanSpeed) }

    Rectangle {
        x: 0; y: 0; width: 248; height: 326; radius: 17; color: visual.panel
        border.width: view.automation.enabled === true ? 2 : 1
        border.color: view.automation.enabled === true ? visual.green : visual.border
        Text { x: 14; y: 14; text: "Komfort"; color: visual.text; font.pixelSize: 14; font.bold: true }
        Text { x: 14; y: 51; width: 220; horizontalAlignment: Text.AlignHCenter; text: view.fmt(view.automation.targetTemperature, 0, "°"); color: visual.text; font.pixelSize: 42; font.bold: true }
        Text { x: 14; y: 101; width: 220; horizontalAlignment: Text.AlignHCenter; text: view.fmt(view.climate.roomTemperature, 1, "° innen"); color: visual.muted; font.pixelSize: 10 }
        Rectangle { x: 14; y: 133; width: 220; height: 55; radius: 13; color: visual.inner
            Rectangle { x: 5; y: 5; width: 46; height: 45; radius: 11; color: visual.disabled
                Text { anchors.centerIn: parent; text: "−"; color: visual.text; font.pixelSize: 21 }
                MouseArea { anchors.fill: parent; onClicked: view.patchAutomation(view.automation.enabled === true, Number(view.automation.targetTemperature || 20) - 1) }
            }
            Text { x: 61; y: 19; width: 98; horizontalAlignment: Text.AlignHCenter; text: "Auto"; color: view.automation.enabled === true ? visual.green : visual.text; font.pixelSize: 16; font.bold: true }
            Rectangle { x: 169; y: 5; width: 46; height: 45; radius: 11; color: visual.disabled
                Text { anchors.centerIn: parent; text: "+"; color: visual.text; font.pixelSize: 21 }
                MouseArea { anchors.fill: parent; onClicked: view.patchAutomation(view.automation.enabled === true, Number(view.automation.targetTemperature || 20) + 1) }
            }
        }
        Rectangle { x: 14; y: 208; width: 220; height: 47; radius: 13; color: view.automation.enabled === true ? visual.selectedGreen : visual.inner; border.color: view.automation.enabled === true ? visual.green : visual.border
            Text { anchors.centerIn: parent; text: "Klimaautomatik"; color: view.automation.enabled === true ? visual.green : visual.text; font.pixelSize: 11; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: view.patchAutomation(view.automation.enabled !== true, Number(view.automation.targetTemperature || 20)) }
        }
        Row {
            x: 14; y: 272; spacing: 8
            Rectangle { width: 106; height: 38; radius: 11; color: visual.inner
                V2Icon { x: 8; y: 8; width: 22; height: 22; kind: "flame"; lineColor: visual.orange; strokeWidth: 1.8 }
                Text { x: 37; y: 13; text: "Autoterm"; color: visual.text; font.pixelSize: 9; font.bold: true }
            }
            Rectangle { width: 106; height: 38; radius: 11; color: visual.inner
                V2Icon { x: 8; y: 8; width: 22; height: 22; kind: "fan"; lineColor: visual.blue; strokeWidth: 1.8 }
                Text { x: 37; y: 13; text: "MaxxFan"; color: visual.text; font.pixelSize: 9; font.bold: true }
            }
        }
    }

    Rectangle {
        x: 257; y: 0; width: 248; height: 326; radius: 17; color: visual.panel
        border.width: view.heater.on === true ? 2 : 1; border.color: view.heater.on === true ? visual.orange : visual.border
        Text { x: 14; y: 14; text: "Autoterm"; color: visual.text; font.pixelSize: 14; font.bold: true }
        Text { x: 14; y: 49; text: view.fmt(view.heater.setpoint, 0, "°"); color: visual.orange; font.pixelSize: 35; font.bold: true }
        Text { x: 77; y: 66; text: "Soll"; color: visual.muted; font.pixelSize: 9 }

        Row {
            x: 14; y: 104; spacing: 4
            Repeater {
                model: [{label:"Temperatur",mode:"temperature"},{label:"Leistung",mode:"power"},{label:"Lüften",mode:"ventilation"}]
                delegate: Rectangle {
                    width: index === 0 ? 82 : 67; height: 36; radius: 9
                    color: view.heater.mode === modelData.mode ? visual.pressed : visual.inner
                    border.color: view.heater.mode === modelData.mode ? visual.orange : visual.border
                    Text { anchors.centerIn: parent; text: modelData.label; color: view.heater.mode === modelData.mode ? visual.orange : visual.text; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: view.heaterMode(modelData.mode) }
                }
            }
        }

        Rectangle {
            x: 14; y: 152; width: 220; height: 44; radius: 11; color: visual.inner; border.color: visual.border
            V2Icon { x: 10; y: 11; width: 22; height: 22; kind: "info"; lineColor: visual.muted; strokeWidth: 1.7 }
            Text { x: 40; y: 14; width: 167; text: view.runtimeOpen ? "Zeitlimit wählen" : (Number(view.heater.durationMinutes || 0) > 0 ? Number(view.heater.durationMinutes) + " min" : "Zeitlimit hinzufügen"); color: visual.text; font.pixelSize: 9; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: view.runtimeOpen = !view.runtimeOpen }
        }
        Row {
            x: 14; y: 202; spacing: 4; visible: view.runtimeOpen
            Repeater {
                model: [{label:"Ohne",value:0},{label:"30",value:30},{label:"60",value:60},{label:"2 h",value:120}]
                delegate: Rectangle {
                    width: 52; height: 36; radius: 9; color: Number(view.heater.durationMinutes || 0) === modelData.value ? visual.pressed : visual.inner; border.color: visual.border
                    Text { anchors.centerIn: parent; text: modelData.label; color: visual.text; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: view.setRuntime(modelData.value) }
                }
            }
        }
        Rectangle {
            x: 14; y: 264; width: 220; height: 48; radius: 13
            color: view.heater.on === true ? visual.orange : visual.inner; border.color: view.heater.on === true ? visual.orange : visual.border
            opacity: view.heater.cooling === true || view.heater.online === false ? .48 : 1
            Text { anchors.centerIn: parent; text: view.heater.cooling === true ? "Nachlauf" : (view.heater.on === true ? "Stoppen" : "Starten"); color: view.heater.on === true ? "#ffffff" : visual.text; font.pixelSize: 11; font.bold: true }
            MouseArea { anchors.fill: parent; enabled: view.heater.cooling !== true && view.heater.online !== false; onClicked: view.api.command("heater", view.heater.on === true ? "stop" : "start", null) }
        }
    }

    Rectangle {
        x: 514; y: 0; width: 248; height: 326; radius: 17; color: visual.panel
        border.width: view.fan.on === true ? 2 : 1; border.color: view.fan.on === true ? visual.blue : visual.border
        Text { x: 14; y: 14; text: "MaxxFan"; color: visual.text; font.pixelSize: 14; font.bold: true }
        Text { x: 14; y: 49; text: (view.fanDragging ? view.pendingFanSpeed : view.fmt(view.fan.speed, 0, "")) + " %"; color: visual.text; font.pixelSize: 35; font.bold: true }
        Rectangle {
            id: fanTrack
            x: 14; y: 104; width: 220; height: 7; radius: 4; color: visual.border
            property int shown: view.fanDragging ? view.pendingFanSpeed : Math.max(0, Math.min(100, Number(view.fan.speed || 0)))
            Rectangle { width: parent.width * fanTrack.shown / 100; height: parent.height; radius: 4; color: visual.blue }
            Rectangle { x: Math.max(0, Math.min(parent.width-width, parent.width*fanTrack.shown/100-width/2)); y: -5; width: 17; height: 17; radius: 9; color: visual.blue }
            MouseArea {
                x: -4; y: -15; width: parent.width + 8; height: 38
                onPressed: { view.fanDragging = true; view.fanSpeedFromX(mouse.x - 4, fanTrack.width) }
                onPositionChanged: if (pressed) view.fanSpeedFromX(mouse.x - 4, fanTrack.width)
                onReleased: { view.commitFanSpeed(); view.fanDragging = false }
                onCanceled: view.fanDragging = false
            }
        }
        Row {
            x: 14; y: 139; spacing: 4
            Repeater {
                model: [{label:"Abluft",mode:"forward"},{label:"Zuluft",mode:"reverse"},{label:"Auto",mode:"auto"}]
                delegate: Rectangle {
                    width: 70; height: 40; radius: 10
                    property bool activeMode: modelData.mode === "auto" ? view.fan.autoHold === true : (view.fan.autoHold !== true && view.fan.mode === modelData.mode)
                    color: activeMode ? visual.pressed : visual.inner; border.color: activeMode ? visual.blue : visual.border
                    Text { anchors.centerIn: parent; text: modelData.label; color: activeMode ? visual.blue : visual.text; font.pixelSize: 9; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: modelData.mode === "auto" ? view.api.command("maxxfan", "auto", view.fan.autoHold !== true) : view.api.command("maxxfan", "mode", modelData.mode) }
                }
            }
        }
        Rectangle {
            x: 14; y: 264; width: 220; height: 48; radius: 13
            color: view.fan.on === true ? visual.blue : visual.inner; border.color: view.fan.on === true ? visual.blue : visual.border
            opacity: view.fan.online === false || view.fan.powered === false ? .48 : 1
            Text { anchors.centerIn: parent; text: view.fan.on === true ? "Ausschalten" : "Einschalten"; color: view.fan.on === true ? "#ffffff" : visual.text; font.pixelSize: 11; font.bold: true }
            MouseArea { anchors.fill: parent; enabled: view.fan.online !== false && view.fan.powered !== false; onClicked: view.api.command("maxxfan", "set", view.fan.on !== true) }
        }
    }
}
