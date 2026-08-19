import QtQuick 2.6

Canvas {
    id: icon
    property string kind: "home"
    property color lineColor: "#8da0ad"
    property real strokeWidth: 2

    onKindChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function line(c, points) {
        c.beginPath()
        c.moveTo(points[0][0], points[0][1])
        for (var i = 1; i < points.length; ++i) c.lineTo(points[i][0], points[i][1])
        c.stroke()
    }

    function circle(c, x, y, radius) {
        c.beginPath(); c.arc(x, y, radius, 0, Math.PI * 2); c.stroke()
    }

    function roundedRect(c, x, y, w, h, radius) {
        var r = Math.min(radius, w / 2, h / 2)
        c.beginPath(); c.moveTo(x + r, y); c.lineTo(x + w - r, y)
        c.quadraticCurveTo(x + w, y, x + w, y + r); c.lineTo(x + w, y + h - r)
        c.quadraticCurveTo(x + w, y + h, x + w - r, y + h); c.lineTo(x + r, y + h)
        c.quadraticCurveTo(x, y + h, x, y + h - r); c.lineTo(x, y + r)
        c.quadraticCurveTo(x, y, x + r, y); c.stroke()
    }

    function weatherCloudShape(c, w, h) {
        c.beginPath()
        c.moveTo(w*.20,h*.66)
        c.bezierCurveTo(w*.08,h*.65,w*.08,h*.45,w*.24,h*.42)
        c.bezierCurveTo(w*.29,h*.19,w*.59,h*.17,w*.69,h*.38)
        c.bezierCurveTo(w*.90,h*.36,w*.96,h*.64,w*.78,h*.68)
        c.lineTo(w*.20,h*.68)
        c.stroke()
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
            line(c, [[w*.13,h*.48],[x,h*.16],[w*.87,h*.48]])
            line(c, [[w*.22,h*.43],[w*.22,h*.85],[w*.43,h*.85],[w*.43,h*.61],[w*.62,h*.61],[w*.62,h*.85],[w*.78,h*.85],[w*.78,h*.43]])
        } else if (kind === "light") {
            circle(c, x, y, w*.15)
            line(c,[[x,h*.04],[x,h*.23]]); line(c,[[x,h*.77],[x,h*.96]])
            line(c,[[w*.04,y],[w*.23,y]]); line(c,[[w*.77,y],[w*.96,y]])
            line(c,[[w*.18,h*.18],[w*.31,h*.31]]); line(c,[[w*.69,h*.69],[w*.82,h*.82]])
            line(c,[[w*.82,h*.18],[w*.69,h*.31]]); line(c,[[w*.31,h*.69],[w*.18,h*.82]])
        } else if (kind === "cabinLight") {
            c.beginPath(); c.moveTo(w*.20,h*.45); c.quadraticCurveTo(x,h*.28,w*.80,h*.45); c.lineTo(w*.72,h*.69); c.quadraticCurveTo(x,h*.80,w*.28,h*.69); c.closePath(); c.stroke()
            line(c,[[w*.34,h*.56],[w*.66,h*.56]]); line(c,[[w*.25,h*.83],[w*.75,h*.83]]); line(c,[[x,h*.08],[x,h*.23]])
        } else if (kind === "sideLeft" || kind === "sideRight") {
            var right = kind === "sideRight"
            var rx = right ? w*.13 : w*.28
            roundedRect(c, rx, h*.25, w*.59, h*.41, w*.06)
            for (var led=0; led<3; ++led) circle(c, rx + w*(.13 + led*.17), h*.455, w*.026)
            if (right) {
                line(c,[[w*.78,h*.31],[w*.94,h*.20]]); line(c,[[w*.78,h*.455],[w*.98,h*.455]]); line(c,[[w*.78,h*.60],[w*.94,h*.72]])
            } else {
                line(c,[[w*.22,h*.31],[w*.06,h*.20]]); line(c,[[w*.22,h*.455],[w*.02,h*.455]]); line(c,[[w*.22,h*.60],[w*.06,h*.72]])
            }
        } else if (kind === "rearLight") {
            roundedRect(c,w*.34,h*.20,w*.50,h*.50,w*.09)
            circle(c,w*.49,h*.36,w*.026); circle(c,w*.68,h*.36,w*.026); circle(c,w*.49,h*.55,w*.026); circle(c,w*.68,h*.55,w*.026)
            line(c,[[w*.27,h*.28],[w*.09,h*.17]]); line(c,[[w*.27,h*.46],[w*.04,h*.46]]); line(c,[[w*.27,h*.64],[w*.09,h*.75]])
        } else if (kind === "lightBar" || kind === "warningBar") {
            roundedRect(c,w*.06,h*.33,w*.88,h*.34,w*.06)
            for (var bar=0; bar<5; ++bar) {
                var bx=w*(.18+bar*.16)
                if (kind === "warningBar") line(c,[[bx,h*.42],[bx+w*.07,h*.58],[bx+w*.02,h*.58]])
                else circle(c,bx,h*.50,w*.018)
            }
            if (kind === "warningBar") {
                line(c,[[x,h*.24],[x,h*.08]]); line(c,[[w*.18,h*.27],[w*.06,h*.14]]); line(c,[[w*.82,h*.27],[w*.94,h*.14]])
            }
        } else if (kind === "highBeam") {
            c.beginPath(); c.moveTo(w*.54,h*.20); c.bezierCurveTo(w*.76,h*.20,w*.88,h*.33,w*.88,h*.50); c.bezierCurveTo(w*.88,h*.67,w*.76,h*.80,w*.54,h*.80); c.closePath(); c.stroke()
            line(c,[[w*.43,h*.28],[w*.08,h*.28]]); line(c,[[w*.43,h*.43],[w*.08,h*.43]]); line(c,[[w*.43,h*.58],[w*.08,h*.58]]); line(c,[[w*.43,h*.73],[w*.08,h*.73]])
        } else if (kind === "outlet") {
            roundedRect(c,w*.18,h*.14,w*.64,h*.66,w*.10)
            line(c,[[w*.38,h*.31],[w*.38,h*.48]]); line(c,[[w*.62,h*.31],[w*.62,h*.48]])
            c.beginPath(); c.arc(x,h*.65,w*.14,Math.PI,0); c.stroke()
        } else if (kind === "pump") {
            circle(c,w*.40,h*.55,w*.20); circle(c,w*.40,h*.55,w*.05)
            line(c,[[w*.05,h*.55],[w*.20,h*.55]]); line(c,[[w*.60,h*.55],[w*.86,h*.55],[w*.86,h*.78]])
            c.beginPath(); c.moveTo(w*.78,h*.08); c.bezierCurveTo(w*.91,h*.25,w*.91,h*.38,w*.78,h*.43); c.bezierCurveTo(w*.65,h*.38,w*.65,h*.25,w*.78,h*.08); c.stroke()
        } else if (kind === "satellite") {
            c.beginPath(); c.moveTo(w*.17,h*.22); c.quadraticCurveTo(w*.29,h*.70,w*.76,h*.73); c.stroke()
            line(c,[[w*.47,h*.62],[w*.32,h*.88]]); line(c,[[w*.18,h*.88],[w*.49,h*.88]]); line(c,[[w*.39,h*.43],[w*.64,h*.18]])
            c.beginPath(); c.arc(w*.68,h*.18,w*.13,-.8,1.6); c.stroke(); c.beginPath(); c.arc(w*.68,h*.18,w*.26,-.8,1.6); c.stroke()
        } else if (kind === "fan") {
            circle(c,x,y,w*.07)
            for (var f=0;f<3;f++){var t=f*Math.PI*2/3;c.beginPath();c.moveTo(x+Math.cos(t)*w*.1,y+Math.sin(t)*h*.1);c.quadraticCurveTo(x+Math.cos(t+.45)*w*.43,y+Math.sin(t+.45)*h*.43,x+Math.cos(t+1.3)*w*.16,y+Math.sin(t+1.3)*h*.16);c.stroke()}
        } else if (kind === "plug") {
            line(c,[[w*.36,h*.08],[w*.36,h*.31]]); line(c,[[w*.64,h*.08],[w*.64,h*.31]])
            c.beginPath(); c.moveTo(w*.25,h*.31); c.lineTo(w*.75,h*.31); c.lineTo(w*.75,h*.49); c.bezierCurveTo(w*.75,h*.70,w*.25,h*.70,w*.25,h*.49); c.closePath(); c.stroke()
            line(c,[[x,h*.68],[x,h*.92]])
        } else if (kind === "solar") {
            circle(c,w*.27,h*.26,w*.10)
            for (var a=0;a<8;a++){var q=a*Math.PI/4;line(c,[[w*.27+Math.cos(q)*w*.15,h*.26+Math.sin(q)*h*.15],[w*.27+Math.cos(q)*w*.20,h*.26+Math.sin(q)*h*.20]])}
            c.beginPath(); c.moveTo(w*.29,h*.49); c.lineTo(w*.78,h*.49); c.lineTo(w*.88,h*.84); c.lineTo(w*.19,h*.84); c.closePath(); c.stroke()
            line(c,[[w*.37,h*.49],[w*.34,h*.84]]); line(c,[[w*.54,h*.49],[w*.54,h*.84]]); line(c,[[w*.69,h*.49],[w*.74,h*.84]]); line(c,[[w*.24,h*.66],[w*.83,h*.66]])
        } else if (kind === "alternator") {
            c.beginPath(); c.arc(x,y,w*.32,.25,Math.PI*1.85); c.stroke()
            line(c,[[w*.75,h*.34],[w*.75,h*.13]]); line(c,[[w*.75,h*.34],[w*.57,h*.34]]); line(c,[[w*.25,h*.67],[w*.25,h*.88]]); line(c,[[w*.25,h*.67],[w*.43,h*.67]])
            line(c,[[w*.56,h*.25],[w*.39,h*.56],[w*.52,h*.56],[w*.44,h*.78],[w*.64,h*.47],[w*.52,h*.47],[w*.56,h*.25]])
        } else if (kind === "battery" || kind === "energy") {
            roundedRect(c,w*.12,h*.26,w*.66,h*.50,w*.08); c.strokeRect(w*.78,h*.40,w*.10,h*.20)
            if (kind === "energy") line(c,[[w*.49,h*.33],[w*.35,h*.56],[w*.48,h*.56],[w*.40,h*.72],[w*.61,h*.47],[w*.49,h*.47]])
            else { line(c,[[w*.28,y],[w*.42,y]]); line(c,[[w*.61,h*.42],[w*.61,h*.58]]); line(c,[[w*.53,y],[w*.69,y]]) }
        } else if (kind === "water") {
            c.beginPath(); c.moveTo(x,h*.08); c.bezierCurveTo(w*.77,h*.42,w*.78,h*.68,x,h*.87); c.bezierCurveTo(w*.22,h*.68,w*.23,h*.42,x,h*.08); c.stroke()
        } else if (kind === "climate") {
            roundedRect(c,w*.38,h*.08,w*.18,h*.58,w*.09); circle(c,w*.47,h*.72,w*.19); line(c,[[w*.47,h*.27],[w*.47,h*.68]])
            line(c,[[w*.66,h*.24],[w*.82,h*.24]]); line(c,[[w*.66,h*.40],[w*.77,h*.40]]); line(c,[[w*.66,h*.56],[w*.82,h*.56]])
        } else if (kind === "flame") {
            c.beginPath(); c.moveTo(x,h*.08); c.bezierCurveTo(w*.57,h*.30,w*.74,h*.35,w*.76,h*.58); c.bezierCurveTo(w*.79,h*.84,w*.59,h*.92,x,h*.92); c.bezierCurveTo(w*.29,h*.92,w*.17,h*.74,w*.24,h*.55); c.bezierCurveTo(w*.29,h*.41,w*.43,h*.50,w*.47,h*.34); c.bezierCurveTo(w*.49,h*.24,w*.43,h*.18,x,h*.08); c.stroke()
        } else if (kind === "weatherClear") {
            circle(c,x,y,w*.20)
            for (var ray=0;ray<8;ray++) {
                var angle=ray*Math.PI/4
                line(c,[[x+Math.cos(angle)*w*.31,y+Math.sin(angle)*h*.31],[x+Math.cos(angle)*w*.43,y+Math.sin(angle)*h*.43]])
            }
        } else if (kind === "weatherCloud") {
            weatherCloudShape(c,w,h)
        } else if (kind === "weatherRain") {
            weatherCloudShape(c,w,h)
            line(c,[[w*.30,h*.76],[w*.24,h*.91]]); line(c,[[w*.52,h*.76],[w*.46,h*.91]]); line(c,[[w*.74,h*.76],[w*.68,h*.91]])
        } else if (kind === "weatherSnow") {
            weatherCloudShape(c,w,h)
            for (var snow=0;snow<3;snow++) {
                var sx=w*(.28+snow*.23), sy=h*.84
                line(c,[[sx-w*.05,sy],[sx+w*.05,sy]]); line(c,[[sx,sy-h*.05],[sx,sy+h*.05]])
                line(c,[[sx-w*.035,sy-h*.035],[sx+w*.035,sy+h*.035]]); line(c,[[sx+w*.035,sy-h*.035],[sx-w*.035,sy+h*.035]])
            }
        } else if (kind === "weatherStorm") {
            weatherCloudShape(c,w,h)
            line(c,[[w*.55,h*.70],[w*.40,h*.86],[w*.54,h*.86],[w*.43,h*.98],[w*.70,h*.79],[w*.56,h*.79]])
        } else if (kind === "weatherFog") {
            weatherCloudShape(c,w,h)
            line(c,[[w*.16,h*.77],[w*.74,h*.77]]); line(c,[[w*.27,h*.88],[w*.86,h*.88]])
        } else if (kind === "settings") {
            circle(c,x,y,w*.13); line(c,[[w*.12,h*.30],[w*.62,h*.30]]); circle(c,w*.74,h*.30,w*.10); line(c,[[w*.38,h*.70],[w*.88,h*.70]]); circle(c,w*.26,h*.70,w*.10)
        } else if (kind === "sunMoon") {
            c.beginPath(); c.arc(w*.43,h*.54,w*.26,.3,Math.PI*1.8); c.stroke(); circle(c,w*.64,h*.36,w*.15)
            line(c,[[w*.64,h*.07],[w*.64,h*.14]]); line(c,[[w*.86,h*.36],[w*.94,h*.36]]); line(c,[[w*.79,h*.20],[w*.86,h*.13]])
        } else if (kind === "back") {
            line(c,[[w*.63,h*.20],[w*.32,y],[w*.63,h*.80]]); line(c,[[w*.34,y],[w*.85,y]])
        } else if (kind === "close") {
            line(c,[[w*.22,h*.22],[w*.78,h*.78]]); line(c,[[w*.78,h*.22],[w*.22,h*.78]])
        } else if (kind === "info") {
            circle(c,x,y,w*.36); circle(c,x,h*.31,w*.02); line(c,[[x,h*.45],[x,h*.70]])
        } else if (kind === "network") {
            circle(c,x,h*.78,w*.035); c.beginPath(); c.arc(x,h*.75,w*.19,Math.PI*1.18,Math.PI*1.82); c.stroke(); c.beginPath(); c.arc(x,h*.75,w*.34,Math.PI*1.18,Math.PI*1.82); c.stroke()
        } else {
            circle(c,x,y,w*.30)
        }
    }
}
