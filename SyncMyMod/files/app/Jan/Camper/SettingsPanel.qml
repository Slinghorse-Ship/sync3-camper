import QtQuick 2.6

Item {
    id: panel
    property var host
    property bool rebootArmed: false
    property string selectedWifiSsid: ""
    property string selectedWifiService: ""
    property var wifi: host ? host.externalWifiState() : ({ available: false, enabled: false, state: "nicht verfügbar", ssid: "", networks: [] })

    function scrollToExternalWifi() {
        if (!selectedWifiSsid && wifi.ssid) {
            selectedWifiSsid = wifi.ssid
            selectedWifiService = serviceForSsid(wifi.ssid)
        }
        scroller.contentY = 805
    }

    function wifiName(entry) {
        return typeof entry === "string" ? entry : String((entry && (entry.ssid || entry.name)) || "")
    }

    function wifiDetail(entry) {
        if (!entry || typeof entry === "string") return ""
        var signal = entry.signal !== undefined ? entry.signal : entry.strength
        var secure = entry.secure === false ? "offen" : "gesichert"
        return (signal !== undefined ? signal + " % · " : "") + secure
    }

    function wifiService(entry) {
        return typeof entry === "object" && entry ? String(entry.service || "") : ""
    }

    function serviceForSsid(ssid) {
        var networks = wifi.networks || []
        for (var index = 0; index < networks.length; ++index)
            if (wifiName(networks[index]) === ssid) return wifiService(networks[index])
        return ""
    }

    function selectWifiNetwork(entry) {
        selectedWifiSsid = wifiName(entry)
        selectedWifiService = wifiService(entry)
    }

    function serviceValue(key, fallback) {
        var service = host && host.system ? (host.system.service || ({})) : ({})
        var value = service[key]
        return value === undefined || value === null || value === "" ? (fallback || "–") : value
    }

    function yes(value) { return Number(value) === 1 ? "OK" : "FEHLT" }
    function interfaceText(name) {
        var state = serviceValue(name + "_state", "nicht vorhanden")
        var address = serviceValue(name + "_address", "–")
        var ssid = name === "wlan0" ? serviceValue("wlan0_ssid", "") : ""
        return state + " · " + address + (ssid ? " · " + ssid : "")
    }

    Rectangle { anchors.fill: parent; color: host.dayMode ? "#f4f5f6" : "#0b1118" }

    Rectangle {
        x: 0; y: 0; width: 800; height: 54
        color: host.headerColor; border.color: host.lineColor
        Text { x: 20; y: 10; text: "EINSTELLUNGEN"; color: host.primaryText; font.pixelSize: 19; font.bold: true }
        Text { x: 20; y: 33; text: "CAMPERCONTROL · LOKALES SYSTEM"; color: host.fordBlue; font.pixelSize: 9; font.bold: true }
        Rectangle {
            x: 657; y: 8; width: 78; height: 38; radius: 9
            color: refreshArea.pressed ? host.innerPanelColor : "transparent"; border.color: host.lineColor
            Text { anchors.centerIn: parent; text: "PRÜFEN"; color: host.primaryText; font.pixelSize: 10; font.bold: true }
            MouseArea { id: refreshArea; anchors.fill: parent; onClicked: host.serviceAction("refresh") }
        }
        Rectangle {
            x: 742; y: 8; width: 42; height: 38; radius: 9
            color: closeArea.pressed ? host.innerPanelColor : "transparent"; border.color: host.lineColor
            Text { anchors.centerIn: parent; text: "×"; color: host.primaryText; font.pixelSize: 25 }
            MouseArea { id: closeArea; anchors.fill: parent; onClicked: host.settingsOpen = false }
        }
    }

    Flickable {
        id: scroller
        x: 0; y: 54; width: 800; height: 368
        contentWidth: width; contentHeight: 1768
        clip: true; boundsBehavior: Flickable.StopAtBounds

        Rectangle {
            x: 14; y: 12; width: 772; height: 132; radius: 13
            color: host.panelColor; border.color: host.lineColor
            Text { x: 16; y: 13; text: "VERBINDUNG"; color: "#32d4a0"; font.pixelSize: 10; font.bold: true }
            Text { x: 16; y: 35; text: "Cerbo GX / Node-RED-Adresse"; color: host.primaryText; font.pixelSize: 13; font.bold: true }
            Rectangle {
                x: 16; y: 59; width: 580; height: 46; radius: 8
                color: host.innerPanelColor; border.color: urlInput.activeFocus ? "#32d4a0" : host.lineColor
                TextInput {
                    id: urlInput; objectName: "camperUrlInput"
                    anchors.fill: parent; anchors.margins: 11
                    text: host.settingsUrl
                    color: host.primaryText; font.pixelSize: 13; selectByMouse: true; clip: true
                    activeFocusOnPress: true
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    onTextChanged: host.settingsUrl = text
                    onActiveFocusChanged: if (activeFocus && Qt.inputMethod) Qt.inputMethod.show()
                    onAccepted: { if (Qt.inputMethod) Qt.inputMethod.hide(); focus = false }
                }
            }
            TouchButton { x: 608; y: 59; width: 70; height: 46; label: "TESTEN"; fontSize: 8; onClicked: host.testConnection() }
            TouchButton { x: 688; y: 59; width: 68; height: 46; label: "SPEICH."; fontSize: 8; active: true; onClicked: host.saveSettings() }
            Text { x: 16; y: 110; text: "IP genügt · Port und API-Pfad werden automatisch ergänzt"; color: host.secondaryText; font.pixelSize: 8 }
        }

        Rectangle {
            x: 14; y: 154; width: 772; height: 176; radius: 13
            color: host.panelColor; border.color: host.lineColor
            Text { x: 16; y: 13; text: "SCHNELLZUGRIFF · HOME"; color: host.fordBlue; font.pixelSize: 10; font.bold: true }
            Repeater {
                model: 4
                delegate: Rectangle {
                    x: 16 + (index % 2) * 376; y: 38 + Math.floor(index / 2) * 61
                    width: 366; height: 53; radius: 9; color: host.innerPanelColor; border.color: host.lineColor
                    Text { x: 10; y: 6; text: "PLATZ " + (index + 1); color: host.secondaryText; font.pixelSize: 8; font.bold: true }
                    Text { x: 10; y: 25; width: 225; elide: Text.ElideRight; text: host.quickAccessName(host.quickAccessIds[index]); color: host.primaryText; font.pixelSize: 11; font.bold: true }
                    TouchButton { x: 258; y: 7; width: 44; height: 39; label: "−"; fontSize: 17; onClicked: host.changeQuickAccess(index, -1) }
                    TouchButton { x: 310; y: 7; width: 44; height: 39; label: "+"; fontSize: 17; onClicked: host.changeQuickAccess(index, 1) }
                }
            }
            Text { x: 16; y: 161; text: "Licht, 12 V, Wasserpumpe, Geräte und Szenen · Doppelbelegungen werden automatisch getauscht"; color: host.secondaryText; font.pixelSize: 8 }
        }

        Rectangle {
            x: 14; y: 340; width: 772; height: 221; radius: 13
            color: host.panelColor; border.color: host.lineColor
            Text { x: 16; y: 13; text: "LICHT-ZUORDNUNG · STAR-POWER CH 7–12"; color: host.fordBlue; font.pixelSize: 10; font.bold: true }
            Repeater {
                model: Math.min(6, host.lightMapping.length)
                delegate: Rectangle {
                    property var mappedLight: host.lightMapping[index]
                    x: 16 + (index % 2) * 376; y: 38 + Math.floor(index / 2) * 56
                    width: 366; height: 48; radius: 9; color: host.innerPanelColor; border.color: host.lineColor
                    Text { x: 10; y: 8; width: 205; elide: Text.ElideRight; text: mappedLight.name; color: host.primaryText; font.pixelSize: 10; font.bold: true }
                    Text { x: 10; y: 27; text: "STAR-POWER"; color: host.secondaryText; font.pixelSize: 8 }
                    TouchButton { x: 245; y: 6; width: 35; height: 36; label: "−"; onClicked: host.changeLightChannel(index, -1) }
                    Text { x: 282; y: 15; width: 42; horizontalAlignment: Text.AlignHCenter; text: "CH " + mappedLight.channel; color: host.primaryText; font.pixelSize: 10; font.bold: true }
                    TouchButton { x: 325; y: 6; width: 35; height: 36; label: "+"; onClicked: host.changeLightChannel(index, 1) }
                }
            }
        }

        Rectangle {
            x: 14; y: 571; width: 772; height: 230; radius: 13
            color: host.panelColor; border.color: host.lineColor
            Text { x: 16; y: 13; text: "NETZWERK · BLUETOOTH · CERBO GX"; color: host.fordBlue; font.pixelSize: 10; font.bold: true }
            Rectangle {
                x: 16; y: 38; width: 366; height: 112; radius: 9; color: host.innerPanelColor; border.color: host.lineColor
                Text { x: 10; y: 9; text: "INTERNET / BRIDGE"; color: host.primaryText; font.pixelSize: 11; font.bold: true }
                Text { x: 10; y: 31; width: 344; text: "Route: " + serviceValue("route_interface", "keine") + " · LAN-Priorität " + yes(serviceValue("preferred_uplink_active", 0)); color: host.secondaryText; font.pixelSize: 9 }
                Text { x: 10; y: 51; width: 344; text: "Ethernet: " + interfaceText("eth0"); color: host.secondaryText; font.pixelSize: 9; elide: Text.ElideRight }
                Text { x: 10; y: 71; width: 344; text: "WLAN: " + interfaceText("wlan0"); color: host.secondaryText; font.pixelSize: 9; elide: Text.ElideRight }
                Text { x: 10; y: 91; width: 344; text: "NAT LAN/WLAN: " + yes(serviceValue("nat_eth0", 0)) + " / " + yes(serviceValue("nat_wlan0", 0)); color: host.secondaryText; font.pixelSize: 9 }
            }
            Rectangle {
                x: 390; y: 38; width: 366; height: 112; radius: 9; color: host.innerPanelColor; border.color: host.lineColor
                Text { x: 10; y: 9; text: "BLUETOOTH / SYSTEM"; color: host.primaryText; font.pixelSize: 11; font.bold: true }
                Text { x: 10; y: 31; text: "Bluetooth: " + (Number(serviceValue("bluetooth_service_up", 0)) === 1 ? "LÄUFT" : "GESTOPPT"); color: host.secondaryText; font.pixelSize: 9 }
                Text { x: 10; y: 51; text: "Adapter: " + serviceValue("bluetooth_adapter_count", 0) + " · Sensoren: " + serviceValue("bluetooth_sensor_count", 0); color: host.secondaryText; font.pixelSize: 9 }
                Text { x: 10; y: 71; text: "Node-RED: " + (Number(serviceValue("node_red_up", 0)) === 1 ? "LÄUFT" : "GESTOPPT"); color: host.secondaryText; font.pixelSize: 9 }
                Text { x: 10; y: 91; text: "CPU: " + serviceValue("cpu_temperature", "–") + " °C"; color: host.secondaryText; font.pixelSize: 9 }
            }
            TouchButton { x: 16; y: 161; width: 174; height: 48; label: "NETZWERK REPARIEREN"; fontSize: 8; onClicked: host.serviceAction("networkRepair") }
            TouchButton { x: 198; y: 161; width: 174; height: 48; label: "BLUETOOTH NEUSTART"; fontSize: 8; onClicked: host.serviceAction("bluetoothRepair") }
            TouchButton { x: 380; y: 161; width: 174; height: 48; label: "NODE-RED NEUSTART"; fontSize: 8; onClicked: host.serviceAction("nodeRedRestart") }
            TouchButton {
                x: 562; y: 161; width: 194; height: 48
                label: panel.rebootArmed ? "NOCHMAL: CERBO RESTART" : "CERBO NEUSTART"
                fontSize: 8; accentColor: "#e65f5f"; active: panel.rebootArmed
                onClicked: {
                    if (panel.rebootArmed) { panel.rebootArmed = false; host.serviceAction("cerboReboot") }
                    else { panel.rebootArmed = true; rebootTimer.restart() }
                }
            }
        }

        Rectangle {
            x: 14; y: 811; width: 772; height: 300; radius: 13
            color: host.panelColor; border.color: host.lineColor
            Text { x: 16; y: 13; text: "EXTERNES WLAN · NETGEAR USB"; color: host.fordBlue; font.pixelSize: 10; font.bold: true }
            Text {
                x: 16; y: 34; width: 520; elide: Text.ElideRight
                text: panel.wifi.available ? ((panel.wifi.enabled ? "AN" : "AUS") + " · " + (panel.wifi.ssid || panel.wifi.state)) : "Steuerung von der Camper-API noch nicht bereitgestellt"
                color: panel.wifi.available ? (panel.wifi.enabled ? "#32d4a0" : host.secondaryText) : "#f6a23c"; font.pixelSize: 9; font.bold: true
            }
            TouchButton {
                x: 16; y: 58; width: 174; height: 40
                label: panel.wifi.enabled ? "EXTERNES WLAN AUS" : "EXTERNES WLAN AN"
                enabled: panel.wifi.available; active: panel.wifi.enabled; fontSize: 8
                onClicked: host.setExternalWifiEnabled(!panel.wifi.enabled)
            }
            TouchButton {
                x: 198; y: 58; width: 174; height: 40
                label: panel.wifi.scanActive ? "SUCHE LÄUFT" : "NETZWERKE SUCHEN"
                enabled: panel.wifi.available && panel.wifi.enabled && !panel.wifi.scanActive; fontSize: 8
                onClicked: host.scanExternalWifi()
            }
            TouchButton {
                x: 380; y: 58; width: 182; height: 40
                label: host.showExternalWifiTile ? "12/230-KACHEL AN" : "12/230-KACHEL AUS"
                active: host.showExternalWifiTile; fontSize: 8
                onClicked: host.showExternalWifiTile = !host.showExternalWifiTile
            }
            TouchButton { x: 570; y: 58; width: 186; height: 40; label: "STATUS AKTUALISIEREN"; fontSize: 8; onClicked: host.serviceAction("refresh") }

            Text { x: 16; y: 108; text: "GEFUNDENE NETZWERKE"; color: host.secondaryText; font.pixelSize: 8; font.bold: true }
            Repeater {
                model: panel.wifi.networks ? Math.min(4, panel.wifi.networks.length) : 0
                delegate: Rectangle {
                    property var networkEntry: panel.wifi.networks[index]
                    property string networkName: panel.wifiName(networkEntry)
                    x: 16; y: 126 + index * 39; width: 356; height: 34; radius: 7
                    color: panel.selectedWifiSsid === networkName ? (host.dayMode ? "#dceff8" : "#102d3d") : host.innerPanelColor
                    border.color: panel.selectedWifiSsid === networkName ? host.fordBlue : host.lineColor
                    Text { x: 10; y: 5; width: 220; elide: Text.ElideRight; text: networkName || "Unbenanntes WLAN"; color: host.primaryText; font.pixelSize: 9; font.bold: true }
                    Text { x: 235; y: 6; width: 110; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: panel.wifiDetail(networkEntry); color: host.secondaryText; font.pixelSize: 8 }
                    MouseArea { anchors.fill: parent; onClicked: panel.selectWifiNetwork(networkEntry) }
                }
            }
            Text { visible: !panel.wifi.networks || !panel.wifi.networks.length; x: 16; y: 137; width: 356; text: panel.wifi.available ? "Noch keine Suchergebnisse" : "Netgear-Adapter/API nicht verfügbar"; color: host.secondaryText; font.pixelSize: 9 }

            Text { x: 390; y: 108; text: "SSID / NETZWERKNAME"; color: host.secondaryText; font.pixelSize: 8; font.bold: true }
            Rectangle {
                x: 390; y: 126; width: 366; height: 42; radius: 8; color: host.innerPanelColor; border.color: ssidInput.activeFocus ? host.fordBlue : host.lineColor
                TextInput {
                    id: ssidInput; anchors.fill: parent; anchors.margins: 10; text: panel.selectedWifiSsid
                    color: host.primaryText; font.pixelSize: 11; selectByMouse: true; clip: true; activeFocusOnPress: true
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    onTextChanged: {
                        panel.selectedWifiSsid = text
                        panel.selectedWifiService = panel.serviceForSsid(text)
                    }
                    onActiveFocusChanged: if (activeFocus && Qt.inputMethod) Qt.inputMethod.show()
                }
            }
            Text { x: 390; y: 178; text: "PASSWORT"; color: host.secondaryText; font.pixelSize: 8; font.bold: true }
            Rectangle {
                x: 390; y: 196; width: 366; height: 42; radius: 8; color: host.innerPanelColor; border.color: passwordInput.activeFocus ? host.fordBlue : host.lineColor
                TextInput {
                    id: passwordInput; anchors.fill: parent; anchors.margins: 10
                    color: host.primaryText; font.pixelSize: 11; selectByMouse: true; clip: true; activeFocusOnPress: true; echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    onActiveFocusChanged: if (activeFocus && Qt.inputMethod) Qt.inputMethod.show()
                }
            }
            TouchButton {
                x: 570; y: 248; width: 186; height: 38
                label: panel.selectedWifiService.length > 0 ? "VERBINDEN" : (panel.selectedWifiSsid.length > 0 ? "ZUERST SUCHEN" : "NETZ WÄHLEN")
                fontSize: 9; active: panel.selectedWifiService.length > 0
                enabled: panel.wifi.available && panel.wifi.enabled && panel.selectedWifiSsid.length > 0 && panel.selectedWifiService.length > 0
                onClicked: { host.connectExternalWifi(panel.selectedWifiSsid, panel.selectedWifiService, passwordInput.text); passwordInput.text = "" }
            }
            Text { x: 390; y: 250; width: 170; wrapMode: Text.WordWrap; text: panel.selectedWifiService.length > 0 ? "Passwort wird nicht gespeichert" : "Netzwerk zuerst aus der Suche auswählen"; color: host.secondaryText; font.pixelSize: 7 }
        }

        Rectangle {
            x: 14; y: 1121; width: 772; height: 262; radius: 13
            color: host.panelColor; border.color: host.lineColor
            Text { x: 16; y: 13; text: "MELDUNGEN" + (host.eventData.unacknowledgedCount ? " · " + host.eventData.unacknowledgedCount + " OFFEN" : ""); color: "#f6a23c"; font.pixelSize: 10; font.bold: true }
            Text { visible: !host.eventData.recent || !host.eventData.recent.length; anchors.centerIn: parent; text: "Keine Meldungen"; color: host.secondaryText; font.pixelSize: 12 }
            Repeater {
                model: host.eventData.recent ? Math.min(5, host.eventData.recent.length) : 0
                delegate: Rectangle {
                    property var entry: host.eventData.recent[index]
                    x: 16; y: 38 + index * 42; width: 740; height: 36; radius: 7; color: host.innerPanelColor; border.color: host.lineColor
                    Text { x: 10; y: 6; width: 125; text: String(entry.source || "SYSTEM").toUpperCase(); color: entry.level === "error" ? "#fb737b" : "#f6a23c"; font.pixelSize: 8; font.bold: true }
                    Text { x: 138; y: 6; width: 445; elide: Text.ElideRight; text: entry.text || entry.code || "Meldung"; color: host.primaryText; font.pixelSize: 9 }
                    Text { x: 138; y: 21; text: host.timeText(entry.createdAt); color: host.secondaryText; font.pixelSize: 7 }
                    TouchButton { x: 620; y: 4; width: 108; height: 28; label: entry.acknowledgedAt ? "BESTÄTIGT" : "BESTÄTIGEN"; fontSize: 7; enabled: !entry.acknowledgedAt; active: !!entry.acknowledgedAt; onClicked: host.acknowledgeEvent(entry.id) }
                }
            }
        }

        Rectangle {
            x: 14; y: 1393; width: 772; height: 300; radius: 13
            color: host.panelColor; border.color: host.lineColor
            Text { x: 16; y: 13; text: "SERVICE & WARTUNG"; color: host.fordBlue; font.pixelSize: 10; font.bold: true }
            Repeater {
                model: host.operations.maintenance ? Math.min(5, host.operations.maintenance.length) : 0
                delegate: Rectangle {
                    property var task: host.operations.maintenance[index]
                    x: 16; y: 38 + index * 49; width: 740; height: 43; radius: 8; color: host.innerPanelColor; border.color: host.lineColor
                    Text { x: 10; y: 7; width: 410; elide: Text.ElideRight; text: task.name || task.id; color: host.primaryText; font.pixelSize: 10; font.bold: true }
                    Text { x: 10; y: 25; text: task.lastDoneAt ? "Zuletzt: " + host.timeText(task.lastDoneAt) : "Noch nicht dokumentiert"; color: task.due ? "#f6a23c" : host.secondaryText; font.pixelSize: 8 }
                    TouchButton { x: 578; y: 5; width: 150; height: 33; label: "HEUTE ERLEDIGT"; fontSize: 8; onClicked: host.completeMaintenance(task.id) }
                }
            }
            Text { x: 16; y: 281; text: "Serviceaktionen und Wartungsbestätigungen werden im lokalen Ereignisprotokoll dokumentiert"; color: host.secondaryText; font.pixelSize: 8 }
        }

        Rectangle {
            x: 14; y: 1703; width: 772; height: 52; radius: 13; color: host.panelColor; border.color: host.lineColor
            Text { x: 16; y: 10; width: 560; text: "Nur lokales Netz · keine Portweiterleitung ins Internet · Cerbo-Neustart erfordert zwei Betätigungen"; wrapMode: Text.WordWrap; color: host.secondaryText; font.pixelSize: 8 }
            TouchButton { x: 612; y: 7; width: 144; height: 38; label: "ALLES SPEICHERN"; fontSize: 8; active: true; onClicked: host.saveSettings() }
        }
    }

    Rectangle {
        visible: scroller.contentY > 4
        x: 790; width: 4; height: Math.max(28, (scroller.height - 12) * (scroller.height - 12) / scroller.contentHeight); radius: 2
        color: host.fordBlue; opacity: 0.8
        y: 58 + (scroller.contentY / Math.max(1, scroller.contentHeight - scroller.height)) * (scroller.height - height - 8)
    }

    Timer { id: rebootTimer; interval: 5000; repeat: false; onTriggered: panel.rebootArmed = false }
}
