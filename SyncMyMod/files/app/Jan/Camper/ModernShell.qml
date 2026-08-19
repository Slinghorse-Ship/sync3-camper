import QtQuick 2.6

Item {
    id: shell
    property var host
    property var api
    property var snapshot: ({})
    property bool dayMode: false

    property var system: snapshot.system || ({})
    property var energy: snapshot.energy || ({})
    property var battery: energy.battery || ({})
    property var solar: energy.solar || ({})
    property var indevolt: energy.indevolt || ({})
    property var water: snapshot.water || ({})
    property var fresh: water.fresh || ({})
    property var climate: snapshot.climate || ({})
    property var heater: climate.heater || ({})
    property var fan: climate.fan || ({})
    property var power: snapshot.power || ({})
    property var inverter: power.inverter || ({})
    property var dcChannels: power.dcChannels || []
    property var powerPageChannels: {
        var filtered = []
        for (var channelIndex = 0; channelIndex < dcChannels.length; ++channelIndex)
            if (Number(dcChannels[channelIndex].channel) !== 3 && dcChannels[channelIndex].id !== "high_beam_manual")
                filtered.push(dcChannels[channelIndex])
        return filtered
    }
    property var externalWifi: host ? host.externalWifiState() : ({ available: false, enabled: false, state: "nicht verfügbar", ssid: "" })
    property int powerTileCount: powerPageChannels.length + (host && host.showExternalWifiTile ? 1 : 0)
    property var vehicle: snapshot.vehicle || ({})
    property var highBeam: vehicle.highBeam || ({})
    property var lights: snapshot.lights || ({})
    property var quickAccessIds: ["outside_front_white", "outside_front_amber", "inside_main", "outside_right"]
    property var operations: snapshot.operations || ({})
    property var commandData: operations.commands || ({})
    property var eventData: operations.events || ({})
    property color background: visual.backgroundBottom
    property color panel: visual.panel
    property color inner: visual.inner
    property color textColor: visual.text
    property color muted: visual.muted
    property color line: visual.border
    property color blue: visual.blue
    property color green: visual.green
    property color orange: visual.orange

    CamperStyle { id: visual; dayMode: shell.dayMode }

    function fmt(value, digits, suffix) {
        if (value === null || value === undefined || value === "" || !isFinite(Number(value))) return "-"
        return Number(value).toFixed(digits) + (suffix || "")
    }

    function go(index) { host.page = index }
    function command(target, action, value, extra) { api.command(target, action, value, extra || ({})) }
    function temperatureCount() {
        var values = [climate.roomTemperature, heater.internalTemperature, heater.externalTemperature]
        var count = 0
        for (var i = 0; i < values.length; ++i)
            if (values[i] !== null && values[i] !== undefined && values[i] !== "" && isFinite(Number(values[i]))) count += 1
        return count
    }
    function compactLightName(light) {
        if (light.id === "outside_front_white") return "TAGFAHR"
        if (light.id === "outside_front_amber") return "WARNBLINK"
        return light.name
    }
    function lightIconKind(light) {
        if (light.id === "high_beam") return "highBeam"
        if (light.id === "inside_main") return "cabinLight"
        if (light.id === "outside_rear") return "rearLight"
        if (light.id === "outside_left") return "workLightLeft"
        if (light.id === "outside_right") return "workLightRight"
        if (light.id === "outside_front_white") return "lightBar"
        if (light.id === "outside_front_amber") return "warningBar"
        return "workLight"
    }
    function powerIconKind(channel) {
        var number = Number(channel.channel)
        if (channel.id === "dc_outlets_left" || channel.id === "dc_outlets_right" || number === 1 || number === 4) return "outlet"
        if (channel.id === "water_pump" || number === 2) return "pump"
        if (channel.id === "high_beam_manual" || number === 3) return "highBeam"
        if (channel.id === "starlink" || number === 5) return "satellite"
        if (channel.id === "maxxfan_power" || number === 6) return "fan"
        return "power"
    }
    function powerTileX(index) {
        if (powerTileCount === 5 && index >= 3) return 144 + (index - 3) * 260
        return 14 + (index % 3) * 260
    }
    function findLight(id) {
        var items = lights.items || []
        for (var i = 0; i < items.length; ++i) if (items[i].id === id) return items[i]
        return ({ id: id, name: id, channel: 0, on: false, dimming: 0, dimmable: false })
    }
    function quickLights() {
        var result = []
        for (var i = 0; i < quickAccessIds.length; ++i) {
            var id = quickAccessIds[i]
            result.push(id === "high_beam" ? ({ id: "high_beam", name: "Fernlicht", channel: Number(highBeam.outputChannel || 3), on: highBeam.on === true, manualOn: highBeam.manualOn === true, dimmable: false }) : findLight(id))
        }
        return result
    }

    Rectangle {
        anchors.fill: parent
        color: shell.background
        gradient: Gradient {
            GradientStop { position: 0.0; color: visual.backgroundTop }
            GradientStop { position: 1.0; color: visual.backgroundBottom }
        }
    }

    Rectangle {
        x: 0; y: 0; width: 800; height: 58
        color: visual.header
        border.color: shell.line
        Image { x: 5; y: 4; width: 56; height: 50; source: "Icon.png"; fillMode: Image.PreserveAspectFit; smooth: true }
        Text { x: 65; y: 10; text: (shell.system.name || "CAMPER").toUpperCase(); color: shell.textColor; font.pixelSize: 17; font.bold: true }
        Text { x: 65; y: 31; text: "\u00b7 " + ["HOME", "LICHT", "SZENEN", "MELDUNGEN", "SERVICE", "12 / 230 V"][shell.host.page]; color: shell.blue; font.pixelSize: 11; font.bold: true }

        Rectangle {
            x: 524; y: 14; width: 112; height: 29; radius: 15
            color: shell.inner; border.color: shell.api.connected ? shell.green : "#ef6e76"
            Rectangle { x: 10; y: 10; width: 8; height: 8; radius: 4; color: shell.api.connected ? shell.green : "#ef6e76" }
            Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: shell.api.connected ? "VERBUNDEN" : "VERBINDUNG"; color: shell.textColor; font.pixelSize: 9; font.bold: true }
        }
        Rectangle {
            x: 647; y: 9; width: 92; height: 39; radius: 9; color: settingsArea.pressed ? shell.inner : "transparent"; border.color: shell.line
            LineIcon { x: 9; y: 8; width: 22; height: 22; kind: "settings"; lineColor: shell.textColor; strokeWidth: 1.8 }
            Text { x: 37; anchors.verticalCenter: parent.verticalCenter; text: "EINST."; color: shell.textColor; font.pixelSize: 10; font.bold: true }
            MouseArea { id: settingsArea; anchors.fill: parent; onClicked: shell.host.openSettings() }
        }
        Rectangle {
            x: 748; y: 9; width: 42; height: 39; radius: 9; color: closeArea.pressed ? "#44232a" : "transparent"; border.color: "#5a333b"
            LineIcon { anchors.centerIn: parent; width: 23; height: 23; kind: "close"; lineColor: shell.textColor; strokeWidth: 2.6 }
            MouseArea { id: closeArea; anchors.fill: parent; onClicked: shell.host.requestClose() }
        }
    }

    Item {
        x: 0; y: 58; width: 800; height: 364; visible: shell.host.page === 0
        ModernTile { x: 10; y: 10; width: 188; height: 88; dayMode: shell.dayMode; icon: "battery"; caption: shell.battery.name || "BATTERIE"; value: shell.fmt(shell.battery.soc, 0, " %"); detail: "Starter " + shell.fmt(shell.battery.starterVoltage, 1, " V"); active: Number(shell.battery.soc || 0) > 0; accentColor: shell.blue; onClicked: shell.go(8) }
        ModernTile { x: 207; y: 10; width: 188; height: 88; dayMode: shell.dayMode; icon: "solar"; caption: "SOLAR GESAMT"; value: shell.fmt(shell.energy.totalSolarPower, 0, " W"); detail: (shell.solar.chargers || []).length + " MPPT · INDEVOLT SOLAR " + (shell.indevolt.online ? "ONLINE" : "OFFLINE"); active: Number(shell.energy.totalSolarPower || 0) > 0; accentColor: shell.blue; onClicked: shell.go(7) }
        ModernTile { x: 404; y: 10; width: 188; height: 88; dayMode: shell.dayMode; icon: "water"; caption: shell.fresh.name || "FRISCHWASSER"; value: shell.fmt(shell.fresh.level, 0, " %"); detail: shell.fmt(shell.fresh.remainingLitres, 0, " Liter"); active: Number(shell.fresh.level || 0) > 0; accentColor: shell.blue }
        ModernTile { x: 601; y: 10; width: 189; height: 88; dayMode: shell.dayMode; icon: "climate"; caption: "INNENRAUM"; value: shell.fmt(shell.climate.roomTemperature, 1, " \u00b0C"); detail: shell.temperatureCount() > 1 ? shell.temperatureCount() + " MESSWERTE" : "TEMPERATUR"; active: shell.temperatureCount() > 1; accentColor: shell.blue; onClicked: if (shell.temperatureCount() > 1) shell.go(10) }

        Rectangle {
            x: 10; y: 108; width: 384; height: 118; radius: 15; color: shell.panel; border.color: shell.heater.on ? shell.orange : shell.line
            LineIcon { x: 20; y: 20; width: 34; height: 34; kind: "climate"; lineColor: shell.heater.on ? shell.orange : shell.muted; strokeWidth: 1.9 }
            Text { x: 72; y: 14; width: 180; elide: Text.ElideRight; text: "AUTOTERM AIR 2D"; color: shell.textColor; font.pixelSize: 14; font.bold: true }
            Text { x: 72; y: 38; text: shell.fmt(shell.heater.setpoint, 0, " \u00b0C SOLL") + "  |  " + (shell.heater.status || "keine Daten"); color: shell.muted; font.pixelSize: 10 }
            MouseArea { x: 8; y: 8; width: 250; height: 53; onClicked: shell.go(6) }
            TouchButton { x: 268; y: 12; width: 100; height: 42; label: shell.heater.on ? "STOPP" : "START"; active: shell.heater.on === true; accentColor: shell.orange; onClicked: shell.command("heater", shell.heater.on ? "stop" : "start", null) }
            Rectangle { x: 16; y: 72; width: 352; height: 1; color: shell.line }
            Text { x: 16; y: 87; text: shell.fan.name || "MAXXFAN"; color: shell.textColor; font.pixelSize: 10; font.bold: true }
            LineIcon { x: 112; y: 81; width: 25; height: 25; kind: "fan"; lineColor: shell.fan.on ? shell.blue : shell.muted; strokeWidth: 1.8 }
            Text { x: 145; y: 87; text: shell.fmt(shell.fan.speed, 0, " %"); color: shell.textColor; font.pixelSize: 11; font.bold: true }
            MouseArea { x: 8; y: 76; width: 250; height: 40; onClicked: shell.go(9) }
            TouchButton { x: 268; y: 77; width: 100; height: 36; label: shell.fan.on ? "AUSSCHALTEN" : "EINSCHALTEN"; active: shell.fan.on === true; onClicked: shell.command("maxxfan", "set", !shell.fan.on) }
        }

        Rectangle {
            x: 404; y: 108; width: 386; height: 118; radius: 15; color: shell.panel; border.color: shell.line
            LineIcon { x: 20; y: 20; width: 34; height: 34; kind: "pump"; lineColor: shell.water.pump && shell.water.pump.on ? shell.blue : shell.muted; strokeWidth: 1.9 }
            Text { x: 72; y: 14; text: "WASSERPUMPE"; color: shell.textColor; font.pixelSize: 14; font.bold: true }
            Text { x: 72; y: 38; text: shell.water.pump && shell.water.pump.on ? "EINGESCHALTET" : "AUSGESCHALTET"; color: shell.muted; font.pixelSize: 10 }
            TouchButton { x: 270; y: 12; width: 100; height: 42; label: shell.water.pump && shell.water.pump.on ? "AUSSCHALTEN" : "EINSCHALTEN"; active: shell.water.pump && shell.water.pump.on === true; onClicked: shell.command("waterPump", "set", !(shell.water.pump && shell.water.pump.on)) }
            Rectangle { x: 16; y: 72; width: 354; height: 1; color: shell.line }
            Text { x: 16; y: 87; text: "MULTIPLUS COMPACT"; color: shell.textColor; font.pixelSize: 11; font.bold: true }
            Text { x: 168; y: 87; text: shell.fmt(shell.inverter.outputPower, 0, " W"); color: shell.muted; font.pixelSize: 10 }
            TouchButton { x: 270; y: 77; width: 100; height: 36; label: shell.inverter.on ? "230 V AUS" : "230 V AN"; active: shell.inverter.on === true; accentColor: "#ad8cf2"; onClicked: shell.command("inverter", "set", !shell.inverter.on) }
        }

        Rectangle {
            x: 10; y: 236; width: 780; height: 116; radius: 15; color: shell.panel; border.color: shell.line
            Text { x: 16; y: 12; text: "SCHNELLZUGRIFF"; color: shell.muted; font.pixelSize: 9; font.bold: true }
            Repeater {
                model: shell.quickLights()
                delegate: Rectangle {
                    property var light: modelData
                    x: 14 + index * 190; y: 34; width: 180; height: 68; radius: 12
                    color: light.on ? (shell.dayMode ? "#dff4ed" : "#15342d") : shell.inner
                    border.color: light.on ? shell.green : shell.line
                    LineIcon { x: 73; y: 5; width: 34; height: 34; kind: shell.lightIconKind(light); lineColor: light.on ? (light.id === "outside_front_amber" ? shell.orange : shell.green) : shell.muted; strokeWidth: 1.8 }
                    Text { x: 10; y: 47; width: 160; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: shell.compactLightName(light); color: shell.textColor; font.pixelSize: 9; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: shell.command("starpower", "set", light.id === "high_beam" ? (light.manualOn ? 0 : 1) : (light.on ? 0 : 1), { channel: light.channel }) }
                }
            }
        }
    }

    VehicleLights {
        x: 0; y: 58; width: 800; height: 364
        visible: shell.host.page === 1
        lights: shell.lights.items || []
        highBeam: shell.highBeam
        dayMode: shell.dayMode
        onSetRequested: if (channel > 0) shell.command("starpower", "set", enabled ? 1 : 0, { channel: channel })
        onDimRequested: if (channel > 0) shell.command("starpower", "dim", value, { channel: channel })
        onHighBeamRequested: if (channel > 0) shell.command("starpower", "set", enabled ? 1 : 0, { channel: channel })
        onFrontModeRequested: shell.host.setFrontMode(mode)
    }

    Item {
        x: 0; y: 58; width: 800; height: 364; visible: shell.host.page === 2
        Text { x: 14; y: 12; text: "SZENEN"; color: shell.textColor; font.pixelSize: 20; font.bold: true }
        Text { x: 14; y: 39; text: "Mehrere Systeme mit einem Tipp"; color: shell.muted; font.pixelSize: 10 }
        Repeater {
            model: shell.operations.scenes || []
            delegate: Rectangle {
                property var scene: modelData
                x: 14 + (index % 3) * 260; y: 70 + Math.floor(index / 3) * 123; width: 246; height: 108; radius: 15; color: shell.panel; border.color: shell.line
                LineIcon { x: 17; y: 20; width: 53; height: 53; kind: scene.icon === "night" || scene.icon === "sleep" ? "alerts" : "scenes"; lineColor: "#f4c94c" }
                Text { x: 86; y: 20; width: 145; elide: Text.ElideRight; text: scene.name; color: shell.textColor; font.pixelSize: 16; font.bold: true }
                Text { x: 86; y: 47; text: scene.actionCount + " AKTIONEN"; color: shell.muted; font.pixelSize: 9 }
                Text { x: 86; y: 72; text: "STARTEN  >"; color: shell.blue; font.pixelSize: 10; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: shell.host.runScene(scene) }
            }
        }
    }

    Item {
        x: 0; y: 58; width: 800; height: 364; visible: shell.host.page === 3
        LineIcon { x: 15; y: 13; width: 38; height: 38; kind: "alerts"; lineColor: shell.eventData.unacknowledgedCount ? shell.orange : shell.green }
        Text { x: 65; y: 13; text: "MELDUNGEN"; color: shell.textColor; font.pixelSize: 20; font.bold: true }
        Text { x: 65; y: 39; text: (shell.eventData.unacknowledgedCount || 0) + " unbest\u00e4tigt"; color: shell.muted; font.pixelSize: 10 }
        Repeater {
            model: shell.eventData.recent ? Math.min(6, shell.eventData.recent.length) : 0
            delegate: Rectangle {
                property var item: shell.eventData.recent[index]
                x: 14; y: 66 + index * 47; width: 772; height: 41; radius: 10; color: shell.panel; border.color: item.level === "critical" ? "#ef6e76" : item.level === "warning" ? shell.orange : shell.line
                Rectangle { x: 12; y: 16; width: 9; height: 9; radius: 5; color: item.level === "critical" ? "#ef6e76" : item.level === "warning" ? shell.orange : shell.green }
                Text { x: 31; y: 6; width: 540; elide: Text.ElideRight; text: item.text; color: shell.textColor; font.pixelSize: 10; font.bold: true }
                Text { x: 31; y: 23; text: shell.host.timeText(item.createdAt) + "  |  " + item.source; color: shell.muted; font.pixelSize: 8 }
                TouchButton { x: 644; y: 5; width: 116; height: 31; visible: !item.acknowledgedAt && (item.level === "warning" || item.level === "critical"); label: "BEST\u00c4TIGEN"; onClicked: shell.command("system", "acknowledge", item.id, { eventId: item.id }) }
            }
        }
        Text { visible: !shell.eventData.recent || !shell.eventData.recent.length; anchors.centerIn: parent; text: "Keine Meldungen"; color: shell.muted; font.pixelSize: 17 }
    }

    Item {
        x: 0; y: 58; width: 800; height: 364; visible: shell.host.page === 4
        Text { x: 14; y: 12; text: "SYSTEM & SERVICE"; color: shell.textColor; font.pixelSize: 20; font.bold: true }
        Repeater {
            model: shell.operations.devices || []
            delegate: Rectangle {
                property var device: modelData
                x: 14 + (index % 3) * 260; y: 51 + Math.floor(index / 3) * 86; width: 246; height: 74; radius: 13; color: shell.panel; border.color: device.online ? shell.green : "#78404a"
                LineIcon { x: 13; y: 16; width: 38; height: 38; kind: "service"; lineColor: device.online ? shell.green : "#ef6e76"; strokeWidth: 1.8 }
                Text { x: 62; y: 13; width: 168; elide: Text.ElideRight; text: device.name; color: shell.textColor; font.pixelSize: 12; font.bold: true }
                Text { x: 62; y: 35; text: device.online ? "ONLINE" : "NICHT VERBUNDEN"; color: device.online ? shell.green : "#ef6e76"; font.pixelSize: 9; font.bold: true }
                Text { x: 62; y: 51; text: "zuletzt vor " + shell.host.ageText(device.lastSeen); color: shell.muted; font.pixelSize: 8 }
            }
        }
    }

    Item {
        x: 0; y: 58; width: 800; height: 364; visible: shell.host.page === 5
        Rectangle {
            x: 14; y: 10; width: 772; height: 76; radius: 15; color: shell.inverter.on ? (shell.dayMode ? "#eee8fb" : "#29203d") : shell.panel; border.color: shell.inverter.on ? "#ad8cf2" : shell.line
            LineIcon { anchors.centerIn: parent; width: 56; height: 56; kind: "plug"; lineColor: shell.inverter.on ? "#ad8cf2" : shell.muted; strokeWidth: 2.2 }
            Text { x: 22; y: 13; width: 180; text: shell.fmt(shell.inverter.outputPower, 0, " W"); color: shell.inverter.on ? "#ad8cf2" : shell.muted; font.pixelSize: 22; font.bold: true }
            Text { x: 390; y: 42; width: 360; horizontalAlignment: Text.AlignRight; text: "MULTIPLUS COMPACT"; color: shell.inverter.on ? "#ad8cf2" : shell.textColor; font.pixelSize: 16; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: shell.command("inverter", "set", !shell.inverter.on) }
        }
        Repeater {
            model: Math.min(6, shell.powerPageChannels.length)
            delegate: Rectangle {
                property var channel: shell.powerPageChannels[index]
                property string displayName: Number(channel.channel) === 6 ? "MaxxFan" : (channel.name || "12 V Kanal")
                x: shell.powerTileX(index)
                y: 98 + Math.floor(index / 3) * 121; width: 246; height: 107; radius: 15
                color: channel.on ? (shell.dayMode ? "#dff4ed" : "#15342d") : shell.panel; border.color: channel.on ? shell.green : shell.line
                LineIcon { x: 94; y: 12; width: 58; height: 58; kind: shell.powerIconKind(channel); lineColor: channel.on ? (Number(channel.channel) === 3 ? "#56b9ff" : shell.green) : shell.muted; strokeWidth: 2.1 }
                Text { x: 82; y: 72; width: 148; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: displayName; color: channel.on ? shell.green : shell.textColor; font.pixelSize: 13; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: shell.command("starpower", "set", channel.on ? 0 : 1, { channel: channel.channel }) }
            }
        }
        Rectangle {
            visible: shell.host && shell.host.showExternalWifiTile
            x: shell.powerTileX(shell.powerPageChannels.length)
            y: 98 + Math.floor(shell.powerPageChannels.length / 3) * 121
            width: 246; height: 107; radius: 15
            color: shell.externalWifi.enabled ? (shell.dayMode ? "#dff1f8" : "#12303c") : shell.panel
            border.color: shell.externalWifi.enabled ? shell.blue : shell.line
            LineIcon { x: 94; y: 12; width: 58; height: 58; kind: "network"; lineColor: shell.externalWifi.enabled ? shell.blue : shell.muted; strokeWidth: 2.1 }
            Text { x: 18; y: 72; width: 210; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: shell.externalWifi.ssid || "EXTERNES WLAN"; color: shell.externalWifi.enabled ? shell.blue : shell.textColor; font.pixelSize: 13; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: shell.host.openExternalWifiSettings() }
        }
    }

    Rectangle {
        visible: false
        x: 0; y: 422; width: 800; height: 58; color: visual.header; border.color: shell.line
        Repeater {
            model: [
                { label: "HOME", icon: "home", page: 0 }, { label: "LICHT", icon: "light", page: 1 },
                { label: "12 / 230", icon: "power", page: 5 }
            ]
            delegate: Rectangle {
                property bool selected: shell.host.page === modelData.page
                x: index * 267; y: 0; width: index === 2 ? 266 : 267; height: 58
                color: selected ? visual.selectedBlue : "transparent"; border.color: shell.line
                Rectangle { x: 0; y: 0; width: parent.width; height: 3; color: selected ? shell.blue : "transparent" }
                LineIcon { x: 18; y: 14; width: 30; height: 30; kind: modelData.icon; lineColor: selected ? shell.blue : shell.textColor; strokeWidth: 2 }
                Text { x: 55; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: selected ? shell.blue : shell.textColor; font.pixelSize: 10; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: shell.go(modelData.page) }
            }
        }
    }
}
