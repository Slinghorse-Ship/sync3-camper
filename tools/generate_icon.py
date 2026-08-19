from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "reference" / "TransitIcon-transparent-large.png"
OUTPUT = ROOT / "SyncMyMod" / "files" / "app" / "Jan" / "Camper" / "Icon.png"

CANVAS_SIZE = 256
# A small safety margin prevents the white outline touching the launcher tile.
CONTENT_WIDTH = 236


source = Image.open(SOURCE).convert("RGBA")
bounds = source.getchannel("A").getbbox()
if bounds is None:
    raise RuntimeError(f"Icon source has no visible pixels: {SOURCE}")

content = source.crop(bounds)
target_height = round(content.height * CONTENT_WIDTH / content.width)
content = content.resize((CONTENT_WIDTH, target_height), Image.Resampling.LANCZOS)

icon = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
x = (CANVAS_SIZE - content.width) // 2
y = (CANVAS_SIZE - content.height) // 2
icon.alpha_composite(content, (x, y))

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
icon.save(OUTPUT, "PNG", optimize=True)
print(f"{OUTPUT} ({content.width}x{content.height} visible content)")
