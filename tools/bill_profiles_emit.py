"""Bill profiles for the rig, from the traced reference photos (tools/beak_profiles.py REFS).

    python tools/bill_profiles_emit.py [scripts/bird/bill_profiles.gd] [--ribs <png>]

Each species' traced lines (culmen, the upper bill's cutting edge = the gape line, the lower mandible's underside)
are scaled to millimetres by the bill's measured length, then to head radii by the life head's half-width
(docs/research/eyes_and_beaks.md 2.2; the rig's head is the same number of head radii, so the bill keeps its
proportion to the head), laid in the bill's frame (origin: the culmen's base, where the feathers end on its top;
x forward along the gape line, y up; the owl, with no gape seen: x along the base-to-tip chord) and cut into ribs:
for the upper bill, points along the culmen each paired with the cutting edge straight across from it (along the
culmen's inward normal, so the ribs turn with a raptor's hook); for the lower, points along its underside paired
with its cutting edge. Face.bill_meshes lofts its cross-sections between each rib's two ends.
Re-run after changing a trace; --ribs draws the ribs to check the pairing.
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from beak_profiles import REFS, ORDER, LIFE_R, ref_points

UPPER_RIBS = 36
LOWER_RIBS = 24


def dense(pts, step=0.01):
    """A polyline through `pts`, Catmull-Rom smoothed, at about `step` spacing."""
    p = [np.asarray(q, float) for q in pts]
    p = [p[0] * 2 - p[1]] + p + [p[-1] * 2 - p[-2]]
    out = []
    for i in range(1, len(p) - 2):
        a, b, c, d = p[i - 1], p[i], p[i + 1], p[i + 2]
        n = max(2, int(np.linalg.norm(c - b) / step))
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3))
    out.append(p[-2])
    out = np.array(out)
    # a light running mean (the traces are read off a grid), ends kept
    sm = out.copy()
    for i in range(2, len(out) - 2):
        sm[i] = out[i - 2:i + 3].mean(0)
    return sm


def arclen(p):
    s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))])
    return s


def at(p, s, x):
    """The point at arc length x along p."""
    x = np.clip(x, 0, s[-1])
    i = min(np.searchsorted(s, x, side="right") - 1, len(p) - 2)
    t = (x - s[i]) / max(s[i + 1] - s[i], 1e-12)
    return p[i] * (1 - t) + p[i + 1] * t


def ray_hit(o, d, p):
    """The arc position along polyline p of the first crossing of the ray o + t d (t > 0), or None."""
    s = arclen(p)
    best = None
    for i in range(len(p) - 1):
        a, b = p[i], p[i + 1]
        e = b - a
        m = np.array([[d[0], -e[0]], [d[1], -e[1]]])
        if abs(np.linalg.det(m)) < 1e-12:
            continue
        t, u = np.linalg.solve(m, a - o)
        if t > 1e-6 and -1e-9 <= u <= 1 + 1e-9:
            if best is None or t < best[0]:
                best = (t, s[i] + u * (s[i + 1] - s[i]))
    return None if best is None else best[1]


def ribs(driver, partner, n, side, turn=(0.4, 0.85)):
    """`n` ribs: points spaced along `driver` (denser toward the tip), each paired with where a line across from it
    meets `partner`: straight across the gape line (down for side -1, up for 1) over the bill's base, turning to the
    driver's own normal between `turn` (shares of its length) so the ribs follow a hook round; the partner's
    position held from running backward."""
    s = arclen(driver)
    ps = arclen(partner)
    out = []
    last = 0.0
    f0 = h0 = None
    for k in range(n):
        f = 1.0 - (1.0 - k / (n - 1)) ** 1.35
        c = at(driver, s, f * s[-1])
        e = 0.01 * s[-1]
        tng = at(driver, s, min(f * s[-1] + e, s[-1])) - at(driver, s, max(f * s[-1] - e, 0.0))
        tng /= max(np.linalg.norm(tng), 1e-12)
        nrm = np.array([tng[1], -tng[0]]) if side < 0 else np.array([-tng[1], tng[0]])
        w = np.clip((f - turn[0]) / max(turn[1] - turn[0], 1e-9), 0.0, 1.0)
        w = w * w * (3 - 2 * w)
        nrm = (1 - w) * np.array([0.0, float(side)]) + w * nrm
        nrm /= np.linalg.norm(nrm)
        h = ray_hit(c, nrm, partner) if k < n - 1 else ps[-1]
        if h is None:
            h = ps[-1] if f > 0.5 else last
        if w > 0.0:   # round the hook: the edge's remaining length shared out evenly to the tip
            if f0 is None:
                f0, h0 = f, max(h, last)
            g = (f - f0) / max(1.0 - f0, 1e-9)
            h = (1 - w) * h + w * (h0 + g * (ps[-1] - h0))
        h = max(h, last)
        last = h
        out.append((c, at(partner, ps, h)))
    return out


def frame(sp):
    r = REFS[sp]
    lines, eye, eye_r, base, tip, marks = ref_points(r)
    a, b, mm = r["mm"]
    pa = base if a == "base" else marks[a]
    pb = tip if b == "tip" else marks[b]
    k = mm / np.linalg.norm(pb - pa) / LIFE_R[sp]   # photo px -> head radii
    sgn = -1.0 if r.get("mirror") else 1.0
    if r["gape_line"]:
        g0, g1 = [np.array([sgn * p[0], -p[1]], float) for p in r["gape_line"]]
        ex = (g1 - g0) / np.linalg.norm(g1 - g0)
    else:
        ex = (tip - base) / np.linalg.norm(tip - base)
    ey = np.array([-ex[1], ex[0]])
    to = lambda p: np.array([np.dot(p - base, ex), np.dot(p - base, ey)]) * k
    return lines, to, {n: to(p) for n, p in marks.items()}, to(eye), eye_r * k


def curves(sp):
    """The species' curves in the bill frame (head radii): culmen, upper cutting edge, lower underside, lower
    cutting edge -- each running back to front."""
    lines, to, marks, eye, eye_r = frame(sp)
    T = lambda key, rev=False: [to(p) for p in (lines[key][::-1] if rev else lines[key])]
    cul = T("culmen")
    if sp == "owl":
        tom = T("under", True)
    else:
        tom = T("gape", True)
    if sp == "owl":
        # no lower mandible shows (it sits in the facial feathers): a thin one under the upper's front half
        d = dense(tom)
        d = d[d[:, 0] >= 0.0]   # (its cutting edge ahead of the culmen's base: the rest is in the face)
        s = arclen(d)
        lo_tom = [at(d, s, f * s[-1]) for f in np.linspace(0.0, 0.55, 8)]
        gon = [p + np.array([0.0, -0.05 * (1.0 - i / 7) ** 0.7 - 0.004]) for i, p in enumerate(lo_tom)]
        lo_tom = [p + np.array([0.0, -0.004]) for p in lo_tom]
    else:
        gon = T("under", True)   # (the sparrow's: its open jaw turned shut, ref_points)
        # the lower's cutting edge: the gape line back to front, as far as the lower's tip (the underside's end) -- the
        # bill shut, it meets the upper's
        d = dense(tom)
        end = np.argmin(np.linalg.norm(d - gon[-1], axis=1))
        lo_tom = list(d[:end + 1])
    return {"culmen": dense(cul), "tomium": dense(tom), "gonys": dense(gon), "lower_tomium": dense(lo_tom)}, marks, eye, eye_r


def build(sp):
    c, marks, eye, eye_r = curves(sp)
    turn = (0.0, 0.0) if sp == "owl" else (0.4, 0.85)   # (the owl's bill is all hook)
    up = ribs(c["culmen"], c["tomium"], UPPER_RIBS, -1, turn)
    lo = ribs(c["gonys"], c["lower_tomium"], LOWER_RIBS, 1, turn)
    return up, lo, c, marks, eye, eye_r


def fmt(v):
    return "%.4f" % v


def emit(path):
    out = ["# GENERATED by tools/bill_profiles_emit.py from the traced reference photos (tools/beak_profiles.py): do not edit.",
           "# Re-run it after changing a trace. Units: head radii. Frame: the culmen's base at the origin, x forward along the",
           "# gape line (the owl: the base-to-tip chord), y up. Ribs run base to tip: upper [culmen x, y, cutting edge x, y],",
           "# lower [underside x, y, cutting edge x, y]. Marks: the cere's end on the culmen, the bristles' end. Eye: the",
           "# reference eye's centre and radius in the same frame (for the face's layout).",
           "class_name BillProfiles", "extends RefCounted", "", "const DATA := {"]
    for sp in ORDER:
        up, lo, c, marks, eye, eye_r = build(sp)
        out.append('\t"%s": {' % sp)
        out.append('\t\t"upper": [%s],' % ", ".join("[%s]" % ", ".join(fmt(v) for v in (*a, *b)) for a, b in up))
        out.append('\t\t"lower": [%s],' % ", ".join("[%s]" % ", ".join(fmt(v) for v in (*a, *b)) for a, b in lo))
        out.append('\t\t"marks": {%s},' % ", ".join('"%s": [%s, %s]' % (k, fmt(v[0]), fmt(v[1])) for k, v in marks.items()))
        out.append('\t\t"eye": [%s, %s, %s],' % (fmt(eye[0]), fmt(eye[1]), fmt(eye_r)))
        out.append("\t},")
    out.append("}")
    open(path, "w", newline="\n").write("\n".join(out) + "\n")
    print("wrote", path)


def draw_ribs(png):
    from PIL import Image, ImageDraw
    W, H = 700, 420
    sheet = Image.new("RGB", (W * len(ORDER), H), (250, 250, 247))
    for i, sp in enumerate(ORDER):
        up, lo, c, marks, eye, eye_r = build(sp)
        pts = np.concatenate([np.array([p for r in up for p in r]), np.array([p for r in lo for p in r]), [eye]])
        lo_, hi_ = pts.min(0) - 0.1, pts.max(0) + 0.1
        k = min((W - 20) / (hi_[0] - lo_[0]), (H - 20) / (hi_[1] - lo_[1]))
        P = lambda p: (i * W + 10 + (p[0] - lo_[0]) * k, H - 10 - (p[1] - lo_[1]) * k)
        dr = ImageDraw.Draw(sheet)
        for name, col in [("culmen", (235, 110, 20)), ("tomium", (200, 60, 60)), ("gonys", (40, 110, 200)), ("lower_tomium", (40, 160, 160))]:
            dr.line([P(p) for p in c[name]], fill=col, width=2)
        for a, b in up:
            dr.line([P(a), P(b)], fill=(120, 120, 120), width=1)
        for a, b in lo:
            dr.line([P(a), P(b)], fill=(150, 150, 220), width=1)
        e = P(eye)
        dr.ellipse([e[0] - eye_r * k, e[1] - eye_r * k, e[0] + eye_r * k, e[1] + eye_r * k], outline=(0, 0, 0))
        dr.text((i * W + 12, 8), sp, fill=(0, 0, 0))
    sheet.save(png)
    print("wrote", png)


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--ribs" in args:
        i = args.index("--ribs")
        draw_ribs(args[i + 1])
        del args[i:i + 2]
    emit(args[0] if args else "scripts/bird/bill_profiles.gd")
