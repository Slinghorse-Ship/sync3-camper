import QtQuick 2.6

Item {
    id: view
    objectName: "v2EnergyPage"
    property var api
    property var snapshot: ({})
    property bool dayMode: false
    property int pane: 0
    property var energy: snapshot.energy || ({})
    property var solar: energy.solar || ({})
    property var chargers: solar.chargers || []
    property var indevolt: energy.indevolt || ({})
    property var gridConnection: indevolt.gridConnection || ({})
    property var orion: energy.orion || ({})
    property var power: snapshot.power || ({})
    property var inverter: power.inverter || ({})
    property var channels: power.dcChannels || []

    CamperStyle { id: visual; dayMode: view.dayMode }

    function valid(value) { return value !== null && value !== undefined && value !== "" && isFinite(Number(value)) }
    function fmt(value, digits, suffix) { return valid(value) ? Number(value).toFixed(digits) + (suffix || "") : "–" + (suffix || "") }
    function signed(value, digits, suffix) { return valid(value) ? (Number(value) > 0 ? "+" : "") + Number(value).toFixed(digits) + (suffix || "") : "–" + (suffix || "") }
    function channelBy(number, id) {
        for (var i = 0; i < channels.length; ++i)
            if ((id && channels[i].id === id) || Number(channels[i].channel) === number) return channels[i]
        return ({ channel: number, id: id, on: false, online: false })
    }
    function toggleChannel(channel) {
        if (!channel || Number(channel.channel) <= 0 || channel.online === false) return
        api.command("starpower", "set", channel.on === true ? 0 : 1, { channel: Number(channel.channel) })
    }
    function totalSolarPower() {
        if (valid(energy.totalSolarPower)) return Number(energy.totalSolarPower)
        return Number(solar.power || 0) + Number(indevolt.solarPower || 0)
    }
    function yieldToday() {
        var total = 0, found = false
        for (var i = 0; i < chargers.length; ++i) if (valid(chargers[i].yieldTodayKwh)) { total += Number(chargers[i].yieldTodayKwh); found = true }
        return found ? total : null
    }
    function chargerAt(index) { return index < chargers.length ? chargers[index] : ({ online: false }) }
    function chargerName(charger, index) {
        var name = String(charger.name || "MPPT").replace("SmartSolar ", "")
        if (name === "MPPT") return name
        return index < 2 ? name + " · " + (index + 1) : name
    }

    Rectangle {
        x: 0; y: 0; width: 290; height: 42; radius: 12; color: visual.inner
        Rectangle { x: view.pane === 0 ? 3 : 148; y: 3; width: view.pane === 0 ? 142 : 139; height: 36; radius: 9; color: visual.pressed }
        Text { x: 3; y: 14; width: 142; horizontalAlignment: Text.AlignHCenter; text: "12 V & 230 V"; color: view.pane === 0 ? visual.blue : visual.text; font.pixelSize: 9; font.bold: true }
        Text { x: 148; y: 14; width: 139; horizontalAlignment: Text.AlignHCenter; text: "Quellen"; color: view.pane === 1 || view.pane === 2 ? visual.blue : visual.text; font.pixelSize: 9; font.bold: true }
        MouseArea { x: 0; y: 0; width: 145; height: 42; onClicked: view.pane = 0 }
        MouseArea { x: 145; y: 0; width: 145; height: 42; onClicked: view.pane = 1 }
    }

    Item {
        objectName: "v2EnergyPowerPane"
        x: 0; y: 49; width: 762; height: 277; visible: view.pane === 0
        Rectangle { objectName: "v2PowerChannelsCard"; x: 0; y: 0; width: 497; height: 277; radius: 17; color: visual.panel; border.color: visual.border
            Repeater {
                model: [
                    {number:1,id:"dc_outlets_left",name:"Links",icon:"outlet",x:13,y:12},
                    {number:2,id:"water_pump",name:"Wasserpumpe",icon:"pump",x:173,y:12},
                    {number:4,id:"dc_outlets_right",name:"Rechts",icon:"outlet",x:333,y:12},
                    {number:5,id:"starlink",name:"Starlink",icon:"satellite",x:93,y:143},
                    {number:6,id:"maxxfan_power",name:"MaxxFan",icon:"fan",x:253,y:143}
                ]
                delegate: Rectangle {
                    objectName: "v2PowerChannel_" + modelData.number
                    property var channel: view.channelBy(modelData.number, modelData.id)
                    x: modelData.x; y: modelData.y; width: 151; height: 122; radius: 15
                    opacity: channel.online === false ? .48 : 1
                    color: channel.on === true ? (view.dayMode ? "#e4f7ef" : "#113027") : visual.inner
                    border.width: channel.on === true ? 2 : 1
                    border.color: channel.on === true ? visual.green : visual.border
                    Rectangle { x: 11; y: 43; width: 38; height: 38; radius: 11; color: channel.on === true ? visual.green : visual.disabled
                        V2Icon { anchors.centerIn: parent; width: 23; height: 23; kind: modelData.icon; lineColor: channel.on === true ? "#effff9" : visual.muted; strokeWidth: 1.8 }
                    }
                    Text { x: 58; y: 55; width: 85; elide: Text.ElideRight; text: modelData.name; color: channel.on === true ? visual.green : visual.text; font.pixelSize: 10; font.bold: true }
                    MouseArea { anchors.fill: parent; enabled: channel.online !== false; onClicked: view.toggleChannel(channel) }
                }
            }
        }

        Rectangle {
            objectName: "v2InverterCard"
            x: 506; y: 0; width: 256; height: 277; radius: 17
            color: view.inverter.on === true ? (view.dayMode ? "#f0ebff" : "#221b35") : visual.panel
            border.width: view.inverter.on === true ? 2 : 1
            border.color: view.inverter.on === true ? visual.purple : visual.border
            opacity: view.inverter.online === false ? .48 : 1
            Rectangle { x: 14; y: 14; width: 46; height: 46; radius: 13; color: view.inverter.on === true ? visual.purple : visual.disabled
                V2Icon { anchors.centerIn: parent; width: 27; height: 27; kind: "plug"; lineColor: view.inverter.on === true ? "#ffffff" : visual.muted; strokeWidth: 2 }
            }
            Text { x: 70; y: 27; text: "230 V"; color: visual.text; font.pixelSize: 15; font.bold: true }
            Rectangle { x: 14; y: 207; width: 228; height: 56; radius: 11; color: visual.inner
                Text { x: 9; y: 10; text: view.fmt(view.inverter.outputPower, 0, " W"); color: visual.text; font.pixelSize: 14; font.bold: true }
                Text { x: 9; y: 34; text: "Verbrauch"; color: visual.muted; font.pixelSize: 8 }
            }
            MouseArea { anchors.fill: parent; enabled: view.inverter.online !== false; onClicked: view.api.command("inverter", "set", view.inverter.on !== true) }
        }
    }

    Item {
        objectName: "v2EnergySourcesPane"
        x: 0; y: 49; width: 762; height: 277; visible: view.pane === 1
        Repeater {
            model: [
                {source:"solar",x:0,w:247,icon:"solar",name:"Solar gesamt"},
                {source:"orion",x:256,w:247,icon:"alternator",name:"Lichtmaschine"},
                {source:"indevolt",x:512,w:250,icon:"battery",name:"INDEVOLT"}
            ]
            delegate: Rectangle {
                objectName: "v2EnergySource_" + modelData.source
                property bool isSolar: modelData.source === "solar"
                property bool isOrion: modelData.source === "orion"
                property bool isIndevolt: modelData.source === "indevolt"
                property bool available: isSolar || (isOrion ? view.orion.online === true : view.indevolt.online === true)
                property bool active: isOrion ? view.orion.on === true : (isIndevolt ? view.gridConnection.on === true : view.totalSolarPower() > 0)
                x: modelData.x; y: 0; width: modelData.w; height: 277; radius: 17
                opacity: available ? 1 : .45
                color: active ? (isOrion ? (view.dayMode ? "#e4f7ef" : "#113027") : (isIndevolt ? (view.dayMode ? "#f0ebff" : "#221b35") : (view.dayMode ? "#fff8df" : "#2a2412"))) : visual.panel
                border.width: active ? 2 : 1
                border.color: active ? (isIndevolt ? visual.purple : (isSolar ? visual.yellow : visual.green)) : visual.border
                Rectangle { x: 14; y: 14; width: 46; height: 46; radius: 13; color: active ? (isIndevolt ? visual.purple : (isSolar ? visual.yellow : visual.green)) : visual.disabled
                    V2Icon { anchors.centerIn: parent; width: 27; height: 27; kind: modelData.icon; lineColor: active ? "#ffffff" : visual.muted; strokeWidth: 1.8 }
                }
                Text { x: 70; y: 29; width: parent.width - 84; elide: Text.ElideRight; text: modelData.name; color: visual.text; font.pixelSize: 13; font.bold: true }
                Text {
                    x: 14; y: 116; width: parent.width - 28
                    text: isSolar ? view.fmt(view.totalSolarPower(), 0, " W") : (isOrion ? view.fmt(view.orion.power, 0, " W") : view.fmt(view.indevolt.soc, 0, " %"))
                    color: visual.text; font.pixelSize: 28; font.bold: true
                }
                Text {
                    x: 14; y: 159; width: parent.width - 28
                    text: isSolar ? (view.valid(view.yieldToday()) ? view.fmt(view.yieldToday(), 2, " kWh heute") : "") : (isOrion ? (view.fmt(view.orion.voltage, 1, " V") + " · " + view.fmt(view.orion.current, 1, " A")) : "")
                    color: visual.muted; font.pixelSize: 9
                }
                Row {
                    visible: isIndevolt
                    x: 14; y: 205; spacing: 10
                    Rectangle { width: 38; height: 38; radius: 11; color: Number(view.indevolt.solarPower || 0) > 0 ? visual.yellow : visual.disabled
                        V2Icon { anchors.centerIn: parent; width: 23; height: 23; kind: "solar"; lineColor: Number(view.indevolt.solarPower || 0) > 0 ? "#ffffff" : visual.muted; strokeWidth: 1.7 }
                    }
                    Rectangle { width: 38; height: 38; radius: 11; color: view.gridConnection.on === true ? visual.purple : visual.disabled
                        V2Icon { anchors.centerIn: parent; width: 23; height: 23; kind: "plug"; lineColor: view.gridConnection.on === true ? "#ffffff" : visual.muted; strokeWidth: 1.7 }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: parent.available && (parent.isSolar || parent.isOrion || view.gridConnection.available === true)
                    onClicked: {
                        if (parent.isSolar) view.pane = 2
                        else if (parent.isOrion) view.api.command("orion", "set", view.orion.on !== true)
                        else view.api.command("indevoltGrid", "set", view.gridConnection.on !== true)
                    }
                }
            }
        }
    }

    Item {
        x: 0; y: 49; width: 762; height: 277; visible: view.pane === 2
        Rectangle {
            x: 0; y: 0; width: 762; height: 46; radius: 15; color: visual.panel; border.color: visual.border
            Rectangle { x: 8; y: 5; width: 38; height: 36; radius: 10; color: visual.selectedBlue
                V2Icon { anchors.centerIn: parent; width: 21; height: 21; kind: "back"; lineColor: visual.blue; strokeWidth: 2 }
                MouseArea { anchors.fill: parent; onClicked: view.pane = 1 }
            }
            Text { x: 58; y: 8; text: "Solar gesamt"; color: visual.text; font.pixelSize: 13; font.bold: true }
            Text { x: 58; y: 27; text: view.chargers.length + " MPPT-Regler und INDEVOLT"; color: visual.muted; font.pixelSize: 8 }
            Text { x: 570; y: 8; width: 96; horizontalAlignment: Text.AlignRight; text: view.fmt(view.totalSolarPower(), 0, " W"); color: visual.text; font.pixelSize: 22; font.bold: true }
            Text { x: 672; y: 18; width: 79; horizontalAlignment: Text.AlignRight; text: view.valid(view.yieldToday()) ? view.fmt(view.yieldToday(), 2, " kWh") : ""; color: visual.yellow; font.pixelSize: 8; font.bold: true }
        }

        Repeater {
            model: 4
            delegate: Rectangle {
                objectName: "v2SolarDetail_" + index
                property bool indevoltCard: index === 3
                property var charger: indevoltCard ? ({}) : view.chargerAt(index)
                property bool online: indevoltCard ? view.indevolt.online === true : charger.online === true
                x: index * 192; y: 53; width: index === 3 ? 186 : 184; height: 224; radius: 15
                opacity: online ? 1 : .48
                color: visual.panel; border.color: visual.border
                V2Icon { x: 13; y: 13; width: 22; height: 22; kind: indevoltCard ? "battery" : "solar"; lineColor: visual.yellow; strokeWidth: 1.8 }
                Text { x: 42; y: 16; width: 115; elide: Text.ElideRight; text: indevoltCard ? "INDEVOLT" : view.chargerName(charger, index); color: visual.text; font.pixelSize: 9; font.bold: true }
                Rectangle { x: parent.width - 20; y: 17; width: 7; height: 7; radius: 4; color: online ? visual.green : visual.muted }
                Text { x: 13; y: 51; text: indevoltCard ? view.fmt(view.indevolt.solarPower, 0, " W") : view.fmt(charger.power, 0, " W"); color: visual.text; font.pixelSize: 26; font.bold: true }
                Text { x: 13; y: 176; text: indevoltCard ? "Akku" : "PV"; color: visual.muted; font.pixelSize: 8 }
                Text { x: 86; y: 176; width: parent.width - 99; horizontalAlignment: Text.AlignRight; text: indevoltCard ? view.fmt(view.indevolt.soc, 0, " %") : view.fmt(charger.pvVoltage, 2, " V"); color: visual.text; font.pixelSize: 8; font.bold: true }
                Text { x: 13; y: 203; text: indevoltCard ? "Batterie" : "Heute"; color: visual.muted; font.pixelSize: 8 }
                Text { x: 86; y: 203; width: parent.width - 99; horizontalAlignment: Text.AlignRight; text: indevoltCard ? view.signed(view.indevolt.batteryPower, 0, " W") : view.fmt(charger.yieldTodayKwh, 2, " kWh"); color: visual.text; font.pixelSize: 8; font.bold: true }
            }
        }
    }
}
