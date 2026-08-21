"""Static contract for the native Qt 5 Transit Horizon V2 port."""

import hashlib
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper"

main = (QML / "CamperMain.qml").read_text(encoding="utf-8")
shell = (QML / "ModernShell.qml").read_text(encoding="utf-8")
lights = (QML / "V2LightsPage.qml").read_text(encoding="utf-8")
energy = (QML / "V2EnergyPage.qml").read_text(encoding="utf-8")
climate = (QML / "V2ClimatePage.qml").read_text(encoding="utf-8")
icon = (QML / "V2Icon.qml").read_text(encoding="utf-8")
overlay = (QML / "VehicleLightOverlay.qml").read_text(encoding="utf-8")
api = (QML / "ApiClient.qml").read_text(encoding="utf-8")
installer = (ROOT / "SyncMyMod" / "autoinstall.sh").read_text(encoding="utf-8")


def digest(name: str) -> str:
    return hashlib.sha256((QML / name).read_bytes()).hexdigest()


def transparent_corners(name: str) -> bool:
    image = Image.open(QML / name).convert("RGBA")
    corners = (
        image.getpixel((0, 0)),
        image.getpixel((image.width - 1, 0)),
        image.getpixel((0, image.height - 1)),
        image.getpixel((image.width - 1, image.height - 1)),
    )
    return all(pixel[3] == 0 for pixel in corners)


native_sources = "\n".join((shell, lights, energy, climate, icon))
light_zone_order = [lights.index('zone:"inside"'), lights.index('zone:"rear"'), lights.index('zone:"left"'), lights.index('zone:"right"')]
light_ids = (
    "inside_main",
    "outside_left",
    "outside_right",
    "outside_rear",
    "outside_front_white",
    "outside_front_amber",
)

checks = {
    "light matrix is inside/rear then left/right": light_zone_order == sorted(light_zone_order)
    and '{zone:"inside",name:"Innen",icon:"cabinLight",row:0,col:0}' in lights
    and '{zone:"rear",name:"Hinten",icon:"rearLight",row:0,col:1}' in lights
    and '{zone:"left",name:"Links",icon:"sideLeft",row:1,col:0}' in lights
    and '{zone:"right",name:"Rechts",icon:"sideRight",row:1,col:1}' in lights,
    "native QML has no browser or HTML embedding": not any(
        token in native_sources for token in ("WebEngine", "WebView", ".html")
    ),
    "V2 shell has the six prototype destinations": all(
        ('label:"' + label + '"') in shell
        for label in ("Home", "Licht", "Klima", "Energie", "Wasser", "System")
    ),
    "one production ApiClient remains shared": main.count("ApiClient {") == 1,
    "V2 pages receive shared snapshot and ApiClient": all(
        token in shell
        for token in (
            "V2LightsPage",
            "V2ClimatePage",
            "V2EnergyPage",
            "api: shell.api",
            "snapshot: shell.snapshot",
        )
    ),
    "runtime is V2-only": (
        main.count("ModernShell {") == 1
        and "designVersion" not in shell
        and "setDesignVersion" not in main
        and "LineIcon {" not in main
    ),
    "all six configured light IDs are used": all(light_id in lights for light_id in light_ids),
    "light cards and photo hotspots toggle real commands": (
        'api.command("starpower", "set"' in lights
        and "host.setFrontMode" in lights
        and lights.count("MouseArea") >= 13
    ),
    "light dimmer sends the existing dim command": 'api.command("starpower", "dim"' in lights,
    "high beam uses live output state and channel three fallback": (
        "highBeam.outputOnline" in lights
        and "highBeam.manualOn" in lights
        and "highBeam.vehicleOn" in lights
        and "highBeam.outputChannel || 3" in lights
    ),
    "exterior light bodies use shared normalized asset coordinates": all(
        token in overlay
        for token in (
            "[.3000, .1361, .5661, .1361]",
            "[.4696, .1000, .7125, .1139]",
            "[.6571,.0944,.0286,.0194]",
            "[.1125,.1139,.0286,.0194]",
            "[.7714,.0139,.0250,.0389]",
            "[.0768,.0139,.0250,.0389]",
            "lampBody(ctx",
            "roofBar(ctx",
        )
    ),
    "local commands are labelled SYNC without blocking Starlink": (
        'body.origin = "sync"' in api
        and 'origin === "vrm"' not in api
        and 'origin == "vrm"' not in api
    ),
    "vehicle-driven high beam is outlined and manual high beam is filled": (
        'color: highBeamCard.manualOn ? "#168fca"' in lights
        and "highBeamCard.vehicleOn && !highBeamCard.manualOn" in lights
    ),
    "driver image has the exact prototype second-door handle geometry": all(
        token in lights
        for token in (
            "355.8, 194",
            "357.8, 192.8, 362.3, 192.5, 364.7, 193.3",
            "356.5, 196.1",
            "visible: !view.rightView",
        )
    ),
    "five DC consumers map to the existing channels": all(
        token in energy
        for token in (
            'number:1,id:"dc_outlets_left"',
            'number:2,id:"water_pump"',
            'number:4,id:"dc_outlets_right"',
            'number:5,id:"starlink"',
            'number:6,id:"maxxfan_power"',
        )
    ),
    "230 V uses the existing inverter command": 'api.command("inverter", "set"' in energy,
    "energy cards avoid channel and online labels": 'text: "Online"' not in energy and 'text: "CH ' not in energy,
    "sources retain solar Orion and INDEVOLT": all(
        token in energy for token in ('source:"solar"', 'source:"orion"', 'source:"indevolt"')
    ),
    "unavailable Orion stays disabled and formatted as dashes": (
        "view.orion.online === true" in energy
        and "parent.available" in energy
        and '"–" + (suffix || "")' in energy
    ),
    "solar detail is live charger list plus INDEVOLT": (
        "property var chargers: solar.chargers || []" in energy
        and "chargerAt(index)" in energy
        and "indevoltCard: index === 3" in energy
    ),
    "Orion and INDEVOLT use established commands": (
        'api.command("orion", "set"' in energy
        and 'api.command("indevoltGrid", "set"' in energy
    ),
    "water page contains only fresh water and pump": (
        "Frischwasser" in shell
        and "Wasserpumpe" in shell
        and not any(label in shell for label in ("Abwasser", "Durchfluss", "Druck"))
    ),
    "climate uses established automation heater and MaxxFan commands": all(
        token in climate
        for token in (
            'api.command("settings", "patch"',
            'api.command("heater",',
            'api.command("maxxfan",',
        )
    ),
    "V2 background fills the complete 800 by 480 viewport": (
        "anchors.fill: parent" in shell
        and "radius: 0" in shell
        and 'radius: 25; color: "#030609"' not in shell
    ),
    "top-right V2 control closes through the shared host path": (
        'kind: "close"' in shell
        and "onClicked: shell.host.requestClose()" in shell
        and 'kind: "settings"' not in shell
    ),
    "Transit line symbol dark asset is the transparent FORD-grille build": (
        digest("transit-line-symbol-dark.png")
        == "f54f528af869c6f3cc2dec1a7b90ae730b6df1d431f67aeb55328ba1fd6aa605"
        and transparent_corners("transit-line-symbol-dark.png")
    ),
    "Transit line symbol light asset is the transparent FORD-grille build": (
        digest("transit-line-symbol-light.png")
        == "2b67063319cdb66767cca2229996b9e6161a849eddd6b0941fb5f984cf1a594f"
        and transparent_corners("transit-line-symbol-light.png")
    ),
    "driver photo matches prototype": digest("VehicleLightsLeft.png")
    == "fea43248c03588cb57d65da00788f429022b819c8e440731ea02136b33123dfe",
    "passenger photo matches prototype": digest("VehicleLightsRight.png")
    == "3439e784e263c051c5b229a37be863d6ef3295887315f76969a48f516337aaca",
    "installer rejects incomplete native V2 payloads": all(
        name in installer
        for name in (
            "V2Icon.qml",
            "V2Gauge.qml",
            "V2LightsPage.qml",
            "V2EnergyPage.qml",
            "V2ClimatePage.qml",
            "V2EdgePanels.qml",
            "VehicleLightOverlay.qml",
            "transit-line-symbol-dark.png",
            "transit-line-symbol-light.png",
        )
    ),
    "installer and app registration use release 3.12.1": (
        'VERSION="3.12.1"' in installer and '"appVersion":"3.12.1"' in installer
    ),
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC V2 Transit Horizon contract failed: " + ", ".join(failed))

print(f"SYNC V2 Transit Horizon contract: {len(checks)} checks passed")
