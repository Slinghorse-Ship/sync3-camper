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

    shell = root.findChild(QObject, "modernShell")
    lights_page = root.findChild(QObject, "v2LightsPage")
    energy_page = root.findChild(QObject, "v2EnergyPage")
    api = root.findChild(QObject, "camperApiClient")
    if None in (shell, lights_page, energy_page, api):
        raise AssertionError("The V2 shell, pages or shared ApiClient were not instantiated")
    if view.width() != 800 or view.height() != 480:
        raise AssertionError("The GX Touch/SYNC reference viewport is not 800x480")

    def snapshot() -> dict:
        value = root.property("snapshot")
        return value.toVariant() if hasattr(value, "toVariant") else value

    def click(x: int, y: int) -> None:
        QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, QPoint(x, y))
        QTest.qWait(100)

    checks = 0

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

    view.close()

print(f"SYNC Qt 5 V2 runtime: {checks} touch/state checks passed")
