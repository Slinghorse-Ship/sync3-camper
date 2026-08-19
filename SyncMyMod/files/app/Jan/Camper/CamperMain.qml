import QtQuick 2.6
import AL2HMIBridge 1.0 as AL2HMIBridge

Item {
    id: root
    width: 800
    height: 480

    signal closeRequested()

    property bool embeddedInGlobalHost: false
    property bool dayMode: AL2HMIBridge.globalSource.dayMode
    property color backgroundTop: visual.backgroundTop
    property color backgroundBottom: visual.backgroundBottom
    property color headerColor: visual.header
    property color panelColor: visual.panel
    property color innerPanelColor: visual.inner
    property color primaryText: visual.text
    property color secondaryText: visual.muted
    property color lineColor: visual.border
    property color fordBlue: visual.blue
    property string settingsFile: "file:///fs/rwdata/fmods/mods/camper/config.json"
    property string baseUrl: "http://172.24.24.1:1880/camper/api/v2"
    property bool settingsOpen: false
    property bool quickSettingsOpen: false
    property string settingsUrl: baseUrl
    property bool showExternalWifiTile: true
    property string designVersion: "v2"
    property var remoteConfig: ({})
    property var lightMapping: []
    property var quickAccessIds: ["switch:water_pump", "switch:starlink", "switch:dc_outlets_left", "light:inside_main"]
    property int page: 0
    property real detailScaleY: 366 / 424
    property double now: new Date().getTime()
    property string observedCommand: ""

    property var snapshot: api.stateData || ({})
    property var system: snapshot.system || ({})
    property var energy: snapshot.energy || ({})
    property var battery: energy.battery || ({})
    property var solar: energy.solar || ({})
    property var indevolt: energy.indevolt || ({})
    property var orion: energy.orion || ({})
    property var indevoltDevices: indevolt.devices || []
    property var water: snapshot.water || ({})
    property var fresh: water.fresh || ({})
    property var pump: water.pump || ({})
    property var climate: snapshot.climate || ({})
    property var temperatureSensors: climate.temperatureSensors || ({})
    property var heater: climate.heater || ({})
    property var fan: climate.fan || ({})
    property var power: snapshot.power || ({})
    property var inverter: power.inverter || ({})
    property var dcChannels: power.dcChannels || []
    property var lights: snapshot.lights || ({})
    property var operations: snapshot.operations || ({})
    property var commandData: operations.commands || ({})
    property var eventData: operations.events || ({})
    property var historyData: operations.history || ({})
    property var forecast: historyData.forecast || ({})
    property var latestCommand: commandData.recent && commandData.recent.length ? commandData.recent[0] : ({})

    CamperStyle { id: visual; dayMode: root.dayMode }

    function formatted(value, digits, suffix) {
        if (value === null || value === undefined || value === "" || !isFinite(Number(value))) return "–"
        return Number(value).toFixed(digits) + (suffix || "")
    }

    function signed(value, suffix) {
        if (value === null || value === undefined || !isFinite(Number(value))) return "–"
        var number = Number(value)
        return (number > 0 ? "+" : "") + number.toFixed(1) + (suffix || "")
    }

    function duration(seconds) {
        if (seconds === null || seconds === undefined || !isFinite(Number(seconds))) return "–"
        var hours = Math.floor(Number(seconds) / 3600)
        var minutes = Math.floor((Number(seconds) % 3600) / 60)
        return hours + " h " + minutes + " min"
    }

    function timeText(timestamp) {
        if (!timestamp) return "–"
        return new Date(Number(timestamp)).toLocaleString(Qt.locale("de_DE"), "dd.MM. hh:mm")
    }

    function ageText(timestamp) {
        if (!timestamp) return "nie"
        var seconds = Math.max(0, Math.round((now - Number(timestamp)) / 1000))
        if (seconds < 60) return seconds + " s"
        if (seconds < 3600) return Math.round(seconds / 60) + " min"
        return Math.round(seconds / 3600) + " h"
    }

    function statusText(value) {
        if (value === "pending") return "AUSSTEHEND"
        if (value === "confirmed") return "BESTÄTIGT"
        if (value === "timeout") return "TIMEOUT"
        if (value === "rejected") return "ABGELEHNT"
        return String(value || "")
    }

    function targetText(value) {
        if (value === "starpower") return "Licht/12 V"
        if (value === "waterPump") return "Wasserpumpe"
        if (value === "inverter") return "MultiPlus"
        if (value === "orion") return "Orion XS"
        if (value === "heater") return "AUTOTERM"
        if (value === "maxxfan") return "MaxxFan"
        if (value === "scene") return "Szene"
        return String(value || "System")
    }

    function readLocalSettings() {
        var xhr = new XMLHttpRequest()
        try {
            xhr.open("GET", settingsFile, false)
            xhr.send()
            var saved = JSON.parse(xhr.responseText || "{}")
            if (saved.baseUrl) baseUrl = api.cleanBaseUrl(saved.baseUrl)
            if (saved.showExternalWifiTile !== undefined)
                showExternalWifiTile = saved.showExternalWifiTile !== false
            if (saved.designVersion === "v1" || saved.designVersion === "v2")
                designVersion = saved.designVersion
            // Migriert einen alten HTTPS-Eintrag sofort in die kanonische
            // lokale HTTP-Adresse, statt ihn beim nächsten Start erneut zu lesen.
            if (saved.baseUrl && String(saved.baseUrl) !== baseUrl)
                persistLocalSettings()
        } catch (error) {
            // Die Datei wird erst beim ersten Speichern angelegt.
        }
        settingsUrl = baseUrl
    }

    function persistLocalSettings() {
        var xhr = new XMLHttpRequest()
        xhr.open("PUT", settingsFile, false)
        xhr.send(JSON.stringify({
            baseUrl: api.cleanBaseUrl(baseUrl),
            showExternalWifiTile: showExternalWifiTile,
            designVersion: designVersion
        }))
    }

    function writeLocalSettings() {
        baseUrl = api.cleanBaseUrl(settingsUrl)
        settingsUrl = baseUrl
        var xhr = new XMLHttpRequest()
        try {
            xhr.open("PUT", settingsFile, false)
            xhr.send(JSON.stringify({
                baseUrl: baseUrl,
                showExternalWifiTile: showExternalWifiTile,
                designVersion: designVersion
            }))
        } catch (error) {
            api.errorText = "Einstellungen konnten nicht gespeichert werden"
        }
        settingsOpen = false
        api.reconnect()
    }

    function setDesignVersion(version) {
        var selected = String(version || "").toLowerCase()
        if (selected !== "v1" && selected !== "v2") return
        designVersion = selected
        page = 0
        try {
            persistLocalSettings()
        } catch (error) {
            api.errorText = "Designauswahl konnte nicht gespeichert werden"
        }
    }

    function loadRemoteSettings(config) {
        remoteConfig = config || ({})
        var configuredLights = remoteConfig.lights || []
        var loaded = []
        for (var i = 0; i < configuredLights.length; ++i) {
            var light = configuredLights[i]
            loaded.push({ id: light.id, name: light.name, channel: Number(light.channel), dimmable: light.dimmable, area: light.area, visible: light.visible })
        }
        lightMapping = loaded
        var remoteQuick = remoteConfig.ui && remoteConfig.ui.quickAccessIds
        if (remoteQuick && remoteQuick.length === 4) {
            quickAccessIds = remoteQuick.slice(0)
        } else {
            var legacyQuick = remoteConfig.ui && remoteConfig.ui.quickAccessLightIds
            if (legacyQuick && legacyQuick.length === 4) {
                var migrated = []
                for (var quickIndex = 0; quickIndex < legacyQuick.length; ++quickIndex)
                    migrated.push(legacyQuick[quickIndex] === "high_beam" ? "switch:high_beam_manual" : "light:" + legacyQuick[quickIndex])
                quickAccessIds = migrated
            }
        }
    }

    function quickAccessOptions() {
        var options = snapshot.ui && snapshot.ui.quickAccessOptions
        return options && options.length ? options : []
    }

    function quickAccessName(id) {
        var options = quickAccessOptions()
        for (var i = 0; i < options.length; ++i) if (options[i].id === id) return options[i].group + " · " + options[i].name
        return id
    }

    function changeQuickAccess(index, direction) {
        var options = quickAccessOptions()
        if (!options.length) return
        var choices = []
        for (var optionIndex = 0; optionIndex < options.length; ++optionIndex) choices.push(options[optionIndex].id)
        var current = choices.indexOf(quickAccessIds[index])
        if (current < 0) current = 0
        var wanted = choices[(current + direction + choices.length) % choices.length]
        var occupant = quickAccessIds.indexOf(wanted)
        var updated = quickAccessIds.slice(0)
        if (occupant >= 0 && occupant !== index) updated[occupant] = updated[index]
        updated[index] = wanted
        quickAccessIds = updated
    }

    function changeLightChannel(index, direction) {
        if (index < 0 || index >= lightMapping.length) return
        var current = Number(lightMapping[index].channel)
        var wanted = 7 + ((current - 7 + direction + 6) % 6)
        var occupant = -1
        for (var i = 0; i < lightMapping.length; ++i)
            if (i !== index && Number(lightMapping[i].channel) === wanted) occupant = i
        var updated = []
        for (var j = 0; j < lightMapping.length; ++j) {
            var light = lightMapping[j]
            var channel = Number(light.channel)
            if (j === index) channel = wanted
            else if (j === occupant) channel = current
            updated.push({ id: light.id, name: light.name, channel: channel, dimmable: light.dimmable, area: light.area, visible: light.visible })
        }
        lightMapping = updated
    }

    function saveLightMapping() {
        if (!lightMapping.length) return
        var updated = []
        for (var i = 0; i < lightMapping.length; ++i) {
            var light = lightMapping[i]
            updated.push({ id: light.id, name: light.name, channel: Number(light.channel), dimmable: light.dimmable, area: light.area, visible: light.visible })
        }
        api.command("settings", "patch", null, { patch: { lights: updated, ui: { quickAccessIds: quickAccessIds } } })
    }

    function requestClose() {
        if (embeddedInGlobalHost) closeRequested()
        else back()
    }

    function openSettings() {
        settingsUrl = baseUrl
        quickSettingsOpen = false
        settingsOpen = true
        api.readSettings()
        api.command("service", "refresh", null, {})
    }

    function saveSettings() {
        saveLightMapping()
        writeLocalSettings()
    }

    function testConnection() {
        baseUrl = api.cleanBaseUrl(settingsUrl)
        settingsUrl = baseUrl
        api.reconnect()
    }

    function serviceAction(action) {
        api.command("service", action, null, {})
    }

    function externalWifiState() {
        var service = system.service || ({})
        var network = snapshot.network || ({})
        var source = network.externalWifi || service.externalWifi || ({})
        var rawNetworks = source.networks !== undefined ? source.networks : service.external_wifi_networks
        var networks = []
        if (typeof rawNetworks === "string" && rawNetworks) {
            try { rawNetworks = JSON.parse(rawNetworks) } catch (error) { rawNetworks = [] }
        }
        if (rawNetworks && rawNetworks.length !== undefined) networks = rawNetworks
        var availableValue = source.available !== undefined ? source.available : service.external_wifi_available
        var enabledValue = source.enabled !== undefined ? source.enabled : service.external_wifi_enabled
        var scanValue = source.scanActive !== undefined ? source.scanActive : service.external_wifi_scan_active
        return {
            available: availableValue === true || Number(availableValue) === 1,
            enabled: enabledValue === true || Number(enabledValue) === 1,
            state: String(source.state || service.external_wifi_state || "nicht verfügbar"),
            ssid: String(source.ssid || service.external_wifi_ssid || ""),
            interfaceName: String(source.interfaceName || service.external_wifi_interface || ""),
            scanActive: scanValue === true || Number(scanValue) === 1,
            networks: networks
        }
    }

    function setExternalWifiEnabled(enabled) {
        api.command("service", "wifiEnable", enabled, { enabled: enabled })
    }

    function scanExternalWifi() {
        api.command("service", "wifiScan", null, {})
    }

    function connectExternalWifi(ssid, service, password) {
        var name = String(ssid || "").replace(/^\s+|\s+$/g, "")
        var servicePath = String(service || "").replace(/^\s+|\s+$/g, "")
        if (!name || !servicePath) return
        api.command("service", "wifiConnect", null, { ssid: name, service: servicePath, password: String(password || "") })
    }

    function openExternalWifiSettings() {
        openSettings()
        settingsPanel.scrollToExternalWifi()
    }

    function acknowledgeEvent(eventId) {
        api.command("system", "acknowledge", eventId, { eventId: eventId })
    }

    function completeMaintenance(taskId) {
        api.command("system", "maintenanceDone", taskId, { taskId: taskId })
    }

    function setLightArea(area, on) {
        var items = lights.items || []
        for (var i = 0; i < items.length; ++i) {
            if (area === "all" || items[i].area === area)
                api.command("starpower", "set", on ? 1 : 0, { channel: items[i].channel })
        }
    }

    function stateLight(id) {
        var items = lights.items || []
        for (var i = 0; i < items.length; ++i)
            if (items[i].id === id) return items[i]
        return ({ channel: 0, on: false, dimming: 0 })
    }

    function setFrontMode(mode) {
        var white = stateLight("outside_front_white")
        var amber = stateLight("outside_front_amber")
        var target = mode === "orange" ? amber : white
        var other = mode === "orange" ? white : amber
        if (Number(other.channel) > 0 && other.on === true)
            api.command("starpower", "set", 0, { channel: Number(other.channel) })
        if (Number(target.channel) > 0)
            api.command("starpower", "set", 1, { channel: Number(target.channel) })
    }

    function runScene(scene) {
        api.command("scene", "run", scene.id, { sceneId: scene.id })
    }

    function heaterSetting(key, value) {
        api.command("heater", "setting", value, { key: key })
    }

    function nextValue(current, values) {
        var index = values.indexOf(current)
        return values[(index + 1) % values.length]
    }

    function heaterModeText(value) {
        if (value === "power") return "LEISTUNG"
        if (value === "ventilation") return "LÜFTEN"
        return "TEMPERATUR"
    }

    function sensorText(value) {
        if (value === "internal") return "AUTOTERM INTERN"
        if (value === "external") return "AUTOTERM EXTERN"
        if (value === "ruuvi1") return "RUUVI DECKE"
        if (value === "ruuvi2") return "RUUVI BODEN"
        if (value === "ruuvi3") return "KOMFORTMITTEL"
        return "KOMFORTMITTEL"
    }

    Component.onCompleted: {
        readLocalSettings()
        api.start()
    }
    Component.onDestruction: api.stop()

    ApiClient {
        id: api
        objectName: "camperApiClient"
        baseUrl: root.baseUrl
        onSettingsReceived: root.loadRemoteSettings(settings)
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.backgroundTop }
            GradientStop { position: 1.0; color: root.backgroundBottom }
        }
    }

    Item {
        id: screen
        width: 800
        height: 480
        anchors.centerIn: parent
        scale: Math.min(root.width / 800, root.height / 480)

        Rectangle {
            x: 0; y: 0; width: 800; height: 56
            color: root.headerColor; border.color: root.lineColor
            Rectangle { x: 0; y: 54; width: 800; height: 2; color: root.fordBlue; opacity: 0.34 }
            Image { x: 4; y: 3; width: 56; height: 50; source: "Icon.png"; fillMode: Image.PreserveAspectFit; smooth: true }
            Text { x: 62; y: 8; text: (system.name || "CAMPER").toUpperCase(); color: root.primaryText; font.pixelSize: 17; font.bold: true }
            Text {
                x: 62; y: 30
                text: "\u00b7 " + (root.page === 6 ? "AUTOTERM AIR 2D" : (root.page === 7 ? "ENERGIEQUELLEN" : (root.page === 8 ? "BATTERIEN" : (root.page === 9 ? "MAXXFAN" : (root.page === 10 ? "TEMPERATUR" : ["HOME", "LICHT", "SZENEN", "MELDUNGEN", "SERVICE", "12 / 230 V"][root.page])))))
                color: root.fordBlue; font.pixelSize: 11; font.bold: true
            }

            Rectangle {
                x: 524; y: 14; width: 112; height: 29; radius: 15
                color: "#1a232c"; border.color: api.connected ? "#32d4a0" : "#e05e68"
                Rectangle { x: 10; y: 10; width: 8; height: 8; radius: 4; color: api.connected ? "#32d4a0" : "#e05e68" }
                Text { x: 24; anchors.verticalCenter: parent.verticalCenter; width: 82; elide: Text.ElideRight; text: api.connected ? "VERBUNDEN" : "VERBINDUNG"; color: root.primaryText; font.pixelSize: 9; font.bold: true }
            }
            Rectangle {
                x: 647; y: 9; width: 92; height: 39; radius: 9; color: detailSettingsArea.pressed ? (root.dayMode ? "#e8edef" : "#111c24") : "transparent"; border.color: root.lineColor
                LineIcon { x: 9; y: 8; width: 22; height: 22; kind: "settings"; lineColor: root.primaryText; strokeWidth: 1.8 }
                Text { x: 37; anchors.verticalCenter: parent.verticalCenter; text: "EINST."; color: root.primaryText; font.pixelSize: 10; font.bold: true }
                MouseArea { id: detailSettingsArea; anchors.fill: parent; onClicked: root.openSettings() }
            }
            Rectangle {
                x: 748; y: 9; width: 42; height: 39; radius: 9; color: detailCloseArea.pressed ? "#44232a" : "transparent"; border.color: "#5a333b"
                LineIcon { anchors.centerIn: parent; width: 23; height: 23; kind: "close"; lineColor: root.primaryText; strokeWidth: 2.6 }
                MouseArea { id: detailCloseArea; anchors.fill: parent; onClicked: root.requestClose() }
            }
        }

        Item {
            x: 0; y: 56; width: 800; height: 424
            visible: root.page === 0

            MetricCard { x: 10; y: 8; width: 187; height: 78; caption: battery.name || "BATTERIE"; value: root.formatted(battery.soc, 0, " %"); detail: root.formatted(battery.voltage, 1, " V") + " · " + root.signed(battery.power, " W"); valueColor: Number(battery.soc || 100) <= 20 ? "#f3a34d" : root.primaryText }
            MetricCard { x: 203; y: 8; width: 187; height: 78; caption: "ENERGIE"; value: root.formatted(energy.totalSolarPower, 0, " W"); detail: "Solar " + root.formatted(solar.power, 0, " W") + " · Orion " + root.formatted(orion.power, 0, " W"); valueColor: "#f5c451" }
            MetricCard { x: 396; y: 8; width: 187; height: 78; caption: fresh.name || "FRISCHWASSER"; value: root.formatted(fresh.level, 0, " %"); detail: root.formatted(fresh.remainingLitres, 0, " Liter"); valueColor: "#45c9fa" }
            MetricCard { x: 589; y: 8; width: 201; height: 78; caption: "INNENRAUM"; value: root.formatted(climate.roomTemperature, 1, " °C"); detail: heater.status || "Keine Heizungsdaten"; valueColor: "#f39b58" }

            Rectangle {
                x: 10; y: 94; width: 383; height: 144; radius: 11; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "KLIMA · " + (heater.name || "AUTOTERM"); color: root.primaryText; font.pixelSize: 14; font.bold: true }
                TouchButton { x: 127; y: 7; width: 82; height: 34; label: "AUTOTERM"; onClicked: root.page = 6 }
                Text { x: 218; y: 8; text: root.formatted(heater.setpoint, 0, " °C"); color: root.primaryText; font.pixelSize: 19; font.bold: true }
                TouchButton { x: 271; y: 7; width: 42; height: 34; label: "−"; onClicked: api.command("heater", "setpoint", Math.max(5, Number(heater.setpoint || 20) - 1)) }
                TouchButton { x: 321; y: 7; width: 42; height: 34; label: "+"; onClicked: api.command("heater", "setpoint", Math.min(30, Number(heater.setpoint || 20) + 1)) }
                TouchButton { x: 12; y: 49; width: 105; height: 34; label: heater.cooling ? "NACHLAUF" : (heater.on ? "STOPP" : "START"); active: heater.on === true; enabled: heater.cooling !== true; accentColor: "#f39b58"; onClicked: api.command("heater", heater.on ? "stop" : "start", null) }
                Text { x: 130; y: 59; text: (fan.name || "MaxxFan") + " · " + root.formatted(fan.speed, 0, " %"); color: root.primaryText; font.pixelSize: 11; font.bold: true }
                TouchButton { x: 271; y: 49; width: 42; height: 34; label: "−"; onClicked: api.command("maxxfan", "speed", Math.max(0, Number(fan.speed || 0) - 10)) }
                TouchButton { x: 321; y: 49; width: 42; height: 34; label: "+"; onClicked: api.command("maxxfan", "speed", Math.min(100, Number(fan.speed || 0) + 10)) }
                TouchButton { x: 12; y: 94; width: 79; height: 35; label: fan.on ? "FAN AUS" : "FAN EIN"; active: fan.on === true; onClicked: api.command("maxxfan", "set", !fan.on) }
                TouchButton { x: 98; y: 94; width: 85; height: 35; label: "RICHTUNG"; onClicked: api.command("maxxfan", "mode", fan.mode === "reverse" ? "forward" : "reverse") }
                TouchButton { x: 190; y: 94; width: 78; height: 35; label: "HAUBE"; onClicked: api.command("maxxfan", "lid", true) }
                TouchButton { x: 275; y: 94; width: 88; height: 35; label: "AUTO"; active: fan.autoHold === true; onClicked: api.command("maxxfan", "auto", !fan.autoHold) }
            }

            Rectangle {
                x: 401; y: 94; width: 389; height: 144; radius: 11; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "VERSORGUNG"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                Text { x: 12; y: 28; text: "Wasserpumpe"; color: root.primaryText; font.pixelSize: 14; font.bold: true }
                TouchButton { x: 247; y: 12; width: 128; height: 38; label: pump.on ? "PUMPE AUS" : "PUMPE EIN"; active: pump.on === true; accentColor: "#45c9fa"; onClicked: api.command("waterPump", "set", !pump.on) }
                Rectangle { x: 12; y: 60; width: 363; height: 1; color: "#2b3946" }
                Text { x: 12; y: 70; width: 205; elide: Text.ElideRight; text: inverter.name || "MultiPlus Compact"; color: root.primaryText; font.pixelSize: 14; font.bold: true }
                Text { x: 12; y: 92; text: (inverter.stateText || "–") + " · " + root.formatted(inverter.outputPower, 0, " W"); color: root.secondaryText; font.pixelSize: 10 }
                TouchButton { x: 247; y: 69; width: 128; height: 38; label: inverter.on ? "230 V AUS" : "230 V EIN"; active: inverter.on === true; accentColor: "#b490ff"; onClicked: api.command("inverter", "set", !inverter.on) }
                Text { x: 12; y: 121; text: "Landstrom " + (inverter.shoreConnected ? "VERBUNDEN" : "GETRENNT") + " · INDEVOLT " + Number(indevolt.onlineCount || 0) + "/" + Number(indevolt.totalCount || 0); color: inverter.shoreConnected ? "#32d4a0" : "#8d9aaa"; font.pixelSize: 10; font.bold: true }
                TouchButton { x: 275; y: 108; width: 100; height: 28; label: "INDEVOLT"; active: indevolt.online === true; accentColor: "#f5c451"; onClicked: root.page = 7 }
            }

            Rectangle {
                x: 10; y: 247; width: 780; height: 127; radius: 11; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "SCHNELLZUGRIFF LICHT"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                TouchButton { x: 606; y: 5; width: 162; height: 30; label: "ALLE 6 LICHTER"; onClicked: root.page = 1 }
                Repeater {
                    model: lights.items ? Math.min(4, lights.items.length) : 0
                    delegate: Rectangle {
                        property var light: lights.items[index]
                        x: 12 + index * 190; y: 38; width: 180; height: 77; radius: 9
                        color: light.on ? (root.dayMode ? "#d9f4eb" : "#173b32") : root.innerPanelColor; border.color: light.on ? "#32d4a0" : root.lineColor
                        Text { x: 9; y: 8; width: 162; elide: Text.ElideRight; text: light.name; color: root.primaryText; font.pixelSize: 12; font.bold: true }
                        TouchButton { x: 9; y: 33; width: 96; height: 33; label: light.on ? "AUS" : "EIN"; active: light.on === true; onClicked: api.command("starpower", "set", light.on ? 0 : 1, { channel: light.channel }) }
                        Text { x: 112; y: 44; width: 58; horizontalAlignment: Text.AlignHCenter; text: root.formatted(light.dimming, 0, " %"); color: root.secondaryText; font.pixelSize: 10 }
                    }
                }
            }

            Rectangle {
                x: 10; y: 382; width: 780; height: 34; radius: 8
                color: latestCommand.status === "timeout" ? (root.dayMode ? "#f9dfe2" : "#4a2026") : latestCommand.status === "pending" ? (root.dayMode ? "#faedc8" : "#463614") : (root.dayMode ? "#d9f4eb" : "#15352e")
                // Command acknowledgements remain available in the log only.
                visible: false
                Text { anchors.centerIn: parent; width: parent.width - 20; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: root.targetText(latestCommand.target) + " · " + latestCommand.action + " · " + root.statusText(latestCommand.status) + (latestCommand.confirmation ? " · " + latestCommand.confirmation : ""); color: root.primaryText; font.pixelSize: 10; font.bold: true }
            }
        }

        VehicleLights {
            x: 0; y: 56; width: 800; height: 424; visible: root.page === 1
            lights: root.lights.items || []
            dayMode: root.dayMode
            onSetRequested: if (channel > 0) api.command("starpower", "set", enabled ? 1 : 0, { channel: channel })
            onDimRequested: if (channel > 0) api.command("starpower", "dim", value, { channel: channel })
            onFrontModeRequested: root.setFrontMode(mode)
        }

        Item {
            x: 0; y: 56; width: 800; height: 424; visible: root.page === 2
            Text { x: 12; y: 10; text: "SZENEN"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
            Text { x: 12; y: 25; text: "Mehrere Geräte mit einem Tipp"; color: root.primaryText; font.pixelSize: 18; font.bold: true }
            Text { x: 12; y: 48; text: "Jede Teilaktion wird einzeln durch echte Rückmeldung geprüft."; color: root.secondaryText; font.pixelSize: 10 }
            Repeater {
                model: operations.scenes || []
                delegate: TouchButton {
                    property var scene: modelData
                    x: 12 + (index % 3) * 174; y: 78 + Math.floor(index / 3) * 112; width: 164; height: 98
                    label: scene.name + "\n" + scene.actionCount + " AKTIONEN"; active: false; accentColor: "#f5c451"; onClicked: root.runScene(scene)
                }
            }
            Rectangle {
                x: 538; y: 10; width: 250; height: 395; radius: 11; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 10; text: "LETZTE BEFEHLE"; color: root.primaryText; font.pixelSize: 13; font.bold: true }
                Repeater {
                    model: commandData.recent ? Math.min(8, commandData.recent.length) : 0
                    delegate: Item {
                        property var command: commandData.recent[index]
                        x: 12; y: 38 + index * 43; width: 226; height: 40
                        Rectangle { x: 0; y: 4; width: 7; height: 7; radius: 4; color: command.status === "confirmed" ? "#32d4a0" : command.status === "pending" ? "#f5c451" : "#f36f79" }
                        Text { x: 15; y: 0; width: 140; elide: Text.ElideRight; text: root.targetText(command.target) + " · " + command.action; color: root.primaryText; font.pixelSize: 10; font.bold: true }
                        Text { x: 15; y: 18; text: root.timeText(command.createdAt); color: root.secondaryText; font.pixelSize: 8 }
                        Text { x: 157; y: 4; width: 69; horizontalAlignment: Text.AlignRight; text: root.statusText(command.status); color: command.status === "confirmed" ? "#32d4a0" : command.status === "pending" ? "#f5c451" : "#f36f79"; font.pixelSize: 8; font.bold: true }
                    }
                }
            }
        }

        Item {
            x: 0; y: 56; width: 800; height: 424; visible: root.page === 3
            Text { x: 12; y: 10; text: "ALARM- & EREIGNISCENTER"; color: root.primaryText; font.pixelSize: 18; font.bold: true }
            Text { x: 610; y: 14; text: (eventData.unacknowledgedCount || 0) + " UNBESTÄTIGT"; color: eventData.unacknowledgedCount ? "#f5c451" : "#32d4a0"; font.pixelSize: 10; font.bold: true }
            Repeater {
                model: eventData.recent ? Math.min(9, eventData.recent.length) : 0
                delegate: Rectangle {
                    property var eventItem: eventData.recent[index]
                    x: 12; y: 43 + index * 40; width: 776; height: 36; radius: 7; color: root.panelColor; border.color: eventItem.level === "critical" ? "#e05e68" : eventItem.level === "warning" ? "#dba942" : "#2b3946"
                    Rectangle { x: 9; y: 14; width: 8; height: 8; radius: 4; color: eventItem.level === "critical" ? "#e05e68" : eventItem.level === "warning" ? "#f5c451" : "#32d4a0" }
                    Text { x: 26; y: 5; width: 510; elide: Text.ElideRight; text: eventItem.text; color: root.primaryText; font.pixelSize: 10; font.bold: true }
                    Text { x: 26; y: 20; text: root.timeText(eventItem.createdAt) + " · " + eventItem.source; color: root.secondaryText; font.pixelSize: 8 }
                    Text { x: 545; y: 12; width: 100; horizontalAlignment: Text.AlignRight; text: eventItem.acknowledgedAt ? "BESTÄTIGT" : ""; color: root.secondaryText; font.pixelSize: 8; font.bold: true }
                    TouchButton { x: 658; y: 4; width: 108; height: 28; visible: !eventItem.acknowledgedAt && (eventItem.level === "warning" || eventItem.level === "critical"); label: "BESTÄTIGEN"; onClicked: api.command("system", "acknowledge", eventItem.id, { eventId: eventItem.id }) }
                }
            }
            Text { visible: !eventData.recent || !eventData.recent.length; anchors.centerIn: parent; text: "Keine Ereignisse"; color: root.secondaryText; font.pixelSize: 16 }
        }

        Item {
            x: 0; y: 56; width: 800; height: 424; visible: root.page === 4
            Rectangle {
                x: 10; y: 8; width: 492; height: 224; radius: 11; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "GERÄTEDIAGNOSE"; color: root.primaryText; font.pixelSize: 13; font.bold: true }
                Repeater {
                    model: operations.devices || []
                    delegate: Rectangle {
                        property var device: modelData
                        x: 12 + (index % 2) * 236; y: 37 + Math.floor(index / 2) * 45; width: 226; height: 39; radius: 7; color: root.innerPanelColor
                        Rectangle { x: 8; y: 9; width: 8; height: 8; radius: 4; color: device.online ? "#32d4a0" : "#e05e68" }
                        Text { x: 23; y: 5; width: 145; elide: Text.ElideRight; text: device.name; color: root.primaryText; font.pixelSize: 10; font.bold: true }
                        Text { x: 23; y: 20; text: "vor " + root.ageText(device.lastSeen) + " · Abbr. " + device.disconnects; color: root.secondaryText; font.pixelSize: 8 }
                        Text { x: 170; y: 12; width: 48; horizontalAlignment: Text.AlignRight; text: device.online ? "ONLINE" : "OFF"; color: device.online ? "#32d4a0" : "#e05e68"; font.pixelSize: 8; font.bold: true }
                    }
                }
            }
            Rectangle {
                x: 510; y: 8; width: 280; height: 224; radius: 11; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "VERLAUF & PROGNOSE"; color: root.primaryText; font.pixelSize: 13; font.bold: true }
                Text { x: 12; y: 39; text: "SOC-Trend 1 h"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 155; y: 35; text: root.signed(forecast.batterySocChange1h, " %"); color: "#32d4a0"; font.pixelSize: 14; font.bold: true }
                Text { x: 12; y: 70; text: "Solar Ø 15 min"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 155; y: 66; text: root.formatted(forecast.solarAverage15m, 0, " W"); color: "#f5c451"; font.pixelSize: 14; font.bold: true }
                Text { x: 12; y: 101; text: "Wasserreichweite"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 155; y: 97; text: root.formatted(forecast.freshWaterDays, 1, " Tage"); color: "#45c9fa"; font.pixelSize: 14; font.bold: true }
                Text { x: 12; y: 132; text: "Batterierestzeit"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 155; y: 128; text: root.duration(forecast.batteryTimeToGoSeconds); color: root.primaryText; font.pixelSize: 13; font.bold: true }
                Text { x: 12; y: 174; width: 256; wrapMode: Text.WordWrap; text: (historyData.samples ? historyData.samples.minute : 0) + " Minuten · " + (historyData.samples ? historyData.samples.quarterHour : 0) + " Viertelstunden · " + (historyData.samples ? historyData.samples.daily : 0) + " Tage lokal gespeichert"; color: root.secondaryText; font.pixelSize: 9 }
            }
            Rectangle {
                x: 10; y: 240; width: 780; height: 172; radius: 11; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "WARTUNGSPLAN"; color: root.primaryText; font.pixelSize: 13; font.bold: true }
                Repeater {
                    model: operations.maintenance || []
                    delegate: Item {
                        property var task: modelData
                        x: 12 + (index % 2) * 383; y: 37 + Math.floor(index / 2) * 42; width: 373; height: 38
                        Text { x: 0; y: 2; width: 225; elide: Text.ElideRight; text: task.name; color: root.primaryText; font.pixelSize: 10; font.bold: true }
                        Text { x: 0; y: 19; text: task.neverDone ? "noch nie erledigt" : (task.due ? "FÄLLIG" : "Termin " + root.timeText(task.dueAt)); color: task.due ? "#f5c451" : "#8392a2"; font.pixelSize: 8 }
                        TouchButton { x: 253; y: 1; width: 112; height: 30; label: "ERLEDIGT"; onClicked: api.command("system", "maintenanceDone", task.id, { taskId: task.id }) }
                    }
                }
            }
        }

        Item {
            x: 0; y: 56; width: 800; height: 424; visible: root.page === 5
            Rectangle {
                x: 10; y: 8; width: 780; height: 88; radius: 11; color: inverter.on ? (root.dayMode ? "#eee7ff" : "#282044") : root.panelColor; border.color: inverter.on ? "#8b61dc" : root.lineColor
                Text { x: 14; y: 10; text: "230 V · VICTRON MULTIPLUS COMPACT"; color: "#a99ac4"; font.pixelSize: 9; font.bold: true }
                Text { x: 14; y: 30; width: 260; elide: Text.ElideRight; text: inverter.stateText || "Keine Rückmeldung"; color: root.primaryText; font.pixelSize: 17; font.bold: true }
                Text { x: 14; y: 56; text: root.formatted(inverter.outputPower, 0, " W Ausgang") + " · Landstrom " + (inverter.shoreConnected ? "verbunden" : "getrennt"); color: root.secondaryText; font.pixelSize: 10 }
                Rectangle { x: 493; y: 17; width: 9; height: 9; radius: 5; color: inverter.online ? "#32d4a0" : "#e05e68" }
                Text { x: 511; y: 15; text: inverter.online ? "VE.BUS BEREIT" : "KEINE RÜCKMELDUNG"; color: inverter.online ? "#32d4a0" : "#e05e68"; font.pixelSize: 9; font.bold: true }
                TouchButton { x: 620; y: 22; width: 144; height: 48; label: inverter.on ? "230 V AUS" : "230 V AN"; active: inverter.on === true; accentColor: "#b490ff"; onClicked: api.command("inverter", "set", !inverter.on) }
            }
            Text { x: 12; y: 108; text: "12 V · SAFIERY STAR-POWER 30 A"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
            Repeater {
                model: Math.min(6, dcChannels.length)
                delegate: Rectangle {
                    property var channelItem: dcChannels[index]
                    property string displayName: Number(channelItem.channel) === 3 ? "Fernlicht manuell" : (channelItem.name || "12 V Kanal")
                    x: 10 + (index % 3) * 263; y: 130 + Math.floor(index / 3) * 134; width: 253; height: 122; radius: 11
                    color: channelItem.on ? (root.dayMode ? "#d9f4eb" : "#173b32") : root.innerPanelColor; border.color: channelItem.on ? "#32d4a0" : root.lineColor
                    Rectangle { x: 12; y: 13; width: 8; height: 8; radius: 4; color: channelItem.online ? "#32d4a0" : "#e05e68" }
                    Text { x: 28; y: 8; width: 170; elide: Text.ElideRight; text: displayName; color: root.primaryText; font.pixelSize: 14; font.bold: true }
                    Text { x: 204; y: 10; text: "CH " + channelItem.channel; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                    Text { x: 12; y: 36; text: channelItem.on ? "EINGESCHALTET" : "AUSGESCHALTET"; color: channelItem.on ? "#65e7bd" : "#8392a2"; font.pixelSize: 9; font.bold: true }
                    TouchButton { x: 12; y: 64; width: 229; height: 43; label: channelItem.on ? "AUSSCHALTEN" : "EINSCHALTEN"; active: channelItem.on === true; onClicked: api.command("starpower", "set", channelItem.on ? 0 : 1, { channel: channelItem.channel }) }
                }
            }
            Text { visible: !dcChannels.length; anchors.centerIn: parent; text: "Keine 12-V-Kanäle konfiguriert"; color: root.secondaryText; font.pixelSize: 15 }
        }

        Item {
            x: 0; y: 56; width: 800; height: 424; visible: root.page === 6
            transform: Scale { origin.x: 0; origin.y: 0; yScale: root.detailScaleY }
            Rectangle {
                x: 10; y: 8; width: 780; height: 52; radius: 10; color: heater.cooling ? (root.dayMode ? "#eee7ff" : "#35284b") : heater.on ? (root.dayMode ? "#fff0df" : "#3b2916") : root.panelColor; border.color: heater.cooling ? "#8b61dc" : heater.on ? "#dc7429" : root.lineColor
                TouchButton { x: 7; y: 8; width: 72; height: 36; label: "ZURÜCK"; onClicked: root.page = 0 }
                Text { x: 92; y: 7; text: "AUTOTERM AIR 2D"; color: root.primaryText; font.pixelSize: 15; font.bold: true }
                Text { x: 92; y: 28; width: 310; elide: Text.ElideRight; text: heater.warning || heater.startBlocked || heater.status || "Keine Daten"; color: heater.warning || heater.startBlocked ? "#f5c451" : "#aeb9c5"; font.pixelSize: 9 }
                Rectangle { x: 455; y: 21; width: 9; height: 9; radius: 5; color: heater.online ? "#32d4a0" : "#e05e68" }
                Text { x: 473; y: 18; text: heater.online ? root.heaterModeText(heater.mode) : "KEINE SERIELLE VERBINDUNG"; color: heater.online ? "#32d4a0" : "#e05e68"; font.pixelSize: 9; font.bold: true }
                TouchButton { x: 630; y: 8; width: 140; height: 36; label: heater.cooling ? "NACHLAUF" : (heater.on ? "STOPPEN" : "STARTEN"); active: heater.on === true; enabled: heater.cooling !== true && (heater.on === true || !heater.startBlocked); accentColor: "#f39b58"; onClicked: api.command("heater", heater.on ? "stop" : "start", null) }
            }

            Rectangle {
                x: 10; y: 68; width: 382; height: 156; radius: 10; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "BETRIEBSART"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                TouchButton { x: 12; y: 29; width: 112; height: 34; label: "TEMPERATUR"; active: heater.mode === "temperature"; accentColor: "#f39b58"; onClicked: root.heaterSetting("mode", "temperature") }
                TouchButton { x: 134; y: 29; width: 112; height: 34; label: "LEISTUNG"; active: heater.mode === "power"; accentColor: "#f39b58"; onClicked: root.heaterSetting("mode", "power") }
                TouchButton { x: 256; y: 29; width: 112; height: 34; label: "LÜFTEN"; active: heater.mode === "ventilation"; accentColor: "#45c9fa"; onClicked: root.heaterSetting("mode", "ventilation") }
                Text { x: 12; y: 78; text: heater.mode === "power" ? "Leistungsstufe" : heater.mode === "ventilation" ? "Lüftungsbetrieb" : "Solltemperatur"; color: root.secondaryText; font.pixelSize: 10 }
                TouchButton { x: 144; y: 70; width: 42; height: 34; visible: heater.mode !== "ventilation"; label: "−"; onClicked: heater.mode === "power" ? root.heaterSetting("power", Math.max(1, Number(heater.powerLevel || 5) - 1)) : api.command("heater", "setpoint", Math.max(5, Number(heater.setpoint || 20) - 1)) }
                Text { x: 194; y: 78; width: 70; horizontalAlignment: Text.AlignHCenter; text: heater.mode === "power" ? root.formatted(heater.powerLevel, 0, " / 10") : heater.mode === "ventilation" ? "AKTIV" : root.formatted(heater.setpoint, 0, " °C"); color: root.primaryText; font.pixelSize: 13; font.bold: true }
                TouchButton { x: 272; y: 70; width: 42; height: 34; visible: heater.mode !== "ventilation"; label: "+"; onClicked: heater.mode === "power" ? root.heaterSetting("power", Math.min(10, Number(heater.powerLevel || 5) + 1)) : api.command("heater", "setpoint", Math.min(30, Number(heater.setpoint || 20) + 1)) }
                Text { x: 12; y: 122; text: "Laufzeit"; color: root.secondaryText; font.pixelSize: 10 }
                TouchButton { x: 85; y: 112; width: 42; height: 34; label: "−"; onClicked: root.heaterSetting("duration", Math.max(0, Number(heater.durationMinutes || 0) - 60)) }
                Text { x: 136; y: 121; width: 105; horizontalAlignment: Text.AlignHCenter; text: Number(heater.durationMinutes || 0) === 0 ? "DAUERBETRIEB" : (Number(heater.durationMinutes) / 60) + " STUNDEN"; color: root.primaryText; font.pixelSize: 10; font.bold: true }
                TouchButton { x: 251; y: 112; width: 42; height: 34; label: "+"; onClicked: root.heaterSetting("duration", Math.min(720, Number(heater.durationMinutes || 0) + 60)) }
                TouchButton { x: 303; y: 112; width: 65; height: 34; label: "STANDBY"; active: heater.standbyVent === true; onClicked: root.heaterSetting("standbyVent", !heater.standbyVent) }
            }

            Rectangle {
                x: 400; y: 68; width: 390; height: 156; radius: 10; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "SENSOR & SCHUTZ"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                Text { x: 12; y: 35; text: "Regelsensor"; color: root.secondaryText; font.pixelSize: 10 }
                TouchButton { x: 125; y: 26; width: 144; height: 34; label: root.sensorText(heater.tempSource); active: heater.sensorOnline === true; onClicked: root.heaterSetting("tempSource", root.nextValue(heater.tempSource, ["ruuvi1", "ruuvi2", "ruuvi3", "internal", "external"])) }
                Text { x: 279; y: 35; text: heater.sensorFallback ? "ERSATZ AKTIV" : (heater.sensorOnline ? "BEREIT" : "FEHLT"); color: heater.sensorOnline ? "#32d4a0" : "#f5c451"; font.pixelSize: 8; font.bold: true }
                TouchButton { x: 12; y: 68; width: 112; height: 34; label: "FROSTSCHUTZ"; active: heater.frostEnabled === true; accentColor: "#45c9fa"; onClicked: root.heaterSetting("frostEnabled", !heater.frostEnabled) }
                Text { x: 135; y: 77; text: "Start " + root.formatted(heater.frostTemp, 0, " °C") + " · Stopp " + root.formatted(heater.frostStop, 0, " °C"); color: root.primaryText; font.pixelSize: 10; font.bold: true }
                TouchButton { x: 302; y: 68; width: 35; height: 34; label: "−"; onClicked: root.heaterSetting("frostTemp", Math.max(0, Number(heater.frostTemp || 5) - 1)) }
                TouchButton { x: 343; y: 68; width: 35; height: 34; label: "+"; onClicked: root.heaterSetting("frostTemp", Math.min(12, Number(heater.frostTemp || 5) + 1)) }
                Text { x: 12; y: 122; text: "Unterspannung"; color: root.secondaryText; font.pixelSize: 10 }
                TouchButton { x: 125; y: 112; width: 42; height: 34; label: "−"; onClicked: root.heaterSetting("lowVoltage", Math.max(10.5, Math.round((Number(heater.lowVoltage || 11.5) - 0.1) * 10) / 10)) }
                Text { x: 176; y: 121; width: 70; horizontalAlignment: Text.AlignHCenter; text: root.formatted(heater.lowVoltage, 1, " V"); color: root.primaryText; font.pixelSize: 11; font.bold: true }
                TouchButton { x: 255; y: 112; width: 42; height: 34; label: "+"; onClicked: root.heaterSetting("lowVoltage", Math.min(13, Math.round((Number(heater.lowVoltage || 11.5) + 0.1) * 10) / 10)) }
                TouchButton { x: 305; y: 112; width: 73; height: 34; label: heater.batterySource === "victron" ? "VICTRON" : "HEIZUNG"; onClicked: root.heaterSetting("batterySource", heater.batterySource === "victron" ? "heater" : "victron") }
            }

            Rectangle {
                x: 10; y: 232; width: 382; height: 180; radius: 10; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "STATUS & TECHNIK"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                Text { x: 12; y: 31; text: "Innenraum"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 118; y: 27; text: root.formatted(climate.roomTemperature, 1, " °C"); color: root.primaryText; font.pixelSize: 14; font.bold: true }
                Text { x: 205; y: 31; text: "Heizung"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 294; y: 27; text: root.formatted(heater.voltage, 1, " V"); color: root.primaryText; font.pixelSize: 14; font.bold: true }
                Text { x: 12; y: 68; text: "Wärmetauscher"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 118; y: 64; text: root.formatted(heater.heatExchangerTemperature, 1, " °C"); color: root.primaryText; font.pixelSize: 13; font.bold: true }
                Text { x: 205; y: 68; text: "Gebläse"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 294; y: 64; text: root.formatted(heater.fanRpm, 0, " rpm"); color: root.primaryText; font.pixelSize: 13; font.bold: true }
                Text { x: 12; y: 105; text: "Kraftstoffpumpe"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 118; y: 101; text: root.formatted(heater.pumpHz, 2, " Hz"); color: root.primaryText; font.pixelSize: 13; font.bold: true }
                Text { x: 205; y: 105; text: "Fehler"; color: root.secondaryText; font.pixelSize: 9 }
                Text { x: 294; y: 101; text: Number(heater.error || 0) ? "E" + heater.error : "KEINER"; color: Number(heater.error || 0) ? "#e05e68" : "#32d4a0"; font.pixelSize: 12; font.bold: true }
                Text { x: 12; y: 143; width: 356; elide: Text.ElideRight; text: "Start: " + (heater.startedBy || "–") + (heater.endAt ? " · Ende " + root.timeText(heater.endAt) : " · Dauerbetrieb"); color: root.secondaryText; font.pixelSize: 9 }
            }

            Rectangle {
                x: 400; y: 232; width: 390; height: 180; radius: 10; color: root.panelColor; border.color: root.lineColor
                Text { x: 12; y: 9; text: "AUTOTERM-WARTUNG"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                Text { x: 12; y: 31; text: heater.maintenanceActive ? "WARTUNGSLAUF AKTIV" : heater.maintenanceDue ? "MONATLICHER LAUF FÄLLIG" : "MONATLICHER LAUF ERLEDIGT"; color: heater.maintenanceActive || heater.maintenanceDue ? "#f5c451" : "#32d4a0"; font.pixelSize: 11; font.bold: true }
                Text { x: 12; y: 51; text: heater.maintenanceActive ? Math.floor(Number(heater.maintenanceSeconds || 0) / 60) + " / 20 min" : "Zuletzt: " + root.timeText(heater.lastMaintenanceRun); color: root.secondaryText; font.pixelSize: 9 }
                TouchButton { x: 12; y: 72; width: 366; height: 38; label: heater.maintenanceActive ? "WARTUNGSLAUF LÄUFT" : "20-MIN-WARTUNGSLAUF STARTEN"; enabled: !heater.on && !heater.cooling && !heater.maintenanceActive && !heater.startBlocked; active: heater.maintenanceActive === true; accentColor: "#f5c451"; onClicked: api.command("heater", "maintenance", null) }
                Text { x: 12; y: 123; text: heater.annualServiceDue ? "JAHRESWARTUNG FÄLLIG" : "JAHRESWARTUNG DOKUMENTIERT"; color: heater.annualServiceDue ? "#f5c451" : "#32d4a0"; font.pixelSize: 10; font.bold: true }
                TouchButton { x: 229; y: 116; width: 149; height: 36; label: "ALS ERLEDIGT"; onClicked: api.command("heater", "annualDone", null) }
                Text { x: 12; y: 151; text: "Zuletzt: " + root.timeText(heater.lastAnnualService); color: root.secondaryText; font.pixelSize: 9 }
            }
        }

        Item {
            x: 0; y: 56; width: 800; height: 424; visible: false
            Rectangle {
                x: 10; y: 8; width: 780; height: 56; radius: 13; color: root.panelColor; border.color: root.lineColor
                TouchButton { x: 8; y: 9; width: 76; height: 38; label: "ZURÜCK"; onClicked: root.page = 0 }
                Text { x: 98; y: 8; text: "INDEVOLT ENERGIESPEICHER"; color: root.primaryText; font.pixelSize: 15; font.bold: true }
                Text { x: 98; y: 31; text: "Automatisch erkannt · " + Number(indevolt.onlineCount || 0) + " von " + Number(indevolt.totalCount || 0) + " online"; color: indevolt.online ? "#32d4a0" : "#e05e68"; font.pixelSize: 9; font.bold: true }
                Text { x: 565; y: 10; width: 95; horizontalAlignment: Text.AlignRight; text: root.formatted(indevolt.solarPower, 0, " W"); color: "#f5c451"; font.pixelSize: 21; font.bold: true }
                Text { x: 565; y: 34; width: 95; horizontalAlignment: Text.AlignRight; text: "SOLAR"; color: root.secondaryText; font.pixelSize: 8; font.bold: true }
                Text { x: 678; y: 10; width: 88; horizontalAlignment: Text.AlignRight; text: root.formatted(indevolt.soc, 0, " %"); color: root.primaryText; font.pixelSize: 21; font.bold: true }
                Text { x: 678; y: 34; width: 88; horizontalAlignment: Text.AlignRight; text: "Ø SOC"; color: root.secondaryText; font.pixelSize: 8; font.bold: true }
            }

            Rectangle {
                x: 10; y: 72; width: 214; height: 342; radius: 13; color: root.innerPanelColor; border.color: root.lineColor
                Text { x: 14; y: 14; text: "ENERGIEFLUSS"; color: "#32d4a0"; font.pixelSize: 9; font.bold: true }
                Text { x: 14; y: 45; text: "SOLAR"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                Text { x: 14; y: 60; text: root.formatted(indevolt.solarPower, 0, " W"); color: "#f5c451"; font.pixelSize: 27; font.bold: true }
                Rectangle { x: 14; y: 101; width: 186; height: 1; color: root.lineColor }
                Text { x: 14; y: 117; text: "BATTERIE"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                Text { x: 14; y: 132; text: root.signed(indevolt.batteryPower, " W"); color: root.primaryText; font.pixelSize: 23; font.bold: true }
                Rectangle { x: 14; y: 173; width: 186; height: 1; color: root.lineColor }
                Text { x: 14; y: 189; text: "AC AUSGANG"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                Text { x: 14; y: 204; text: root.formatted(indevolt.acOutputPower, 0, " W"); color: "#b490ff"; font.pixelSize: 23; font.bold: true }
                Text { x: 14; y: 246; text: "AC Eingang " + root.formatted(indevolt.acInputPower, 0, " W"); color: root.secondaryText; font.pixelSize: 10 }
                Rectangle { x: 14; y: 276; width: 186; height: 44; radius: 10; color: indevolt.online ? (root.dayMode ? "#d9f4eb" : "#17372f") : (root.dayMode ? "#f9dfe2" : "#3d2228"); border.color: indevolt.online ? "#32d4a0" : "#e05e68" }
                Rectangle { x: 26; y: 294; width: 8; height: 8; radius: 4; color: indevolt.online ? "#32d4a0" : "#e05e68" }
                Text { x: 43; y: 290; text: indevolt.online ? "SYSTEM BEREIT" : "NICHT VERBUNDEN"; color: root.primaryText; font.pixelSize: 10; font.bold: true }
            }

            Rectangle {
                x: 232; y: 72; width: 558; height: 342; radius: 13; color: root.innerPanelColor; border.color: root.lineColor
                Text { x: 14; y: 13; text: "GERÄTE IM NETZWERK"; color: root.secondaryText; font.pixelSize: 9; font.bold: true }
                Text { visible: root.indevoltDevices.length === 0; anchors.centerIn: parent; text: "Kein INDEVOLT erreichbar\nErkennung läuft im Hintergrund"; horizontalAlignment: Text.AlignHCenter; color: root.secondaryText; font.pixelSize: 13; lineHeight: 1.4 }
                Flickable {
                    x: 10; y: 35; width: 538; height: 297
                    contentWidth: width; contentHeight: deviceColumn.height
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: deviceColumn
                        width: 538; spacing: 8
                        Repeater {
                            model: root.indevoltDevices
                            delegate: Rectangle {
                                property var dev: modelData
                                width: 538; height: 88; radius: 11
                                color: dev.online ? (root.dayMode ? "#e1f5ef" : "#162a27") : (root.dayMode ? "#f2ecee" : "#1e1c22")
                                border.color: dev.online ? "#286c59" : "#50313a"
                                Rectangle { x: 0; y: 14; width: 4; height: 60; radius: 2; color: dev.online ? "#32d4a0" : "#e05e68" }
                                Text { x: 14; y: 10; width: 240; elide: Text.ElideRight; text: dev.serial ? "INDEVOLT " + String(dev.serial).slice(-6) : "INDEVOLT"; color: root.primaryText; font.pixelSize: 14; font.bold: true }
                                Text { x: 14; y: 31; width: 240; elide: Text.ElideRight; text: dev.serial || "Seriennummer wird gelesen"; color: root.secondaryText; font.pixelSize: 8 }
                                Text { x: 14; y: 57; width: 190; elide: Text.ElideRight; text: dev.status || "Offline"; color: dev.online ? "#32d4a0" : "#e05e68"; font.pixelSize: 10; font.bold: true }
                                Text { x: 265; y: 11; width: 63; horizontalAlignment: Text.AlignRight; text: root.formatted(dev.soc, 0, " %"); color: root.primaryText; font.pixelSize: 17; font.bold: true }
                                Text { x: 339; y: 11; width: 82; horizontalAlignment: Text.AlignRight; text: root.formatted(dev.solarPower, 0, " W"); color: "#f5c451"; font.pixelSize: 17; font.bold: true }
                                Text { x: 432; y: 11; width: 92; horizontalAlignment: Text.AlignRight; text: root.signed(dev.batteryPower, " W"); color: root.primaryText; font.pixelSize: 17; font.bold: true }
                                Text { x: 265; y: 36; width: 63; horizontalAlignment: Text.AlignRight; text: "SOC"; color: root.secondaryText; font.pixelSize: 8 }
                                Text { x: 339; y: 36; width: 82; horizontalAlignment: Text.AlignRight; text: "SOLAR"; color: root.secondaryText; font.pixelSize: 8 }
                                Text { x: 432; y: 36; width: 92; horizontalAlignment: Text.AlignRight; text: "BATTERIE"; color: root.secondaryText; font.pixelSize: 8 }
                                Text { x: 265; y: 61; width: 259; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: (dev.mode || "–") + " · AC " + root.formatted(dev.acOutputPower, 0, " W"); color: root.secondaryText; font.pixelSize: 9 }
                            }
                        }
                    }
                }
            }
        }

        EnergySolarDetails {
            x: 0; y: 56; width: 800; height: 424
            visible: root.page === 7
            transform: Scale { origin.x: 0; origin.y: 0; yScale: root.detailScaleY }
            dayMode: root.dayMode
            solar: root.solar
            indevolt: root.indevolt
            orion: root.orion
            onBackRequested: root.page = 0
            onOrionCommandRequested: api.command("orion", "set", enabledState)
            onIndevoltGridCommandRequested: api.command("indevoltGrid", "set", enabledState)
        }

        BatteryDetails {
            x: 0; y: 56; width: 800; height: 424
            visible: root.page === 8
            transform: Scale { origin.x: 0; origin.y: 0; yScale: root.detailScaleY }
            dayMode: root.dayMode
            battery: root.battery
            onBackRequested: root.page = 0
        }

        MaxxFanDetails {
            x: 0; y: 56; width: 800; height: 424
            visible: root.page === 9
            transform: Scale { origin.x: 0; origin.y: 0; yScale: root.detailScaleY }
            dayMode: root.dayMode
            fan: root.fan
            onBackRequested: root.page = 0
            onCommandRequested: api.command("maxxfan", action, value)
        }

        TemperatureDetails {
            x: 0; y: 56; width: 800; height: 424
            visible: root.page === 10
            transform: Scale { origin.x: 0; origin.y: 0; yScale: root.detailScaleY }
            dayMode: root.dayMode
            climate: root.climate
            heater: root.heater
            temperatureSensors: root.temperatureSensors
            onBackRequested: root.page = 0
            onVentilationPatchRequested: api.command("settings", "patch", null, { patch: patch })
            onClimateAutomationPatchRequested: api.command("settings", "patch", null, { patch: patch })
            onTemperatureSensorPatchRequested: api.command("settings", "patch", null, { patch: patch })
        }

        ModernShell {
            x: 0; y: 0; width: 800; height: 480; z: 80
            visible: root.designVersion === "v2" && root.page >= 0 && root.page <= 5 && !root.settingsOpen
            host: root
            api: api
            snapshot: root.snapshot
            dayMode: root.dayMode
            quickAccessIds: root.quickAccessIds
        }

        Rectangle {
            x: 0; y: 422; width: 800; height: 58; z: 120
            visible: root.designVersion === "v1"
            color: root.headerColor
            border.color: root.lineColor

            Repeater {
                model: [
                    { label: "HOME", page: 0 }, { label: "LICHT", page: 1 }, { label: "12 / 230", page: 5 }
                ]
                delegate: Rectangle {
                    property bool selected: root.page === modelData.page || (modelData.page === 0 && root.page >= 6)
                    x: index * 267
                    y: 0
                    width: index === 2 ? 266 : 267
                    height: 58
                    color: selected ? visual.selectedBlue : "transparent"
                    border.color: root.lineColor

                    Rectangle {
                        x: 0; y: 0; width: parent.width; height: 3
                        color: selected ? root.fordBlue : "transparent"
                    }
                    LineIcon {
                        x: 18; y: 14; width: 30; height: 30
                        kind: modelData.page === 0 ? "home" : (modelData.page === 1 ? "light" : "power")
                        lineColor: selected ? root.fordBlue : root.primaryText; strokeWidth: 2
                    }
                    Text {
                        x: 55; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: selected ? root.fordBlue : root.primaryText
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.settingsOpen = false; root.page = modelData.page }
                    }
                }
            }
        }

        SettingsPanel {
            id: settingsPanel
            anchors.fill: parent
            visible: root.settingsOpen
            z: 100
            host: root
        }

        Timer {
            interval: 1000; repeat: true; running: true
            onTriggered: root.now = new Date().getTime()
        }
    }
}
