import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import schemdraw
import schemdraw.elements as elm

elm.style(elm.STYLE_IEC)

SKILL_SCRIPTS = Path.home() / ".cursor/skills/hk-circuit-diagram/scripts"
sys.path.insert(0, str(SKILL_SCRIPTS))
from incandescent_lamp import IncandescentLamp

INK = "#1c242a"
BG = "#ffffff"
out = Path(__file__).resolve().parent / "IMG_0354.jpg"
out.parent.mkdir(parents=True, exist_ok=True)

with schemdraw.Drawing(show=False, dpi=200) as d:
    d.config(color=INK, bgcolor=BG, lw=2.2, margin=0.55, inches_per_unit=0.65)
    sw = elm.Switch().right()
    bat = elm.Battery().right()

    elm.Line().down().at(sw.start)
    l1 = IncandescentLamp().right()
    l2 = IncandescentLamp().right().at(l1.start, dy=-2.2)
    elm.Line().at(l1.end).toy(l2.end)
    elm.Line().to(l2.end)
    l3 = IncandescentLamp().right().at(l2.start, dy=-2.2)
    elm.Line().at(l2.start).toy(l3.start)
    elm.Line().to(l3.start)
    elm.Line().at(l3.end).tox(bat.end)
    elm.Line().to(bat.end)
    d.save(str(out), dpi=200, transparent=False)

print(out)
