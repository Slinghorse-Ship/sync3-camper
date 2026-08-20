"""Qt 5 touch/command smoke-test for the native SYNC Transit Horizon V2 UI."""

import os
import tempfile
from pathlib import Path


os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PyQt5.QtCore import QObject, QPoint, Qt, QUrl
from PyQt5.QtGui import QGuiApplication
from PyQt5.QtQuick import QQuickView
from PyQt5.QtTest import QTest

from preview_qml import prepare_app


def item_with(items: list, key: str, value):
    for item in items:
        if item.get(key) == value:
            return item
    raise AssertionError(f"No item with {key}={value!r}")


application = QGuiApplication.instance() or QGuiApplication([])
with tempfile.TemporaryDirectory(prefix="camper-v2-runtime-") as directory:
    app_file = prepare_app(Path(directory))
    view = QQuickView()
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.setSource(QUrl.fromLocalFile(str(app_file)))
    if view.status() == QQuickView.Error:
        raise AssertionError("\n".join(error.toString() for error in view.errors()))
    root = view.rootObject()
    if root is None:
        raise AssertionError("CamperMain root object was not created")

    root.setProperty("embeddedInGlobalHost", True)
    root.setProperty("dayMode", False)
    view.resize(800, 480)
    view.show()
    QTest.qWait(250)

    def corner_colors():
        image = view.grabWindow()
        if image.isNull():
            raise AssertionError("V2 viewport could not be captured")
        return [
            image.pixelColor(0, 0),
            image.pixelColor(799, 0),
            image.pixelColor(0, 479),
            image.pixelColor(799, 479),
        ]

    night_corners = corner_colors()
    if any(color.alpha() != 255 or max(color.red(), color.green(), color.blue()) >= 50 for color in night_corners):
        raise AssertionError("Night V2 background does not fill all four viewport corners")
    root.setProperty("dayMode", True)
    QTest.qWait(80)
    day_corners = corner_colors()
    if any(color.alpha() != 255 or min(color.red(), color.green(), color.blue()) <= 220 for color in day_corners):
        raise AssertionError("Day V2 background does not fill all four viewport corners")
    root.setProperty("dayMode", False)
    QTest.qWait(80)

    shell = root.findChild(QObject, "modernShell")
    lights_page = root.findChild(QObject, "v2LightsPage")
    energy_page = root.findChild(QObject, "v2EnergyPage")
    energy_power_pane = root.findChild(QObject, "v2EnergyPowerPane")
    power_channels_card = root.findChild(QObject, "v2PowerChannelsCard")
    inverter_card = root.findChild(QObject, "v2InverterCard")
    energy_sources_pane = root.findChild(QObject, "v2EnergySourcesPane")
    edge_panels = root.findChild(QObject, "v2EdgePanelsHost")
    left_edge = root.findChild(QObject, "v2LeftEdgeSwipe")
    right_edge = root.findChild(QObject, "v2RightEdgeSwipe")
    edge_close = root.findChild(QObject, "v2EdgePanelClose")
    favorites_header_button = root.findChild(QObject, "v2FavoritesHeaderButton")
    weather_header_button = root.findChild(QObject, "v2WeatherHeaderButton")
    clock_status = root.findChild(QObject, "v2ClockStatus")
    favorites_subtitle = root.findChild(QObject, "v2FavoritesSubtitle")
    favorites_editor_label = root.findChild(QObject, "v2FavoritesEditorLabel")
    favorite_save_button = root.findChild(QObject, "v2FavoriteSaveButton")
    weather_panel = root.findChild(QObject, "v2WeatherPanel")
    weather_chart = root.findChild(QObject, "v2Weather24HourChart")
    tide_summary = root.findChild(QObject, "v2TideSummary")
    api = root.findChild(QObject, "camperApiClient")
    required_objects = {
        "modernShell": shell,
        "v2LightsPage": lights_page,
        "v2EnergyPage": energy_page,
        "v2EnergyPowerPane": energy_power_pane,
        "v2PowerChannelsCard": power_channels_card,
        "v2InverterCard": inverter_card,
        "v2EnergySourcesPane": energy_sources_pane,
        "v2EdgePanelsHost": edge_panels,
        "v2LeftEdgeSwipe": left_edge,
        "v2RightEdgeSwipe": right_edge,
        "v2EdgePanelClose": edge_close,
        "v2FavoritesHeaderButton": favorites_header_button,
        "v2WeatherHeaderButton": weather_header_button,
        "v2ClockStatus": clock_status,
        "v2FavoritesSubtitle": favorites_subtitle,
        "v2FavoritesEditorLabel": favorites_editor_label,
        "v2FavoriteSaveButton": favorite_save_button,
        "v2WeatherPanel": weather_panel,
        "v2Weather24HourChart": weather_chart,
        "v2TideSummary": tide_summary,
        "camperApiClient": api,
    }
    missing_objects = [name for name, item in required_objects.items() if item is None]
    if missing_objects:
        instantiated = sorted(
            str(item.objectName()) for item in root.findChildren(QObject)
            if any(token in str(item.objectName()) for token in ("Favorite", "QuickAccess"))
        )
        raise AssertionError(
            "The V2 runtime did not instantiate: " + ", ".join(missing_objects)
            + "; related instantiated objects: " + ", ".join(instantiated)
        )
    if view.width() != 800 or view.height() != 480:
        raise AssertionError("The GX Touch/SYNC reference viewport is not 800x480")
    if (int(energy_page.property("x")), int(energy_page.property("y")), int(energy_page.property("width")), int(energy_page.property("height"))) != (19, 65, 762, 326):
        raise AssertionError("Energy page does not fit the 762x326 content viewport")
    if (int(energy_power_pane.property("x")), int(energy_power_pane.property("y")), int(energy_power_pane.property("width")), int(energy_power_pane.property("height"))) != (0, 49, 762, 277):
        raise AssertionError("12/230-V pane does not fit the energy content viewport")
    if (int(energy_sources_pane.property("x")), int(energy_sources_pane.property("y")), int(energy_sources_pane.property("width")), int(energy_sources_pane.property("height"))) != (0, 49, 762, 277):
        raise AssertionError("Sources pane does not fit the energy content viewport")
    channels_right = int(power_channels_card.property("x")) + int(power_channels_card.property("width"))
    inverter_left = int(inverter_card.property("x"))
    inverter_right = inverter_left + int(inverter_card.property("width"))
    if channels_right > inverter_left or inverter_left - channels_right != 9 or inverter_right != 762:
        raise AssertionError("12/230-V cards overlap or waste the energy viewport")

    def snapshot() -> dict:
        value = root.property("snapshot")
        return value.toVariant() if hasattr(value, "toVariant") else value

    def variant(value):
        return value.toVariant() if hasattr(value, "toVariant") else value

    def click(x: int, y: int) -> None:
        QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, QPoint(x, y))
        QTest.qWait(100)

    def swipe(start_x: int, end_x: int, y: int, end_y: int | None = None) -> None:
        final_y = y if end_y is None else end_y
        QTest.mousePress(view, Qt.LeftButton, Qt.NoModifier, QPoint(start_x, y))
        QTest.qWait(30)
        QTest.mouseMove(view, QPoint(end_x, final_y), 80)
        QTest.mouseRelease(view, Qt.LeftButton, Qt.NoModifier, QPoint(end_x, final_y))
        QTest.qWait(260)

    checks = 0

    # Home keeps the Victron system DC total separate from direct battery flow.
    # Positive SmartShunt power means charging; negative means discharging.
    flow_cases = (
        (52, "↑ Lädt +52 W"),
        (-52, "↓ Entlädt 52 W"),
        (0, "Ruhe"),
        (None, "–"),
    )
    for value, expected in flow_cases:
        actual = shell.batteryFlowText(value)
        if actual != expected:
            raise AssertionError(f"Battery-flow formatter expected {expected!r} for {value!r}, got {actual!r}")
    runtime_cases = (
        ((17 * 3600, -52), "17 h"),
        ((90 * 3600, -52), "3,8 Tage"),
        ((None, -52), "–"),
        ((17 * 3600, 52), "Lädt"),
    )
    for arguments, expected in runtime_cases:
        actual = shell.timeToGo(*arguments)
        if actual != expected:
            raise AssertionError(f"Time-to-go formatter expected {expected!r} for {arguments!r}, got {actual!r}")
    checks += 1

    # Visible header controls are adjacent to the clock and only change the
    # shared panel state. They remain above the scrim for direct panel switching.
    if (int(favorites_header_button.property("x")), int(favorites_header_button.property("width")),
            int(favorites_header_button.property("height"))) != (512, 42, 42):
        raise AssertionError("Favorites header control is not the required 42-pixel target")
    if (int(weather_header_button.property("x")), int(weather_header_button.property("width")),
            int(weather_header_button.property("height"))) != (560, 42, 42):
        raise AssertionError("Weather header control is not the required 42-pixel target")
    if int(clock_status.property("x")) != 602:
        raise AssertionError("Header panel controls are no longer immediately beside the clock")
    api.setProperty("lastCommandResult", {})
    api.setProperty("lastCommandRequest", {})
    click(533, 27)
    if edge_panels.property("activePanel") != -1 or favorites_header_button.property("active") is not True:
        raise AssertionError("Visible star control did not open/activate Favorites")
    click(581, 27)
    if (edge_panels.property("activePanel") != 1 or weather_header_button.property("active") is not True
            or favorites_header_button.property("active") is not False):
        raise AssertionError("Visible cloud control did not switch exclusively to DWD Weather")
    command_result = api.property("lastCommandResult")
    command_result = command_result.toVariant() if hasattr(command_result, "toVariant") else command_result
    if command_result:
        raise AssertionError("Header panel controls issued a backend command")
    if variant(api.property("lastCommandRequest")):
        raise AssertionError("Header panel controls touched the API request path")
    click(533, 27)
    if edge_panels.property("activePanel") != -1:
        raise AssertionError("Visible star control did not switch back to Favorites")
    click(302, 34)
    if edge_panels.property("activePanel") != 0:
        raise AssertionError("Shared close control did not reset the header panel state")
    checks += 1

    # Invisible physical-edge gestures share one mutually-exclusive host.
    if (int(left_edge.property("width")), int(left_edge.property("y")), int(left_edge.property("height"))) != (18, 56, 335):
        raise AssertionError("Left V2 edge zone does not match x 0..17 / y 56..390")
    if (int(right_edge.property("x")), int(right_edge.property("width")), int(right_edge.property("y")), int(right_edge.property("height"))) != (782, 18, 56, 335):
        raise AssertionError("Right V2 edge zone does not match x 782..799 / y 56..390")
    swipe(3, 92, 30)
    swipe(797, 708, 430)
    swipe(3, 30, 220, 350)
    if edge_panels.property("activePanel") != 0:
        raise AssertionError("Header, navigation or vertical movement opened an edge panel")
    swipe(3, 92, 240)
    if edge_panels.property("activePanel") != -1:
        raise AssertionError("Left-edge swipe did not open backend favorites")
    checks += 1

    # Favorites are distinct from the Home shortcuts and the first resolved
    # favorite uses its exact backend command.
    state = snapshot()
    home_ids = [item["id"] for item in state["ui"]["quickAccess"]]
    favorite_ids = [item["id"] for item in state["ui"]["favorites"]]
    if home_ids == favorite_ids:
        raise AssertionError("Favorites fell back to the Home quickAccess list")
    inside_before = item_with(state["lights"]["items"], "id", "inside_main")["on"]
    click(165, 112)
    if item_with(snapshot()["lights"]["items"], "id", "inside_main")["on"] is inside_before:
        raise AssertionError("Available favorite did not forward its backend command")
    checks += 1

    # An unavailable but visible favorite remains read-only.
    api.setProperty("lastCommandResult", {})
    click(165, 346)
    command_result = api.property("lastCommandResult")
    command_result = command_result.toVariant() if hasattr(command_result, "toVariant") else command_result
    if command_result:
        raise AssertionError("Unavailable favorite accepted a command")
    checks += 1

    # Both compact editors reserve an explicit 12-pixel text/control gap. The
    # Favorites selection changes locally, then saves only favoriteIds.
    if (str(favorites_subtitle.property("text")), int(favorites_subtitle.property("width"))) != ("Antippen zum Schalten", 190):
        raise AssertionError("Favorites subtitle is not concise and width-bounded")
    favorites_gap = int(favorite_save_button.property("x")) - (
        int(favorites_editor_label.property("x")) + int(favorites_editor_label.property("width"))
    )
    if favorites_gap != 12:
        raise AssertionError(f"Favorites editor header gap expected 12 px, got {favorites_gap}")
    selected_before = list(variant(root.property("favoriteIds")))
    api.setProperty("lastCommandRequest", {})
    click(293, 114)
    selected_after = list(variant(root.property("favoriteIds")))
    if selected_after == selected_before or variant(api.property("lastCommandRequest")):
        raise AssertionError("Favorites editor did not remain a local-only selection change")
    click(242, 423)
    request = variant(api.property("lastCommandRequest"))
    if (request.get("target") != "settings" or request.get("action") != "patch"
            or list(request.get("extra", {}).get("patch", {}).get("ui", {}).get("favoriteIds", [])) != selected_after):
        raise AssertionError("Favorites editor did not save only the favoriteIds settings patch")
    if [item["id"] for item in snapshot()["ui"]["quickAccess"]] != home_ids:
        raise AssertionError("Favorites editor changed the Home quickAccess list")
    checks += 1

    if int(edge_close.property("width")) < 44 or int(edge_close.property("height")) < 44:
        raise AssertionError("Shared edge-panel close target is smaller than 44 pixels")
    click(302, 34)
    if edge_panels.property("activePanel") != 0:
        raise AssertionError("Shared edge-panel close control did not close favorites")
    swipe(797, 708, 240)
    if edge_panels.property("activePanel") != 1:
        raise AssertionError("Right-edge swipe did not open snapshot weather")
    if int(weather_panel.property("width")) != 560:
        raise AssertionError("Weather panel is not the required 560 pixels wide")
    hourly = weather_chart.property("hourlyData")
    hourly = hourly.toVariant() if hasattr(hourly, "toVariant") else hourly
    if len(hourly) < 24:
        raise AssertionError("Weather chart did not receive 24 backend hours")
    tide_curve = weather_chart.property("tideData")
    tide_curve = tide_curve.toVariant() if hasattr(tide_curve, "toVariant") else tide_curve
    if len(tide_curve) < 2 or len(tide_curve) > 25:
        raise AssertionError("Weather chart did not receive the bounded BSH tide curve")
    tide_text = str(tide_summary.property("text"))
    if tide_summary.property("visible") is not True or not all(token in tide_text for token in ("HW", "NW", "m PNP")):
        raise AssertionError("Optional BSH tide snapshot was not rendered beside the sun data")
    click(274, 34)
    if edge_panels.property("activePanel") != 0:
        raise AssertionError("Shared edge-panel close control did not close weather")
    checks += 1

    # Bottom navigation is touch-driven and opens the light page.
    click(209, 433)
    if shell.property("currentPage") != 1:
        raise AssertionError("V2 Licht navigation did not respond to touch")
    checks += 1

    # A whole light card toggles the existing STAR-Power channel command.
    before = item_with(snapshot()["lights"]["items"], "id", "inside_main")["on"]
    click(557, 139)
    after = item_with(snapshot()["lights"]["items"], "id", "inside_main")["on"]
    if after is before:
        raise AssertionError("Inside-light card did not toggle the shared backend state")
    checks += 1

    # The common dimmer commits a real dim command for the selected light.
    click(562, 367)
    level = item_with(snapshot()["lights"]["items"], "id", "inside_main")["dimming"]
    if not 23 <= int(level) <= 27:
        raise AssertionError(f"Inside-light dimmer expected about 25 %, got {level}")
    checks += 1

    # Vehicle-driven high beam stays visible; touching the card toggles manual CH3.
    before_manual = snapshot()["vehicle"]["highBeam"]["manualOn"]
    click(704, 293)
    high_beam = snapshot()["vehicle"]["highBeam"]
    if high_beam["manualOn"] is before_manual or high_beam["outputChannel"] != 3:
        raise AssertionError("Manual high beam did not toggle the real channel-three state")
    checks += 1

    # Both real Transit photo perspectives can be selected without replacing state.
    lights_page.setProperty("rightView", True)
    QTest.qWait(60)
    if lights_page.property("rightView") is not True:
        raise AssertionError("Passenger-side Transit view did not activate")
    lights_page.setProperty("rightView", False)
    checks += 1

    shell.setProperty("currentPage", 3)
    energy_page.setProperty("pane", 0)
    QTest.qWait(80)

    # Five DC consumers use STAR-Power; exercise the initially-off Starlink tile.
    starlink_before = item_with(snapshot()["power"]["dcChannels"], "channel", 5)["on"]
    click(187, 313)
    starlink_after = item_with(snapshot()["power"]["dcChannels"], "channel", 5)["on"]
    if starlink_after is starlink_before:
        raise AssertionError("Starlink DC card did not toggle the shared backend state")
    checks += 1

    # The 230 V card drives the existing inverter target.
    inverter_before = snapshot()["power"]["inverter"]["on"]
    click(653, 252)
    if snapshot()["power"]["inverter"]["on"] is inverter_before:
        raise AssertionError("230 V card did not toggle the shared inverter state")
    checks += 1

    # The preview deliberately has no Orion. Its source card must be disabled.
    energy_page.setProperty("pane", 1)
    api.setProperty("lastCommandResult", {})
    QTest.qWait(60)
    click(398, 252)
    command_result = api.property("lastCommandResult")
    command_result = command_result.toVariant() if hasattr(command_result, "toVariant") else command_result
    if command_result:
        raise AssertionError("Unavailable Orion source accepted a command")
    checks += 1

    # Solar total opens the live charger/INDEVOLT detail pane.
    click(142, 252)
    if energy_page.property("pane") != 2:
        raise AssertionError("Solar total did not open the detail pane")
    state = snapshot()
    if len(state["energy"]["solar"]["chargers"]) != 3 or not state["energy"]["indevolt"]["online"]:
        raise AssertionError("Solar detail is not bound to charger and INDEVOLT state")
    checks += 1

    shell.setProperty("currentPage", 2)
    QTest.qWait(80)

    # Climate controls use the same settings/heater/MaxxFan command adapter.
    automation_before = snapshot()["climate"]["automation"]["enabled"]
    click(143, 296)
    if snapshot()["climate"]["automation"]["enabled"] is automation_before:
        raise AssertionError("Climate automation card did not update shared state")
    checks += 1

    heater_before = snapshot()["climate"]["heater"]["on"]
    click(400, 353)
    if snapshot()["climate"]["heater"]["on"] is heater_before:
        raise AssertionError("Autoterm start/stop card did not update shared state")
    checks += 1

    fan_before = snapshot()["climate"]["fan"]["on"]
    click(657, 353)
    if snapshot()["climate"]["fan"]["on"] is fan_before:
        raise AssertionError("MaxxFan card did not update shared state")
    checks += 1

    # Water has only freshwater data and the actual pump command.
    shell.setProperty("currentPage", 4)
    QTest.qWait(60)
    pump_before = snapshot()["water"]["pump"]["on"]
    click(592, 228)
    if snapshot()["water"]["pump"]["on"] is pump_before:
        raise AssertionError("Water-pump card did not update shared state")
    checks += 1

    # Settings remain reachable through System after the redundant header
    # settings icon becomes the always-visible close control.
    click(718, 433)
    if shell.property("currentPage") != 5:
        raise AssertionError("System navigation did not remain reachable")
    checks += 1

    close_count = {"value": 0}

    def on_close_requested():
        close_count["value"] += 1

    root.closeRequested.connect(on_close_requested)
    click(769, 30)
    if close_count["value"] != 1:
        raise AssertionError("Top-right V2 close control did not emit exactly one close request")
    checks += 1

    view.close()

print(f"SYNC Qt 5 V2 runtime: {checks} touch/state checks passed")
