import QtQuick 2.6

Item {
    id: panels
    objectName: "v2EdgePanelsHost"

    property var api
    property var favorites: []
    property var weather: ({})
    property bool dayMode: false
    property int activePanel: 0 // -1 = Favoriten, 0 = geschlossen, 1 = Wetter

    readonly property var hourlyForecast: weather && weather.hourly && weather.hourly.length
        ? weather.hourly : (weather && weather.forecast && weather.forecast.length ? weather.forecast : [])
    readonly property var dailyForecast: weather && weather.daily && weather.daily.length
        ? weather.daily : (weather && weather.dailyForecast && weather.dailyForecast.length ? weather.dailyForecast : [])
    readonly property var currentWeather: currentHourly()
    readonly property bool weatherAvailable: hourlyForecast.length > 0 || dailyForecast.length > 0

    CamperStyle { id: visual; dayMode: panels.dayMode }

    function close() { activePanel = 0 }
    function openFavorites() { activePanel = -1 }
    function openWeather() { activePanel = 1 }

    function validNumber(value) {
        return value !== null && value !== undefined && value !== "" && isFinite(Number(value))
    }

    function numberFrom(object, primary, secondary) {
        if (object && validNumber(object[primary])) return Number(object[primary])
        if (object && secondary && validNumber(object[secondary])) return Number(object[secondary])
        return null
    }

    function textFrom(object, primary, secondary) {
        if (object && object[primary] !== null && object[primary] !== undefined && String(object[primary]).length)
            return String(object[primary])
        if (object && secondary && object[secondary] !== null && object[secondary] !== undefined && String(object[secondary]).length)
            return String(object[secondary])
        return ""
    }

    function temperatureText(object) {
        var value = numberFrom(object, "temperature", "temperatureC")
        if (value === null) value = numberFrom(object, "tempC", "temp")
        return value === null ? "–°" : value.toFixed(0) + "°"
    }

    function detailText(label, value, suffix) {
        return validNumber(value) ? label + " " + Number(value).toFixed(0) + suffix : ""
    }

    function weatherLocation() {
        if (!weather) return "Wetter"
        if (weather.station && weather.station.name) return String(weather.station.name)
        if (typeof weather.location === "string" && weather.location.length) return weather.location
        if (weather.location && weather.location.name) return String(weather.location.name)
        return textFrom(weather, "stationName", "locationName") || "Wetter"
    }

    function weatherUpdatedText() {
        var value = weather && (weather.fetchedAtUtc || weather.updatedAt || weather.observedAt)
        if (!value) return ""
        var date = new Date(value)
        if (isNaN(date.getTime())) return ""
        return "Stand " + Qt.formatTime(date, "hh:mm") + (weather.stale === true ? " · veraltet" : "")
    }

    function sunTime(key) {
        var value = weather && weather.sun ? weather.sun[key] : null
        if (!value) return "–"
        var date = new Date(value)
        return isNaN(date.getTime()) ? "–" : Qt.formatTime(date, "hh:mm")
    }

    function currentHourly() {
        if (!hourlyForecast || !hourlyForecast.length) return ({})
        var now = new Date().getTime()
        for (var i = 0; i < hourlyForecast.length; ++i) {
            var value = hourlyForecast[i] && (hourlyForecast[i].t || hourlyForecast[i].timestamp || hourlyForecast[i].time || hourlyForecast[i].validAt)
            var time = new Date(value).getTime()
            if (isNaN(time) || time >= now - 3600000) return hourlyForecast[i]
        }
        return hourlyForecast[hourlyForecast.length - 1]
    }

    function forecastTime(item) {
        var value = item && (item.t || item.timestamp || item.time || item.at || item.validAt)
        if (!value) return textFrom(item, "label", "period") || "–"
        var date = new Date(value)
        return isNaN(date.getTime()) ? String(value) : Qt.formatTime(date, "hh:mm")
    }

    function dailyLabel(item) {
        var value = item && (item.date || item.timestamp || item.time || item.validAt)
        if (!value) return textFrom(item, "label", "day") || "–"
        var date = new Date(value)
        return isNaN(date.getTime()) ? String(value) : Qt.formatDate(date, "ddd")
    }

    function minimumTemperature(item) {
        var value = numberFrom(item, "minC", "temperatureMin")
        if (value === null) value = numberFrom(item, "minTemperature", "minTemperatureC")
        if (value === null) value = numberFrom(item, "minTemperatureC", "tempMin")
        return value
    }

    function maximumTemperature(item) {
        var value = numberFrom(item, "maxC", "temperatureMax")
        if (value === null) value = numberFrom(item, "maxTemperature", "maxTemperatureC")
        if (value === null) value = numberFrom(item, "maxTemperatureC", "tempMax")
        return value
    }

    function rainProbability(item) {
        var value = numberFrom(item, "precipProbabilityPct", "maxHourlyPrecipProbabilityPct")
        if (value === null) value = numberFrom(item, "precipitationProbability", "precipitationProbabilityPercent")
        if (value === null) value = numberFrom(item, "rainProbability", "probabilityOfPrecipitation")
        return value
    }

    function rainAmount(item) {
        var value = numberFrom(item, "precipMm", "precipitation")
        if (value === null) value = numberFrom(item, "precipitationMm", "rr1c")
        if (value === null) value = numberFrom(item, "rr1c", "RR1c")
        return value
    }

    function chartUsesProbability() {
        for (var i = 0; i < Math.min(24, hourlyForecast.length); ++i)
            if (rainProbability(hourlyForecast[i]) !== null) return true
        return false
    }

    function chartRainValue(item) {
        return chartUsesProbability() ? rainProbability(item) : rainAmount(item)
    }

    function chartRainLabel() {
        return chartUsesProbability() ? "Regen %" : "RR1c mm"
    }

    function weatherIcon(item) {
        var value = textFrom(item, "icon", "condition")
        value = value.toLowerCase()
        if (value.indexOf("storm") >= 0 || value.indexOf("thunder") >= 0 || value.indexOf("gewitter") >= 0) return "weatherStorm"
        if (value.indexOf("snow") >= 0 || value.indexOf("schnee") >= 0) return "weatherSnow"
        if (value.indexOf("rain") >= 0 || value.indexOf("regen") >= 0 || value.indexOf("shower") >= 0) return "weatherRain"
        if (value.indexOf("fog") >= 0 || value.indexOf("mist") >= 0 || value.indexOf("nebel") >= 0) return "weatherFog"
        if (value.indexOf("clear") >= 0 || value.indexOf("sun") >= 0 || value.indexOf("sonn") >= 0) return "weatherClear"
        return "weatherCloud"
    }

    function canActivate(item) {
        var command = item && item.command
        return item && item.available === true && command && command.target && command.action
    }

    function activate(item) {
        if (!canActivate(item) || !api) return
        var command = item.command
        var extra = ({})
        for (var key in command)
            if (key !== "target" && key !== "action" && key !== "value") extra[key] = command[key]
        api.command(command.target, command.action, command.value, extra)
    }

    function favoriteIcon(item) {
        var kinds = {
            "bulb":"cabinLight", "right-light":"sideRight", "down-light":"rearLight", "left-light":"sideLeft",
            "lightbar":"lightBar", "warningbar":"warningBar", "highbeam":"highBeam", "outlet":"outlet",
            "pump":"pump", "satellite":"satellite", "fan":"fan", "plug":"plug", "heater":"flame",
            "battery":"battery", "home":"home"
        }
        return kinds[item && item.icon] || "energy"
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        visible: panels.activePanel !== 0
        color: panels.dayMode ? "#6a87939c" : "#a8000509"
        opacity: panels.activePanel === 0 ? 0 : 1
        z: 20
        Behavior on opacity { NumberAnimation { duration: 140 } }
        MouseArea { anchors.fill: parent; onClicked: panels.close() }
    }

    Rectangle {
        id: favoritePanel
        objectName: "v2FavoritesPanel"
        x: panels.activePanel === -1 ? 0 : -width
        y: 0
        width: 340
        height: parent.height
        z: 30
        color: visual.panel
        border.color: visual.border
        border.width: 1
        clip: true
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        V2Icon { x: 20; y: 17; width: 32; height: 32; kind: "favorite"; lineColor: visual.blue; strokeWidth: 1.8 }
        Text { x: 62; y: 18; text: "Favoriten"; color: visual.text; font.pixelSize: 20; font.bold: true }
        Text { x: 62; y: 45; text: "Schnellzugriff"; color: visual.muted; font.pixelSize: 9; font.bold: true }
        Rectangle { x: 20; y: 69; width: 300; height: 1; color: visual.border }

        Text {
            visible: !panels.favorites || panels.favorites.length === 0
            x: 20; y: 104; width: 300
            text: "Keine Favoriten vom Camper-Backend"
            color: visual.muted; font.pixelSize: 11; wrapMode: Text.WordWrap
        }

        Repeater {
            model: panels.favorites ? Math.min(4, panels.favorites.length) : 0
            delegate: Rectangle {
                property var favorite: panels.favorites[index]
                property bool actionable: panels.canActivate(favorite)
                x: 14; y: 80 + index * 78; width: 312; height: 68; radius: 14
                opacity: favorite.available === false ? .55 : 1
                color: favorite.active === true ? visual.selectedBlue : visual.inner
                border.width: favorite.active === true ? 2 : 1
                border.color: favorite.active === true ? visual.blue : visual.border

                Rectangle {
                    x: 12; y: 12; width: 44; height: 44; radius: 12
                    color: favorite.active === true ? visual.blue : visual.disabled
                    V2Icon {
                        anchors.centerIn: parent; width: 26; height: 26
                        kind: panels.favoriteIcon(favorite)
                        lineColor: favorite.active === true ? "#ffffff" : visual.muted
                        strokeWidth: 1.8
                    }
                }
                Text {
                    x: 68; y: 13; width: 181; elide: Text.ElideRight
                    text: favorite.name || "Favorit"
                    color: visual.text; font.pixelSize: 12; font.bold: true
                }
                Text {
                    x: 68; y: 38; width: 181; elide: Text.ElideRight
                    text: favorite.status || (favorite.available === false ? "Nicht verfügbar" : "")
                    color: favorite.active === true ? visual.blue : visual.muted; font.pixelSize: 9
                }
                Text {
                    x: 252; y: 26; width: 45; horizontalAlignment: Text.AlignRight
                    text: parent.actionable ? "›" : "ANZEIGE"
                    color: parent.actionable ? visual.blue : visual.muted
                    font.pixelSize: parent.actionable ? 20 : 7; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: parent.actionable
                    onClicked: panels.activate(parent.favorite)
                }
            }
        }

        Text {
            x: 20; y: 407; width: 300; height: 47
            text: "Nicht verfügbare Einträge bleiben sichtbar und schalten nicht."
            color: visual.muted; font.pixelSize: 8; wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        id: weatherPanel
        objectName: "v2WeatherPanel"
        x: panels.activePanel === 1 ? panels.width - width : panels.width
        y: 0
        width: 560
        height: parent.height
        z: 30
        color: visual.panel
        border.color: visual.border
        border.width: 1
        clip: true
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        Text { x: 72; y: 14; width: 468; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: panels.weatherLocation(); color: visual.text; font.pixelSize: 20; font.bold: true }
        Text { x: 72; y: 42; width: 468; horizontalAlignment: Text.AlignRight; text: panels.weatherUpdatedText(); color: visual.muted; font.pixelSize: 9; font.bold: true }
        Rectangle { x: 14; y: 66; width: 532; height: 1; color: visual.border }

        Item {
            visible: panels.weatherAvailable
            x: 14; y: 78; width: 154; height: 153
            Rectangle { anchors.fill: parent; radius: 14; color: visual.inner; border.color: visual.border }
            V2Icon { x: 13; y: 12; width: 57; height: 57; kind: panels.weatherIcon(panels.currentWeather); lineColor: visual.blue; strokeWidth: 2.2 }
            Text { x: 77; y: 12; width: 68; text: panels.temperatureText(panels.currentWeather); color: visual.text; font.pixelSize: 30; font.bold: true }
            Text { x: 13; y: 78; width: 128; elide: Text.ElideRight; text: panels.textFrom(panels.currentWeather, "condition", "summary") || "Wetterlage"; color: visual.text; font.pixelSize: 10; font.bold: true }
            Text {
                x: 13; y: 105; width: 128; elide: Text.ElideRight
                text: {
                    var pieces = []
                    var rain = panels.rainProbability(panels.currentWeather)
                    var wind = panels.numberFrom(panels.currentWeather, "windKmh", "windSpeedKmh")
                    if (wind === null) wind = panels.numberFrom(panels.currentWeather, "windSpeed", "wind")
                    if (rain !== null) pieces.push("Regen " + rain.toFixed(0) + " %")
                    if (wind !== null) pieces.push("Wind " + wind.toFixed(0) + " km/h")
                    return pieces.join("\n")
                }
                color: visual.muted; font.pixelSize: 8; lineHeight: 1.35
            }
            Text {
                x: 13; y: 136; width: 128; elide: Text.ElideRight
                text: "Sonne ↑ " + panels.sunTime("riseUtc") + "  ↓ " + panels.sunTime("setUtc")
                color: visual.muted; font.pixelSize: 7
            }
        }

        Text {
            visible: !panels.weatherAvailable
            x: 14; y: 92; width: 532; height: 104
            text: panels.weather && panels.weather.status ? String(panels.weather.status) : "Keine Wetterdaten vom Camper-Backend"
            color: visual.muted; font.pixelSize: 11; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            visible: panels.weatherAvailable
            x: 178; y: 78; width: 368; height: 153; radius: 14
            color: visual.inner; border.color: visual.border
            Text { x: 11; y: 8; text: "Nächste 24 Stunden"; color: visual.text; font.pixelSize: 9; font.bold: true }
            Row {
                x: 236; y: 8; spacing: 9
                Rectangle { width: 9; height: 3; radius: 2; color: visual.orange; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Temperatur"; color: visual.muted; font.pixelSize: 7 }
                Rectangle { width: 9; height: 7; radius: 1; color: visual.blue; opacity: .55; anchors.verticalCenter: parent.verticalCenter }
                Text { text: panels.chartRainLabel(); color: visual.muted; font.pixelSize: 7 }
            }
            Canvas {
                id: weatherChart
                objectName: "v2Weather24HourChart"
                x: 9; y: 27; width: 350; height: 116
                property var hourlyData: panels.hourlyForecast
                property bool dayPalette: panels.dayMode
                onHourlyDataChanged: requestPaint()
                onDayPaletteChanged: requestPaint()
                onPaint: {
                    var context = getContext("2d")
                    context.clearRect(0, 0, width, height)
                    var count = Math.min(24, hourlyData && hourlyData.length ? hourlyData.length : 0)
                    if (!count) return
                    var left = 8, right = width - 7, top = 9, bottom = height - 18
                    var minimum = 1000, maximum = -1000, rainMaximum = panels.chartUsesProbability() ? 100 : 0
                    var hasTemperature = false
                    for (var i = 0; i < count; ++i) {
                        var temperature = panels.numberFrom(hourlyData[i], "tempC", "temperature")
                        if (temperature === null) temperature = panels.numberFrom(hourlyData[i], "temperatureC", "temp")
                        if (temperature !== null) {
                            minimum = Math.min(minimum, temperature)
                            maximum = Math.max(maximum, temperature)
                            hasTemperature = true
                        }
                        var rain = panels.chartRainValue(hourlyData[i])
                        if (rain !== null && !panels.chartUsesProbability()) rainMaximum = Math.max(rainMaximum, rain)
                    }
                    if (rainMaximum <= 0) rainMaximum = 1
                    if (!hasTemperature) { minimum = 0; maximum = 1 }
                    if (maximum - minimum < 3) { maximum += 1.5; minimum -= 1.5 }
                    else { maximum += 1; minimum -= 1 }
                    context.lineWidth = 1
                    context.strokeStyle = panels.dayMode ? "#ccd7dd" : "#263743"
                    for (var grid = 0; grid < 3; ++grid) {
                        var gy = top + grid * (bottom - top) / 2
                        context.beginPath(); context.moveTo(left, gy); context.lineTo(right, gy); context.stroke()
                    }
                    var step = count > 1 ? (right - left) / (count - 1) : 0
                    context.fillStyle = panels.dayMode ? "#4eafe4" : "#42bcff"
                    context.globalAlpha = .38
                    for (var bar = 0; bar < count; ++bar) {
                        var rainValue = panels.chartRainValue(hourlyData[bar])
                        if (rainValue === null || rainValue <= 0) continue
                        var barHeight = Math.max(2, Math.min(bottom - top, (rainValue / rainMaximum) * (bottom - top)))
                        context.fillRect(left + bar * step - 2, bottom - barHeight, 4, barHeight)
                    }
                    context.globalAlpha = 1
                    if (hasTemperature) {
                        context.beginPath(); context.strokeStyle = panels.dayMode ? "#dd762e" : "#ff9c4a"; context.lineWidth = 2.2
                        var started = false
                        for (var point = 0; point < count; ++point) {
                            var pointTemperature = panels.numberFrom(hourlyData[point], "tempC", "temperature")
                            if (pointTemperature === null) pointTemperature = panels.numberFrom(hourlyData[point], "temperatureC", "temp")
                            if (pointTemperature === null) continue
                            var px = left + point * step
                            var py = bottom - (pointTemperature - minimum) / (maximum - minimum) * (bottom - top)
                            if (!started) { context.moveTo(px, py); started = true } else context.lineTo(px, py)
                        }
                        context.stroke()
                    }
                    context.fillStyle = panels.dayMode ? "#61727c" : "#8fa2af"; context.font = "7px sans-serif"
                    var marks = count >= 24 ? [0, 6, 12, 18, 23] : [0, Math.floor((count - 1) / 2), count - 1]
                    for (var mark = 0; mark < marks.length; ++mark) {
                        var itemIndex = marks[mark]
                        var label = panels.forecastTime(hourlyData[itemIndex])
                        var labelX = left + itemIndex * step
                        if (mark === 0) context.textAlign = "left"
                        else if (mark === marks.length - 1) context.textAlign = "right"
                        else context.textAlign = "center"
                        context.fillText(label, labelX, height - 4)
                    }
                }
            }
            Text {
                visible: !panels.hourlyForecast || panels.hourlyForecast.length === 0
                anchors.centerIn: parent; text: "Keine Stundenprognose"; color: visual.muted; font.pixelSize: 9
            }
        }

        Text { x: 14; y: 244; text: "6-Tage-Vorhersage"; color: visual.muted; font.pixelSize: 9; font.bold: true }
        Repeater {
            model: panels.weatherAvailable ? Math.min(6, panels.dailyForecast.length) : 0
            delegate: Rectangle {
                property var dayItem: panels.dailyForecast[index]
                x: 14 + index * 89; y: 264; width: 84; height: 154; radius: 12
                color: visual.inner; border.color: visual.border
                Text { x: 4; y: 10; width: 76; horizontalAlignment: Text.AlignHCenter; text: panels.dailyLabel(parent.dayItem); color: visual.text; font.pixelSize: 9; font.bold: true; font.capitalization: Font.AllUppercase }
                V2Icon { x: 24; y: 34; width: 36; height: 36; kind: panels.weatherIcon(parent.dayItem); lineColor: visual.blue; strokeWidth: 1.8 }
                Text {
                    x: 3; y: 81; width: 78; horizontalAlignment: Text.AlignHCenter
                    text: {
                        var maximum = panels.maximumTemperature(parent.dayItem)
                        var minimum = panels.minimumTemperature(parent.dayItem)
                        return (maximum === null ? "–" : maximum.toFixed(0)) + "° / " + (minimum === null ? "–" : minimum.toFixed(0)) + "°"
                    }
                    color: visual.text; font.pixelSize: 11; font.bold: true
                }
                Text {
                    x: 3; y: 112; width: 78; horizontalAlignment: Text.AlignHCenter
                    text: {
                        var chance = panels.rainProbability(parent.dayItem)
                        var amount = panels.rainAmount(parent.dayItem)
                        if (chance !== null) return "Regen " + chance.toFixed(0) + " %"
                        return amount === null ? "" : "RR1c " + amount.toFixed(1) + " mm"
                    }
                    color: visual.muted; font.pixelSize: 7
                }
            }
        }

        Text {
            visible: panels.weatherAvailable && (!panels.dailyForecast || panels.dailyForecast.length === 0)
            x: 14; y: 294; width: 532; text: "Keine Tagesprognose vom Camper-Backend"
            horizontalAlignment: Text.AlignHCenter; color: visual.muted; font.pixelSize: 9
        }

        Text {
            x: 14; y: 445; width: 532; horizontalAlignment: Text.AlignRight
            text: "Quelle: " + (panels.weather && panels.weather.attribution ? String(panels.weather.attribution) : "Deutscher Wetterdienst") + " · Daten vom Cerbo"
            color: visual.muted; font.pixelSize: 7
        }
    }

    Rectangle {
        id: closeButton
        objectName: "v2EdgePanelClose"
        visible: panels.activePanel !== 0
        x: panels.activePanel === -1 ? 278 : 250
        y: 10
        width: 48
        height: 48
        radius: 14
        z: 50
        color: closeArea.pressed ? visual.pressed : visual.inner
        border.color: visual.border
        V2Icon { anchors.centerIn: parent; width: 22; height: 22; kind: "close"; lineColor: visual.text; strokeWidth: 2 }
        MouseArea { id: closeArea; anchors.fill: parent; onClicked: panels.close() }
    }

    MouseArea {
        id: leftEdge
        objectName: "v2LeftEdgeSwipe"
        visible: panels.activePanel === 0
        x: 0; y: 56; width: 18; height: 335
        z: 10
        property real startX: 0
        property real startY: 0
        propagateComposedEvents: true
        onPressed: { startX = mouse.x; startY = mouse.y }
        onReleased: {
            var dx = mouse.x - startX
            var dy = mouse.y - startY
            if (dx >= 48 && Math.abs(dx) > Math.abs(dy) * 1.5) panels.openFavorites()
            else mouse.accepted = false
        }
        onClicked: mouse.accepted = false
    }

    MouseArea {
        id: rightEdge
        objectName: "v2RightEdgeSwipe"
        visible: panels.activePanel === 0
        x: 782; y: 56; width: 18; height: 335
        z: 10
        property real startX: 0
        property real startY: 0
        propagateComposedEvents: true
        onPressed: { startX = mouse.x; startY = mouse.y }
        onReleased: {
            var dx = startX - mouse.x
            var dy = mouse.y - startY
            if (dx >= 48 && Math.abs(dx) > Math.abs(dy) * 1.5) panels.openWeather()
            else mouse.accepted = false
        }
        onClicked: mouse.accepted = false
    }
}
