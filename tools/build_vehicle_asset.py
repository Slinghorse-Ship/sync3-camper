import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--source", type=Path, default=ROOT / "reference" / "VehicleLights-2left-2right-1rear-transparent.png")
parser.add_argument("--output", type=Path, default=ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper" / "VehicleLights.png")
args = parser.parse_args()
SOURCE = args.source
OUTPUT = args.output

image = Image.open(SOURCE).convert("RGBA")
bounds = image.getchannel("A").getbbox()
if bounds is None:
    raise RuntimeError("Vehicle source is fully transparent")

image = image.crop(bounds)
image.thumbnail((548, 348), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (560, 360), (0, 0, 0, 0))
canvas.alpha_composite(image, ((560 - image.width) // 2, (360 - image.height) // 2))
canvas.save(OUTPUT, optimize=True)
print(f"Wrote {OUTPUT} ({image.width}x{image.height} on 560x360)")
