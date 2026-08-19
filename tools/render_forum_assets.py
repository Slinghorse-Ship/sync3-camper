"""Render the forum's SVG diagrams as broadly uploadable PNG files."""

from pathlib import Path

from PyQt5.QtCore import QSize
from PyQt5.QtGui import QGuiApplication, QImage, QPainter
from PyQt5.QtSvg import QSvgRenderer


ASSETS = Path(__file__).resolve().parents[3] / "outputs" / "forum-victron-community" / "assets"
app = QGuiApplication([])

for source in (ASSETS / "architecture-campercontrol.svg", ASSETS / "climate-control-flow.svg"):
    renderer = QSvgRenderer(str(source))
    size = renderer.defaultSize()
    image = QImage(QSize(size.width(), size.height()), QImage.Format_ARGB32)
    image.fill(0)
    painter = QPainter(image)
    renderer.render(painter)
    painter.end()
    target = source.with_suffix(".png")
    if not image.save(str(target)):
        raise RuntimeError(f"Could not write {target}")
    print(target)
