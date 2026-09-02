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
out = Path(__file__).resolve().parent / "IMG_0357.jpg"
out.parent.mkdir(parents=True, exist_ok=True)

with schemdraw.Drawing(show=False, dpi=200) as d:
    d.config(color=INK, bgcolor=BG, lw=2.2, margin=0.55, inches_per_unit=0.65)
    elm.Line().right().length(1.5)
    elm.Resistor().right()
    elm.Line().right().length(1.5)
    elm.Line().down().length(2)
    jr = elm.Dot()
    elm.Line().down().length(2)
    elm.Line().left().length(1.5)
    elm.Resistor().left()
    elm.Line().left().length(1.5)
    elm.Line().up().length(2)
    jl = elm.Dot()
    elm.Line().up().length(2)
    elm.Switch().right().at(jl.center)
    elm.Battery().right()
    elm.Line().to(jr.center)
    d.save(str(out), dpi=200, transparent=False)

print(out)
