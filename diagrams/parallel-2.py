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
out = Path(__file__).resolve().parent / "IMG_0356.jpg"
out.parent.mkdir(parents=True, exist_ok=True)

with schemdraw.Drawing(show=False, dpi=200) as d:
    d.config(color=INK, bgcolor=BG, lw=2.2, margin=0.55, inches_per_unit=0.65)
    bat = elm.Battery().down()
    elm.Line().right().at(bat.start).length(3)
    p1 = elm.Dot()
    elm.Resistor().down()
    q1 = elm.Dot()
    elm.Line().right().at(p1.center).length(2)
    p2 = elm.Dot()
    elm.Resistor().down()
    q2 = elm.Dot()
    elm.Line().right().at(p2.center).length(2)
    p3 = elm.Dot()
    elm.Resistor().down()
    q3 = elm.Dot()
    elm.Line().at(q3.center).to(q2.center)
    elm.Line().to(q1.center)
    elm.Switch().at(bat.end).to(q1.center)
    d.save(str(out), dpi=200, transparent=False)

print(out)
