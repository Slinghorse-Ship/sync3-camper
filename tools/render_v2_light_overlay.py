#!/usr/bin/env python3
"""Render the two 800x480 all-on coordinate proofs without a Qt dependency."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
QML = ROOT / "SyncMyMod/files/app/Jan/Camper"
REFERENCE = ROOT / "reference"
STAGE = (19, 65, 453, 326)

GEOMETRY = {
    "driver": {
        "asset": "VehicleLightsLeft.png",
        "front": (.3000, .1361, .5661, .1361),
        "side": ((.6571, .0944, .0286, .0194), (.8107, .0972, .0304, .0194)),
        "rear": (.7714, .0139, .0250, .0389),
    },
    "passenger": {
        "asset": "VehicleLightsRight.png",
        "front": (.4696, .1667, .7196, .1806),
        "side": ((.1125, .1139, .0286, .0194), (.2625, .1111, .0304, .0194)),
        "rear": (.0768, .0139, .0250, .0389),
    },
}


def source_transform() -> tuple[float, float, float]:
    _, _, width, height = STAGE
    scale = min(width / 560, height / 360)
    return (STAGE[0] + (width - 560 * scale) / 2, STAGE[1] + (height - 360 * scale) / 2, scale)


def point(x: float, y: float) -> tuple[float, float]:
    left, top, scale = source_transform()
    return (left + x * 560 * scale, top + y * 360 * scale)


def rectangle(value: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    x, y = point(value[0], value[1])
    _, _, scale = source_transform()
    return (x, y, x + value[2] * 560 * scale, y + value[3] * 360 * scale)


def draw_lights(canvas: Image.Image, geometry: dict[str, object]) -> None:
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    start = point(*geometry["front"][:2])
    end = point(*geometry["front"][2:])
    glow_draw.line((start, end), fill=(73, 174, 244, 235), width=8)
    for body in geometry["side"]:
        glow_draw.rounded_rectangle(rectangle(body), radius=2, fill=(235, 249, 255, 245))
    glow_draw.rectangle(rectangle(geometry["rear"]), fill=(235, 249, 255, 245))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(4)))

    bodies = ImageDraw.Draw(canvas)
    bodies.line((start, end), fill=(250, 253, 255, 255), width=4)
    for body in geometry["side"]:
        bodies.rounded_rectangle(rectangle(body), radius=2, fill=(250, 253, 255, 255))
    bodies.rectangle(rectangle(geometry["rear"]), fill=(250, 253, 255, 255))


def render(name: str, geometry: dict[str, object]) -> Path:
    canvas = Image.new("RGBA", (800, 480), "#0d1722")
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((19, 65, 471, 390), radius=17, fill="#101b26", outline="#344554")
    asset = Image.open(QML / str(geometry["asset"])).convert("RGBA")
    scale = min(STAGE[2] / asset.width, STAGE[3] / asset.height)
    rendered = asset.resize((round(asset.width * scale), round(asset.height * scale)), Image.Resampling.LANCZOS)
    left = STAGE[0] + (STAGE[2] - rendered.width) // 2
    top = STAGE[1] + (STAGE[3] - rendered.height) // 2
    canvas.alpha_composite(rendered, (left, top))
    draw_lights(canvas, geometry)

    draw.rounded_rectangle((481, 65, 781, 390), radius=17, fill="#101b26", outline="#344554")
    draw.text((501, 90), "ALL-ON OVERLAY QA", fill="#e7eef4")
    draw.text((501, 120), "Roof-Bar / Seiten / Heck", fill="#8da0ad")
    draw.text((501, 145), "nur auf Lampenkoerpern", fill="#59caff")
    draw.text((501, 345), "800 x 480  |  " + name, fill="#8da0ad")
    draw.rounded_rectangle((19, 401, 781, 465), radius=18, fill="#101b26", outline="#344554")
    draw.text((44, 425), "CamperControl V2 Lichtkoordinaten", fill="#e7eef4")

    output = REFERENCE / f"CamperControl-v3.12-v2-lights-{name}-all-on.png"
    canvas.convert("RGB").save(output, optimize=True)
    return output


def main() -> int:
    REFERENCE.mkdir(exist_ok=True)
    for name, geometry in GEOMETRY.items():
        print(render(name, geometry))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
