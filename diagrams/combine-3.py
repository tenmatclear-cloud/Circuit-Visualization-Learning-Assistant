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
out = Path(__file__).resolve().parent / "IMG_0360.jpg"
out.parent.mkdir(parents=True, exist_ok=True)

with schemdraw.Drawing(show=False, dpi=200) as d:
    d.config(color=INK, bgcolor=BG, lw=2.2, margin=0.55, inches_per_unit=0.65)
    tl = elm.Dot()
    elm.Resistor().right().length(6)
    elm.Resistor().down()
    mr = elm.Dot()
    elm.Resistor().left().length(6)
    ml = elm.Dot()
    elm.Resistor().up()
    elm.Resistor().endpoints(tl.center, mr.center)
    elm.Line().down().at(ml.center)
    elm.Switch().right()
    elm.Battery().right()
    elm.Line().up().to(mr.center)
    d.save(str(out), dpi=200, transparent=False)

print(out)
