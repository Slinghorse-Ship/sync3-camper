"""Static contract for the V2-only SYNC edge panels."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod/files/app/Jan/Camper"

main = (QML / "CamperMain.qml").read_text(encoding="utf-8")
shell = (QML / "ModernShell.qml").read_text(encoding="utf-8")
panels = (QML / "V2EdgePanels.qml").read_text(encoding="utf-8")
icons = (QML / "V2Icon.qml").read_text(encoding="utf-8")
settings = (QML / "SettingsPanel.qml").read_text(encoding="utf-8")
installer = (ROOT / "SyncMyMod/autoinstall.sh").read_text(encoding="utf-8")
preview = (ROOT / "tools/preview_qml.py").read_text(encoding="utf-8")
readme = (ROOT / "README.md").read_text(encoding="utf-8")
app_entry = (ROOT / "SyncMyMod/files/other/app-entry.json").read_text(encoding="utf-8")
wrapper = (QML / "Camper.qml").read_text(encoding="utf-8")


checks = {
    "edge host is instantiated once by the V2 shell": (
        shell.count("V2EdgePanels {") == 1
        and "V2EdgePanels" not in main
        and "designVersion" not in shell
    ),
    "weather is snapshot-only and never performs HTTP": (
        "weather: shell.snapshot.weather || ({})" in shell
        and "property var weather" in panels
        and not any(token in panels for token in ("XMLHttpRequest", "http://", "https://"))
    ),
    "weather matches the Cerbo schema-1 transport": all(
        token in panels
        for token in (
            "weather.station.name",
            "weather.fetchedAtUtc",
            "weather.stale === true",
            "weather.sun",
            'sunTime("riseUtc")',
            'sunTime("setUtc")',
            '"tempC"',
            '"precipProbabilityPct"',
            '"precipMm"',
            '"windKmh"',
            '"minC"',
            '"maxC"',
            '"maxHourlyPrecipProbabilityPct"',
        )
    ),
    "optional BSH tides use only the defensive Cerbo weather contract": all(
        token in panels
        for token in (
            "weather.tides",
            'data.source !== "BSH"',
            'data.referenceLevel !== "PNP"',
            "data.updatedUtc",
            "data.stale",
            "station.distanceKm",
            "data.nextHigh",
            "data.nextLow",
            "event.heightM === null",
            'objectName: "v2TideSummary"',
            "visible: panels.tidesAvailable",
            ' + " m PNP"',
            '" · veraltet"',
        )
    ),
    "invalid or absent tides remain hidden without a SYNC network path": (
        "function validIsoTimestamp(value)" in panels
        and "function validTides(data)" in panels
        and "validTideEvent(data.nextHigh) && validTideEvent(data.nextLow)" in panels
        and "XMLHttpRequest" not in panels
        and "http://" not in panels
        and "https://" not in panels
    ),
    "optional tide curve is strictly bounded and independently scaled": all(
        token in panels
        for token in (
            "function validTideCurve(data)",
            "data.curve.length < 2 || data.curve.length > 27",
            'typeof point.heightM !== "number"',
            "pointTime <= previousTime",
            "property var tideData: panels.tideCurve",
            "panels.tideCurveAvailable && tideData.length >= 2",
            "var tideMinimum = 1000, tideMaximum = -1000",
            "var chartEnd = chartStart + 24 * 60 * 60 * 1000",
            "var tideStart = new Date(tideData[0].t).getTime()",
            "var visibleTides = []",
            'context.strokeStyle = "#21d4d8"',
            'text: "Tide"',
        )
    ),
    "weather renders 24 hours and six days": (
        'objectName: "v2Weather24HourChart"' in panels
        and "Math.min(24," in panels
        and "Math.min(6, panels.dailyForecast.length)" in panels
        and 'text: "6-Tage-Vorhersage"' in panels
    ),
    "weather chart exposes scales and maps every official MOSMIX group plus defensive hail": all(
        token in panels
        for token in (
            'text: "Temperatur °C"',
            'Math.ceil(maximum) + " °C"',
            'Math.floor(minimum) + " °C"',
            'tideMaximum.toFixed(1).replace(".", ",") + " m"',
            "code === 80 || code === 81 || code === 82",
            "code === 83 || code === 84",
            "code === 56 || code === 57 || code === 66 || code === 67",
            "code === 96 || code === 99",
            'value.indexOf("partly-cloudy")',
            'value.indexOf("cloud")',
            'value.indexOf("overcast")',
            "code === 1 || code === 2 || code === 3",
            '81:"Regenschauer"',
            '95:"Gewitter mit Regen oder Schnee"',
            'return "weatherUnknown"',
        )
    ) and all(kind in icons for kind in ('kind === "weatherFreezingRain"', 'kind === "weatherSleet"', 'kind === "weatherHail"', 'kind === "weatherUnknown"')),
    "DWD attribution is permanently visible": (
        "Deutscher Wetterdienst" in panels
        and 'x: 14; y: 445; width: 532' in panels
        and "visible:" not in panels[panels.index('text: "Quelle: "'):panels.index('text: "Quelle: "') + 240]
    ),
    "favorites are distinct from Home quick access and fail closed": (
        "snapshot.ui && snapshot.ui.favorites" in shell
        and "favorites: shell.favoriteItems()" in shell
        and "favorites: shell.quickItems()" not in shell
        and "snapshot.ui && snapshot.ui.quickAccess" in shell
        and 'property var favoriteIds: []' in main
        and "remoteConfig.ui.favoriteIds" in main
        and "fallbackQuick" not in shell
        and "findLight" not in shell
    ),
    "favorites reuse only the shared option catalog and their own settings patch": (
        "snapshot.ui && snapshot.ui.quickAccessOptions" in shell
        and "favoriteOptions: shell.favoriteOptions()" in shell
        and "function changeFavorite(index, direction)" in main
        and "function saveFavorite()" in main
        and "patch: { ui: { favoriteIds: ids } }" in main
        and "quickAccessIds" not in main[main.index("function saveFavorite()"):main.index("function changeLightChannel")]
    ),
    "favorite and Home selectors skip occupied IDs without moving other slots": (
        "function cycleUniqueSelection(values, index, direction)" in main
        and "if (slotIndex !== index && updated[slotIndex] === wanted)" in main
        and "quickAccessIds = cycleUniqueSelection(quickAccessIds, index, direction)" in main
        and "favoriteIds = cycleUniqueSelection(favoriteIds, index, direction)" in main
        and "updated[occupant]" not in main[main.index("function cycleUniqueSelection"):main.index("function saveFavorite")]
        and "Belegte Einträge werden übersprungen" in settings
    ),
    "favorites use the native V2 star icon": (
        'kind: "favorite"' in panels
        and 'kind === "favorite"' in icons
        and 'kind: "home"' not in panels[panels.index('id: favoritePanel'):panels.index('id: weatherPanel')]
    ),
    "favorite commands fail closed on capability": all(
        token in panels
        for token in (
            "item.available === true",
            "command.target",
            "command.action",
            "api.command(command.target, command.action, command.value, extra)",
            "enabled: parent.actionable",
        )
    ),
    "favorites editor text is bounded with twelve-pixel control gaps": (
        'objectName: "v2FavoritesSubtitle"' in panels
        and 'width: 190; clip: true; elide: Text.ElideRight; text: "Antippen zum Schalten"' in panels
        and 'objectName: "v2FavoritesEditorLabel"' in panels
        and 'x: 14; y: 407; width: 132; height: 32; clip: true; elide: Text.ElideRight' in panels
        and 'x: 158; y: 401; width: 168; height: 44' in panels
        and 'x: 64; y: 10; width: 132; clip: true; elide: Text.ElideRight' in panels
        and 'x: 208; y: 12; width: 42; height: 44' in panels
        and 'objectName: "v2HomeQuickAccessName" + index' in settings
        and 'x: 10; y: 25; width: 236; clip: true; elide: Text.ElideRight' in settings
        and 'objectName: "v2HomeQuickAccessPrevious" + index; x: 258' in settings
    ),
    "one activePanel property makes drawers mutually exclusive": (
        "property int activePanel: 0" in panels
        and "activePanel = -1" in panels
        and "activePanel = 1" in panels
        and panels.count("property int activePanel") == 1
    ),
    "header buttons are 42-pixel panel-only controls beside the clock": (
        'objectName: "v2ClockStatus"' in shell
        and 'x: 602; y: 10; width: 76; height: 30' in shell
        and panels.count('objectName: "v2FavoritesHeaderButton"') == 1
        and panels.count('objectName: "v2WeatherHeaderButton"') == 1
        and 'x: 512; y: 6; width: 42; height: 42' in panels
        and 'x: 560; y: 6; width: 42; height: 42' in panels
    ),
    "header buttons open only their mutually-exclusive UI panels": (
        "property bool active: panels.activePanel === -1" in panels
        and "property bool active: panels.activePanel === 1" in panels
        and "onClicked: panels.openFavorites()" in panels
        and "onClicked: panels.openWeather()" in panels
        and 'kind: "favorite"' in panels[panels.index('id: favoritesHeaderButton'):panels.index('id: weatherHeaderButton')]
        and 'kind: "weatherCloud"' in panels[panels.index('id: weatherHeaderButton'):panels.index('id: leftEdge')]
        and "api.command" not in panels[panels.index('id: favoritesHeaderButton'):panels.index('id: leftEdge')]
    ),
    "header buttons expose an active/open visual state above the scrim": (
        panels[panels.index('id: favoritesHeaderButton'):panels.index('id: weatherHeaderButton')].count("visual.selectedBlue") == 1
        and panels[panels.index('id: weatherHeaderButton'):panels.index('id: leftEdge')].count("visual.selectedBlue") == 1
        and panels[panels.index('id: favoritesHeaderButton'):panels.index('id: leftEdge')].count("z: 60") == 2
        and 'x: 372; y: 14; width: 168' in panels
    ),
    "drawers have their agreed widths": (
        'id: favoritePanel' in panels
        and 'id: weatherPanel' in panels
        and panels[panels.index('id: favoritePanel'):panels.index('id: weatherPanel')].count("width: 340") == 1
        and "width: 560" in panels[panels.index('id: weatherPanel'):panels.index('id: closeButton')]
    ),
    "drawers share one scrim and one 48-pixel close control": (
        panels.count("id: scrim") == 1
        and panels.count('objectName: "v2EdgePanelClose"') == 1
        and "width: 48\n        height: 48" in panels
    ),
    "invisible edge zones exclude header and navigation": (
        'x: 0; y: 56; width: 18; height: 335' in panels
        and 'x: 782; y: 56; width: 18; height: 335' in panels
        and "dx >= 48" in panels
        and panels.count("Math.abs(dx) > Math.abs(dy) * 1.5") == 2
        and 'objectName: "v2EdgeHandle"' not in panels
        and "id: edgeHandle" not in panels
    ),
    "weather is read-only": "panels.activate" not in panels[panels.index("id: weatherPanel"):],
    "preview fixture uses the exact backend schema": all(
        token in preview
        for token in (
            'schema: 1',
            'source: "DWD MOSMIX_L"',
            'attribution: "Deutscher Wetterdienst"',
            "station:",
            "modelRunUtc:",
            "fetchedAtUtc:",
            "stale: false",
            "timezone:",
            "riseUtc:",
            "setUtc:",
            "hourly: [",
            "daily: [",
        )
    ),
    "preview includes an independent optional BSH tide fixture": all(
        token in preview
        for token in (
            "tides: {",
            'source: "BSH"',
            'referenceLevel: "PNP"',
            "nextHigh:",
            "nextLow:",
            "heightM:",
            "curve: [",
        )
    ),
    "preview keeps favorites and Home fixtures distinct": (
        'favoriteIds: ["light:inside_main", "switch:dc_outlets_left", "switch:maxxfan", "device:orion"]' in preview
        and "favorites: [" in preview
        and "quickAccess: [" in preview
        and preview.index("favorites: [") < preview.index("quickAccess: [")
    ),
    "installer requires the edge-panel payload": '"${APP_SOURCE}/V2EdgePanels.qml"' in installer,
    "release version is consistent": all(
        "3.12.0" in text for text in (installer, readme, app_entry, wrapper, shell, preview)
    ),
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC V2 edge-panel contract failed: " + ", ".join(failed))

print(f"SYNC V2 edge-panel contract: {len(checks)} checks passed")
