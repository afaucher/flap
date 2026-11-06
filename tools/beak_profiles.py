"""Beak profiles: each species' beak as the rig builds it, against a side-on reference photo traced by hand.

    python tools/beak_profiles.py <ours.json> <out.jpg>

<ours.json> comes from tests/probe_beak_profile.gd. Two panels per species:
  left  -- the face: ours filled (head grey, the bill's outside dark, its lower bill lighter, the eye a ring), the
           reference's outline over it in orange: the photo scaled by the species' measured bill to our head's size
           (life size x our head radius / the life head's, LIFE_R: the rig's heads are a little over life size),
           its gape line laid along ours and its culmen's base (where the feathers end on the bill's top) on ours
           (Face.bill_base), so the bill's length, depth, pitch and hook, and the eye's place, read against the head;
  right -- the bill alone, both scaled so the chord from the culmen's base to the tip is 1 and laid along it:
           its shape (depth, the culmen's curve, the hook) whatever its length.
Traces are in each photo's pixels (Wikimedia Commons, at 1600 px wide), x right, y down; `mirror` for a bird
facing left. A trace is approximate: a few pixels on the grid at 1-2x zoom, feathers hiding the bill's base.
The same traces make the rig's bills (tools/bill_profiles_emit.py -> scripts/bird/bill_profiles.gd) and the
expected profile in tests/test_bill_profile.gd.
"""
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

REFS = {
    "crow": {
        "mm": ("base", "tip", 47.0), "gape_line": ((905, 485), (1300, 410)),
        "src": "File:AMERICAN CROW.jpg (cuatrok77 hernandez, CC BY 2.0)",
        "eye": (765, 470, 40), "base": (855, 295), "tip": (1428, 410),
        "lines": {
            "culmen": [(855, 295), (900, 305), (950, 312), (1000, 308), (1050, 307), (1100, 308), (1150, 310), (1200, 314),
                       (1250, 322), (1300, 333), (1350, 350), (1390, 370), (1415, 392), (1428, 410)],
            "gape": [(1425, 408), (1300, 410), (1200, 418), (1100, 430), (1000, 445), (940, 465), (905, 485)],
            "under": [(1420, 412), (1390, 420), (1350, 430), (1300, 440), (1250, 452), (1200, 465), (1150, 478), (1100, 492),
                      (1050, 510), (1000, 530), (950, 548), (920, 560)],
            "head": [(880, 296), (800, 270), (700, 250), (600, 244), (500, 256), (400, 290), (300, 360), (200, 460), (120, 580)],
            "throat": [(920, 560), (860, 620), (820, 700), (780, 800), (765, 900)],
        },
        "marks": {"bristles end": (1060, 307)},
    },
    "sparrow": {
        "mm": ("base", "tip", 12.0), "gape_line": ((470, 440), (140, 460)),
        "src": "File:Passer domesticus male head (Germany).jpg (Thorsten Denhard, CC BY-SA 3.0); bill open: the lower mandible turned shut",
        "mirror": True,
        "eye": (680, 290, 50), "base": (380, 290), "tip": (102, 482),
        "lines": {
            "culmen": [(380, 290), (360, 302), (330, 312), (300, 325), (270, 340), (240, 360), (210, 380), (180, 405), (150, 430),
                       (120, 460), (102, 482)],
            "gape": [(102, 482), (140, 460), (180, 448), (230, 438), (280, 425), (330, 412), (360, 405), (470, 440)],
            "head": [(380, 260), (460, 200), (560, 160), (700, 124), (840, 116), (1000, 124), (1160, 160), (1280, 220), (1380, 320)],
            "throat": [(420, 600), (460, 700), (520, 840), (560, 960)],
        },
        # the lower mandible as photographed (open): tomium from the tip back, underside from the tip back
        "open_lower": {"tomium": [(160, 620), (210, 590), (260, 560), (310, 530), (360, 505), (410, 485), (460, 472), (510, 465)],
                       "under": [(160, 620), (170, 622), (230, 612), (280, 604), (340, 595), (390, 585), (420, 580)],
                       "to": [(110, 486), (470, 440)]},   # its tip and back tomium point, shut: under the upper's tip, at the rictus
        "marks": {},
    },
    "hawk": {
        "mm": ("cere ends", "tip", 26.0), "gape_line": ((1130, 595), (1300, 650)),
        "src": "File:Red-tailed hawk (44371).jpg (Rhododendrites, CC BY-SA 4.0)",
        "eye": (730, 410, 100), "base": (1130, 362), "tip": (1338, 768),
        "lines": {
            "culmen": [(1130, 362), (1170, 368), (1210, 385), (1240, 405), (1255, 425), (1280, 440), (1305, 460), (1325, 485),
                       (1345, 515), (1360, 545), (1372, 580), (1380, 620), (1383, 660), (1380, 690), (1370, 720), (1355, 745), (1338, 768)],
            "gape": [(1338, 768), (1340, 760), (1330, 720), (1322, 680), (1310, 655), (1300, 650), (1270, 645), (1230, 635),
                     (1180, 620), (1130, 595), (1050, 580), (950, 580), (850, 595), (820, 600)],
            "under": [(1310, 662), (1300, 668), (1260, 660), (1220, 650), (1180, 640), (1140, 628), (1100, 622)],
            "head": [(1120, 300), (1080, 240), (960, 180), (800, 130), (600, 96), (400, 120), (260, 200), (120, 340), (20, 460)],
            "throat": [(1100, 622), (1060, 740), (1000, 820), (960, 940), (940, 1040)],
        },
        "marks": {"cere ends": (1255, 425)},
    },
    "falcon": {
        "mm": ("cere ends", "tip", 14.5), "gape_line": ((982, 525), (1045, 537)),
        "src": "File:Turmfalke in Berlin-Spandau (DSCF0410).jpg (Andrea014, CC BY-SA 4.0); Common Kestrel, adult male",
        "eye": (895, 395, 45), "base": (1000, 425), "tip": (1056, 589),
        "lines": {
            "culmen": [(1000, 425), (1010, 432), (1025, 445), (1035, 460), (1045, 472), (1048, 476), (1055, 482), (1062, 490),
                       (1069, 500), (1073, 512), (1075, 525), (1075, 540), (1072, 555), (1067, 570), (1061, 582), (1056, 589)],
            "gape": [(1056, 589), (1057, 585), (1056, 570), (1055, 555), (1052, 545), (1045, 537), (1020, 532), (995, 528), (982, 525)],
            "under": [(1050, 548), (1030, 552), (1010, 550), (997, 545)],
            "head": [(980, 430), (950, 360), (910, 300), (840, 256), (740, 244), (620, 256), (520, 300), (470, 380), (430, 500)],
            "throat": [(997, 545), (990, 560), (980, 600), (960, 640), (940, 690)],
        },
        "marks": {"cere ends": (1048, 476)},
    },
    "owl": {
        "mm": ("base", "tip", 16.0), "gape_line": None,
        "src": "File:'Dawn' Profile - geograph.org.uk - 2448954.jpg (Peter Trimming, CC BY-SA 2.0); Barn Owl",
        "eye": (980, 636, 60), "base": (1260, 896), "tip": (1305, 1111),
        "lines": {
            "culmen": [(1260, 896), (1320, 914), (1342, 925), (1359, 944), (1369, 966), (1373, 993), (1371, 1015), (1365, 1041),
                       (1354, 1068), (1339, 1090), (1320, 1105), (1305, 1111)],
            "under": [(1305, 1111), (1309, 1105), (1320, 1075), (1324, 1038), (1316, 1008), (1297, 985), (1267, 968), (1230, 955),
                      (1185, 942), (1140, 931), (1102, 925)],
            "head": [(880, 220), (1040, 240), (1160, 320), (1280, 440), (1380, 580), (1430, 740), (1420, 840)],
            "throat": [(1280, 1080), (1240, 1200), (1200, 1280)],
        },
        "marks": {},
    },
}
ORDER = ["crow", "sparrow", "hawk", "falcon", "owl"]
# The life head's feathered half-width (mm): docs/research/eyes_and_beaks.md 2.2; the kestrel's estimated from its
# photo (its crown 19 mm above the eye's centre, as the rig's falcon head is at 1.2x). The rig's heads are a little
# over life size (crow 1.17x, owl 1.04x), so a photo is laid on ours at life size x our head radius / this.
LIFE_R = {"crow": 23.0, "sparrow": 10.5, "hawk": 30.0, "falcon": 24.5, "owl": 55.0}
for _sp in ORDER:
    REFS[_sp]["life_r"] = LIFE_R[_sp]
NAMES = {"crow": "American Crow", "sparrow": "House Sparrow", "hawk": "Red-tailed Hawk", "falcon": "Common Kestrel",
         "owl": "Barn Owl"}


def ref_points(r):
    """The reference's lines in a y-up frame (and mirrored to face right), the open lower jaw shut."""
    s = -1.0 if r.get("mirror") else 1.0
    f = lambda p: np.array([s * p[0], -p[1]], float)
    lines = {k: [f(p) for p in v] for k, v in r["lines"].items()}
    if "open_lower" in r:
        o = r["open_lower"]
        a0, a1 = f(o["tomium"][0]), f(o["tomium"][-1])
        b0, b1 = f(o["to"][0]), f(o["to"][1])
        ang = math.atan2(*(b1 - b0)[::-1]) - math.atan2(*(a1 - a0)[::-1])
        R = np.array([[math.cos(ang), -math.sin(ang)], [math.sin(ang), math.cos(ang)]])
        mv = lambda p: R @ (f(p) - a0) + b0
        lines["lower tomium"] = [mv(p) for p in o["tomium"]]
        lines["under"] = [mv(p) for p in o["under"]]
    e = r["eye"]
    return lines, f(e[:2]), e[2], f(r["base"]), f(r["tip"]), {k: f(p) for k, p in r["marks"].items()}


def similarity(a0, a1, b0, b1):
    """The map (scale, rotation, shift) taking a0 -> b0 and a1 -> b1, on 2-vectors."""
    za, zb = complex(*(a1 - a0)), complex(*(b1 - b0))
    k = zb / za
    return lambda p: (lambda z: np.array([z.real, z.imag]))(k * complex(*(np.asarray(p) - a0)) + complex(*b0))


def ours(d):
    """Ours in the chart's frame (x = -z forward, y up), in mm: triangles with colours, the landmarks."""
    u = 1000.0
    out = {"head": [], "bill": [], "hr": d["hr"] * u}
    hv = np.array(d["head"]) * u
    ht = d["head_tris"]
    for i in range(0, len(ht), 3):
        tri = hv[ht[i:i + 3]]
        out["head"].append([(-v[2], v[1]) for v in tri])
    for part in ["BeakUpper", "BeakLower"]:
        vs = d[part]
        t = d[part + "_tris"]
        for i in range(0, len(t), 3):
            tri = [vs[j] for j in t[i:i + 3]]
            part = round(np.mean([int(v[3][2:4], 16) for v in tri]) / 255 * 3)   # (COLOR.g: which surface)
            col = [(46, 48, 54), (196, 140, 140), (96, 98, 106), (196, 140, 140)][part]
            out["bill"].append(([(-v[2] * u, v[1] * u) for v in tri], float(np.mean([v[0] for v in tri])), col))
    e = d["eye"]
    out["eye"] = np.array([-e[2] * u, e[1] * u])
    out["eye_r"] = e[3] * u
    up = np.array([(-v[2] * u, v[1] * u) for v in d["BeakUpper"]])
    # the culmen's base: where the bill's top leaves the head (the first point of its top line outside the head)
    res = 400.0 / out["hr"]
    mask, to_px = raster(out["head"], res, out["hr"])
    w = (up[:, 0].max() - up[:, 0].min()) / 25
    best = None
    for x in np.linspace(up[:, 0].min(), up[:, 0].max(), 300):
        near = up[np.abs(up[:, 0] - x) < w]
        if len(near) == 0:
            continue
        y = near[:, 1].max()
        px, py = to_px((x, y + 0.002 * out["hr"]))
        if not (0 <= px < mask.shape[1] and 0 <= py < mask.shape[0]) or not mask[py, px]:
            best = np.array([x, y])
            break
    if "base" in d:   # (the culmen's base as the rig places it: Face.bill_base)
        best = np.array([-d["base"][2] * u, d["base"][1] * u])
    out["base"] = best
    fwd = np.array([math.cos(math.radians(d.get("pitch", 0.0))), math.sin(math.radians(d.get("pitch", 0.0)))])
    ahead = [p for p in up if np.dot(p - best, fwd) > 0.0]   # (not the base's section carried back into the head)
    out["tip"] = max(ahead, key=lambda p: np.linalg.norm(p - best))
    # the gape line: the upper mandible's underside over the bill's basal 40 %, fitted straight
    pts = []
    for x in np.linspace(best[0], best[0] + 0.4 * (out["tip"][0] - best[0]), 12):
        near = up[np.abs(up[:, 0] - x) < w]
        if len(near):
            pts.append((x, near[:, 1].min()))
    pts = np.array(pts)
    a = np.polyfit(pts[:, 0], pts[:, 1], 1)[0] if len(pts) > 2 and np.ptp(pts[:, 0]) > 1e-6 else 0.0
    out["gape_dir"] = math.atan(a)
    return out


def raster(tris, res, hr):
    """The triangles filled on a grid (res px per mm) round the head: the mask and the point -> pixel map."""
    w = int(5 * hr * res)
    img = Image.new("1", (w, w), 0)
    dr = ImageDraw.Draw(img)
    to_px = lambda p: (int(w / 2 + p[0] * res), int(w / 2 - p[1] * res))
    for t in tris:
        dr.polygon([to_px(p) for p in t], fill=1)
    return np.array(img, bool), to_px


ORANGE = (235, 110, 20)
GREY = (205, 208, 212)
BG = (250, 250, 247)


def ref_frame(o, r):
    """The photo laid on ours: scaled to mm by the bill's measured length, its gape line along ours, its culmen's
    base on ours (the owl: its chord along ours, no gape seen)."""
    lines, eye, eye_r, base, tip, marks = ref_points(r)
    a, b, mm = r["mm"]
    pa = base if a == "base" else marks[a]
    pb = tip if b == "tip" else marks[b]
    scale = mm / np.linalg.norm(pb - pa) * o["hr"] / r["life_r"]   # (to our head's size)
    s = -1.0 if r.get("mirror") else 1.0
    if r["gape_line"]:
        g0, g1 = [np.array([s * p[0], -p[1]], float) for p in r["gape_line"]]
        rot = o["gape_dir"] - math.atan2(g1[1] - g0[1], g1[0] - g0[0])
    else:
        rot = math.atan2(*(o["tip"] - o["base"])[::-1]) - math.atan2(*(tip - base)[::-1])
    k = scale * complex(math.cos(rot), math.sin(rot))
    m = lambda p: (lambda z: np.array([z.real, z.imag]))(k * complex(*(np.asarray(p) - base)) + complex(*o["base"]))
    return m, scale


def panel(o, r, mode, W=760, H=520, ss=3):
    lines, eye, eye_r, base, tip, marks = ref_points(r)
    if mode == "face":
        m, scale = ref_frame(o, r)
        mo = lambda p: np.asarray(p)
        pts = [o["eye"], o["base"], o["tip"], m(eye)] + [m(p) for v in lines.values() for p in v]
        pts += [np.array(p) for t, _, _ in o["bill"] for p in t]
        pts += [np.array(p) for t in o["head"] for p in t]
        lo, hi = np.min(pts, 0) - 2, np.max(pts, 0) + 2
    else:
        L = np.array([0.0, 0.0]), np.array([1.0, 0.0])
        m = similarity(base, tip, *L)
        mo = similarity(o["base"], o["tip"], *L)
        pts = [m(p) for k, v in lines.items() if k not in ("head", "throat") for p in v] + [mo(p) for t, _, _ in o["bill"] for p in t]
        pts = [p for p in pts if p[0] > -0.3]
        lo, hi = np.min(pts, 0) - 0.12, np.max(pts, 0) + 0.12
        lo[0] = -0.3
    k = min(W / (hi[0] - lo[0]), H / (hi[1] - lo[1])) * ss
    cx, cy = (lo + hi) / 2
    P = lambda p: (W * ss / 2 + (p[0] - cx) * k, H * ss / 2 - (p[1] - cy) * k)
    img = Image.new("RGB", (W * ss, H * ss), BG)
    dr = ImageDraw.Draw(img)
    for t, x, col in sorted(o["bill"], key=lambda q: q[1]):
        c = tuple(min(255, int(v * 0.85 + 30)) for v in col) if max(col) < 40 else col
        dr.polygon([P(mo(p)) for p in t], fill=c, outline=c)
    for t in o["head"]:   # (over the bill: its base inside the head is hidden, as drawn)
        dr.polygon([P(mo(p)) for p in t], fill=GREY if mode == "face" else BG)
    if mode == "face":
        e = P(o["eye"])
        rr = o["eye_r"] * k
        dr.ellipse([e[0] - rr, e[1] - rr, e[0] + rr, e[1] + rr], outline=(40, 40, 40), width=2 * ss)
    lw = 3 * ss
    for name, v in lines.items():
        if mode == "shape" and name in ("head", "throat"):
            continue
        q = [P(m(p)) for p in v]
        if name in ("head", "throat"):
            for a, b in zip(q[:-1], q[1:]):   # dashed: the feathers' outline
                for s in np.arange(0, 1, 0.2):
                    dr.line([tuple(np.add(a, np.subtract(b, a) * s)), tuple(np.add(a, np.subtract(b, a) * (s + 0.1)))], fill=ORANGE, width=lw)
        else:
            dr.line(q, fill=ORANGE, width=lw, joint="curve")
    if mode == "face":
        e = P(m(eye))
        rr = eye_r * scale * k
        dr.ellipse([e[0] - rr, e[1] - rr, e[0] + rr, e[1] + rr], outline=ORANGE, width=lw)
        x0, y0 = 14 * ss, H * ss - 16 * ss   # a 10 mm scale bar
        dr.line([(x0, y0), (x0 + 10 * k, y0)], fill=(40, 40, 40), width=3 * ss)
        dr.text((x0, y0 - 22 * ss), "10 mm", fill=(40, 40, 40), font=ImageFont.truetype("arial.ttf", 16 * ss))
    for name, p in marks.items():
        q = P(m(p))
        dr.ellipse([q[0] - 5 * ss, q[1] - 5 * ss, q[0] + 5 * ss, q[1] + 5 * ss], fill=ORANGE)
    for p in ([o["base"], o["tip"]] if mode == "face" else [np.zeros(2), np.array([1.0, 0])]):
        q = P(mo(p) if mode == "face" else p)
        dr.ellipse([q[0] - 4 * ss, q[1] - 4 * ss, q[0] + 4 * ss, q[1] + 4 * ss], outline=(30, 90, 200), width=2 * ss)
    return img.resize((W, H), Image.LANCZOS)


def metrics(o, r):
    """Ours and the photo's bill: chord (mm), depth near the base / chord, the eye's distance from the culmen's base (mm)."""
    lines, eye, eye_r, base, tip, marks = ref_points(r)
    m, scale = ref_frame(o, r)
    bill = [a + (b - a) * f for k, v in lines.items() if k not in ("head", "throat") for a, b in zip(v[:-1], v[1:])
            for f in np.linspace(0, 1, 20)]   # (densified: the traces' points are sparse)

    def depth(pts, b, t):   # across the chord at 15 % along it
        ax = (t - b) / np.linalg.norm(t - b)
        nrm = np.array([-ax[1], ax[0]])
        L = np.linalg.norm(t - b)
        sel = [np.dot(p - b, nrm) for p in pts if abs(np.dot(p - b, ax) - 0.15 * L) < 0.06 * L]
        return (max(sel) - min(sel)) / L if sel else float("nan")
    our_pts = [np.array(p) for t, _, _ in o["bill"] for p in t]
    return {"chord": (np.linalg.norm(o["tip"] - o["base"]), np.linalg.norm(m(tip) - m(base))),
            "depth": (depth(our_pts, o["base"], o["tip"]), depth(bill, base, tip)),
            "eye": (np.linalg.norm(o["eye"] - o["base"]), np.linalg.norm(m(eye) - m(base)))}


def main(src, out):
    d = json.load(open(src))
    font = ImageFont.truetype("arial.ttf", 22)
    small = ImageFont.truetype("arial.ttf", 16)
    W, H, T = 760, 520, 62
    sheet = Image.new("RGB", (2 * W + 30, len(ORDER) * (H + T) + 70), (255, 255, 255))
    sd = ImageDraw.Draw(sheet)
    sd.text((12, 10), "Beaks in profile: ours (filled; blue rings its culmen base and tip) against a traced photo (orange; dashed: "
            "the head's feathers, dots: cere / bristle ends)", fill=(20, 20, 20), font=font)
    sd.text((12, 38), "Left: the photo scaled by the species' measured bill to our head's size (life x our head radius / the life head's), gape lines and culmen bases laid together."
            "   Right: the bill alone, base-to-tip chord = 1.", fill=(60, 60, 60), font=small)
    for i, sp in enumerate(ORDER):
        o = ours(d[sp])
        y = 70 + i * (H + T)
        mt = metrics(o, REFS[sp])
        sd.text((12, y), "%s  --  bill chord (culmen base to tip): ours %.1f mm, photo %.1f (x%.2f);  eye to culmen base: ours %.1f mm, "
                "photo %.1f" % (NAMES[sp], *mt["chord"], mt["chord"][0] / mt["chord"][1], *mt["eye"]), fill=(20, 20, 20), font=font)
        sd.text((12, y + 28), REFS[sp]["src"], fill=(110, 110, 110), font=small)
        for j, mode in enumerate(["face", "shape"]):
            sheet.paste(panel(o, REFS[sp], mode, W, H), (j * (W + 30), y + T - 8))
    sheet.save(out, quality=90)
    print("wrote", out)
    for sp in ORDER:
        print(sp, {k: tuple(round(x, 2) for x in v) for k, v in metrics(ours(d[sp]), REFS[sp]).items()})


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
