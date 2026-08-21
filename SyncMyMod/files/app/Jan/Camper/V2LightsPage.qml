import QtQuick 2.6

Item {
    id: view
    objectName: "v2LightsPage"
    property var host
    property var api
    property var snapshot: ({})
    property bool dayMode: false
    property var lights: (snapshot.lights || ({})).items || []
    property var highBeam: (snapshot.vehicle || ({})).highBeam || ({})
    property var scenes: ((snapshot.operations || ({})).scenes || [])
    property bool rightView: false
    property string selectedZone: "inside"
    property bool dimmerDragging: false
    property int pendingLevel: 0

    CamperStyle { id: visual; dayMode: view.dayMode }

    function findLight(id) {
        for (var i = 0; i < lights.length; ++i) if (lights[i].id === id) return lights[i]
        return ({ id: id, channel: 0, on: false, dimming: 0, dimmable: id !== "outside_front_amber" })
    }
    function lightForZone(zone) {
        var ids = { inside: "inside_main", left: "outside_left", right: "outside_right", rear: "outside_rear", front: "outside_front_white", amber: "outside_front_amber" }
        return findLight(ids[zone] || "")
    }
    function level(light) { return Math.max(0, Math.min(100, Math.round(Number(light.dimming || 0)))) }
    function toggleZone(zone) {
        if (zone === "highbeam") {
            if (highBeam.outputOnline !== true) return
            api.command("starpower", "set", highBeam.manualOn === true ? 0 : 1, { channel: Number(highBeam.outputChannel || 3) })
            return
        }
        var item = lightForZone(zone)
        if (Number(item.channel) <= 0) return
        if (zone !== "amber") {
            selectedZone = zone
            pendingLevel = level(item)
        }
        if (zone === "left") rightView = false
        if (zone === "right") rightView = true
        if ((zone === "front" || zone === "amber") && item.on !== true) {
            host.setFrontMode(zone === "amber" ? "orange" : "white")
        } else {
            api.command("starpower", "set", item.on === true ? 0 : 1, { channel: Number(item.channel) })
        }
    }
    function selectedLight() { return lightForZone(selectedZone) }
    function selectedName() {
        var names = { inside: "Innenlicht", left: "Außen links", right: "Außen rechts", rear: "Außen hinten", front: "Weiße Frontleiste" }
        return names[selectedZone] || "Licht"
    }
    function applyDimFromX(position, widthValue) {
        pendingLevel = Math.max(0, Math.min(100, Math.round(position * 100 / Math.max(1, widthValue))))
    }
    function commitDim() {
        var item = selectedLight()
        if (Number(item.channel) <= 0 || item.dimmable === false) return
        api.command("starpower", "dim", pendingLevel, { channel: Number(item.channel) })
    }
    function findScene(candidates) {
        for (var i = 0; i < scenes.length; ++i) {
            var key = String(scenes[i].id || "").toLowerCase()
            var name = String(scenes[i].name || "").toLowerCase()
            for (var j = 0; j < candidates.length; ++j)
                if (key === candidates[j] || name === candidates[j]) return scenes[i]
        }
        return null
    }
    function runLightScene(kind) {
        var candidates = kind === "camping" ? ["camping", "ankommen", "arrival"] : (kind === "night" ? ["nacht", "night"] : ["alles aus", "all off", "away", "abwesend"])
        var scene = findScene(candidates)
        if (scene) host.runScene(scene)
        else if (kind === "off") {
            host.setLightArea("all", false)
            if (highBeam.outputOnline === true && highBeam.manualOn === true)
                api.command("starpower", "set", 0, { channel: Number(highBeam.outputChannel || 3) })
        }
    }

    Rectangle {
        id: stage
        x: 0; y: 0; width: 453; height: 326; radius: 17
        color: visual.panel; border.color: visual.border; clip: true

        Image {
            anchors.fill: parent
            source: view.rightView ? "VehicleLightsRight.png" : "VehicleLightsLeft.png"
            fillMode: Image.PreserveAspectFit; smooth: true
        }
        Canvas {
            id: driverDoorHandle
            objectName: "v2DriverDoorHandleOverlay"
            anchors.fill: parent
            visible: !view.rightView
            antialiasing: true
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.save()
                var scale = Math.min(width / 560, height / 360)
                ctx.translate((width - 560 * scale) / 2, (height - 360 * scale) / 2)
                ctx.scale(scale, scale)

                // Exact second sliding-door handle from the Transit Horizon
                // prototype (SVG viewBox 0 0 560 360, lines 883-889).
                ctx.beginPath()
                ctx.moveTo(355.8, 194)
                ctx.bezierCurveTo(357.8, 192.8, 362.3, 192.5, 364.7, 193.3)
                ctx.lineTo(364.2, 195.6)
                ctx.bezierCurveTo(361.9, 196.6, 358.1, 196.8, 355.9, 195.9)
                ctx.closePath()
                ctx.fillStyle = "rgba(16,19,21,.94)"
                ctx.fill()
                ctx.strokeStyle = "rgba(85,88,86,.58)"
                ctx.lineWidth = .55
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(357.1, 193.8)
                ctx.bezierCurveTo(359.2, 193.1, 362.1, 193, 363.8, 193.6)
                ctx.strokeStyle = "rgba(183,183,177,.32)"
                ctx.lineWidth = .48
                ctx.lineCap = "round"
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(356.5, 196.1)
                ctx.bezierCurveTo(358.7, 197, 362.1, 196.9, 364, 196)
                ctx.strokeStyle = "rgba(5,7,8,.72)"
                ctx.lineWidth = .65
                ctx.lineCap = "round"
                ctx.stroke()
                ctx.restore()
            }
        }
        VehicleLightOverlay {
            anchors.fill: parent
            rightView: view.rightView; geometryRightView: view.rightView
            insideOn: view.lightForZone("inside").on === true; insideLevel: view.level(view.lightForZone("inside"))
            leftOn: view.lightForZone("left").on === true; leftLevel: view.level(view.lightForZone("left"))
            rightOn: view.lightForZone("right").on === true; rightLevel: view.level(view.lightForZone("right"))
            rearOn: view.lightForZone("rear").on === true; rearLevel: view.level(view.lightForZone("rear"))
            frontOn: view.lightForZone("front").on === true || view.lightForZone("amber").on === true
            frontLevel: view.lightForZone("amber").on === true ? view.level(view.lightForZone("amber")) : view.level(view.lightForZone("front"))
            frontAmber: view.lightForZone("amber").on === true
            highBeamOn: view.highBeam.on === true
        }

        MouseArea {
            x: view.rightView ? parent.width*.309 : parent.width*.6085; y: parent.height*.353
            width: parent.width*.162; height: parent.height*.268
            onClicked: view.toggleZone("inside")
        }
        MouseArea {
            x: view.rightView ? parent.width*.077 : parent.width*.643; y: view.rightView ? parent.height*.065 : parent.height*.036
            width: parent.width*.098; height: parent.height*.15
            onClicked: view.toggleZone(view.rightView ? "right" : "left")
        }
        MouseArea {
            x: view.rightView ? parent.width*.232 : parent.width*.794; y: view.rightView ? parent.height*.043 : parent.height*.046
            width: parent.width*.098; height: parent.height*.15
            onClicked: view.toggleZone(view.rightView ? "right" : "left")
        }
        MouseArea {
            x: view.rightView ? parent.width*.036 : parent.width*.74; y: 0
            width: parent.width*.102; height: parent.height*.124
            onClicked: view.toggleZone("rear")
        }
        MouseArea {
            x: view.rightView ? parent.width*.409 : parent.width*.281; y: view.rightView ? parent.height*.006 : parent.height*.078
            width: parent.width*(view.rightView ? .364 : .315); height: parent.height*(view.rightView ? .202 : .144)
            onClicked: view.toggleZone("highbeam")
        }

        Rectangle {
            x: 14; y: parent.height - 49; width: 168; height: 37; radius: 11
            color: visual.inner
            Rectangle { x: 3; y: 3; width: 79; height: 31; radius: 8; color: !view.rightView ? visual.pressed : "transparent" }
            Rectangle { x: 86; y: 3; width: 79; height: 31; radius: 8; color: view.rightView ? visual.pressed : "transparent" }
            Text { x: 3; y: 10; width: 79; horizontalAlignment: Text.AlignHCenter; text: "Fahrerseite"; color: !view.rightView ? visual.blue : visual.text; font.pixelSize: 9; font.bold: true }
            Text { x: 86; y: 10; width: 79; horizontalAlignment: Text.AlignHCenter; text: "Beifahrerseite"; color: view.rightView ? visual.blue : visual.text; font.pixelSize: 9; font.bold: true }
            MouseArea { x: 0; y: 0; width: 84; height: parent.height; onClicked: view.rightView = false }
            MouseArea { x: 84; y: 0; width: 84; height: parent.height; onClicked: view.rightView = true }
        }
    }

    Rectangle {
        id: controls
        x: 462; y: 0; width: 300; height: 326; radius: 17
        color: visual.panel; border.color: visual.border

        Rectangle {
            x: 5; y: 5; width: 290; height: 30; radius: 12; color: visual.inner
            Repeater {
                model: [{label:"Camping",kind:"camping"},{label:"Nacht",kind:"night"},{label:"Alles aus",kind:"off"}]
                delegate: Item {
                    x: index * 96; width: index === 2 ? 98 : 96; height: 30
                    Text { anchors.centerIn: parent; text: modelData.label; color: visual.text; font.pixelSize: 9; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: view.runLightScene(modelData.kind) }
                }
            }
        }

        Repeater {
            model: [
                {zone:"inside",name:"Innen",icon:"cabinLight",row:0,col:0},
                {zone:"rear",name:"Hinten",icon:"rearLight",row:0,col:1},
                {zone:"left",name:"Links",icon:"sideLeft",row:1,col:0},
                {zone:"right",name:"Rechts",icon:"sideRight",row:1,col:1}
            ]
            delegate: Rectangle {
                objectName: "v2LightZone_" + modelData.zone
                property var itemLight: view.lightForZone(modelData.zone)
                property bool itemOn: itemLight.on === true
                x: 5 + modelData.col * 147; y: 38 + modelData.row * 77; width: 143; height: 73; radius: 10
                color: itemOn ? (view.dayMode ? "#eaf8fe" : "#102b3a") : visual.inner
                border.width: itemOn || view.selectedZone === modelData.zone ? 2 : 1
                border.color: itemOn ? "#59caff" : (view.selectedZone === modelData.zone ? "#36b8ff" : visual.border)
                Rectangle { x: 7; y: 7; width: 29; height: 29; radius: 9; color: itemOn ? "#168fca" : visual.disabled
                    V2Icon { anchors.centerIn: parent; width: 20; height: 20; kind: modelData.icon; lineColor: itemOn ? "#eafaff" : visual.muted; strokeWidth: 1.7 }
                }
                Text { x: 43; y: 9; width: 92; elide: Text.ElideRight; text: modelData.name; color: visual.text; font.pixelSize: 10; font.bold: true }
                Text { x: 43; y: 27; width: 92; text: view.level(itemLight) + " %"; color: itemOn ? "#75d8ff" : visual.muted; font.pixelSize: 8 }
                Rectangle { x: 7; y: 62; width: 129; height: 4; radius: 2; color: visual.border
                    Rectangle { width: parent.width * view.level(itemLight) / 100; height: parent.height; radius: 2; color: itemOn ? "#36b8ff" : visual.muted; opacity: itemOn ? 1 : .38 }
                }
                MouseArea { anchors.fill: parent; onClicked: view.toggleZone(modelData.zone) }
            }
        }

        Rectangle {
            id: frontCard
            objectName: "v2LightZone_front"
            x: 5; y: 192; width: 143; height: 73; radius: 10
            property bool whiteOn: view.lightForZone("front").on === true
            property bool amberOn: view.lightForZone("amber").on === true
            color: amberOn ? (view.dayMode ? "#fff7e8" : "#302314") : ((whiteOn) ? (view.dayMode ? "#eaf8fe" : "#102b3a") : visual.inner)
            border.width: whiteOn || amberOn || view.selectedZone === "front" ? 2 : 1
            border.color: amberOn ? "#ffad45" : (whiteOn || view.selectedZone === "front" ? "#59caff" : visual.border)
            Item { x: 0; y: 0; width: 71; height: 73
                V2Icon { x: 24; y: 9; width: 24; height: 24; kind: "lightBar"; lineColor: frontCard.whiteOn ? "#59caff" : visual.muted; strokeWidth: 1.7 }
                Text { x: 0; y: 43; width: 71; horizontalAlignment: Text.AlignHCenter; text: "Weiß"; color: frontCard.whiteOn ? "#59caff" : visual.muted; font.pixelSize: 8; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: view.toggleZone("front") }
            }
            Rectangle { x: 71; width: 1; height: parent.height; color: visual.border }
            Item { x: 72; y: 0; width: 71; height: 73
                V2Icon { x: 24; y: 9; width: 24; height: 24; kind: "warningBar"; lineColor: frontCard.amberOn ? "#ffb450" : visual.muted; strokeWidth: 1.7 }
                Text { x: 0; y: 43; width: 71; horizontalAlignment: Text.AlignHCenter; text: "Orange"; color: frontCard.amberOn ? "#ffb450" : visual.muted; font.pixelSize: 8; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: view.toggleZone("amber") }
            }
        }

        Rectangle {
            id: highBeamCard
            objectName: "v2LightZone_highbeam"
            x: 152; y: 192; width: 143; height: 73; radius: 10
            property bool manualOn: view.highBeam.manualOn === true
            property bool vehicleOn: view.highBeam.vehicleOn === true
            opacity: view.highBeam.outputOnline === true ? 1 : .45
            color: manualOn ? (view.dayMode ? "#eaf8fe" : "#102b3a") : visual.inner
            border.width: manualOn || vehicleOn ? 2 : 1
            border.color: manualOn || vehicleOn ? "#59caff" : visual.border
            Rectangle { x: 7; y: 7; width: 29; height: 29; radius: 9
                objectName: "v2HighBeamIconTile"
                color: highBeamCard.manualOn ? "#168fca" : (view.dayMode ? "#f3f6f7" : "#101820")
                border.width: highBeamCard.vehicleOn && !highBeamCard.manualOn ? 1 : 0
                border.color: "#59caff"
                V2Icon { anchors.centerIn: parent; width: 20; height: 20; kind: "highBeam"; lineColor: highBeamCard.manualOn ? "#ffffff" : (highBeamCard.vehicleOn ? "#59caff" : visual.muted); strokeWidth: 1.7 }
            }
            Text { x: 43; y: 12; width: 92; text: "Fernlicht"; color: visual.text; font.pixelSize: 10; font.bold: true }
            MouseArea { anchors.fill: parent; enabled: view.highBeam.outputOnline === true; onClicked: view.toggleZone("highbeam") }
        }

        Rectangle {
            x: 5; y: 271; width: 290; height: 50; radius: 12; color: visual.inner
            Text { x: 8; y: 5; text: view.selectedName(); color: visual.text; font.pixelSize: 9; font.bold: true }
            Text { x: 225; y: 5; width: 57; horizontalAlignment: Text.AlignRight; text: (view.dimmerDragging ? view.pendingLevel : view.level(view.selectedLight())) + " %"; color: visual.text; font.pixelSize: 9; font.bold: true }
            Rectangle {
                id: dimTrack
                x: 8; y: 31; width: 274; height: 6; radius: 3; color: visual.border
                property int shown: view.dimmerDragging ? view.pendingLevel : view.level(view.selectedLight())
                Rectangle { width: parent.width * dimTrack.shown / 100; height: parent.height; radius: 3; color: "#36b8ff" }
                Rectangle { x: Math.max(0, Math.min(parent.width - width, parent.width * dimTrack.shown / 100 - width / 2)); y: -5; width: 16; height: 16; radius: 8; color: "#36b8ff" }
                MouseArea {
                    x: -4; y: -15; width: parent.width + 8; height: 36
                    onPressed: { view.dimmerDragging = true; view.applyDimFromX(mouse.x - 4, dimTrack.width) }
                    onPositionChanged: if (pressed) view.applyDimFromX(mouse.x - 4, dimTrack.width)
                    onReleased: { view.commitDim(); view.dimmerDragging = false }
                    onCanceled: view.dimmerDragging = false
                }
            }
        }
    }
}
