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
    property string settingsUrl: baseUrl
    property bool showExternalWifiTile: true
    property var remoteConfig: ({})
    property var lightMapping: []
    property var quickAccessIds: ["switch:water_pump", "switch:starlink", "switch:dc_outlets_left", "light:inside_main"]
    property double now: new Date().getTime()
    property alias page: modernShell.currentPage

    property var snapshot: api.stateData || ({})
    property var system: snapshot.system || ({})
    property var lights: snapshot.lights || ({})
    property var operations: snapshot.operations || ({})
    property var eventData: operations.events || ({})

    CamperStyle { id: visual; dayMode: root.dayMode }

    function formatted(value, digits, suffix) {
        if (value === null || value === undefined || value === "" || !isFinite(Number(value))) return "–"
        return Number(value).toFixed(digits) + (suffix || "")
    }

    function timeText(timestamp) {
        if (!timestamp) return "–"
        return new Date(Number(timestamp)).toLocaleString(Qt.locale("de_DE"), "dd.MM. hh:mm")
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
            // Frühere designVersion-Werte werden absichtlich ignoriert: 3.12 ist V2-only.
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
            showExternalWifiTile: showExternalWifiTile
        }))
    }

    function writeLocalSettings() {
        baseUrl = api.cleanBaseUrl(settingsUrl)
        settingsUrl = baseUrl
        try {
            persistLocalSettings()
        } catch (error) {
            api.errorText = "Einstellungen konnten nicht gespeichert werden"
        }
        settingsOpen = false
        api.reconnect()
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
        for (var i = 0; i < options.length; ++i)
            if (options[i].id === id) return options[i].group + " · " + options[i].name
        return id || "Nicht belegt"
    }

    function changeQuickAccess(index, direction) {
        var options = quickAccessOptions()
        if (!options.length || index < 0 || index >= 4) return
        var choices = []
        for (var optionIndex = 0; optionIndex < options.length; ++optionIndex) choices.push(options[optionIndex].id)
        var current = choices.indexOf(quickAccessIds[index])
        if (current < 0) current = 0
        var wanted = choices[(current + direction + choices.length) % choices.length]
        var occupant = quickAccessIds.indexOf(wanted)
        var updated = quickAccessIds.slice(0)
        while (updated.length < 4) updated.push("")
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

    function saveRemoteConfiguration() {
        var patch = { ui: { quickAccessIds: quickAccessIds } }
        if (lightMapping.length) {
            var updated = []
            for (var i = 0; i < lightMapping.length; ++i) {
                var light = lightMapping[i]
                updated.push({ id: light.id, name: light.name, channel: Number(light.channel), dimmable: light.dimmable, area: light.area, visible: light.visible })
            }
            patch.lights = updated
        }
        api.command("settings", "patch", null, { patch: patch })
    }

    function requestClose() {
        if (embeddedInGlobalHost) closeRequested()
        else back()
    }

    function openSettings() {
        settingsUrl = baseUrl
        settingsOpen = true
        api.readSettings()
        api.command("service", "refresh", null, {})
    }

    function saveSettings() {
        saveRemoteConfiguration()
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
        for (var i = 0; i < items.length; ++i)
            if (area === "all" || items[i].area === area)
                api.command("starpower", "set", on ? 1 : 0, { channel: items[i].channel })
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

        ModernShell {
            id: modernShell
            x: 0; y: 0; width: 800; height: 480
            visible: !root.settingsOpen
            host: root
            api: api
            snapshot: root.snapshot
            dayMode: root.dayMode
            quickAccessIds: root.quickAccessIds
            now: root.now
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
