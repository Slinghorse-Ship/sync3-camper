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

    function beginVehicleCoordinates(ctx) {
        var scale = Math.min(width / 560, height / 360)
        ctx.save()
        ctx.translate((width - 560 * scale) / 2, (height - 360 * scale) / 2)
        ctx.scale(scale, scale)
    }

    function lampBody(ctx, geometry, color, level, square) {
        var x = geometry[0] * 560
        var y = geometry[1] * 360
        var w = geometry[2] * 560
        var h = geometry[3] * 360
        ctx.save()
        ctx.shadowColor = color
        ctx.shadowBlur = 2 + Math.max(0, Math.min(100, level)) / 22
        ctx.fillStyle = color
        if (square) {
            ctx.fillRect(x, y, w, h)
        } else {
            var radius = Math.min(2.5, h / 2)
            ctx.beginPath()
            ctx.moveTo(x + radius, y)
            ctx.lineTo(x + w - radius, y)
            ctx.quadraticCurveTo(x + w, y, x + w, y + radius)
            ctx.lineTo(x + w, y + h - radius)
            ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h)
            ctx.lineTo(x + radius, y + h)
            ctx.quadraticCurveTo(x, y + h, x, y + h - radius)
            ctx.lineTo(x, y + radius)
            ctx.quadraticCurveTo(x, y, x + radius, y)
            ctx.fill()
        }
        ctx.restore()
    }

    function roofBar(ctx, geometry, color, level, lineWidth) {
        ctx.save()
        ctx.lineCap = "round"
        ctx.lineWidth = lineWidth
        ctx.strokeStyle = color
        ctx.shadowColor = color
        ctx.shadowBlur = 2 + Math.max(0, Math.min(100, level)) / 20
        ctx.beginPath()
        ctx.moveTo(geometry[0] * 560, geometry[1] * 360)
        ctx.lineTo(geometry[2] * 560, geometry[3] * 360)
        ctx.stroke()
        ctx.restore()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        beginVehicleCoordinates(ctx)

        if (insideOn) {
            // Beifahrerseite: Wohnraum liegt in dieser Perspektive links
            // hinter der Kabine. Fahreransicht: Wohnraum liegt rechts.
            var ix = geometryRightView ? 223 : 402
            var iy = 164
            glow(ctx, ix, iy, 90, "rgba(255,191,93,ALPHA)", 0.18 + insideLevel / 180)
        }

        // Alle Außenleuchten sind in den normierten 560x360-Assetkoordinaten
        // definiert. Dieselben Werte werden auf SYNC und GX verwendet:
        // links:  Front (.3000,.1361)-(.5661,.1361), Seite
        //         (.6571,.0944) / (.8107,.0972), Heck (.7714,.0139)
        // rechts: Front (.4696,.1000)-(.7125,.1139), Seite
        //         (.1125,.1139) / (.2625,.1111), Heck (.0768,.0139).
        // Die Touchflächen bleiben bewusst größer; der sichtbare Lichtkörper
        // sitzt dagegen ausschließlich direkt auf der jeweiligen Lampe.
        var frontBar = geometryRightView
                ? [.4696, .1000, .7125, .1139]
                : [.3000, .1361, .5661, .1361]
        if (highBeamOn) {
            roofBar(ctx, frontBar, "rgba(108,198,255,0.96)", 100, 6)
        }

        if (frontOn && (!frontAmber || blinkVisible)) {
            // Weiß/orange liegt als schmaler Lichtkörper innerhalb der Roof-Bar.
            var frontColor = frontAmber ? "rgba(255,143,18,0.98)" : "rgba(250,253,255,0.98)"
            roofBar(ctx, frontBar, frontColor, frontLevel, 3)
        }

        var sideActive = rightView ? rightOn : leftOn
        var sideLevel = rightView ? rightLevel : leftLevel
        if (sideActive) {
            // Kurze horizontale Lichtkörper direkt auf den Dachträgerlampen.
            var sideLamps = geometryRightView
                    ? [[.1125,.1139,.0286,.0194], [.2625,.1111,.0304,.0194]]
                    : [[.6571,.0944,.0286,.0194], [.8107,.0972,.0304,.0194]]
            for (var s = 0; s < sideLamps.length; ++s)
                lampBody(ctx, sideLamps[s], "rgba(235,249,255,0.98)", sideLevel, false)
        }

        if (rearOn) {
            // Quadratische Heckleuchte am hintersten Dachträger-Eck.
            var rearLamp = geometryRightView
                    ? [.0768,.0139,.0250,.0389]
                    : [.7714,.0139,.0250,.0389]
            lampBody(ctx, rearLamp, "rgba(235,249,255,0.98)", rearLevel, true)
        }

        ctx.restore()
    }
}
