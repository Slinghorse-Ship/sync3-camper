"""Interactive desktop preview for the SYNC 3 CamperControl QML UI.

The preview runs a temporary copy of the production QML and swaps only the
API component for a local in-memory demo adapter. It never sends commands to
Node-RED or camper hardware.
"""

import os
import shutil
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_APP = ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper"
DAY_MODE = "--day" in sys.argv
PAGE = next((int(arg.split("=", 1)[1]) for arg in sys.argv if arg.startswith("--page=")), 0)
V2_PAGE = next((int(arg.split("=", 1)[1]) for arg in sys.argv if arg.startswith("--v2-page=")), 0)
ENERGY_PANE = next((int(arg.split("=", 1)[1]) for arg in sys.argv if arg.startswith("--energy-pane=")), 0)
PASSENGER_VIEW = "--passenger-view" in sys.argv
SETTINGS_VIEW = "--settings" in sys.argv
WIFI_SETTINGS_VIEW = "--wifi-settings" in sys.argv
WARNING_VIEW = "--warning" in sys.argv
CPU_VIEW = "--cpu" in sys.argv
SENSORS_VIEW = "--sensors" in sys.argv
DIMMER_VIEW = "--dimmer" in sys.argv
WRAPPER_SMOKE_TEST = "--wrapper-smoke-test" in sys.argv
EDGE_PANEL = next((arg.split("=", 1)[1].lower() for arg in sys.argv if arg.startswith("--edge-panel=")), "")
SCREENSHOT = next((arg.split("=", 1)[1] for arg in sys.argv if arg.startswith("--screenshot=")), "")

DEMO_API = r'''import QtQuick 2.6

Item {
    id: root
    property string baseUrl: "preview://offline"
    property bool connected: true
    property bool polling: false
    property int pollIntervalMs: 500
    property string statusText: "Lokale Vorschau"
    property string errorText: ""
    property string networkType: "preview"
    property string clientAddress: "lokal"
    property string activeBaseUrl: "preview://offline"
    property var lastCommandResult: ({})
    property var lastCommandRequest: ({})
    property var stateData: ({
        system: { name: "FORD TRANSIT CAMPER", online: true, service: {
            external_wifi_available: 1, external_wifi_enabled: 1, external_wifi_state: "verbunden",
            external_wifi_ssid: "Camping-WLAN", external_wifi_interface: "wlan1", external_wifi_scan_active: 0,
            external_wifi_networks: [
                { ssid: "Camping-WLAN", service: "/net/connman/service/wifi_demo_1_managed_psk", signal: 82, secure: true },
                { ssid: "Starlink Transit", service: "/net/connman/service/wifi_demo_2_managed_psk", signal: 71, secure: true },
                { ssid: "FritzBox Gast", service: "/net/connman/service/wifi_demo_3_managed_psk", signal: 49, secure: true }
            ]
        } },
        ui: {
            quickAccessOptions: [
                { id: "switch:water_pump", group: "12 V", name: "Wasserpumpe" },
                { id: "switch:starlink", group: "12 V", name: "Starlink" },
                { id: "scene:arrival", group: "Szenen", name: "Ankommen" },
                { id: "device:orion", group: "Geräte", name: "Orion XS" },
                { id: "light:inside_main", group: "Licht", name: "Innenlicht" },
                { id: "switch:dc_outlets_left", group: "12 V", name: "Steckdosen links" },
                { id: "switch:maxxfan", group: "Geräte", name: "MaxxFan" }
            ],
            favoriteIds: ["light:inside_main", "switch:dc_outlets_left", "switch:maxxfan", "device:orion"],
            favorites: [
                { id: "light:inside_main", name: "Innenlicht", icon: "bulb", active: true, available: true, status: "EIN · 72 %", command: { target: "starpower", action: "set", value: 0, channel: 9 } },
                { id: "switch:dc_outlets_left", name: "Steckdosen links", icon: "outlet", active: true, available: true, status: "EIN", command: { target: "starpower", action: "set", value: 0, channel: 1 } },
                { id: "switch:maxxfan", name: "MaxxFan", icon: "fan", active: true, available: true, status: "30 %", command: { target: "maxxfan", action: "set", value: false } },
                { id: "device:orion", name: "Orion XS", icon: "battery", active: false, available: false, status: "NICHT VERFÜGBAR", command: { target: "orion", action: "set", value: true } }
            ],
            quickAccess: [
                { id: "switch:water_pump", name: "Wasserpumpe", icon: "pump", active: true, available: true, status: "EIN", command: { target: "waterPump", action: "set", value: false } },
                { id: "switch:starlink", name: "Starlink", icon: "satellite", active: false, available: true, status: "AUS", command: { target: "starpower", action: "set", value: 1, channel: 5 } },
                { id: "scene:arrival", name: "Ankommen", icon: "home", active: false, available: true, status: "STARTEN", command: { target: "scene", action: "run", value: "arrival", sceneId: "arrival" } },
                { id: "device:orion", name: "Orion XS", icon: "battery", active: false, available: false, status: "NICHT VERFÜGBAR", command: { target: "orion", action: "set", value: true } }
            ]
        },
        weather: {
            schema: 1,
            source: "DWD MOSMIX_L",
            attribution: "Deutscher Wetterdienst",
            station: { id: "PREVIEW", name: "Stellplatz am See", distanceKm: 4.2 },
            modelRunUtc: new Date(Date.now() - 7200000).toISOString(),
            fetchedAtUtc: new Date(Date.now() - 240000).toISOString(),
            stale: false,
            timezone: "Europe/Berlin",
            sun: { date: new Date().toISOString().slice(0, 10), riseUtc: new Date(Date.now() - 18000000).toISOString(), setUtc: new Date(Date.now() + 18000000).toISOString(), origin: "calculated" },
            tides: {
                source: "BSH", attribution: "Bundesamt für Seeschifffahrt und Hydrographie",
                station: { id: "PREVIEW-TIDE", name: "Pegel am See", distanceKm: 6.8 },
                updatedUtc: new Date(Date.now() - 300000).toISOString(), stale: false, referenceLevel: "PNP",
                nextHigh: { t: new Date(Date.now() + 2 * 3600000).toISOString(), heightM: 4.2 },
                nextLow: { t: new Date(Date.now() + 8 * 3600000).toISOString(), heightM: 1.1 }
            },
            hourly: [
                { t: new Date(Date.now()).toISOString(), tempC: 18.4, condition: "Leicht bewölkt", icon: "partly-cloudy", precipProbabilityPct: 15, precipMm: 0, windKmh: 11 },
                { t: new Date(Date.now() +  1*3600000).toISOString(), tempC: 18.0, icon: "cloudy", precipProbabilityPct: 20, precipMm: 0, windKmh: 10 },
                { t: new Date(Date.now() +  2*3600000).toISOString(), tempC: 17.1, icon: "cloudy", precipProbabilityPct: 28, precipMm: 0, windKmh: 9 },
                { t: new Date(Date.now() +  3*3600000).toISOString(), tempC: 16.2, icon: "rain", precipProbabilityPct: 65, precipMm: .8, windKmh: 12 },
                { t: new Date(Date.now() +  4*3600000).toISOString(), tempC: 15.5, icon: "rain", precipProbabilityPct: 72, precipMm: 1.4, windKmh: 13 },
                { t: new Date(Date.now() +  5*3600000).toISOString(), tempC: 14.9, icon: "rain", precipProbabilityPct: 60, precipMm: .6, windKmh: 12 },
                { t: new Date(Date.now() +  6*3600000).toISOString(), tempC: 14.3, icon: "cloudy", precipProbabilityPct: 35, precipMm: .1, windKmh: 10 },
                { t: new Date(Date.now() +  7*3600000).toISOString(), tempC: 13.8, icon: "cloudy", precipProbabilityPct: 25, precipMm: 0, windKmh: 9 },
                { t: new Date(Date.now() +  8*3600000).toISOString(), tempC: 13.4, icon: "cloudy", precipProbabilityPct: 20, precipMm: 0, windKmh: 8 },
                { t: new Date(Date.now() +  9*3600000).toISOString(), tempC: 13.1, icon: "cloudy", precipProbabilityPct: 18, precipMm: 0, windKmh: 7 },
                { t: new Date(Date.now() + 10*3600000).toISOString(), tempC: 12.8, icon: "cloudy", precipProbabilityPct: 15, precipMm: 0, windKmh: 6 },
                { t: new Date(Date.now() + 11*3600000).toISOString(), tempC: 12.5, icon: "clear", precipProbabilityPct: 10, precipMm: 0, windKmh: 5 },
                { t: new Date(Date.now() + 12*3600000).toISOString(), tempC: 12.3, icon: "clear", precipProbabilityPct: 8, precipMm: 0, windKmh: 5 },
                { t: new Date(Date.now() + 13*3600000).toISOString(), tempC: 12.1, icon: "clear", precipProbabilityPct: 8, precipMm: 0, windKmh: 4 },
                { t: new Date(Date.now() + 14*3600000).toISOString(), tempC: 12.4, icon: "clear", precipProbabilityPct: 6, precipMm: 0, windKmh: 4 },
                { t: new Date(Date.now() + 15*3600000).toISOString(), tempC: 13.2, icon: "clear", precipProbabilityPct: 5, precipMm: 0, windKmh: 5 },
                { t: new Date(Date.now() + 16*3600000).toISOString(), tempC: 14.5, icon: "partly-cloudy", precipProbabilityPct: 8, precipMm: 0, windKmh: 6 },
                { t: new Date(Date.now() + 17*3600000).toISOString(), tempC: 16.1, icon: "partly-cloudy", precipProbabilityPct: 10, precipMm: 0, windKmh: 7 },
                { t: new Date(Date.now() + 18*3600000).toISOString(), tempC: 17.8, icon: "partly-cloudy", precipProbabilityPct: 12, precipMm: 0, windKmh: 8 },
                { t: new Date(Date.now() + 19*3600000).toISOString(), tempC: 19.2, icon: "partly-cloudy", precipProbabilityPct: 15, precipMm: 0, windKmh: 9 },
                { t: new Date(Date.now() + 20*3600000).toISOString(), tempC: 20.1, icon: "cloudy", precipProbabilityPct: 22, precipMm: 0, windKmh: 10 },
                { t: new Date(Date.now() + 21*3600000).toISOString(), tempC: 20.5, icon: "cloudy", precipProbabilityPct: 30, precipMm: 0, windKmh: 11 },
                { t: new Date(Date.now() + 22*3600000).toISOString(), tempC: 19.8, icon: "rain", precipProbabilityPct: 48, precipMm: .3, windKmh: 12 },
                { t: new Date(Date.now() + 23*3600000).toISOString(), tempC: 18.6, icon: "rain", precipProbabilityPct: 55, precipMm: .5, windKmh: 13 }
            ],
            daily: [
                { date: new Date(Date.now()).toISOString().slice(0, 10), minC: 12, maxC: 21, icon: "partly-cloudy", maxHourlyPrecipProbabilityPct: 72, precipMm: 2.8 },
                { date: new Date(Date.now() + 1*86400000).toISOString().slice(0, 10), minC: 11, maxC: 22, icon: "clear", maxHourlyPrecipProbabilityPct: 12, precipMm: 0 },
                { date: new Date(Date.now() + 2*86400000).toISOString().slice(0, 10), minC: 13, maxC: 24, icon: "clear", maxHourlyPrecipProbabilityPct: 8, precipMm: 0 },
                { date: new Date(Date.now() + 3*86400000).toISOString().slice(0, 10), minC: 14, maxC: 20, icon: "rain", maxHourlyPrecipProbabilityPct: 80, precipMm: 5.4 },
                { date: new Date(Date.now() + 4*86400000).toISOString().slice(0, 10), minC: 10, maxC: 18, icon: "cloudy", maxHourlyPrecipProbabilityPct: 35, precipMm: .2 },
                { date: new Date(Date.now() + 5*86400000).toISOString().slice(0, 10), minC: 9, maxC: 19, icon: "partly-cloudy", maxHourlyPrecipProbabilityPct: 20, precipMm: 0 }
            ]
        },
        energy: {
            totalSolarPower: 312,
            dcSystemPower: 156,
            battery: { name: "SMARTSHUNT", soc: 82, voltage: 13.4, starterVoltage: 12.7, current: -10.3, power: -138, consumedAh: 42.6, timeToGoSeconds: 61200, installedCapacityAh: 300, online: true },
            solar: { name: "VICTRON SOLAR", power: 312, chargers: [
                { instance: 278, name: "SmartSolar MPPT 100/30", serial: "HQ2241ZN2NP", power: 118, pvVoltage: 38.7, yieldTodayKwh: 0.72, state: 5, online: true },
                { instance: 279, name: "SmartSolar MPPT 100/30", serial: "HQ2212HZN77", power: 104, pvVoltage: 37.9, yieldTodayKwh: 0.65, state: 5, online: true },
                { instance: 290, name: "SmartSolar MPPT 150/45", serial: "HQ193529VPL", power: 90, pvVoltage: 71.2, yieldTodayKwh: 0.54, state: 4, online: true }
            ] },
            indevolt: { online: true, onlineCount: 1, totalCount: 1, solarPower: 174, batteryPower: 86,
                gridConnection: { available: true, online: true, on: false, voltage: 235.8, current: 0, power: 0, energyForwardKwh: 0.013, status: "CAMPERNETZ GETRENNT" },
                devices: [{ online: true, serial: "INDEVOLT-DEMO", status: "Bereit", soc: 74, solarPower: 174, batteryPower: 86, mode: "Solar", acOutputPower: 0 }] }
        },
        water: { fresh: { name: "FRISCHWASSER", level: 68, remainingLitres: 81 }, pump: { on: true } },
        climate: {
            roomTemperature: 21.6,
            temperatureSensors: {
                ceiling: { online: true, temp: 23.8, humidity: 54, label: "Ruuvi Decke", service: "com.victronenergy.temperature.41" },
                floor: { online: true, temp: 19.4, humidity: 61, label: "Ruuvi Boden", service: "com.victronenergy.temperature.42" },
                comfort: { online: true, temp: 21.6, label: "Komfortmittel · Boden + Decke" },
                stratification: { delta: 4.4, threshold: 4, warning: true },
                assignment: { ceilingService: "com.victronenergy.temperature.41", floorService: "com.victronenergy.temperature.42" },
                configuredAssignment: { ceilingService: "com.victronenergy.temperature.41", floorService: "com.victronenergy.temperature.42" },
                candidates: [
                    { service: "com.victronenergy.temperature.41", label: "Ruuvi Decke" },
                    { service: "com.victronenergy.temperature.42", label: "Ruuvi Boden" }
                ]
            },
            ventilation: { enabled: false, active: false, supplyOn: false, exhaustOn: false, supplyFeedback: false, exhaustFeedback: false, cpuTemperature: 53.4, onTemperature: 65, offTemperature: 60, hysteresis: 5, sensorOnline: true, sensorName: "Cerbo GX CPU", reason: "CPU-Lüftung aus" },
            automation: { enabled: false, mode: "auto", demand: "idle", targetTemperature: 22, hysteresis: 1, fanSpeed: 50, sensorOnline: true, sensorName: "Komfortmittel", reason: "Klimaautomatik aus", heaterRunning: false, fanRunning: false },
            heater: { name: "AUTOTERM AIR 2D", online: true, sensorOnline: true, sensorFallback: false, on: false, cooling: false, setpoint: 22, status: "Bereit", mode: "temperature", voltage: 13.4, lowVoltage: 11.5, internalTemperature: 22.4, externalTemperature: 9.8, heatExchangerTemperature: 34.7, effectiveSensor: "Komfortmittel", tempSource: "ruuvi3", frostProtection: true, frostTarget: 7 },
            fan: { name: "MAXXFAN", on: true, speed: 30, speedStep: 3, mode: "forward", lid: 1, lidOpen: true, autoHold: false, voltage: 13.2, current: 1.4, power: 18.5, calibrated: true, calibrating: false, online: true, powered: true, powerChannel: 6 }
        },
        power: {
            inverter: { name: "MULTIPLUS COMPACT", on: false, stateText: "Aus", outputPower: 0, shoreConnected: false },
            dcChannels: [
                { id: "dc_outlets_left", channel: 1, name: "12 V links", on: true },
                { id: "water_pump", channel: 2, name: "Wasserpumpe", on: true },
                { id: "high_beam_manual", channel: 3, name: "Fernlicht manuell", on: false },
                { id: "dc_outlets_right", channel: 4, name: "12 V rechts", on: true },
                { channel: 5, name: "Starlink", on: false },
                { channel: 6, name: "MaxxFan Versorgung", on: true }
            ]
        },
        vehicle: { highBeam: { on: true, manualOn: false, vehicleOn: true, outputChannel: 3, digitalInput: 4, inputOnline: true, outputOnline: true } },
        lights: { items: [
            { id: "outside_front_white", name: "Tagfahrlicht Balken", channel: 7, area: "outside", on: true, dimming: 100, dimmable: true },
            { id: "outside_front_amber", name: "Warnlicht Balken", channel: 8, area: "outside", on: false, dimming: 100, dimmable: false, blinking: false },
            { id: "inside_main", name: "Innenlicht", channel: 9, area: "inside", on: true, dimming: 72, dimmable: true },
            { id: "outside_right", name: "Außen rechts", channel: 10, area: "outside", on: true, dimming: 65, dimmable: true },
            { id: "outside_rear", name: "Außen hinten", channel: 11, area: "outside", on: true, dimming: 50, dimmable: true },
            { id: "outside_left", name: "Außen links", channel: 12, area: "outside", on: true, dimming: 55, dimmable: true }
        ] },
        operations: {
            scenes: [
                { id: "arrival", name: "Ankommen", icon: "arrival", actionCount: 4 },
                { id: "night", name: "Nacht", icon: "night", actionCount: 5 },
                { id: "outside", name: "Außenlicht", icon: "light", actionCount: 3 },
                { id: "away", name: "Abwesend", icon: "sleep", actionCount: 6 }
            ],
            events: { unacknowledgedCount: 1, recent: [
                { id: "demo-1", level: "warning", text: "Frischwasser unter 70 %", source: "Wassertank", createdAt: Date.now() - 1800000 },
                { id: "demo-2", level: "info", text: "INDEVOLT verbunden", source: "Netzwerk", createdAt: Date.now() - 3600000, acknowledgedAt: Date.now() }
            ] },
            commands: { recent: [] },
            history: { forecast: {} },
            devices: [
                { name: "Cerbo GX", online: true, lastSeen: Date.now() - 1000 },
                { name: "STAR-POWER", online: true, lastSeen: Date.now() - 1800 },
                { name: "AUTOTERM", online: true, lastSeen: Date.now() - 2200 },
                { name: "MAXXFAN", online: true, lastSeen: Date.now() - 2500 },
                { name: "INDEVOLT", online: true, lastSeen: Date.now() - 3200 },
                { name: "RUUVI", online: true, lastSeen: Date.now() - 900 }
            ]
        }
    })

    signal commandResult(var result)
    signal settingsReceived(var settings)

    function cleanBaseUrl(value) { return String(value || "preview://offline") }
    function start() { polling = true }
    function stop() { polling = false }
    function reconnect() { connected = true; statusText = "Lokale Vorschau" }
    function readSettings() {
        settingsReceived({
            lights: stateData.lights.items,
            ui: {
                quickAccessIds: ["switch:water_pump", "switch:starlink", "scene:arrival", "device:orion"],
                favoriteIds: stateData.ui.favoriteIds.slice(0)
            }
        })
    }
    function commit(copy) { stateData = JSON.parse(JSON.stringify(copy)) }
    function command(target, action, value, extra) {
        lastCommandRequest = { target: target, action: action, value: value, extra: extra || ({}) }
        var copy = JSON.parse(JSON.stringify(stateData))
        var channel = extra && extra.channel !== undefined ? Number(extra.channel) : -1
        var changed = false
        var i
        if (target === "starpower") {
            var groups = [copy.lights.items, copy.power.dcChannels]
            for (var g = 0; g < groups.length; ++g) for (i = 0; i < groups[g].length; ++i) {
                if (Number(groups[g][i].channel) !== channel) continue
                if (action === "dim") groups[g][i].dimming = Number(value)
                else groups[g][i].on = Number(value) !== 0
                changed = true
            }
            if (channel === 3) {
                copy.vehicle.highBeam.manualOn = Number(value) !== 0
                copy.vehicle.highBeam.on = copy.vehicle.highBeam.manualOn || copy.vehicle.highBeam.vehicleOn
            }
        } else if (target === "waterPump") {
            copy.water.pump.on = Boolean(value); changed = true
        } else if (target === "inverter") {
            copy.power.inverter.on = Boolean(value)
            copy.power.inverter.stateText = value ? "Ein" : "Aus"
            copy.power.inverter.outputPower = value ? 245 : 0
            changed = true
        } else if (target === "indevoltGrid") {
            copy.energy.indevolt.gridConnection.on = Boolean(value)
            copy.energy.indevolt.gridConnection.power = value ? 680 : 0
            copy.energy.indevolt.gridConnection.current = value ? 2.9 : 0
            copy.energy.indevolt.gridConnection.status = value ? "CAMPERNETZ FREIGEGEBEN" : "CAMPERNETZ GETRENNT"
            changed = true
        } else if (target === "heater") {
            if (action === "start") copy.climate.heater.on = true
            else if (action === "stop") copy.climate.heater.on = false
            else if (action === "setpoint") copy.climate.heater.setpoint = Number(value)
            changed = true
        } else if (target === "maxxfan") {
            if (action === "set") copy.climate.fan.on = Boolean(value)
            else if (action === "speed") copy.climate.fan.speed = Number(value)
            else if (action === "mode") copy.climate.fan.mode = String(value)
            else if (action === "lid") copy.climate.fan.lid = Number(copy.climate.fan.lid) === 1 ? 0 : 1
            else if (action === "auto") copy.climate.fan.autoHold = Boolean(value)
            changed = true
        } else if (target === "service" && action === "wifiEnable") {
            copy.system.service.external_wifi_enabled = Boolean(value)
            copy.system.service.external_wifi_state = value ? "bereit" : "aus"
            if (!value) copy.system.service.external_wifi_ssid = ""
            changed = true
        } else if (target === "service" && action === "wifiConnect") {
            var wifiService = String((extra && extra.service) || "")
            if (wifiService.indexOf("/net/connman/service/") === 0) {
                copy.system.service.external_wifi_enabled = true
                copy.system.service.external_wifi_ssid = String((extra && extra.ssid) || "")
                copy.system.service.external_wifi_service = wifiService
                copy.system.service.external_wifi_state = "verbunden"
                changed = true
            }
        } else if (target === "settings" && action === "patch" && extra && extra.patch && extra.patch.ventilation) {
            var ventilation = extra.patch.ventilation
            copy.climate.ventilation.enabled = ventilation.enabled === true
            copy.climate.ventilation.onTemperature = Number(ventilation.onTemperature)
            copy.climate.ventilation.hysteresis = Number(ventilation.hysteresis)
            copy.climate.ventilation.offTemperature = copy.climate.ventilation.onTemperature - copy.climate.ventilation.hysteresis
            copy.climate.ventilation.active = copy.climate.ventilation.enabled && Number(copy.climate.ventilation.cpuTemperature) >= copy.climate.ventilation.onTemperature
            copy.climate.ventilation.supplyOn = copy.climate.ventilation.active
            copy.climate.ventilation.exhaustOn = copy.climate.ventilation.active
            copy.climate.ventilation.reason = copy.climate.ventilation.enabled ? (copy.climate.ventilation.active ? "Über Einschalttemperatur" : "CPU-Temperatur im Sollbereich") : "CPU-Lüftung aus"
            changed = true
        } else if (target === "settings" && action === "patch" && extra && extra.patch && extra.patch.climateAutomation) {
            var climateAutomation = extra.patch.climateAutomation
            copy.climate.automation.enabled = climateAutomation.enabled === true
            copy.climate.automation.mode = String(climateAutomation.mode || "auto")
            copy.climate.automation.targetTemperature = Number(climateAutomation.targetTemperature)
            copy.climate.automation.hysteresis = Number(climateAutomation.hysteresis)
            copy.climate.automation.fanSpeed = Number(climateAutomation.fanSpeed)
            copy.climate.automation.demand = "idle"
            copy.climate.automation.reason = copy.climate.automation.enabled ? "Solltemperatur erreicht" : "Klimaautomatik aus"
            changed = true
        } else if (target === "system" && action === "acknowledge") {
            for (i = 0; i < copy.operations.events.recent.length; ++i)
                if (copy.operations.events.recent[i].id === value) copy.operations.events.recent[i].acknowledgedAt = Date.now()
            copy.operations.events.unacknowledgedCount = 0
            changed = true
        } else if (target === "scene") {
            copy.lights.items[0].on = true
            changed = true
        }
        if (changed) commit(copy)
        lastCommandResult = { ok: true, status: "confirmed", preview: true }
        commandResult(lastCommandResult)
    }
}
'''


def prepare_app(temp_root: Path) -> Path:
    target = temp_root / "Camper"
    shutil.copytree(SOURCE_APP, target)
    preview_config = target / "preview-config.json"
    preview_config.write_text("{}", encoding="utf-8")
    for qml_file in target.glob("*.qml"):
        text = qml_file.read_text(encoding="utf-8")
        text = text.replace("import AL2HMIBridge 1.0 as AL2HMIBridge\n", "")
        text = text.replace(
            "property bool dayMode: AL2HMIBridge.globalSource.dayMode",
            "property bool dayMode: " + ("true" if DAY_MODE else "false"),
        )
        text = text.replace(
            'property string settingsFile: "file:///fs/rwdata/fmods/mods/camper/config.json"',
            'property string settingsFile: "' + preview_config.as_uri() + '"',
        )
        if PASSENGER_VIEW and qml_file.name in ("VehicleLights.qml", "V2LightsPage.qml"):
            text = text.replace("property bool rightView: false", "property bool rightView: true")
        if (SETTINGS_VIEW or WIFI_SETTINGS_VIEW) and qml_file.name == "CamperMain.qml":
            text = text.replace("property bool settingsOpen: false", "property bool settingsOpen: true")
        if qml_file.name == "ModernShell.qml":
            text = text.replace("property int currentPage: 0", "property int currentPage: " + str(V2_PAGE))
        if qml_file.name == "V2EnergyPage.qml":
            text = text.replace("property int pane: 0", "property int pane: " + str(ENERGY_PANE))
        if WIFI_SETTINGS_VIEW and qml_file.name == "SettingsPanel.qml":
            text = text.replace("id: scroller", "id: scroller\n        Component.onCompleted: contentY = 905")
        if CPU_VIEW and qml_file.name == "TemperatureDetails.qml":
            text = text.replace("property int controlTab: 0", "property int controlTab: 1")
        if SENSORS_VIEW and qml_file.name == "TemperatureDetails.qml":
            text = text.replace("property int controlTab: 0", "property int controlTab: 2")
        qml_file.write_text(text, encoding="utf-8")
    demo_api = DEMO_API
    if WARNING_VIEW:
        demo_api = demo_api.replace('id: "outside_front_white", name: "Tagfahrlicht Balken", channel: 7, area: "outside", on: true', 'id: "outside_front_white", name: "Tagfahrlicht Balken", channel: 7, area: "outside", on: false')
        demo_api = demo_api.replace('id: "outside_front_amber", name: "Warnlicht Balken", channel: 8, area: "outside", on: false', 'id: "outside_front_amber", name: "Warnlicht Balken", channel: 8, area: "outside", on: true')
    (target / "ApiClient.qml").write_text(demo_api, encoding="utf-8")
    return target / ("Camper.qml" if WRAPPER_SMOKE_TEST else "CamperMain.qml")


os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt5.QtCore import QObject, QPoint, Qt, QTimer, QUrl
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQuick import QQuickView
from PyQt5.QtTest import QTest


class PreviewView(QQuickView):
    def keyPressEvent(self, event):
        root = self.rootObject()
        if event.key() == Qt.Key_F2 and root is not None:
            root.setProperty("dayMode", not bool(root.property("dayMode")))
            return
        if event.key() == Qt.Key_F11:
            self.showNormal() if self.visibility() == QQuickView.FullScreen else self.showFullScreen()
            return
        if event.key() == Qt.Key_Escape:
            self.close()
            return
        super().keyPressEvent(event)


def main() -> int:
    application = QGuiApplication(sys.argv)
    application.setApplicationName("CamperControl UI Vorschau")
    with tempfile.TemporaryDirectory(prefix="camper-control-preview-") as directory:
        app_file = prepare_app(Path(directory))
        view = PreviewView()
        view.setTitle("CamperControl v3.12.0 – lokale UI-Vorschau (keine Hardware)")
        view.setResizeMode(QQuickView.SizeRootObjectToView)
        view.setSource(QUrl.fromLocalFile(str(app_file)))
        if view.status() == QQuickView.Error:
            for error in view.errors():
                print(error.toString(), file=sys.stderr)
            return 1
        view.resize(800, 480)
        root = view.rootObject()
        if root is not None:
            root.setProperty("embeddedInGlobalHost", True)
            if not WRAPPER_SMOKE_TEST:
                root.setProperty("dayMode", DAY_MODE)
                root.setProperty("page", PAGE)
            root.closeRequested.connect(view.close)
        view.show()
        if EDGE_PANEL in ("favorites", "weather"):
            def open_edge_panel():
                panel = root.findChild(QObject, "v2EdgePanelsHost") if root is not None else None
                if panel is not None:
                    panel.setProperty("activePanel", -1 if EDGE_PANEL == "favorites" else 1)
            QTimer.singleShot(500, open_edge_panel)
        if DIMMER_VIEW:
            # Innenlicht-Dimmbalken auf der Lichtseite: öffnet ausschließlich
            # das große Overlay und sendet in der Demo keine Hardwarebefehle.
            QTimer.singleShot(650, lambda: QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, QPoint(80, 166)))
        if PASSENGER_VIEW:
            def select_passenger_view():
                vehicle_view = root.findChild(QObject, "vehicleLightsView") if root is not None else None
                if vehicle_view is not None:
                    vehicle_view.setProperty("rightView", True)
            QTimer.singleShot(500, select_passenger_view)
        print("Lokale Demo: keine Verbindung und keine Befehle an Camper-Hardware.")
        print("F2 = Tag/Nacht, F11 = Vollbild, Esc = Schließen")
        if SCREENSHOT:
            def capture():
                image = view.grabWindow()
                target = Path(SCREENSHOT).resolve()
                target.parent.mkdir(parents=True, exist_ok=True)
                if image.isNull() or not image.save(str(target)):
                    print("Vorschau-Screenshot konnte nicht gespeichert werden.", file=sys.stderr)
                    application.exit(1)
                    return
                print(target)
                application.quit()
            QTimer.singleShot(1500, capture)
        elif "--smoke-test" in sys.argv:
            QTimer.singleShot(1200, application.quit)
        return application.exec_()


if __name__ == "__main__":
    raise SystemExit(main())
