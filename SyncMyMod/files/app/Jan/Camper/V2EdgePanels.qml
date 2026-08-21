import QtQuick 2.6

Item {
    id: panels
    objectName: "v2EdgePanelsHost"

    property var api
    property var host
    property var favorites: []
    property var favoriteIds: []
    property var favoriteOptions: []
    property var weather: ({})
    property bool dayMode: false
    property int activePanel: 0 // -1 = Favoriten, 0 = geschlossen, 1 = Wetter

    readonly property var hourlyForecast: weather && weather.hourly && weather.hourly.length
        ? weather.hourly : (weather && weather.forecast && weather.forecast.length ? weather.forecast : [])
    readonly property var dailyForecast: weather && weather.daily && weather.daily.length
        ? weather.daily : (weather && weather.dailyForecast && weather.dailyForecast.length ? weather.dailyForecast : [])
    readonly property var currentWeather: currentHourly()
    readonly property bool weatherAvailable: hourlyForecast.length > 0 || dailyForecast.length > 0
    readonly property var tides: weather && weather.tides && typeof weather.tides === "object" ? weather.tides : null
    readonly property bool tidesAvailable: validTides(tides)
    readonly property bool tideCurveAvailable: validTideCurve(tides)
    readonly property var tideCurve: tideCurveAvailable ? tides.curve : []

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

    function validIsoTimestamp(value) {
        if (typeof value !== "string" || !/(Z|[+-]\d\d:\d\d)$/.test(value)) return false
        var date = new Date(value)
        return !isNaN(date.getTime())
    }

    function validTideEvent(event) {
        return event && typeof event === "object" && validIsoTimestamp(event.t)
                && (event.heightM === null || validNumber(event.heightM))
    }

    function validTides(data) {
        if (!data || typeof data !== "object" || data.source !== "BSH" || data.referenceLevel !== "PNP") return false
        if (!data.attribution || data.license !== "CC BY 4.0"
                || data.licenseUrl !== "https://creativecommons.org/licenses/by/4.0/"
                || typeof data.changes !== "string" || !data.changes.length || data.changes.length > 256
                || !validIsoTimestamp(data.updatedUtc)
                || (data.stale !== true && data.stale !== false)) return false
        var station = data.station
        if (!station || typeof station !== "object" || !station.id || !station.name
                || !validNumber(station.distanceKm)) return false
        return validTideEvent(data.nextHigh) && validTideEvent(data.nextLow)
    }

    function validTideCurve(data) {
        if (!validTides(data) || !data.curve || typeof data.curve.length !== "number"
                || data.curve.length < 2 || data.curve.length > 27) return false
        var previousTime = -1
        for (var i = 0; i < data.curve.length; ++i) {
            var point = data.curve[i]
            if (!point || typeof point !== "object" || !validIsoTimestamp(point.t)
                    || typeof point.heightM !== "number" || !isFinite(point.heightM)
                    || point.heightM < -20 || point.heightM > 20) return false
            var pointTime = new Date(point.t).getTime()
            if (pointTime <= previousTime) return false
            previousTime = pointTime
        }
        return true
    }

    function tideEventText(label, event, markStale) {
        if (!validTideEvent(event)) return ""
        var date = new Date(event.t)
        var height = event.heightM === null ? "–" : Number(event.heightM).toFixed(1).replace(".", ",") + " m PNP"
        return label + " " + Qt.formatTime(date, "hh:mm") + " · " + height
                + (markStale && tides.stale === true ? " · veraltet" : "")
    }

    function tideSummary() {
        if (!tidesAvailable) return ""
        return tideEventText("HW", tides.nextHigh, true) + "\n" + tideEventText("NW", tides.nextLow, false)
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
        var fallback = textFrom(item, "condition", "summary")
        value = (value + " " + fallback).toLowerCase()
        if (value.indexOf("hail") >= 0 || value.indexOf("hagel") >= 0) return "weatherHail"
        if (value.indexOf("storm") >= 0 || value.indexOf("thunder") >= 0 || value.indexOf("gewitter") >= 0) return "weatherStorm"
        if (value.indexOf("freezing") >= 0 || value.indexOf("gefrier") >= 0 || value.indexOf("ice-rain") >= 0) return "weatherFreezingRain"
        if (value.indexOf("sleet") >= 0 || value.indexOf("mixed") >= 0 || value.indexOf("schneeregen") >= 0) return "weatherSleet"
        if (value.indexOf("snow") >= 0 || value.indexOf("schnee") >= 0) return "weatherSnow"
        if (value.indexOf("rain") >= 0 || value.indexOf("regen") >= 0 || value.indexOf("shower") >= 0 || value.indexOf("drizzle") >= 0 || value.indexOf("sprüh") >= 0) return "weatherRain"
        if (value.indexOf("fog") >= 0 || value.indexOf("mist") >= 0 || value.indexOf("nebel") >= 0) return "weatherFog"
        if (value.indexOf("clear") >= 0 || value.indexOf("sun") >= 0 || value.indexOf("sonn") >= 0) return "weatherClear"
        if (value.indexOf("partly-cloudy") >= 0 || value.indexOf("cloud") >= 0 || value.indexOf("overcast") >= 0 || value.indexOf("bewölk") >= 0 || value.indexOf("bedeckt") >= 0 || value.indexOf("wolk") >= 0) return "weatherCloud"
        var code = numberFrom(item, "ww", "weatherCode")
        if (code !== null) {
            code = Math.round(code)
            if (code === 96 || code === 99) return "weatherHail"
            if (code === 95 || code === 97 || code === 98) return "weatherStorm"
            if (code === 56 || code === 57 || code === 66 || code === 67) return "weatherFreezingRain"
            if (code === 68 || code === 69 || code === 83 || code === 84) return "weatherSleet"
            if (code === 71 || code === 73 || code === 75 || code === 85 || code === 86) return "weatherSnow"
            if (code === 51 || code === 53 || code === 55 || code === 61 || code === 63 || code === 65 || code === 80 || code === 81 || code === 82) return "weatherRain"
            if (code === 45 || code === 49) return "weatherFog"
            if (code === 0) return "weatherClear"
            if (code === 1 || code === 2 || code === 3) return "weatherCloud"
        }
        return "weatherUnknown"
    }

    function weatherDescription(item) {
        var explicit = textFrom(item, "condition", "summary")
        if (explicit.length) return explicit
        var code = numberFrom(item, "ww", "weatherCode")
        if (code !== null) {
            code = Math.round(code)
            var descriptions = ({
                0:"Klar", 1:"Auflockernd", 2:"Bewölkt", 3:"Zunehmend bewölkt",
                45:"Nebel", 49:"Eisnebel",
                51:"Leichter Sprühregen", 53:"Sprühregen", 55:"Starker Sprühregen",
                56:"Leicht gefrierender Sprühregen", 57:"Gefrierender Sprühregen",
                61:"Leichter Regen", 63:"Regen", 65:"Starker Regen",
                66:"Leicht gefrierender Regen", 67:"Gefrierender Regen",
                68:"Leichter Schneeregen", 69:"Schneeregen",
                71:"Leichter Schneefall", 73:"Schneefall", 75:"Starker Schneefall",
                80:"Leichter Regenschauer", 81:"Regenschauer", 82:"Heftiger Regenschauer",
                83:"Leichter Schneeregenschauer", 84:"Schneeregenschauer",
                85:"Leichter Schneeschauer", 86:"Schneeschauer",
                95:"Gewitter mit Regen oder Schnee",
                96:"Hagelgewitter", 97:"Starkes Gewitter", 98:"Gewitter", 99:"Starkes Hagelgewitter"
            })
            if (descriptions[code]) return descriptions[code]
        }
        return "Wetterlage"
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

    function favoriteIdAt(index) {
        return favoriteIds && index >= 0 && index < favoriteIds.length ? String(favoriteIds[index] || "") : ""
    }

    function favoriteForSlot(index) {
        var id = favoriteIdAt(index)
        for (var i = 0; favorites && i < favorites.length; ++i)
            if (String(favorites[i].id || "") === id) return favorites[i]
        return null
    }

    function favoriteSelectionName(index) {
        var id = favoriteIdAt(index)
        for (var i = 0; favoriteOptions && i < favoriteOptions.length; ++i) {
            if (String(favoriteOptions[i].id || "") !== id) continue
            var group = String(favoriteOptions[i].group || "")
            var name = String(favoriteOptions[i].name || id)
            return group ? group + " · " + name : name
        }
        return id || "Nicht belegt"
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
        Text { x: 62; y: 18; width: 190; clip: true; elide: Text.ElideRight; text: "Favoriten"; color: visual.text; font.pixelSize: 20; font.bold: true }
        Text { objectName: "v2FavoritesSubtitle"; x: 62; y: 45; width: 190; clip: true; elide: Text.ElideRight; text: "Antippen zum Schalten"; color: visual.muted; font.pixelSize: 9; font.bold: true }
        Rectangle { x: 20; y: 69; width: 300; height: 1; color: visual.border }

        Repeater {
            model: 4
            delegate: Rectangle {
                property string favoriteId: panels.favoriteIdAt(index)
                property var favorite: panels.favoriteForSlot(index)
                property bool actionable: panels.canActivate(favorite)
                property bool favoriteActive: favorite && favorite.active === true
                property bool favoriteUnavailable: favorite && favorite.available === false
                x: 14; y: 80 + index * 78; width: 312; height: 68; radius: 14
                opacity: favoriteUnavailable ? .55 : 1
                color: favoriteActive ? visual.selectedBlue : visual.inner
                border.width: favoriteActive ? 2 : 1
                border.color: favoriteActive ? visual.blue : visual.border

                Rectangle {
                    x: 10; y: 12; width: 44; height: 44; radius: 12
                    color: favoriteActive ? visual.blue : visual.disabled
                    V2Icon {
                        anchors.centerIn: parent; width: 26; height: 26
                        kind: panels.favoriteIcon(favorite)
                        lineColor: favoriteActive ? "#ffffff" : visual.muted
                        strokeWidth: 1.8
                    }
                }
                Text {
                    objectName: "v2FavoriteName" + index
                    x: 64; y: 10; width: 132; clip: true; elide: Text.ElideRight
                    text: favorite && favorite.name ? favorite.name : panels.favoriteSelectionName(index)
                    color: visual.text; font.pixelSize: 12; font.bold: true
                }
                Text {
                    x: 64; y: 37; width: 132; clip: true; elide: Text.ElideRight
                    text: favorite && favorite.status ? favorite.status : (favoriteId ? "Wird aufgelöst" : "Nicht belegt")
                    color: favoriteActive ? visual.blue : visual.muted; font.pixelSize: 8
                }
                MouseArea {
                    x: 0; y: 0; width: 204; height: parent.height
                    enabled: parent.actionable
                    onClicked: panels.activate(parent.favorite)
                }
                Rectangle {
                    objectName: "v2FavoritePrevious" + index
                    x: 208; y: 12; width: 42; height: 44; radius: 11
                    color: favoritePreviousArea.pressed ? visual.pressed : visual.disabled
                    border.color: visual.border
                    Text { anchors.centerIn: parent; text: "−"; color: visual.text; font.pixelSize: 18 }
                    MouseArea {
                        id: favoritePreviousArea; anchors.fill: parent
                        enabled: panels.favoriteOptions && panels.favoriteOptions.length > 0
                        onClicked: if (panels.host) panels.host.changeFavorite(index, -1)
                    }
                }
                Rectangle {
                    objectName: "v2FavoriteNext" + index
                    x: 258; y: 12; width: 42; height: 44; radius: 11
                    color: favoriteNextArea.pressed ? visual.pressed : visual.disabled
                    border.color: visual.border
                    Text { anchors.centerIn: parent; text: "+"; color: visual.text; font.pixelSize: 18 }
                    MouseArea {
                        id: favoriteNextArea; anchors.fill: parent
                        enabled: panels.favoriteOptions && panels.favoriteOptions.length > 0
                        onClicked: if (panels.host) panels.host.changeFavorite(index, 1)
                    }
                }
            }
        }

        Text {
            objectName: "v2FavoritesEditorLabel"
            x: 14; y: 407; width: 132; height: 32; clip: true; elide: Text.ElideRight
            text: "Favoriten auswählen"
            color: visual.muted; font.pixelSize: 9; font.bold: true; verticalAlignment: Text.AlignVCenter
        }
        Rectangle {
            id: favoriteSaveButton
            objectName: "v2FavoriteSaveButton"
            x: 158; y: 401; width: 168; height: 44; radius: 11
            color: favoriteSaveArea.pressed ? visual.pressed : visual.selectedBlue
            border.color: visual.blue
            opacity: panels.favoriteIds && panels.favoriteIds.length > 0 ? 1 : .45
            Text { anchors.centerIn: parent; text: "AUSWAHL SPEICHERN"; color: visual.blue; font.pixelSize: 8; font.bold: true }
            MouseArea {
                id: favoriteSaveArea; anchors.fill: parent
                enabled: panels.favoriteIds && panels.favoriteIds.length > 0
                onClicked: if (panels.host) panels.host.saveFavorite()
            }
        }
        Text {
            x: 14; y: 451; width: 312; clip: true; elide: Text.ElideRight
            text: "Nicht verfügbare Favoriten bleiben schreibgeschützt."
            color: visual.muted; font.pixelSize: 7
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

        Text { x: 372; y: 14; width: 168; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: panels.weatherLocation(); color: visual.text; font.pixelSize: 18; font.bold: true }
        Text { x: 372; y: 42; width: 168; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: panels.weatherUpdatedText(); color: visual.muted; font.pixelSize: 9; font.bold: true }
        Rectangle { x: 14; y: 66; width: 532; height: 1; color: visual.border }

        Item {
            visible: panels.weatherAvailable
            x: 14; y: 78; width: 154; height: 153
            Rectangle { anchors.fill: parent; radius: 14; color: visual.inner; border.color: visual.border }
            V2Icon { x: 13; y: 12; width: 57; height: 57; kind: panels.weatherIcon(panels.currentWeather); lineColor: visual.blue; strokeWidth: 2.2 }
            Text { x: 77; y: 12; width: 68; text: panels.temperatureText(panels.currentWeather); color: visual.text; font.pixelSize: 30; font.bold: true }
            Text { x: 13; y: 78; width: 128; elide: Text.ElideRight; text: panels.weatherDescription(panels.currentWeather); color: visual.text; font.pixelSize: 10; font.bold: true }
            Text {
                x: 13; y: 101; width: 128; height: 13; elide: Text.ElideRight
                text: {
                    var pieces = []
                    var rain = panels.rainProbability(panels.currentWeather)
                    var wind = panels.numberFrom(panels.currentWeather, "windKmh", "windSpeedKmh")
                    if (wind === null) wind = panels.numberFrom(panels.currentWeather, "windSpeed", "wind")
                    if (rain !== null) pieces.push("Regen " + rain.toFixed(0) + " %")
                    if (wind !== null) pieces.push("Wind " + wind.toFixed(0) + " km/h")
                    return pieces.join(" · ")
                }
                color: visual.muted; font.pixelSize: 7
            }
            Text {
                x: 13; y: 117; width: 128; elide: Text.ElideRight
                text: "Sonne ↑ " + panels.sunTime("riseUtc") + "  ↓ " + panels.sunTime("setUtc")
                color: visual.muted; font.pixelSize: 7
            }
            Text {
                objectName: "v2TideSummary"
                visible: panels.tidesAvailable
                x: 13; y: 131; width: 128; height: 21; clip: true; elide: Text.ElideRight
                text: panels.tideSummary()
                color: panels.tides && panels.tides.stale === true ? visual.orange : visual.blue
                font.pixelSize: 6; font.bold: true; lineHeight: 1.2
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
                x: 180; y: 8; spacing: 6
                Rectangle { width: 9; height: 3; radius: 2; color: visual.orange; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Temperatur °C"; color: visual.muted; font.pixelSize: 7 }
                Rectangle { width: 9; height: 7; radius: 1; color: visual.blue; opacity: .55; anchors.verticalCenter: parent.verticalCenter }
                Text { text: panels.chartRainLabel(); color: visual.muted; font.pixelSize: 7 }
                Rectangle { visible: panels.tideCurveAvailable; width: visible ? 9 : 0; height: 3; radius: 2; color: "#21d4d8"; anchors.verticalCenter: parent.verticalCenter }
                Text { visible: panels.tideCurveAvailable; text: "Tide"; color: visual.muted; font.pixelSize: 7 }
            }
            Canvas {
                id: weatherChart
                objectName: "v2Weather24HourChart"
                x: 9; y: 27; width: 350; height: 116
                property var hourlyData: panels.hourlyForecast
                property var tideData: panels.tideCurve
                property bool dayPalette: panels.dayMode
                onHourlyDataChanged: requestPaint()
                onTideDataChanged: requestPaint()
                onDayPaletteChanged: requestPaint()
                onPaint: {
                    var context = getContext("2d")
                    context.clearRect(0, 0, width, height)
                    var count = Math.min(24, hourlyData && hourlyData.length ? hourlyData.length : 0)
                    if (!count) return
                    // Leave enough room for signed two-digit "-12 °C" labels
                    // and keep both Y scales fully inside the 800x480 canvas.
                    var left = 43, right = width - (panels.tideCurveAvailable ? 39 : 7), top = 9, bottom = height - 18
                    var chartStart = new Date(hourlyData[0].t || hourlyData[0].timestamp || hourlyData[0].time || hourlyData[0].validAt).getTime()
                    if (panels.tideCurveAvailable) {
                        var tideStart = new Date(tideData[0].t).getTime()
                        if (!isNaN(tideStart)) chartStart = tideStart
                    }
                    if (isNaN(chartStart)) return
                    var chartEnd = chartStart + 24 * 60 * 60 * 1000
                    var chartDuration = chartEnd - chartStart
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
                    var hourWidth = (right - left) / 24
                    context.fillStyle = panels.dayMode ? "#4eafe4" : "#42bcff"
                    context.globalAlpha = .38
                    for (var bar = 0; bar < count; ++bar) {
                        var rainValue = panels.chartRainValue(hourlyData[bar])
                        if (rainValue === null || rainValue <= 0) continue
                        var barHeight = Math.max(2, Math.min(bottom - top, (rainValue / rainMaximum) * (bottom - top)))
                        var barTime = new Date(hourlyData[bar].t || hourlyData[bar].timestamp || hourlyData[bar].time || hourlyData[bar].validAt).getTime()
                        if (isNaN(barTime)) barTime = chartStart + bar * 60 * 60 * 1000
                        var barX = left + Math.max(0, Math.min(1, (barTime - chartStart) / chartDuration)) * (right - left)
                        context.fillRect(barX - Math.max(2, hourWidth * .25), bottom - barHeight, Math.max(4, hourWidth * .5), barHeight)
                    }
                    context.globalAlpha = 1
                    if (hasTemperature) {
                        context.beginPath(); context.strokeStyle = panels.dayMode ? "#dd762e" : "#ff9c4a"; context.lineWidth = 2.2
                        var started = false
                        for (var point = 0; point < count; ++point) {
                            var pointTemperature = panels.numberFrom(hourlyData[point], "tempC", "temperature")
                            if (pointTemperature === null) pointTemperature = panels.numberFrom(hourlyData[point], "temperatureC", "temp")
                            if (pointTemperature === null) continue
                            var pointTime = new Date(hourlyData[point].t || hourlyData[point].timestamp || hourlyData[point].time || hourlyData[point].validAt).getTime()
                            if (isNaN(pointTime)) pointTime = chartStart + point * 60 * 60 * 1000
                            var px = left + Math.max(0, Math.min(1, (pointTime - chartStart) / chartDuration)) * (right - left)
                            var py = bottom - (pointTemperature - minimum) / (maximum - minimum) * (bottom - top)
                            if (!started) { context.moveTo(px, py); started = true } else context.lineTo(px, py)
                        }
                        context.stroke()
                    }
                    if (panels.tideCurveAvailable && tideData.length >= 2) {
                        var tideMinimum = 1000, tideMaximum = -1000
                        var visibleTides = []
                        for (var tideRange = 0; tideRange < tideData.length; ++tideRange) {
                            var rangeTime = new Date(tideData[tideRange].t).getTime()
                            if (rangeTime < chartStart || rangeTime > chartEnd) continue
                            visibleTides.push(tideData[tideRange])
                            tideMinimum = Math.min(tideMinimum, tideData[tideRange].heightM)
                            tideMaximum = Math.max(tideMaximum, tideData[tideRange].heightM)
                        }
                        if (visibleTides.length >= 2 && tideMaximum - tideMinimum < .2) {
                            tideMaximum += .1
                            tideMinimum -= .1
                        } else if (visibleTides.length >= 2) {
                            var tidePadding = (tideMaximum - tideMinimum) * .08
                            tideMaximum += tidePadding
                            tideMinimum -= tidePadding
                        }
                        context.beginPath()
                        context.strokeStyle = "#21d4d8"
                        context.lineWidth = 1.8
                        var tideStarted = false
                        var tideSpan = Math.max(.1, tideMaximum - tideMinimum)
                        for (var tidePoint = 0; tidePoint < visibleTides.length; ++tidePoint) {
                            var tideTime = new Date(visibleTides[tidePoint].t).getTime()
                            var tideX = left + (tideTime - chartStart) / chartDuration * (right - left)
                            var tideY = bottom - (visibleTides[tidePoint].heightM - tideMinimum) / tideSpan * (bottom - top)
                            if (!tideStarted) { context.moveTo(tideX, tideY); tideStarted = true } else context.lineTo(tideX, tideY)
                        }
                        if (tideStarted) context.stroke()
                        if (visibleTides.length >= 2) {
                            context.fillStyle = "#21d4d8"
                            context.font = "7px sans-serif"
                            context.textAlign = "left"
                            context.fillText(tideMaximum.toFixed(1).replace(".", ",") + " m", right + 3, top + 7)
                            context.fillText(tideMinimum.toFixed(1).replace(".", ",") + " m", right + 3, bottom + 2)
                        }
                    }
                    if (hasTemperature) {
                        context.fillStyle = panels.dayMode ? "#b85d20" : "#ff9c4a"
                        context.font = "7px sans-serif"
                        context.textAlign = "left"
                        context.fillText(Math.ceil(maximum) + " °C", 3, top + 7)
                        context.fillText(Math.floor(minimum) + " °C", 3, bottom + 2)
                    }
                    context.fillStyle = panels.dayMode ? "#61727c" : "#8fa2af"; context.font = "7px sans-serif"
                    var marks = [0, 6, 12, 18, 24]
                    for (var mark = 0; mark < marks.length; ++mark) {
                        var label = Qt.formatTime(new Date(chartStart + marks[mark] * 60 * 60 * 1000), "hh:mm")
                        var labelX = left + marks[mark] / 24 * (right - left)
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
            elide: Text.ElideRight
            text: "Quelle: " + (panels.weather && panels.weather.attribution ? String(panels.weather.attribution) : "Deutscher Wetterdienst")
                    + (panels.tidesAvailable ? " · Tide: " + String(panels.tides.attribution) : "") + " · Daten vom Cerbo"
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

    Rectangle {
        id: favoritesHeaderButton
        objectName: "v2FavoritesHeaderButton"
        property bool active: panels.activePanel === -1
        x: 512; y: 6; width: 42; height: 42; radius: 12
        z: 60
        color: favoritesHeaderArea.pressed ? visual.pressed : (active ? visual.selectedBlue : visual.inner)
        border.color: active ? visual.blue : visual.border
        border.width: active ? 2 : 1
        V2Icon {
            anchors.centerIn: parent; width: 22; height: 22; kind: "favorite"
            lineColor: favoritesHeaderButton.active ? visual.blue : visual.muted; strokeWidth: 1.8
        }
        MouseArea { id: favoritesHeaderArea; anchors.fill: parent; onClicked: panels.openFavorites() }
    }

    Rectangle {
        id: weatherHeaderButton
        objectName: "v2WeatherHeaderButton"
        property bool active: panels.activePanel === 1
        x: 560; y: 6; width: 42; height: 42; radius: 12
        z: 60
        color: weatherHeaderArea.pressed ? visual.pressed : (active ? visual.selectedBlue : visual.inner)
        border.color: active ? visual.blue : visual.border
        border.width: active ? 2 : 1
        V2Icon {
            anchors.centerIn: parent; width: 23; height: 23; kind: "weatherCloud"
            lineColor: weatherHeaderButton.active ? visual.blue : visual.muted; strokeWidth: 1.8
        }
        MouseArea { id: weatherHeaderArea; anchors.fill: parent; onClicked: panels.openWeather() }
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
