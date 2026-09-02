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
out = Path(__file__).resolve().parent / "IMG_0358.jpg"
out.parent.mkdir(parents=True, exist_ok=True)

with schemdraw.Drawing(show=False, dpi=200) as d:
    d.config(color=INK, bgcolor=BG, lw=2.2, margin=0.55, inches_per_unit=0.65)
    sw = elm.Switch().right()
    bat = elm.Battery().right()

    elm.Line().down().at(sw.start)
    elm.Resistor().right()
    a = elm.Dot()
    elm.Line().up().length(1.2)
    elm.Resistor().right()
    elm.Line().down().length(1.2)
    b = elm.Dot()
    elm.Line().down().length(1.2).at(a.center)
    elm.Resistor().right()
    elm.Line().up().to(b.center)
    elm.Line().right().length(1.5)
    elm.Line().up().toy(bat.end)
    elm.Line().to(bat.end)
    d.save(str(out), dpi=200, transparent=False)

print(out)
