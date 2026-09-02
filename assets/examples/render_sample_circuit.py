#!/usr/bin/env python3
"""Render a textbook-style series-lamp circuit as JPEG for student download.

Requires: pip install "schemdraw[matplotlib]"
"""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import schemdraw
import schemdraw.elements as elm
from schemdraw.elements.elements import Element2Term, gap
from schemdraw.segments import Segment, SegmentArc, SegmentCircle

OUT = Path(__file__).with_name("sample-circuit.jpg")
INK = "#1c242a"
BG = "#fffcf6"


class IncandescentLamp(Element2Term):
    """Circle with an upward filament arch, matching the textbook incandescent symbol."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.segments.append(Segment([(0, 0), (0, 0), gap, (1, 0), (1, 0)]))
        self.segments.append(SegmentCircle((0.5, 0), 0.5))
        self.segments.append(SegmentArc((0.5, 0), width=0.72, height=0.72, theta1=0, theta2=180))


def main():
    with schemdraw.Drawing(show=False, dpi=200) as d:
        d.config(
            color=INK,
            bgcolor=BG,
            lw=2.2,
            margin=0.55,
            inches_per_unit=0.65,
        )

        # Top: switch on the battery positive (long plate), then battery.
        # Bottom: two lamps in series, drawn left-to-right so the filament arch stays up.
        switch = elm.Switch().right()
        battery = elm.Battery().right()
        elm.Line().down().at(switch.start)
        IncandescentLamp().right()
        IncandescentLamp().right()
        elm.Line().to(battery.end)

        d.save(str(OUT), dpi=200, transparent=False)

    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
