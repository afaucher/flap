"""Charts of our oaks (tools/oak_form.py --json) against real oaks' ranges (docs/research/oak_form.md): each panel a
measure, our limbs as dots (one row per oak), the real range as a band.

Usage: python tools/oak_chart.py <oak_form.json> <out.png>
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

# Real oaks' ranges, from docs/research/oak_form.md (the grade there): [low, high, label].
REAL = {
    "spread": [1.5, 6.0, "fork + 1-4 laterals 0.5-2 m apart below it [E]; arborists' ideal: scaffolds 1.2 m+ apart [S]"],
    "at_fork": [2.0, 3.0, "a fork of 2 (55%), 3 (35%), rarely 4 stems [E]; several from one point is the weak 'multiple attachment' [S]"],
    "tort": [1.05, 1.15, "scaffold path / chord 1.05-1.15 [E] (no measured value exists)"],
    "bends": [3.0, 10.0, "a 10-25 deg change every 1-3 m, plus ~1 elbow of 30-50 deg [E]"],
    "straight": [1.0, 3.0, "1-3 m between direction changes [E]"],
    "lean": [20.0, 100.0, "fork stems 20-45, laterals 50-75, lowest 70-100 deg [E]"],
    "reach": [0.6, 1.0, "upper scaffolds 0.6-0.9, the low laterals (the longest) to the edge [E]"],
    "ratio": [0.25, 0.55, "laterals 0.25-0.55 [E]; < 0.5 for a collar [S]; fork stems 0.6-0.95, but only 2-3 of them"],
    "pipe": [0.9, 1.1, "Leonardo exponent 1.8-2.3 [S] -> daughters' area 0.9-1.1x [E]"],
    "side_gap": [1.0, 4.0, "a fork or side branch every 1-4 m along a scaffold [E/G]"],
}

W, ROW, PAD, LEFT = 1500, 34, 18, 300
BG, INK, BAND, DOT, LOW = (250, 248, 243), (40, 36, 30), (150, 200, 140), (120, 70, 35), (60, 110, 170)


def font(size):
    for name in ("arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def panel(d, y, title, real, rows, lo, hi, unit, note=""):
    """rows: [(label, [values], [colours])]"""
    f, fs = font(17), font(13)
    d.text((PAD, y), title, fill=INK, font=f)
    if note:
        d.text((PAD, y + 20), note, fill=(110, 100, 90), font=fs)
    top = y + 44
    x0, x1 = LEFT, W - 60
    sx = lambda v: x0 + (min(max(v, lo), hi) - lo) / (hi - lo) * (x1 - x0)
    h = ROW * len(rows)
    if real:
        d.rectangle([sx(real[0]), top - 4, sx(real[1]), top + h], fill=BAND)
        d.text((sx(real[0]) + 4, top + h + 2), "real: " + real[2], fill=(60, 110, 50), font=fs)
    for k in range(6):
        v = lo + (hi - lo) * k / 5
        d.line([sx(v), top + h, sx(v), top + h + 5], fill=INK)
        d.text((sx(v) - 12, top + h + 18), ("%g" % round(v, 2)) + unit, fill=INK, font=fs)
    d.line([x0, top + h, x1, top + h], fill=INK)
    for i, (label, vals, cols) in enumerate(rows):
        cy = top + i * ROW + ROW // 2
        d.text((PAD, cy - 8), label, fill=INK, font=fs)
        for v, c in zip(vals, cols):
            d.ellipse([sx(v) - 6, cy - 6, sx(v) + 6, cy + 6], fill=c, outline=(255, 255, 255))
    return top + h + 46


def main():
    res = json.load(open(sys.argv[1]))
    oaks = res["oaks"]
    img = Image.new("RGB", (W, 2900), BG)
    d = ImageDraw.Draw(img)
    d.text((PAD, 10), "Our oaks (measured from the drawn wood, seed 7) against real oaks", fill=INK, font=font(24))
    d.text((PAD, 40), "dots: our first-order limbs, a row per oak (brown: out of the fork, blue: the low limbs under it); green band: real oaks",
           fill=(110, 100, 90), font=font(14))
    y = 80
    col = lambda f: LOW if f["lean"] > 75 else DOT
    rows = [("oak %d (dbh %.1f m)" % (o["id"], o["dbh"]), [f["y"] - o["first"][0]["y"] for f in o["first"]], [col(f) for f in o["first"]]) for o in oaks]
    y = panel(d, y, "1  Where the first-order limbs leave the trunk (m above the lowest)", REAL["spread"], rows, 0, 10, " m",
              "ours: 9-10 limbs within 1.7 m, 6-9 of them within 1 m of the fork")
    rows = [("oak %d" % o["id"], [sum(1 for f in o["first"] if abs(f["rel_y"]) <= 0.5)], [DOT]) for o in oaks]
    y = panel(d, y, "2  Limbs leaving within +-0.5 m of the fork", REAL["at_fork"], rows, 0, 10, "")
    rows = [("oak %d" % o["id"], [f["tort"] for f in o["first"]], [col(f) for f in o["first"]]) for o in oaks]
    y = panel(d, y, "3  Straightness: each limb's main axis, path length / straight-line length", REAL["tort"], rows, 1.0, 1.6, "")
    rows = [("oak %d" % o["id"], [f["bends"] / max(f["arc"], 0.1) * 10 for f in o["first"]], [col(f) for f in o["first"]]) for o in oaks]
    y = panel(d, y, "4  Direction changes over 10 deg (metre to metre), per 10 m of limb", REAL["bends"], rows, 0, 12, "")
    rows = [("oak %d" % o["id"], [f["straight"] for f in o["first"]], [col(f) for f in o["first"]]) for o in oaks]
    y = panel(d, y, "4b The longest dead-straight run along each limb (within 2 deg)", REAL["straight"], rows, 0, 12, " m",
              "ours: every piece has an exactly straight middle (the perch, _limb's span) and bends only at its ends")
    rows = [("oak %d" % o["id"], [f["lean"] for f in o["first"]], [col(f) for f in o["first"]]) for o in oaks]
    y = panel(d, y, "5  Angle each limb leaves at, from the vertical (its first metre)", REAL["lean"], rows, 0, 110, " deg")
    rows = [("oak %d" % o["id"], [f["reach_crown"] for f in o["first"]], [col(f) for f in o["first"]]) for o in oaks]
    y = panel(d, y, "6  Each limb's reach / the crown's radius", REAL["reach"], rows, 0, 1.1, "")
    rows = [("oak %d" % o["id"], [f["ratio"] for f in o["first"]], [col(f) for f in o["first"]]) for o in oaks]
    y = panel(d, y, "7  Limb diameter where it leaves / the trunk's (collar left out)", REAL["ratio"], rows, 0, 1.0, "")
    rows = [("oak %d" % o["id"], [p for f in o["first"] for p in f["pipes"]], [col(f) for f in o["first"] for p in f["pipes"]]) for o in oaks]
    y = panel(d, y, "8  At each joint along a limb: daughters' cross-section / the parent's", REAL["pipe"], rows, 0.5, 3.0, "",
              "ours 1.4 at the first joint, 2.6 at the second: the limbs thicken where they fork")
    rows = []
    for o in oaks:
        gaps = []
        for f in o["first"]:
            gaps.append(f["arc"] / max(f["n_side"], 0.5))
        rows.append(("oak %d" % o["id"], gaps, [col(f) for f in o["first"]]))
    y = panel(d, y, "9  Metres of limb per side branch (twigs left out; twigs are only at the pieces' tips)", REAL["side_gap"], rows, 0, 16, " m")
    img.crop((0, 0, W, y + 10)).save(sys.argv[2])
    print("wrote", sys.argv[2])


if __name__ == "__main__":
    main()
