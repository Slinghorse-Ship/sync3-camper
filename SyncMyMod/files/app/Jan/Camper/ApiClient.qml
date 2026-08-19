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

    function poll() {
        if (requestActive) return
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
        }
        try {
            pollWatchdog.restart()
            xhr.send()
        } catch (error) {
            pollWatchdog.stop()
            activePollRequest = null
            requestActive = false
            connectionFailed(0)
        }
    }

    function command(target, action, value, extra) {
        if (!connected) {
            errorText = "Keine Verbindung"
            commandResult({ ok: false, error: errorText })
            return
        }
        var body = extra || ({})
        body.target = target
        body.action = action
        body.value = value
        requestSequence += 1
        body.requestId = "sync3-" + new Date().getTime() + "-" + requestSequence

        var xhr = new XMLHttpRequest()
        xhr.open("POST", (activeBaseUrl || cleanBaseUrl(baseUrl)) + "/command", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            var packet = root.parseResponse(xhr)
            if (xhr.status >= 200 && xhr.status < 300 && packet) {
                root.lastCommandResult = packet
                root.commandResult(packet)
                root.commandFollowupsRemaining = 5
                delayedPoll.restart()
                commandFollowupPoll.restart()
            } else {
                root.errorText = "Befehl fehlgeschlagen"
                root.commandResult(packet || { ok: false, error: root.errorText })
            }
        }
        try {
            xhr.send(JSON.stringify(body))
        } catch (error) {
            errorText = String(error)
        }
    }

    function readSettings() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", (activeBaseUrl || cleanBaseUrl(baseUrl)) + "/settings", true)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            var packet = root.parseResponse(xhr)
            if (xhr.status >= 200 && xhr.status < 300 && packet && packet.config)
                root.settingsReceived(packet.config)
        }
        xhr.send()
    }

    function start() {
        polling = true
        poll()
    }

    function stop() {
        polling = false
    }

    function reconnect() {
        var pending = activePollRequest
        activePollRequest = null
        if (pending) pending.abort()
        pollWatchdog.stop()
        connected = false
        requestActive = false
        activeBaseUrl = ""
        candidateIndex = 0
        activeFailureCount = 0
        poll()
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
            root.commandFollowupsRemaining -= 1
            root.poll()
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
        }
    }
}
