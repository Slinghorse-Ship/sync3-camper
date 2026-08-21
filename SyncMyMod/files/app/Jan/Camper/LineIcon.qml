import QtQuick 2.6

// Original CamperControl device drawings plus selected navigation symbols
// adapted from Lucide; see the repository NOTICE.md and LICENSE-LUCIDE.txt.
Canvas {
    id: icon
    property string kind: "home"
    property color lineColor: "#45c9fa"
    property real strokeWidth: 2.4

    onKindChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function line(ctx, points) {
        ctx.beginPath()
        ctx.moveTo(points[0][0], points[0][1])
        for (var i = 1; i < points.length; ++i) ctx.lineTo(points[i][0], points[i][1])
        ctx.stroke()
    }

    onPaint: {
        var c = getContext("2d")
        c.clearRect(0, 0, width, height)
        c.strokeStyle = lineColor
        c.fillStyle = lineColor
        c.lineWidth = strokeWidth
        c.lineCap = "round"
        c.lineJoin = "round"
        var w = width, h = height, x = w / 2, y = h / 2

        if (kind === "home") {
            line(c, [[w*.12,h*.49],[x,h*.15],[w*.88,h*.49]])
            line(c, [[w*.23,h*.43],[w*.23,h*.86],[w*.43,h*.86],[w*.43,h*.62],[w*.64,h*.62],[w*.64,h*.86],[w*.77,h*.86],[w*.77,h*.43]])
        } else if (kind === "light") {
            c.beginPath(); c.moveTo(w*.31,h*.43); c.bezierCurveTo(w*.31,h*.22,w*.69,h*.22,w*.69,h*.43); c.bezierCurveTo(w*.69,h*.57,w*.60,h*.61,w*.59,h*.70); c.lineTo(w*.41,h*.70); c.bezierCurveTo(w*.40,h*.61,w*.31,h*.57,w*.31,h*.43); c.stroke()
            line(c,[[w*.39,h*.76],[w*.61,h*.76]]); line(c,[[w*.42,h*.83],[w*.58,h*.83]])
            line(c,[[x,h*.06],[x,h*.17]]); line(c,[[w*.17,h*.18],[w*.25,h*.27]]); line(c,[[w*.83,h*.18],[w*.75,h*.27]]); line(c,[[w*.11,h*.45],[w*.22,h*.45]]); line(c,[[w*.89,h*.45],[w*.78,h*.45]])
        } else if (kind === "solar") {
            c.beginPath(); c.arc(w*.28,h*.27,w*.10,0,Math.PI*2); c.stroke()
            for (var a=0;a<8;a++){var q=a*Math.PI/4;line(c,[[w*.28+Math.cos(q)*w*.15,h*.27+Math.sin(q)*h*.15],[w*.28+Math.cos(q)*w*.21,h*.27+Math.sin(q)*h*.21]])}
            c.beginPath(); c.moveTo(w*.29,h*.47); c.lineTo(w*.79,h*.47); c.lineTo(w*.89,h*.82); c.lineTo(w*.20,h*.82); c.closePath(); c.stroke()
            line(c,[[w*.37,h*.47],[w*.34,h*.82]]); line(c,[[w*.53,h*.47],[w*.54,h*.82]]); line(c,[[w*.69,h*.47],[w*.74,h*.82]])
            line(c,[[w*.25,h*.64],[w*.84,h*.64]])
        } else if (kind === "cabinLight") {
            // Flat interior ceiling light, not a generic sun/bulb.
            c.beginPath(); c.moveTo(w*.2,h*.42); c.quadraticCurveTo(x,h*.25,w*.8,h*.42); c.lineTo(w*.72,h*.68); c.quadraticCurveTo(x,h*.78,w*.28,h*.68); c.closePath(); c.stroke()
            line(c,[[w*.34,h*.53],[w*.66,h*.53]])
        } else if (kind === "workLight" || kind === "workLightLeft" || kind === "workLightRight" || kind === "rearLight") {
            // Rectangular four-LED work lamp as installed on the roof rack.
            c.strokeRect(w*.18,h*.28,w*.64,h*.40)
            for (var led=0;led<4;led++){c.beginPath();c.arc(w*(.29+led*.14),h*.48,w*.035,0,Math.PI*2);c.stroke()}
            if (kind === "rearLight") {
                line(c,[[w*.22,h*.76],[w*.12,h*.88]]); line(c,[[w*.5,h*.76],[w*.5,h*.93]]); line(c,[[w*.78,h*.76],[w*.88,h*.88]])
            } else if (kind === "workLightRight") {
                line(c,[[w*.86,h*.35],[w*.97,h*.28]]); line(c,[[w*.86,h*.5],[w*.99,h*.5]]); line(c,[[w*.86,h*.65],[w*.97,h*.72]])
            } else {
                line(c,[[w*.14,h*.35],[w*.03,h*.28]]); line(c,[[w*.14,h*.5],[w*.01,h*.5]]); line(c,[[w*.14,h*.65],[w*.03,h*.72]])
            }
        } else if (kind === "lightBar" || kind === "warningBar") {
            // Long dual-colour strip inside the front light bar.
            c.strokeRect(w*.08,h*.32,w*.84,h*.36)
            for (var bar=0;bar<5;bar++){
                if (kind === "warningBar") line(c,[[w*(.19+bar*.15),h*.42],[w*(.24+bar*.15),h*.58]])
                else { c.beginPath(); c.arc(w*(.2+bar*.15),h*.5,w*.025,0,Math.PI*2); c.stroke() }
            }
            if (kind === "warningBar") { line(c,[[w*.15,h*.22],[w*.08,h*.12]]); line(c,[[w*.85,h*.22],[w*.92,h*.12]]) }
        } else if (kind === "highBeam") {
            c.beginPath(); c.moveTo(w*.55,h*.2); c.quadraticCurveTo(w*.22,h*.2,w*.22,h*.5); c.quadraticCurveTo(w*.22,h*.8,w*.55,h*.8); c.closePath(); c.stroke()
            line(c,[[w*.62,h*.3],[w*.92,h*.3]]); line(c,[[w*.62,h*.5],[w*.92,h*.5]]); line(c,[[w*.62,h*.7],[w*.92,h*.7]])
        } else if (kind === "scenes") {
            c.strokeRect(w*.15,h*.36,w*.7,h*.48)
            line(c,[[w*.15,h*.36],[w*.26,h*.16],[w*.88,h*.16],[w*.77,h*.36]])
            line(c,[[w*.31,h*.17],[w*.42,h*.36],[w*.58,h*.17],[w*.69,h*.36]])
        } else if (kind === "alerts") {
            c.beginPath(); c.arc(x,h*.82,w*.07,0,Math.PI); c.stroke()
            c.beginPath(); c.moveTo(w*.2,h*.72); c.quadraticCurveTo(w*.3,h*.63,w*.3,h*.43); c.quadraticCurveTo(w*.3,h*.17,x,h*.17); c.quadraticCurveTo(w*.7,h*.17,w*.7,h*.43); c.quadraticCurveTo(w*.7,h*.63,w*.8,h*.72); c.closePath(); c.stroke()
        } else if (kind === "service") {
            c.beginPath(); c.arc(w*.35,h*.32,w*.18,0.6,4.7); c.stroke()
            line(c,[[w*.46,h*.44],[w*.82,h*.8]])
            c.beginPath(); c.arc(w*.82,h*.8,w*.08,0,Math.PI*2); c.stroke()
        } else if (kind === "power") {
            line(c,[[w*.56,h*.08],[w*.27,h*.53],[w*.48,h*.53],[w*.39,h*.92],[w*.75,h*.4],[w*.53,h*.4]])
        } else if (kind === "outlet") {
            c.strokeRect(w*.16,h*.20,w*.68,h*.58)
            line(c,[[w*.36,h*.34],[w*.36,h*.52]]); line(c,[[w*.64,h*.34],[w*.64,h*.52]])
            c.beginPath(); c.arc(x,h*.63,w*.075,Math.PI,0); c.stroke()
        } else if (kind === "plug") {
            line(c,[[w*.36,h*.10],[w*.36,h*.31]]); line(c,[[w*.64,h*.10],[w*.64,h*.31]])
            c.strokeRect(w*.25,h*.30,w*.50,h*.29)
            line(c,[[x,h*.59],[x,h*.76],[w*.67,h*.88]])
        } else if (kind === "satellite") {
            c.beginPath(); c.moveTo(w*.18,h*.28); c.quadraticCurveTo(w*.30,h*.70,w*.72,h*.72); c.stroke()
            line(c,[[w*.46,h*.61],[w*.32,h*.86]]); line(c,[[w*.20,h*.86],[w*.48,h*.86]])
            line(c,[[w*.38,h*.42],[w*.61,h*.20]])
            c.beginPath(); c.arc(w*.66,h*.18,w*.11,-.8,1.6); c.stroke()
            c.beginPath(); c.arc(w*.67,h*.18,w*.23,-.8,1.6); c.stroke()
        } else if (kind === "network") {
            // Klassisches WLAN-Symbol für den externen Netgear-Uplink.
            c.beginPath(); c.arc(x,h*.82,w*.055,0,Math.PI*2); c.fill()
            c.beginPath(); c.arc(x,h*.78,w*.20,Math.PI*1.18,Math.PI*1.82); c.stroke()
            c.beginPath(); c.arc(x,h*.78,w*.35,Math.PI*1.18,Math.PI*1.82); c.stroke()
            c.beginPath(); c.arc(x,h*.78,w*.50,Math.PI*1.18,Math.PI*1.82); c.stroke()
        } else if (kind === "battery") {
            c.strokeRect(w*.13,h*.25,w*.7,h*.52); c.strokeRect(w*.83,h*.39,w*.08,h*.23)
            line(c,[[w*.29,h*.51],[w*.43,h*.51]]); line(c,[[w*.62,h*.43],[w*.62,h*.59],[w*.54,h*.51],[w*.7,h*.51]])
        } else if (kind === "water") {
            c.beginPath(); c.moveTo(x,h*.08); c.bezierCurveTo(w*.78,h*.43,w*.78,h*.68,x,h*.86); c.bezierCurveTo(w*.22,h*.68,w*.22,h*.43,x,h*.08); c.stroke()
        } else if (kind === "climate") {
            c.beginPath(); c.arc(w*.42,h*.72,w*.16,0,Math.PI*2); c.stroke(); c.strokeRect(w*.36,h*.14,w*.12,h*.55)
            line(c,[[w*.42,h*.3],[w*.42,h*.68]]); line(c,[[w*.61,h*.28],[w*.72,h*.28]]); line(c,[[w*.61,h*.41],[w*.68,h*.41]]); line(c,[[w*.61,h*.54],[w*.72,h*.54]])
        } else if (kind === "fan") {
            c.beginPath(); c.arc(x,y,w*.08,0,Math.PI*2); c.stroke()
            for(var f=0;f<3;f++){var t=f*Math.PI*2/3;c.beginPath();c.moveTo(x+Math.cos(t)*w*.1,y+Math.sin(t)*h*.1);c.quadraticCurveTo(x+Math.cos(t+.45)*w*.43,y+Math.sin(t+.45)*h*.43,x+Math.cos(t+1.3)*w*.16,y+Math.sin(t+1.3)*h*.16);c.stroke()}
        } else if (kind === "pump") {
            c.beginPath(); c.arc(w*.43,h*.54,w*.22,0,Math.PI*2); c.stroke()
            c.beginPath(); c.arc(w*.43,h*.54,w*.07,0,Math.PI*2); c.stroke()
            line(c,[[w*.04,h*.54],[w*.21,h*.54]]); line(c,[[w*.65,h*.54],[w*.88,h*.54],[w*.88,h*.78]])
            c.beginPath(); c.moveTo(w*.72,h*.08); c.bezierCurveTo(w*.84,h*.24,w*.84,h*.34,w*.72,h*.39); c.bezierCurveTo(w*.60,h*.34,w*.60,h*.24,w*.72,h*.08); c.stroke()
        } else if (kind === "settings") {
            c.beginPath(); c.arc(x,y,w*.2,0,Math.PI*2); c.stroke(); c.beginPath(); c.arc(x,y,w*.07,0,Math.PI*2); c.stroke(); for(var g=0;g<8;g++){var z=g*Math.PI/4;line(c,[[x+Math.cos(z)*w*.25,y+Math.sin(z)*h*.25],[x+Math.cos(z)*w*.4,y+Math.sin(z)*h*.4]])}
        } else if (kind === "close") {
            line(c,[[w*.2,h*.2],[w*.8,h*.8]]); line(c,[[w*.8,h*.2],[w*.2,h*.8]])
        } else {
            c.beginPath(); c.arc(x,y,w*.3,0,Math.PI*2); c.stroke()
        }
    }
}
