"""Geometry contract for both 800x480 SYNC V2 energy panes."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
qml = (ROOT / "SyncMyMod/files/app/Jan/Camper/V2EnergyPage.qml").read_text(encoding="utf-8")
shell = (ROOT / "SyncMyMod/files/app/Jan/Camper/ModernShell.qml").read_text(encoding="utf-8")


def overlaps(first, second):
    ax, ay, aw, ah = first
    bx, by, bw, bh = second
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


power_model = re.search(r'model: \[\s*(\{number:1,.*?\{number:6,.*?)\s*\]', qml, re.S)
if not power_model:
    raise AssertionError("12/230-V geometry model is missing")
coordinates = [tuple(map(int, match)) + (151, 122) for match in re.findall(r'x:(\d+),y:(\d+)', power_model.group(1))]
if len(coordinates) != 5:
    raise AssertionError(f"Expected five power cards, got {len(coordinates)}")
if any(x < 0 or y < 0 or x + width > 497 or y + height > 277 for x, y, width, height in coordinates):
    raise AssertionError("A power card leaves its 497x277 container")
if any(overlaps(coordinates[a], coordinates[b]) for a in range(5) for b in range(a + 1, 5)):
    raise AssertionError("12/230-V power cards overlap")

sources = [(0, 0, 247, 277), (256, 0, 247, 277), (512, 0, 250, 277)]
if any(overlaps(sources[a], sources[b]) for a in range(3) for b in range(a + 1, 3)):
    raise AssertionError("Energy source cards overlap")
if sources[-1][0] + sources[-1][2] != 762:
    raise AssertionError("Energy source cards do not fill the 762-pixel viewport")

checks = {
    "energy page uses the unscaled 762x326 shell viewport": (
        "V2EnergyPage { id: energyPage; x: 19; y: 65; width: 762; height: 326" in shell
        and "scale:" not in qml
    ),
    "both pane containers are 762x277 at y49": (
        qml.count('x: 0; y: 49; width: 762; height: 277; visible: view.pane ===') == 3
        and 'objectName: "v2EnergyPowerPane"' in qml
        and 'objectName: "v2EnergySourcesPane"' in qml
    ),
    "power and inverter cards use the full width with a nine-pixel gap": (
        'objectName: "v2PowerChannelsCard"; x: 0; y: 0; width: 497; height: 277' in qml
        and 'x: 506; y: 0; width: 256; height: 277' in qml
    ),
    "source cards use equal gaps and bounded widths": all(
        token in qml for token in (
            '{source:"solar",x:0,w:247',
            '{source:"orion",x:256,w:247',
            '{source:"indevolt",x:512,w:250',
        )
    ),
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    raise AssertionError("SYNC V2 energy geometry failed: " + ", ".join(failed))

print(f"SYNC V2 energy geometry: {len(checks)} checks, no overlaps, exact 800x480 fit")
