import QtQuick 2.6

Item {
    id: view
    objectName: "vehicleLightsView"

    property var lights: []
    property var highBeam: ({})
    property bool dayMode: false
    property bool rightView: false
    property color primaryText: visual.text
    property color secondaryText: visual.muted
    property color panelColor: visual.panel
    property color borderColor: visual.border

    CamperStyle { id: visual; dayMode: view.dayMode }

    signal setRequested(int channel, bool enabled)
    signal dimRequested(int channel, int value)
    signal frontModeRequested(string mode)
    signal highBeamRequested(int channel, bool enabled)

    function findLight(lightId) {
        for (var index = 0; index < lights.length; index += 1) {
            if (lights[index].id === lightId)
                return lights[index]
        }
        return { id: lightId, name: lightId, channel: 0, on: false, dimming: 0 }
    }

    function percent(light) { return Math.max(0, Math.min(100, Math.round(Number(light.dimming || 0)))) }
    function sideToggle(showRight, channel, enabled) { rightView = showRight; setRequested(channel, enabled) }
    function sideDim(showRight, channel, value) { rightView = showRight; dimRequested(channel, value) }
    function openDimmer(title, iconKind, channel, enabled, value, showRight) {
        if (showRight !== undefined) rightView = showRight
        dimmer.open(title, iconKind, channel, enabled, value)
    }
    function toggleFrontMode(mode) {
        var selected = mode === "orange" ? frontAmber : frontWhite
        if (selected.on === true) setRequested(Number(selected.channel), false)
        else frontModeRequested(mode)
    }

    property var inside: findLight("inside_main")
    property var leftSide: findLight("outside_left")
    property var rightSide: findLight("outside_right")
    property var rear: findLight("outside_rear")
    property var frontWhite: findLight("outside_front_white")
    property var frontAmber: findLight("outside_front_amber")
    property bool frontActive: frontWhite.on === true || frontAmber.on === true
    property string frontMode: frontAmber.on === true ? "orange" : "white"
    property int frontDimming: frontMode === "orange" ? percent(frontAmber) : percent(frontWhite)
    property int frontPreviewDimming: frontDimming

    VehicleLightCard {
        x: 6; y: 6; width: 154; height: 112
        title: "INNENLICHT"; iconKind: "cabinLight"; channel: Number(view.inside.channel); lightOn: view.inside.on === true; dimming: view.percent(view.inside); dayMode: view.dayMode
        onToggleRequested: view.setRequested(channel, enabled); onDimRequested: view.dimRequested(channel, value)
        onDimmerRequested: view.openDimmer(title, iconKind, channel, enabled, value)
    }
    VehicleLightCard {
        x: 6; y: 124; width: 154; height: 112
        title: "AUSSEN LINKS"; iconKind: "workLightLeft"; channel: Number(view.leftSide.channel); lightOn: view.leftSide.on === true; dimming: view.percent(view.leftSide); dayMode: view.dayMode
        onToggleRequested: view.sideToggle(false, channel, enabled); onDimRequested: view.sideDim(false, channel, value)
        onDimmerRequested: view.openDimmer(title, iconKind, channel, enabled, value, false)
    }
    VehicleLightCard {
        x: 6; y: 242; width: 154; height: 112
        title: "AUSSEN RECHTS"; iconKind: "workLightRight"; channel: Number(view.rightSide.channel); lightOn: view.rightSide.on === true; dimming: view.percent(view.rightSide); dayMode: view.dayMode
        onToggleRequested: view.sideToggle(true, channel, enabled); onDimRequested: view.sideDim(true, channel, value)
        onDimmerRequested: view.openDimmer(title, iconKind, channel, enabled, value, true)
    }

    Item {
        x: 164; y: 6; width: 470; height: 306
        // Beifahrerseite (rechts) mit Markise; Fahrerseite ohne Markise im Vordergrund.
        Image { anchors.fill: parent; source: view.rightView ? "VehicleLightsRight.png" : "VehicleLightsLeft.png"; fillMode: Image.PreserveAspectFit; smooth: true }
        VehicleLightOverlay {
            anchors.fill: parent
            rightView: view.rightView
            geometryRightView: view.rightView
            insideOn: view.inside.on === true; insideLevel: view.percent(view.inside)
            leftOn: view.leftSide.on === true; leftLevel: view.percent(view.leftSide)
            rightOn: view.rightSide.on === true; rightLevel: view.percent(view.rightSide)
            rearOn: view.rear.on === true; rearLevel: view.percent(view.rear)
            frontOn: view.frontActive; frontLevel: view.frontDimming; frontAmber: view.frontMode === "orange"
            highBeamOn: view.highBeam.on === true
        }

        // Direkte Bedienung auf den realen Leuchten im Fahrzeugbild.
        // Tagfahr-/Warnstreifen bleiben absichtlich bei den separaten Tasten.
        MouseArea {
            x: view.rightView ? 145 : 286; y: 108; width: 76; height: 82
            onClicked: view.setRequested(Number(view.inside.channel), view.inside.on !== true)
        }
        MouseArea {
            x: view.rightView ? 36 : 302; y: view.rightView ? 20 : 11; width: 46; height: 46
            onClicked: view.sideToggle(view.rightView, Number(view.rightView ? view.rightSide.channel : view.leftSide.channel), !(view.rightView ? view.rightSide.on : view.leftSide.on))
        }
        MouseArea {
            x: view.rightView ? 109 : 373; y: view.rightView ? 13 : 14; width: 46; height: 46
            onClicked: view.sideToggle(view.rightView, Number(view.rightView ? view.rightSide.channel : view.leftSide.channel), !(view.rightView ? view.rightSide.on : view.leftSide.on))
        }
        MouseArea {
            x: view.rightView ? 17 : 348; y: 0; width: 48; height: 38
            onClicked: view.setRequested(Number(view.rear.channel), view.rear.on !== true)
        }
        MouseArea {
            x: view.rightView ? 215 : 132; y: view.rightView ? 12 : 24
            width: view.rightView ? 139 : 148; height: 44
            onClicked: view.highBeamRequested(Number(view.highBeam.outputChannel || 3), !view.highBeam.manualOn)
        }
    }

    TouchButton { x: 300; y: 318; width: 88; height: 38; label: "FAHRER"; active: !view.rightView; onClicked: view.rightView = false }
    TouchButton { x: 394; y: 318; width: 104; height: 38; label: "BEIFAHRER"; active: view.rightView; onClicked: view.rightView = true }

    VehicleLightCard {
        x: 640; y: 6; width: 154; height: 112
        title: "AUSSEN HINTEN"; iconKind: "rearLight"; channel: Number(view.rear.channel); lightOn: view.rear.on === true; dimming: view.percent(view.rear); dayMode: view.dayMode
        onToggleRequested: view.setRequested(channel, enabled); onDimRequested: view.dimRequested(channel, value)
        onDimmerRequested: view.openDimmer(title, iconKind, channel, enabled, value)
    }

    Rectangle {
        x: 640; y: 124; width: 154; height: 82; radius: 12
        color: view.highBeam.on ? (view.dayMode ? "#dcefff" : "#14354b") : view.panelColor
        border.color: view.highBeam.on ? "#56b9ff" : view.borderColor; border.width: view.highBeam.on ? 2 : 1
        LineIcon { x: 57; y: 8; width: 40; height: 40; kind: "highBeam"; lineColor: view.highBeam.on ? "#56b9ff" : view.secondaryText; strokeWidth: 2 }
        Text { x: 8; y: 57; width: 138; horizontalAlignment: Text.AlignRight; text: "FERNLICHT"; color: view.highBeam.on ? "#56b9ff" : view.primaryText; font.pixelSize: 10; font.bold: true }
        MouseArea { anchors.fill: parent; onClicked: view.highBeamRequested(Number(view.highBeam.outputChannel || 3), !view.highBeam.manualOn) }
    }

    Rectangle {
        x: 640; y: 212; width: 154; height: 142; radius: 12
        color: view.frontActive ? (view.dayMode ? "#fff1d9" : "#382913") : view.panelColor
        border.color: view.frontActive ? (view.frontMode === "orange" ? "#ff9f1a" : "#bfeeff") : view.borderColor
        LineIcon { x: 9; y: 5; width: 25; height: 25; kind: view.frontMode === "orange" ? "warningBar" : "lightBar"; lineColor: view.frontMode === "orange" ? "#ff9f1a" : (view.frontActive ? "#19a7ff" : view.secondaryText); strokeWidth: 1.8 }
        TouchButton { x: 8; y: 31; width: 67; height: 48; label: "TAGFAHR"; fontSize: 9; active: view.frontMode === "white" && view.frontActive; onClicked: view.toggleFrontMode("white") }
        TouchButton { x: 79; y: 31; width: 67; height: 48; label: "WARNBLINK"; fontSize: 8; active: view.frontMode === "orange" && view.frontActive; accentColor: "#ff9f1a"; onClicked: view.toggleFrontMode("orange") }
        TouchButton { x: 8; y: 93; width: 138; height: 41; visible: view.frontMode !== "orange"; label: view.frontDimming + " %  DIMMEN"; fontSize: 10; active: view.frontWhite.on === true; onClicked: view.openDimmer("TAGFAHRLICHT BALKEN", "lightBar", Number(view.frontWhite.channel), view.frontWhite.on === true, view.frontDimming) }
        Text { x: 48; y: 106; width: 58; visible: view.frontMode === "orange"; horizontalAlignment: Text.AlignHCenter; text: "500 ms"; color: "#ff9f1a"; font.pixelSize: 10; font.bold: true }
    }

    DimmerOverlay {
        id: dimmer
        anchors.fill: parent
        dayMode: view.dayMode
        onToggleRequested: view.setRequested(channel, enabled)
        onDimRequested: view.dimRequested(channel, value)
    }
}
