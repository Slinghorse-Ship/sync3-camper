import QtQuick 2.6

Item {
    id: view
    property bool dayMode: false
    property var climate: ({})
    property var heater: ({})
    property var ventilation: climate.ventilation || ({})
    property var automation: climate.automation || ({})
    property var temperatureSensors: climate.temperatureSensors || ({})
    property int controlTab: 0
    signal backRequested()
    signal ventilationPatchRequested(var patch)
    signal climateAutomationPatchRequested(var patch)
    signal temperatureSensorPatchRequested(var patch)

    property color panelColor: visual.panel
    property color innerColor: visual.inner
    property color textColor: visual.text
    property color mutedColor: visual.muted
    property color lineColor: visual.border
    property color orangeColor: visual.orange

    CamperStyle { id: visual; dayMode: view.dayMode }

    function valid(value) { return value !== null && value !== undefined && value !== "" && isFinite(Number(value)) }
    function fmt(value) { return valid(value) ? Number(value).toFixed(1) + " °C" : "–" }
    function ventilationPatch(enabled, onTemperature, hysteresis, manualOn) {
        ventilationPatchRequested({ ventilation: {
            enabled: enabled,
            manualOn: manualOn === undefined ? ventilation.manualOn === true : manualOn === true,
            onTemperature: Math.max(30, Math.min(95, Number(onTemperature))),
            hysteresis: Math.max(2, Math.min(20, Number(hysteresis)))
        } })
    }
    function climatePatch(enabled, mode, target, hysteresis, fanSpeed) {
        climateAutomationPatchRequested({ climateAutomation: {
            enabled: enabled,
            mode: mode,
            targetTemperature: Math.max(10, Math.min(30, Number(target))),
            hysteresis: Math.max(0.5, Math.min(5, Number(hysteresis))),
            fanSpeed: Math.max(10, Math.min(100, Math.round(Number(fanSpeed) / 10) * 10))
        } })
    }
    function readings() {
        var result = []
        var comfort = temperatureSensors.comfort || ({})
        var floor = temperatureSensors.floor || ({})
        var ceiling = temperatureSensors.ceiling || ({})
        if (valid(comfort.temp) || valid(climate.roomTemperature)) result.push({ name: "KOMFORTMITTEL", value: valid(comfort.temp) ? comfort.temp : climate.roomTemperature, source: comfort.label || heater.effectiveSensor || "Regelsensor", kind: "Regeltemperatur" })
        if (valid(floor.temp)) result.push({ name: "BODENHÖHE", value: floor.temp, source: floor.label || "Ruuvi Boden", kind: valid(floor.humidity) ? Number(floor.humidity).toFixed(0) + " % Luftfeuchte" : "Frostschutzsensor" })
        if (valid(ceiling.temp)) result.push({ name: "DECKENHÖHE", value: ceiling.temp, source: ceiling.label || "Ruuvi Decke", kind: valid(ceiling.humidity) ? Number(ceiling.humidity).toFixed(0) + " % Luftfeuchte" : "Lüftungssensor" })
        if (valid(heater.internalTemperature)) result.push({ name: "AUTOTERM INTERN", value: heater.internalTemperature, source: "Heizgerät", kind: "Interner Sensor" })
        if (valid(heater.externalTemperature)) result.push({ name: "EXTERNER SENSOR", value: heater.externalTemperature, source: "Autotherm-Eingang", kind: "Externer Messwert" })
        return result.slice(0, 6)
    }
    function sensorCandidates() { return temperatureSensors.candidates || [] }
    function configuredService(role) {
        var configured = temperatureSensors.configuredAssignment || temperatureSensors.assignment || ({})
        return String(configured[role + "Service"] || "")
    }
    function serviceLabel(service) {
        if (!service) return "NICHT ZUGEORDNET"
        var candidates = sensorCandidates()
        for (var i = 0; i < candidates.length; i++) if (String(candidates[i].service) === String(service)) return String(candidates[i].label || candidates[i].customName || candidates[i].productName || service)
        return String(service).replace("com.victronenergy.temperature.", "Sensor ").replace("com.victronenergy.temperature/", "Sensor ")
    }
    function nextService(role) {
        var candidates = sensorCandidates()
        var current = configuredService(role)
        var other = configuredService(role === "floor" ? "ceiling" : "floor")
        var services = [""]
        for (var i = 0; i < candidates.length; i++) if (String(candidates[i].service) !== other) services.push(String(candidates[i].service))
        var index = services.indexOf(current)
        return services[(index + 1 + services.length) % services.length]
    }
    function assignSensor(role) {
        var patch = { temperatureSensors: {
            floorService: configuredService("floor"), ceilingService: configuredService("ceiling")
        } }
        patch.temperatureSensors[role + "Service"] = nextService(role)
        temperatureSensorPatchRequested(patch)
    }

    Rectangle {
        x: 10; y: 8; width: 780; height: 56; radius: 13; color: view.panelColor; border.color: view.lineColor
        TouchButton { x: 8; y: 9; width: 76; height: 38; label: "ZURÜCK"; onClicked: view.backRequested() }
        LineIcon { x: 99; y: 10; width: 35; height: 35; kind: "climate"; lineColor: view.orangeColor; strokeWidth: 2 }
        Text { x: 145; y: 8; text: "TEMPERATUR-MESSWERTE"; color: view.textColor; font.pixelSize: 15; font.bold: true }
        Text { x: 145; y: 31; text: view.readings().length + " aktuell verfügbare Werte"; color: view.mutedColor; font.pixelSize: 9 }
        Text { x: 618; y: 10; width: 148; horizontalAlignment: Text.AlignRight; text: view.fmt(view.climate.roomTemperature); color: view.orangeColor; font.pixelSize: 21; font.bold: true }
        Text { x: 618; y: 34; width: 148; horizontalAlignment: Text.AlignRight; text: "INNENRAUM"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
    }

    Rectangle {
        x: 10; y: 72; width: 496; height: 342; radius: 13; color: view.innerColor; border.color: view.lineColor
        Repeater {
            model: view.readings()
            delegate: Rectangle {
                property var reading: modelData
                x: 12 + (index % 2) * 238; y: 11 + Math.floor(index / 2) * 106
                width: 226; height: 96; radius: 13
                color: view.panelColor; border.color: index === 0 ? view.orangeColor : view.lineColor
                LineIcon { x: 13; y: 12; width: 34; height: 34; kind: "climate"; lineColor: index === 0 ? view.orangeColor : view.mutedColor; strokeWidth: 2 }
                Text { x: 55; y: 11; width: 156; elide: Text.ElideRight; text: reading.name; color: view.textColor; font.pixelSize: 10; font.bold: true }
                Text { x: 55; y: 31; width: 156; elide: Text.ElideRight; text: reading.kind; color: view.mutedColor; font.pixelSize: 8 }
                Text { x: 13; y: 49; text: view.fmt(reading.value); color: index === 0 ? view.orangeColor : view.textColor; font.pixelSize: 21; font.bold: true }
                Text { x: 108; y: 65; width: 104; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: reading.source; color: view.mutedColor; font.pixelSize: 7; font.bold: true }
            }
        }
        Text { anchors.centerIn: parent; visible: view.readings().length === 0; text: "Keine Temperaturwerte verfügbar"; color: view.mutedColor; font.pixelSize: 15 }
    }

    Rectangle {
        x: 516; y: 72; width: 274; height: 342; radius: 13; color: view.panelColor
        border.color: (view.controlTab === 0 ? view.automation.enabled : (view.controlTab === 1 ? (view.ventilation.enabled || view.ventilation.manualOn) : false)) ? "#42d6a4" : view.lineColor
        TouchButton { x: 10; y: 10; width: 80; height: 34; label: "INNEN"; fontSize: 8; active: view.controlTab === 0; onClicked: view.controlTab = 0 }
        TouchButton { x: 97; y: 10; width: 80; height: 34; label: "CERBO CPU"; fontSize: 8; active: view.controlTab === 1; onClicked: view.controlTab = 1 }
        TouchButton { x: 184; y: 10; width: 80; height: 34; label: "SENSOREN"; fontSize: 8; active: view.controlTab === 2; onClicked: view.controlTab = 2 }

        Item {
            x: 0; y: 0; width: 274; height: 342; visible: view.controlTab === 0
            Text { x: 15; y: 53; text: "KLIMAAUTOMATIK"; color: view.textColor; font.pixelSize: 12; font.bold: true }
            Text { x: 15; y: 73; width: 244; elide: Text.ElideRight; text: view.automation.reason || "Klimaautomatik aus"; color: view.automation.sensorOnline ? view.mutedColor : "#f07070"; font.pixelSize: 8 }
            TouchButton { x: 14; y: 92; width: 76; height: 34; label: "AUTO"; fontSize: 9; active: view.automation.mode === "auto"; onClicked: view.climatePatch(view.automation.enabled === true, "auto", Number(view.automation.targetTemperature || 22), Number(view.automation.hysteresis || 1), Number(view.automation.fanSpeed || 50)) }
            TouchButton { x: 99; y: 92; width: 76; height: 34; label: "HEIZEN"; fontSize: 9; active: view.automation.mode === "heat"; accentColor: view.orangeColor; onClicked: view.climatePatch(view.automation.enabled === true, "heat", Number(view.automation.targetTemperature || 22), Number(view.automation.hysteresis || 1), Number(view.automation.fanSpeed || 50)) }
            TouchButton { x: 184; y: 92; width: 76; height: 34; label: "LÜFTEN"; fontSize: 9; active: view.automation.mode === "cool"; accentColor: "#45c9fa"; onClicked: view.climatePatch(view.automation.enabled === true, "cool", Number(view.automation.targetTemperature || 22), Number(view.automation.hysteresis || 1), Number(view.automation.fanSpeed || 50)) }
            Rectangle { x: 14; y: 135; width: 246; height: 57; radius: 11; color: view.innerColor; border.color: view.lineColor
                Text { x: 12; y: 8; text: "SOLLWERT"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
                TouchButton { x: 113; y: 8; width: 38; height: 41; label: "−"; onClicked: view.climatePatch(view.automation.enabled === true, view.automation.mode || "auto", Number(view.automation.targetTemperature || 22) - 1, Number(view.automation.hysteresis || 1), Number(view.automation.fanSpeed || 50)) }
                Text { x: 151; y: 19; width: 51; horizontalAlignment: Text.AlignHCenter; text: Number(view.automation.targetTemperature || 22).toFixed(0) + "°"; color: view.orangeColor; font.pixelSize: 17; font.bold: true }
                TouchButton { x: 202; y: 8; width: 38; height: 41; label: "+"; onClicked: view.climatePatch(view.automation.enabled === true, view.automation.mode || "auto", Number(view.automation.targetTemperature || 22) + 1, Number(view.automation.hysteresis || 1), Number(view.automation.fanSpeed || 50)) }
            }
            Rectangle { x: 14; y: 201; width: 246; height: 50; radius: 11; color: view.innerColor; border.color: view.lineColor
                Text { x: 12; y: 8; text: "MAXXFAN BEI KÜHLUNG"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
                TouchButton { x: 113; y: 6; width: 38; height: 38; label: "−"; onClicked: view.climatePatch(view.automation.enabled === true, view.automation.mode || "auto", Number(view.automation.targetTemperature || 22), Number(view.automation.hysteresis || 1), Number(view.automation.fanSpeed || 50) - 10) }
                Text { x: 151; y: 17; width: 51; horizontalAlignment: Text.AlignHCenter; text: Number(view.automation.fanSpeed || 50).toFixed(0) + "%"; color: "#45c9fa"; font.pixelSize: 14; font.bold: true }
                TouchButton { x: 202; y: 6; width: 38; height: 38; label: "+"; onClicked: view.climatePatch(view.automation.enabled === true, view.automation.mode || "auto", Number(view.automation.targetTemperature || 22), Number(view.automation.hysteresis || 1), Number(view.automation.fanSpeed || 50) + 10) }
            }
            Text { x: 16; y: 261; width: 242; text: view.automation.demand === "heat" ? "AUTOTERM AKTIV" : (view.automation.demand === "cool" ? "MAXXFAN AKTIV" : "BEREIT"); color: view.automation.demand === "heat" ? view.orangeColor : (view.automation.demand === "cool" ? "#45c9fa" : view.mutedColor); font.pixelSize: 10; font.bold: true }
            TouchButton { x: 14; y: 286; width: 246; height: 43; label: view.automation.enabled ? "KLIMAAUTOMATIK AUS" : "KLIMAAUTOMATIK EIN"; fontSize: 10; active: view.automation.enabled === true; accentColor: "#42d6a4"; onClicked: view.climatePatch(!view.automation.enabled, view.automation.mode || "auto", Number(view.automation.targetTemperature || 22), Number(view.automation.hysteresis || 1), Number(view.automation.fanSpeed || 50)) }
        }

        Item {
            x: 0; y: 0; width: 274; height: 342; visible: view.controlTab === 1
            Text { x: 15; y: 53; text: "CERBO-CPU-LÜFTUNG"; color: view.textColor; font.pixelSize: 12; font.bold: true }
            Text { x: 174; y: 50; width: 84; horizontalAlignment: Text.AlignRight; text: view.fmt(view.ventilation.cpuTemperature); color: view.orangeColor; font.pixelSize: 16; font.bold: true }
            Text { x: 15; y: 75; width: 244; elide: Text.ElideRight; text: view.ventilation.reason || "CPU-Lüftung aus"; color: view.ventilation.sensorOnline ? view.mutedColor : "#f07070"; font.pixelSize: 8 }
            Rectangle { x: 14; y: 96; width: 246; height: 57; radius: 11; color: view.innerColor; border.color: view.lineColor
                Text { x: 12; y: 8; text: "EINSCHALTEN AB"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
                TouchButton { x: 113; y: 8; width: 38; height: 41; label: "−"; onClicked: view.ventilationPatch(view.ventilation.enabled === true, Number(view.ventilation.onTemperature || 65) - 1, Number(view.ventilation.hysteresis || 5)) }
                Text { x: 151; y: 19; width: 51; horizontalAlignment: Text.AlignHCenter; text: Number(view.ventilation.onTemperature || 65).toFixed(0) + "°"; color: view.orangeColor; font.pixelSize: 17; font.bold: true }
                TouchButton { x: 202; y: 8; width: 38; height: 41; label: "+"; onClicked: view.ventilationPatch(view.ventilation.enabled === true, Number(view.ventilation.onTemperature || 65) + 1, Number(view.ventilation.hysteresis || 5)) }
            }
            Rectangle { x: 14; y: 162; width: 246; height: 50; radius: 11; color: view.innerColor; border.color: view.lineColor
                Text { x: 12; y: 8; text: "AUS BEI " + view.fmt(view.ventilation.offTemperature); color: view.textColor; font.pixelSize: 9; font.bold: true }
                TouchButton { x: 157; y: 6; width: 38; height: 38; label: "−"; onClicked: view.ventilationPatch(view.ventilation.enabled === true, Number(view.ventilation.onTemperature || 65), Number(view.ventilation.hysteresis || 5) - 1) }
                TouchButton { x: 202; y: 6; width: 38; height: 38; label: "+"; onClicked: view.ventilationPatch(view.ventilation.enabled === true, Number(view.ventilation.onTemperature || 65), Number(view.ventilation.hysteresis || 5) + 1) }
            }
            Rectangle { x: 14; y: 221; width: 246; height: 54; radius: 11; color: view.innerColor; border.color: view.lineColor
                Text { x: 12; y: 8; text: "RELAIS 1 · ABLUFT"; color: view.textColor; font.pixelSize: 9; font.bold: true }
                Text { x: 12; y: 30; text: view.ventilation.exhaustOn ? "EIN" : "AUS"; color: view.ventilation.exhaustOn ? "#42d6a4" : view.mutedColor; font.pixelSize: 9; font.bold: true }
                Text { x: 126; y: 8; text: "RELAIS 2 · ZULUFT"; color: view.textColor; font.pixelSize: 9; font.bold: true }
                Text { x: 126; y: 30; text: view.ventilation.supplyOn ? "EIN" : "AUS"; color: view.ventilation.supplyOn ? "#42d6a4" : view.mutedColor; font.pixelSize: 9; font.bold: true }
            }
            TouchButton { x: 14; y: 286; width: 118; height: 43; label: view.ventilation.enabled ? "AUTO AUS" : "AUTO EIN"; fontSize: 9; active: view.ventilation.enabled === true; accentColor: "#42d6a4"; onClicked: view.ventilationPatch(!view.ventilation.enabled, Number(view.ventilation.onTemperature || 65), Number(view.ventilation.hysteresis || 5)) }
            TouchButton { x: 142; y: 286; width: 118; height: 43; label: view.ventilation.manualOn ? "MANUELL AUS" : "MANUELL EIN"; fontSize: 9; active: view.ventilation.manualOn === true; accentColor: "#45c9fa"; onClicked: view.ventilationPatch(view.ventilation.enabled === true, Number(view.ventilation.onTemperature || 65), Number(view.ventilation.hysteresis || 5), !view.ventilation.manualOn) }
        }

        Item {
            x: 0; y: 0; width: 274; height: 342; visible: view.controlTab === 2
            Text { x: 15; y: 53; text: "RUUVI-ZUORDNUNG"; color: view.textColor; font.pixelSize: 12; font.bold: true }
            Text { x: 15; y: 73; width: 244; text: view.sensorCandidates().length + " Victron-Temperaturdienste gefunden"; color: view.sensorCandidates().length ? view.mutedColor : "#f07070"; font.pixelSize: 8 }
            Rectangle { x: 14; y: 94; width: 246; height: 70; radius: 11; color: view.innerColor; border.color: view.lineColor
                Text { x: 12; y: 9; text: "DECKENHÖHE · LÜFTUNG"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
                Text { x: 12; y: 30; width: 164; elide: Text.ElideRight; text: view.serviceLabel(view.configuredService("ceiling")); color: view.textColor; font.pixelSize: 9; font.bold: true }
                TouchButton { x: 181; y: 18; width: 53; height: 40; label: "WEITER"; fontSize: 7; onClicked: view.assignSensor("ceiling") }
            }
            Rectangle { x: 14; y: 173; width: 246; height: 70; radius: 11; color: view.innerColor; border.color: view.lineColor
                Text { x: 12; y: 9; text: "BODENHÖHE · FROSTSCHUTZ"; color: view.mutedColor; font.pixelSize: 8; font.bold: true }
                Text { x: 12; y: 30; width: 164; elide: Text.ElideRight; text: view.serviceLabel(view.configuredService("floor")); color: view.textColor; font.pixelSize: 9; font.bold: true }
                TouchButton { x: 181; y: 18; width: 53; height: 40; label: "WEITER"; fontSize: 7; onClicked: view.assignSensor("floor") }
            }
        }
    }
}
