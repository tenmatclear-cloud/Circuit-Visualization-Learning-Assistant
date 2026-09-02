import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import schemdraw
import schemdraw.elements as elm

elm.style(elm.STYLE_IEC)

SKILL_SCRIPTS = Path.home() / ".cursor/skills/hk-circuit-diagram/scripts"
sys.path.insert(0, str(SKILL_SCRIPTS))
from incandescent_lamp import IncandescentLamp  # noqa: F401

INK = "#1c242a"
BG = "#ffffff"
out = Path(__file__).resolve().parent / "IMG_0359.jpg"
out.parent.mkdir(parents=True, exist_ok=True)

with schemdraw.Drawing(show=False, dpi=200) as d:
    d.config(color=INK, bgcolor=BG, lw=2.2, margin=0.55, inches_per_unit=0.65)
    sw = elm.Switch().right()
    bat = elm.Battery().right()
    top_j = elm.Dot()

    elm.Line().down().length(1).at(sw.start)
    elm.Resistor().down()
    left_j = elm.Dot()
    elm.Line().down().length(2.5)
    elm.Line().right().length(1.5)
    elm.Resistor().right()
    elm.Line().right().length(1.5)
    elm.Line().right().length(2.5)
    elm.Line().up().length(6.5)
    elm.Line().left().to(top_j.center)

    elm.Line().down().length(1).at(top_j.center)
    elm.Resistor().down()
    mid_j = elm.Dot()
    elm.Line().to(left_j.center)
    d.save(str(out), dpi=200, transparent=False)

print(out)
