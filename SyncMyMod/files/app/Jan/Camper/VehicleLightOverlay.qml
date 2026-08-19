import QtQuick 2.6

Canvas {
    id: overlay
    property bool rightView: false
    property bool geometryRightView: false
    property bool insideOn: false
    property real insideLevel: 0
    property bool leftOn: false
    property real leftLevel: 0
    property bool rightOn: false
    property real rightLevel: 0
    property bool rearOn: false
    property real rearLevel: 0
    property bool frontOn: false
    property real frontLevel: 0
    property bool frontAmber: false
    property bool highBeamOn: false
    property bool blinkVisible: true

    Timer {
        interval: 500
        repeat: true
        running: overlay.frontOn && overlay.frontAmber
        onTriggered: { overlay.blinkVisible = !overlay.blinkVisible; overlay.repaint() }
        onRunningChanged: if (!running) { overlay.blinkVisible = true; overlay.repaint() }
    }

    function repaint() { requestPaint() }
    onRightViewChanged: repaint()
    onGeometryRightViewChanged: repaint()
    onInsideOnChanged: repaint(); onInsideLevelChanged: repaint()
    onLeftOnChanged: repaint(); onLeftLevelChanged: repaint()
    onRightOnChanged: repaint(); onRightLevelChanged: repaint()
    onRearOnChanged: repaint(); onRearLevelChanged: repaint()
    onFrontOnChanged: repaint(); onFrontLevelChanged: repaint()
    onFrontAmberChanged: repaint(); onHighBeamOnChanged: repaint()
    Component.onCompleted: repaint()

    function glow(ctx, x, y, radius, color, strength) {
        var gradient = ctx.createRadialGradient(x, y, 1, x, y, radius)
        gradient.addColorStop(0, color.replace("ALPHA", Math.min(0.95, strength).toFixed(2)))
        gradient.addColorStop(0.35, color.replace("ALPHA", Math.min(0.45, strength * 0.55).toFixed(2)))
        gradient.addColorStop(1, color.replace("ALPHA", "0"))
        ctx.fillStyle = gradient
        ctx.beginPath(); ctx.arc(x, y, radius, 0, Math.PI * 2); ctx.fill()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        if (insideOn) {
            // Beifahrerseite: Wohnraum liegt in dieser Perspektive links
            // hinter der Kabine. Fahreransicht: Wohnraum liegt rechts.
            var ix = geometryRightView ? 180 : 325
            var iy = 150
            glow(ctx, ix, iy, 78, "rgba(255,191,93,ALPHA)", 0.18 + insideLevel / 180)
        }

        // Der manuelle bzw. vom Fahrzeug gemeldete Fernlichtzustand gehört
        // ausschließlich zum Zusatzbalken am Dachträger. Die serienmäßigen
        // Ford-Scheinwerfer werden von CamperControl weder geschaltet noch
        // als eingeschaltet dargestellt.
        // Pixelgenau auf die in beiden Fahrzeugbildern unterschiedlich
        // perspektivisch liegenden Frontbalken ausgerichtet.
        var fx1 = geometryRightView ? 225 : 142
        var fx2 = geometryRightView ? 340 : 270
        var fy = geometryRightView ? 32 : 43
        if (highBeamOn) {
            ctx.save()
            ctx.lineCap = "round"
            ctx.lineWidth = 10
            ctx.strokeStyle = "rgba(108,198,255,0.92)"
            ctx.shadowColor = "#49aef4"
            ctx.shadowBlur = 22
            ctx.beginPath(); ctx.moveTo(fx1, fy); ctx.lineTo(fx2, fy + (geometryRightView ? 4 : 1)); ctx.stroke()
            ctx.restore()
        }

        if (frontOn && (!frontAmber || blinkVisible)) {
            // Schmaler weißer/oranger Streifen innerhalb desselben Balkens.
            var fc = frontAmber ? "rgba(255,143,18,ALPHA)" : "rgba(250,253,255,ALPHA)"
            ctx.save()
            ctx.lineCap = "round"
            ctx.lineWidth = 2
            ctx.strokeStyle = fc.replace("ALPHA", (0.40 + frontLevel / 170).toFixed(2))
            ctx.shadowColor = frontAmber ? "#ff8f12" : "#ffffff"
            ctx.shadowBlur = 5 + frontLevel / 12
            ctx.beginPath(); ctx.moveTo(fx1, fy + 2); ctx.lineTo(fx2, fy + 2 + (geometryRightView ? 4 : 1)); ctx.stroke()
            ctx.restore()
        }

        var sideActive = rightView ? rightOn : leftOn
        var sideLevel = rightView ? rightLevel : leftLevel
        if (sideActive) {
            // Pro sichtbarer Fahrzeugseite exakt zwei kleine Dachträgerlampen.
            var sideLamps = geometryRightView ? [[58,43], [137,36]] : [[324,32], [395,37]]
            for (var s = 0; s < sideLamps.length; ++s)
                glow(ctx, sideLamps[s][0], sideLamps[s][1], 14 + sideLevel / 18, "rgba(235,249,255,ALPHA)", 0.38 + sideLevel / 135)
        }

        if (rearOn) {
            glow(ctx, geometryRightView ? 42 : 372, 13, 15 + rearLevel / 18, "rgba(235,249,255,ALPHA)", 0.42 + rearLevel / 130)
        }

    }
}
