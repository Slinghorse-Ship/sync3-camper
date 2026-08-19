"""Build transparent day/night Transit header symbols.

The original V2 mockup crops contain the correct Transit perspective but also
contain the mockup background.  This keeps that geometry pixel-for-pixel,
derives a soft alpha mask from the source contrast and replaces only the tiny
front grille insert with a block-letter FORD grille.
"""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "reference"
OUTPUT = ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper"


def smoothstep(value: float, low: float, high: float) -> int:
    position = max(0.0, min(1.0, (value - low) / (high - low)))
    eased = position * position * (3.0 - 2.0 * position)
    return round(eased * 255)


def add_raptor_grille(image: Image.Image) -> None:
    """Draw a compact four-letter grille that survives the 63x40 UI size."""

    draw = ImageDraw.Draw(image, "RGBA")
    # This inset stays inside the existing perspective-correct grille outline.
    draw.polygon(((107, 55), (136, 55), (136, 68), (106, 68)), fill=(6, 13, 17, 238))

    glyphs = {
        "F": ("111", "100", "110", "100", "100"),
        "O": ("111", "101", "101", "101", "111"),
        "R": ("110", "101", "110", "101", "101"),
        "D": ("110", "101", "101", "101", "110"),
    }
    x = 108
    for letter in "FORD":
        for row, pixels in enumerate(glyphs[letter]):
            for column, pixel in enumerate(pixels):
                if pixel == "1":
                    draw.rectangle(
                        (x + column * 2, 56 + row * 2, x + column * 2 + 1, 57 + row * 2),
                        fill=(239, 247, 251, 255),
                    )
        x += 7


def build(source_name: str, output_name: str, day: bool) -> None:
    source = Image.open(REFERENCE / source_name).convert("RGB")
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    target_pixels = result.load()

    for y in range(source.height):
        for x in range(source.width):
            red, green, blue = source_pixels[x, y]
            luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            if day:
                # Empty source pixels sit at roughly #f9f9f9. Dark outlines,
                # cyan glass accents and the soft body shading remain visible.
                contrast = max(0.0, 249.0 - luminance)
                alpha = smoothstep(contrast, 4.0, 42.0)
            else:
                # Empty source pixels remain below ~18 luma throughout the
                # crop; the Transit body starts just above it and linework is
                # considerably brighter.
                alpha = smoothstep(luminance, 17.0, 72.0)
            target_pixels[x, y] = (red, green, blue, alpha)

    add_raptor_grille(result)
    output = OUTPUT / output_name
    result.save(output, "PNG", optimize=True)
    print(f"Wrote {output} ({result.width}x{result.height}, RGBA)")


build("transit-line-symbol-dark-source.png", "transit-line-symbol-dark.png", day=False)
build("transit-line-symbol-light-source.png", "transit-line-symbol-light.png", day=True)
