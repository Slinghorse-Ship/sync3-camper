import QtQuick 2.6

Item {
    id: root

    property string baseUrl: "http://172.24.24.1:1880/camper/api/v2"
    property bool connected: false
    property bool polling: false
    // Die Synchronisierung läuft ohne zeitliche Begrenzung. Der große
    // Gesamtzustand wird auf der alten SYNC-Hardware jedoch bewusst nicht
    // zweimal pro Sekunde verarbeitet. Nach Bedienbefehlen folgen separate,
    // schnelle Bestätigungsabfragen.
    property int pollIntervalMs: 1500
    property bool requestActive: false
    property var activePollRequest: null
    property string statusText: "Nicht verbunden"
    property string errorText: ""
    property string networkType: "unknown"
    property string clientAddress: ""
    property string activeBaseUrl: ""
    property int candidateIndex: 0
    property int requestSequence: 0
    property int activeFailureCount: 0
    property int activeFailureTolerance: 2
    property int commandFollowupsRemaining: 0
    property bool commandActive: false
    property var activeCommandRequest: null
    property var commandQueue: []
    property int commandQueueLimit: 8
    property bool settingsReadPending: false
    property bool settingsRequestActive: false
    property var activeSettingsRequest: null
    // "state" ist bereits eine eingebaute Item-Eigenschaft und darf in
    // QtQuick 2.6 nicht mit einem anderen Typ neu deklariert werden.
    property var stateData: ({})
    property var lastCommandResult: ({})

    signal commandResult(var result)
    signal settingsReceived(var settings)

    function cleanBaseUrl(value) {
        var result = String(value || "").replace(/^\s+|\s+$/g, "")
        if (!result) result = "172.24.24.1"
        // CamperControl ist eine rein lokale HTTP-API. Frühere Versionen
        // übernahmen ein gespeichertes https:// (oder die Dashboard-URL auf
        // Port 1881) unverändert und lösten dadurch Zertifikatsfehler aus.
        // Deshalb werden Schema, Port und Pfad hier kanonisch festgelegt.
        result = result.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "")
        result = result.replace(/^\/+/, "")
        var pathStart = result.indexOf("/")
        var authority = pathStart >= 0 ? result.substring(0, pathStart) : result
        var queryStart = authority.search(/[?#]/)
        if (queryStart >= 0) authority = authority.substring(0, queryStart)

        // Das Fahrzeugnetz verwendet IPv4/mDNS-Namen. Ein eventuell
        // gespeicherter Dashboard- oder API-Port wird durch 1880 ersetzt.
        var portStart = authority.lastIndexOf(":")
        if (portStart > 0) authority = authority.substring(0, portStart)
        if (!authority) authority = "172.24.24.1"
        return "http://" + authority + ":1880/camper/api/v2"
    }

    function parseResponse(xhr) {
        try {
            return JSON.parse(xhr.responseText || "{}")
        } catch (error) {
            return null
        }
    }

    function candidateUrls() {
        var values = []
        function add(value) {
            var candidate = cleanBaseUrl(value)
            for (var i = 0; i < values.length; ++i) if (values[i] === candidate) return
            values.push(candidate)
        }
        if (activeBaseUrl) add(activeBaseUrl)
        add(baseUrl)
        add("http://172.24.24.1:1880/camper/api/v2")
        // Wenn SYNC statt am Cerbo-AP direkt am Fahrzeug-/Starlink-LAN
        // angemeldet ist, ist der Cerbo über seine bevorzugte Ethernet-
        // Adresse erreichbar. Diese Suche bleibt für den Benutzer unsichtbar.
        add("http://192.168.1.84:1880/camper/api/v2")
        add("http://venus.local:1880/camper/api/v2")
        add("http://einstein:1880/camper/api/v2")
        add("http://einstein.local:1880/camper/api/v2")
        return values
    }

    function currentBaseUrl() {
        var values = candidateUrls()
        if (!values.length) return cleanBaseUrl(baseUrl)
        return values[Math.max(0, Math.min(candidateIndex, values.length - 1))]
    }

    function connectionFailed(status) {
        var values = candidateUrls()
        // Kurze WLAN-/Node-RED-Hänger dürfen die bestehende Verbindung nicht
        // sofort verwerfen. Erst danach beginnt die unsichtbare Fallback-Suche.
        if (activeBaseUrl && currentBaseUrl() === activeBaseUrl && activeFailureCount + 1 < activeFailureTolerance) {
            activeFailureCount += 1
            retryPoll.restart()
            return
        }
        activeFailureCount = 0
        candidateIndex += 1
        if (candidateIndex < values.length) {
            retryPoll.restart()
            return
        }
        candidateIndex = 0
        activeBaseUrl = ""
        connected = false
        statusText = "Keine Verbindung"
        errorText = statusText
    }

    function networkRequestActive() {
        return requestActive || commandActive || settingsRequestActive
    }

    function scheduleNextRequest() {
        requestDrain.restart()
    }

    function drainRequests() {
        if (networkRequestActive()) return
        if (commandQueue.length > 0) {
            if (!connected) {
                commandQueue = []
                errorText = "Keine Verbindung"
                commandResult({ ok: false, error: errorText })
                return
            }
            startNextCommand()
            return
        }
        if (settingsReadPending) startSettingsRead()
    }

    function poll() {
        if (networkRequestActive()) return
        requestActive = true
        var xhr = new XMLHttpRequest()
        activePollRequest = xhr
        var attemptedUrl = currentBaseUrl()
        xhr.open("GET", attemptedUrl + "/state", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            if (xhr !== root.activePollRequest) return
            pollWatchdog.stop()
            root.activePollRequest = null
            root.requestActive = false
            var packet = root.parseResponse(xhr)
            if (xhr.status >= 200 && xhr.status < 300 && packet && packet.ok && packet.state) {
                if (!root.stateData || Number(root.stateData.sequence || -1) !== Number(packet.state.sequence || 0))
                    root.stateData = packet.state
                if (packet.connection) {
                    root.networkType = String(packet.connection.networkType || "unknown")
                    root.clientAddress = String(packet.connection.clientAddress || "")
                }
                root.connected = true
                root.activeBaseUrl = attemptedUrl
                root.candidateIndex = 0
                root.activeFailureCount = 0
                root.statusText = "Verbunden"
                root.errorText = ""
            } else {
                root.connectionFailed(xhr.status)
            }
            root.scheduleNextRequest()
        }
        try {
            pollWatchdog.restart()
            xhr.send()
        } catch (error) {
            pollWatchdog.stop()
            activePollRequest = null
            requestActive = false
            connectionFailed(0)
            scheduleNextRequest()
        }
    }

    function command(target, action, value, extra) {
        if (!connected) {
            errorText = "Keine Verbindung"
            commandResult({ ok: false, error: errorText })
            return
        }
        var body = ({})
        var supplied = extra || ({})
        for (var key in supplied) body[key] = supplied[key]
        body.target = target
        body.action = action
        body.value = value
        // Node-RED remains the authority. SYNC only labels its local intent;
        // notably Starlink channel 5 may still be switched off locally.
        body.origin = "sync"
        requestSequence += 1
        body.requestId = "sync3-" + new Date().getTime() + "-" + requestSequence

        var queued = commandQueue.slice(0)
        var channel = body.channel === undefined ? "" : String(body.channel)
        var coalescable = action === "dim" || action === "speed"
        if (coalescable) {
            for (var index = queued.length - 1; index >= 0; --index) {
                var pending = queued[index]
                var pendingChannel = pending.channel === undefined ? "" : String(pending.channel)
                if (pending.target === target && pending.action === action && pendingChannel === channel) {
                    queued[index] = body
                    commandQueue = queued
                    scheduleNextRequest()
                    return
                }
            }
        }
        if (queued.length >= commandQueueLimit) {
            errorText = "Befehlswarteschlange voll"
            commandResult({ ok: false, error: errorText })
            return
        }
        queued.push(body)
        commandQueue = queued
        scheduleNextRequest()
    }

    function startNextCommand() {
        if (networkRequestActive() || commandQueue.length <= 0) return
        var queued = commandQueue.slice(0)
        var body = queued.shift()
        commandQueue = queued
        commandActive = true
        var xhr = new XMLHttpRequest()
        activeCommandRequest = xhr
        xhr.open("POST", (activeBaseUrl || cleanBaseUrl(baseUrl)) + "/command", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            if (xhr !== root.activeCommandRequest) return
            commandWatchdog.stop()
            root.activeCommandRequest = null
            root.commandActive = false
            var packet = root.parseResponse(xhr)
            if (xhr.status >= 200 && xhr.status < 300 && packet) {
                root.lastCommandResult = packet
                root.commandResult(packet)
                root.commandFollowupsRemaining = Math.min(5, root.commandFollowupsRemaining + 5)
                delayedPoll.restart()
                commandFollowupPoll.restart()
            } else {
                root.errorText = "Befehl fehlgeschlagen"
                root.commandResult(packet || { ok: false, error: root.errorText })
            }
            root.scheduleNextRequest()
        }
        try {
            commandWatchdog.restart()
            xhr.send(JSON.stringify(body))
        } catch (error) {
            commandWatchdog.stop()
            activeCommandRequest = null
            commandActive = false
            errorText = String(error)
            commandResult({ ok: false, error: errorText })
            scheduleNextRequest()
        }
    }

    function readSettings() {
        settingsReadPending = true
        scheduleNextRequest()
    }

    function startSettingsRead() {
        if (networkRequestActive() || !settingsReadPending) return
        settingsReadPending = false
        settingsRequestActive = true
        var xhr = new XMLHttpRequest()
        activeSettingsRequest = xhr
        xhr.open("GET", (activeBaseUrl || cleanBaseUrl(baseUrl)) + "/settings", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            if (xhr !== root.activeSettingsRequest) return
            settingsWatchdog.stop()
            root.activeSettingsRequest = null
            root.settingsRequestActive = false
            var packet = root.parseResponse(xhr)
            if (xhr.status >= 200 && xhr.status < 300 && packet && packet.config)
                root.settingsReceived(packet.config)
            root.scheduleNextRequest()
        }
        try {
            settingsWatchdog.restart()
            xhr.send()
        } catch (error) {
            settingsWatchdog.stop()
            activeSettingsRequest = null
            settingsRequestActive = false
            errorText = String(error)
            scheduleNextRequest()
        }
    }

    function start() {
        polling = true
        poll()
    }

    function stop() {
        polling = false
        requestDrain.stop()
        delayedPoll.stop()
        commandFollowupPoll.stop()
        retryPoll.stop()
        pollWatchdog.stop()
        commandWatchdog.stop()
        settingsWatchdog.stop()
        if (activePollRequest) activePollRequest.abort()
        if (activeCommandRequest) activeCommandRequest.abort()
        if (activeSettingsRequest) activeSettingsRequest.abort()
        activePollRequest = null
        activeCommandRequest = null
        activeSettingsRequest = null
        requestActive = false
        commandActive = false
        settingsRequestActive = false
        settingsReadPending = false
        commandQueue = []
    }

    function reconnect() {
        var pending = activePollRequest
        activePollRequest = null
        if (pending) pending.abort()
        var pendingCommand = activeCommandRequest
        activeCommandRequest = null
        if (pendingCommand) pendingCommand.abort()
        var pendingSettings = activeSettingsRequest
        activeSettingsRequest = null
        if (pendingSettings) pendingSettings.abort()
        pollWatchdog.stop()
        commandWatchdog.stop()
        settingsWatchdog.stop()
        connected = false
        requestActive = false
        commandActive = false
        settingsRequestActive = false
        settingsReadPending = false
        commandQueue = []
        activeBaseUrl = ""
        candidateIndex = 0
        activeFailureCount = 0
        poll()
    }

    Timer {
        id: requestDrain
        interval: 1
        repeat: false
        onTriggered: root.drainRequests()
    }

    Timer {
        interval: root.pollIntervalMs
        repeat: true
        running: root.polling
        onTriggered: root.poll()
    }

    Timer {
        id: delayedPoll
        interval: 150
        repeat: false
        onTriggered: root.poll()
    }

    Timer {
        id: commandFollowupPoll
        interval: 350
        repeat: true
        onTriggered: {
            if (root.commandFollowupsRemaining <= 0) {
                stop()
                return
            }
            if (!root.networkRequestActive()) {
                root.commandFollowupsRemaining -= 1
                root.poll()
            }
        }
    }

    Timer {
        id: retryPoll
        interval: 500
        repeat: false
        onTriggered: root.poll()
    }

    Timer {
        id: pollWatchdog
        interval: 4000
        repeat: false
        onTriggered: {
            if (!root.requestActive) return
            var pending = root.activePollRequest
            root.activePollRequest = null
            root.requestActive = false
            if (pending) pending.abort()
            root.connectionFailed(0)
            root.scheduleNextRequest()
        }
    }

    Timer {
        id: commandWatchdog
        interval: 4000
        repeat: false
        onTriggered: {
            if (!root.commandActive) return
            var pending = root.activeCommandRequest
            root.activeCommandRequest = null
            root.commandActive = false
            if (pending) pending.abort()
            root.errorText = "Befehl ohne Antwort"
            root.commandResult({ ok: false, error: root.errorText })
            root.scheduleNextRequest()
        }
    }

    Timer {
        id: settingsWatchdog
        interval: 4000
        repeat: false
        onTriggered: {
            if (!root.settingsRequestActive) return
            var pending = root.activeSettingsRequest
            root.activeSettingsRequest = null
            root.settingsRequestActive = false
            if (pending) pending.abort()
            root.errorText = "Einstellungen ohne Antwort"
            root.scheduleNextRequest()
        }
    }
}
