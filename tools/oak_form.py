"""Our oaks' form, measured from the wood as drawn (TreeData.limbs, written by probe_tree_paths), for comparing with
real oaks (docs/research/oak_form.md): where the first-order limbs leave the trunk, how many leave the fork, their
angles, how straight each limb's main axis is (arc / chord, turns), its reach against the crown, the side branches
along it, the radius at each junction (the pipe model), and how often each tube's bark photo repeats round it
(ArenaBuilder._tube: a whole number of tiles at the tube's FIRST radius, so a tube that starts swollen or tapers
squeezes the tiles).

Usage: python tools/oak_form.py <tree_paths.json> [--pines <pine_paths.json>] [--json <out.json>]
"""
import json
import math
import sys

TILE = {"oak_trunk": 1.0, "oak_limb": 0.5, "pine_trunk": 2.0, "limb": 0.6, "twig": 0.3}
ASPECT = {"oak_trunk": 2.0, "oak_limb": 2.0, "pine_trunk": 1.0, "limb": 1.0, "twig": 1.0}   # tile height / width
PHOTO = {"oak_limb": (1.0, 2.0), "oak_trunk": (1.0, 2.0), "limb": (1.7, 1.7), "pine_trunk": (2.0, 2.0), "twig": (1.7, 1.7)}   # m the scan covers


def sub(a, b):
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def norm(v):
    return math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2)


def unit(v):
    n = norm(v) or 1e-9
    return [v[0] / n, v[1] / n, v[2] / n]


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def ang(a, b):
    return math.degrees(math.acos(max(-1.0, min(1.0, dot(unit(a), unit(b))))))


def arc(pts):
    return sum(norm(sub(pts[i], pts[i - 1])) for i in range(1, len(pts)))


def resample(pts, step):
    out = [pts[0]]
    carry = 0.0
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        seg = norm(sub(b, a))
        d = step - carry
        while d <= seg:
            t = d / seg
            out.append([a[k] + (b[k] - a[k]) * t for k in range(3)])
            d += step
        carry = seg - (d - step)
    return out


def trunk_radius(o, y):
    """ArenaBuilder._trunk's radius at height y (the flare and rings left out, but for the flare at the foot)."""
    r, h, cb, top = o["radius"], o["height"], o["crown_base"], o["stem"]
    rr = r * (1.0 + (0.4 - 1.0) * min(max(y / h, 0.0), 1.0))
    if cb > 0.0 and y > cb:
        rr = r * (0.9 + (0.6 - 0.9) * min(max((y - cb) / max(top - cb, 0.1), 0.0), 1.0))
    return rr * (1.0 + 0.55 * math.exp(-max(y, 0.0) / 0.9))


def bark_tiles(radii, pts, key):
    """Copies of the bark photo round a tube, and its drawn width (m) and stretch (drawn aspect / photo's) at the middle."""
    tile = TILE[key]
    around = max(1.0, round(2 * math.pi * radii[0] / tile)) * tile
    copies = around / tile
    mid = len(radii) // 2
    width = tile * 2 * math.pi * radii[mid] / around
    height = tile * ASPECT[key]
    pw, ph = PHOTO[key]
    return {"copies": copies, "width": width, "height": height, "stretch": (height / width) / (ph / pw),
            "scale": pw / width}


def analyse(o):
    c = [o["base"][0], 0.0, o["base"][1]]
    limbs = [l for l in o["limbs"]]
    for i, l in enumerate(limbs):
        l["i"] = i
        l["twig"] = len(l["pts"]) == 7 and l["r"][0] < 0.08
        l["children"] = []
        l["parent"] = None
    # Parents: a tube starting on another tube (its nearest point within a few cm), else on the trunk.
    for l in limbs:
        s = l["pts"][0]
        hd = math.hypot(s[0] - c[0], s[2] - c[2])
        if hd < 0.05:
            l["parent"] = "trunk"
            continue
        best, bj, bk = 1e9, None, None
        for m in limbs:
            if m is l:
                continue
            for k in range(len(m["pts"]) - 1):
                a_, b_ = m["pts"][k], m["pts"][k + 1]
                ab = sub(b_, a_)
                u = max(0.0, min(1.0, dot(sub(s, a_), ab) / max(dot(ab, ab), 1e-9)))
                d = norm(sub(s, [a_[i] + ab[i] * u for i in range(3)]))
                if d < best:
                    best, bj, bk = d, m, (k + 1 if u > 0.5 else k)
        if best < 0.06:
            l["parent"] = bj["i"]
            l["at"] = bk
            bj["children"].append(l["i"])
    first = [l for l in limbs if l["parent"] == "trunk"]
    out = {"id": o["id"], "height": o["height"], "dbh": 2 * o["radius"], "fork": o["crown_base"], "stem": o["stem"]}
    # The crown: how far the leaves reach from the trunk.
    out["crown_r"] = max(math.hypot(f["c"][0] - c[0], f["c"][2] - c[2]) + f["r"][0] for f in o["leaves"])
    out["crown_top"] = max(f["c"][1] + f["r"][1] for f in o["leaves"])
    out["crown_low"] = min(f["c"][1] - f["r"][1] for f in o["leaves"])
    rows = []
    for l in first:
        # The main axis: on from each piece's tip, through the thickest tube starting there.
        axis = [l]
        while True:
            cur = axis[-1]
            tip_kids = [limbs[j] for j in cur["children"] if limbs[j]["at"] == len(cur["pts"]) - 1 and not limbs[j]["twig"]]
            if not tip_kids:
                break
            axis.append(max(tip_kids, key=lambda m: m["r"][0]))
        pts = []
        for piece in axis:
            pts += piece["pts"] if not pts else piece["pts"][1:]
        # Out of the trunk: from where it leaves the bark.
        y0 = l["pts"][0][1]
        rt = trunk_radius(o, y0)
        k0 = next((k for k, p in enumerate(pts) if math.hypot(p[0] - c[0], p[2] - c[2]) >= rt), 0)
        outside = pts[k0:]
        rs = resample(outside, 0.5)
        a_len = arc(outside)
        chord = norm(sub(outside[-1], outside[0]))
        # Turns: the heading over each metre against the metre before, counted over 20 degrees.
        heads = [sub(rs[i + 2], rs[i]) for i in range(0, len(rs) - 2, 2)]
        turns = [ang(heads[i], heads[i - 1]) for i in range(1, len(heads))]
        sharp = [t for t in turns if t > 20.0]
        bends = [t for t in turns if t > 10.0]
        # The longest dead-straight run: 0.5 m steps all within 2 deg of the run's first heading.
        steps = [sub(rs[i + 1], rs[i]) for i in range(len(rs) - 1)]
        straight, i0 = 0.0, 0
        for i in range(len(steps)):
            while ang(steps[i], steps[i0]) > 2.0:
                i0 += 1
            straight = max(straight, (i - i0 + 1) * 0.5)
        # The angle it leaves at, from the vertical, over its first metre outside the bark.
        k1 = next((k for k, p in enumerate(rs) if norm(sub(p, rs[0])) >= 1.0), len(rs) - 1)
        lean = ang(sub(rs[k1], rs[0]), [0, 1, 0])
        reach = max(math.hypot(p[0] - c[0], p[2] - c[2]) for p in pts)
        # Side branches along the axis (not twigs), the twigs, and their angles off the parent.
        sides, twigs, side_angles, side_ratio = [], 0, [], []
        run_at = {}
        acc = 0.0
        for piece in axis:
            for k in range(len(piece["pts"])):
                if k > 0:
                    acc += norm(sub(piece["pts"][k], piece["pts"][k - 1]))
                run_at[(piece["i"], k)] = acc
        axis_ids = {p["i"] for p in axis}
        for piece in axis:
            for j in piece["children"]:
                m = limbs[j]
                if m["i"] in axis_ids:
                    continue
                if m["twig"]:
                    twigs += 1
                    continue
                k = m["at"]
                sides.append(run_at[(piece["i"], k)])
                pd = sub(piece["pts"][min(k + 1, len(piece["pts"]) - 1)], piece["pts"][max(k - 1, 0)])
                mr = resample(m["pts"], 0.25)
                side_angles.append(ang(sub(mr[min(3, len(mr) - 1)], mr[0]), pd))
                side_ratio.append(m["r"][0] / piece["r"][k])
        # The pipe model at each joint along the axis: the parent's end radius against what leaves it.
        pipes = []
        for a_, b_ in zip(axis, axis[1:]):
            r_in = a_["r"][-1]
            outs = [limbs[j]["r"][0] for j in a_["children"] if limbs[j]["at"] == len(a_["pts"]) - 1]
            pipes.append(sum(r * r for r in outs) / (r_in * r_in))
        # Its radius just outside the bark against the trunk's there (the collar left out: _limb swells it 1.75x at
        # the axis, dying away over 2.2 r0).
        r0 = l["r"][0] / 1.75
        rows.append({"y": y0, "rel_y": y0 - o["crown_base"], "az": math.degrees(math.atan2(pts[-1][0] - c[0], pts[-1][2] - c[2])),
                     "lean": lean, "arc": a_len, "chord": chord, "tort": a_len / chord, "turns": len(sharp), "bends": len(bends), "straight": straight,
                     "turn_mean": sum(turns) / len(turns) if turns else 0.0, "turn_max": max(turns) if turns else 0.0,
                     "reach": reach, "reach_crown": reach / out["crown_r"], "end_y": pts[-1][1],
                     "r0": r0, "ratio": r0 / trunk_radius(o, y0) * (1.0 + 0.55 * math.exp(-max(y0, 0.0) / 0.9)) / (1.0 + 0.55 * math.exp(-max(y0, 0.0) / 0.9)),
                     "n_side": len(sides), "first_side": min(sides) if sides else None, "twigs": twigs,
                     "side_angles": side_angles, "side_ratio": side_ratio, "pipes": pipes,
                     "tip_r": axis[-1]["r"][-1], "pieces": len(axis)})
    out["first"] = sorted(rows, key=lambda r: r["y"])
    # Twigs: where they leave (at a tube's tip or along it).
    tw = [l for l in limbs if l["twig"]]
    out["twigs"] = len(tw)
    out["twigs_at_tips"] = sum(1 for l in tw if l["parent"] not in (None, "trunk") and l["at"] == len(limbs[l["parent"]]["pts"]) - 1)
    out["pieces"] = len([l for l in limbs if not l["twig"]])
    out["unattached"] = sum(1 for l in limbs if l["parent"] is None)
    out["bark_limbs"] = [bark_tiles(l["r"], l["pts"], "oak_limb") | {"r0": l["r"][0], "rmid": l["r"][len(l["r"]) // 2]} for l in limbs if not l["twig"]]
    # The trunk as ArenaBuilder._trunk draws it: its first ring is at -0.15 m, flared.
    r_first = trunk_radius(o, 0.0) * 1.0
    rings = [trunk_radius(o, y) for y in (1.0, 3.0, o["crown_base"])]
    tile = TILE["oak_trunk"]
    around = max(1.0, round(2 * math.pi * r_first / tile)) * tile
    out["bark_trunk"] = {"copies": around / tile, "width_at": [tile * 2 * math.pi * r / around for r in rings]}
    return out


def pine_bark(p):
    rows = []
    for l in p["limbs"]:
        key = l["key"]
        if key not in TILE:
            continue
        rows.append(bark_tiles(l["r"], l["pts"], key) | {"r0": l["r"][0], "rmid": l["r"][len(l["r"]) // 2]})
    r = p["radius"]
    r_first = r * 1.3
    around = max(1.0, round(2 * math.pi * r_first / 2.0)) * 2.0
    return {"name": p["name"], "limbs": rows, "trunk": {"copies": around / 2.0, "width_at": [2.0 * 2 * math.pi * r * (1 - 0.6 * y / p["height"]) / around for y in (1.0, 3.0, p["height"] * 0.5)]}}


def fmt(v, f="%.2f"):
    return "-" if v is None else f % v


def main():
    args = sys.argv[1:]
    d = json.load(open(args[0]))
    res = [analyse(o) for o in d["oaks"]]
    pines = None
    if "--pines" in args:
        pines = [pine_bark(p) for p in json.load(open(args[args.index("--pines") + 1]))["oaks"]]
    for r in res:
        print("OAK %d: height %.1f m, dbh %.2f m, fork at %.1f m (%.0f%% of height), bole top %.1f m, crown radius %.1f m (%.1f to %.1f m up), %d limb pieces, %d twigs (%d at a piece's tip), %d unattached"
              % (r["id"], r["height"], r["dbh"], r["fork"], 100 * r["fork"] / r["height"], r["stem"], r["crown_r"], r["crown_low"], r["crown_top"], r["pieces"], r["twigs"], r["twigs_at_tips"], r["unattached"]))
        print("  first-order limbs: %d; within 1 m of the fork: %d; leaving between %.1f and %.1f m (spread %.1f m)" % (
            len(r["first"]), sum(1 for f in r["first"] if abs(f["rel_y"]) <= 1.0), r["first"][0]["y"], r["first"][-1]["y"], r["first"][-1]["y"] - r["first"][0]["y"]))
        print("   y(m) rel  lean  r0   r0/rt reach r/crown arc  chord arc/ch turns(>20/m) mean max  sides 1st  twigs pipes")
        for f in r["first"]:
            print("  %5.1f %+4.1f %4.0f %5.2f %5.2f %5.1f %5.2f %5.1f %5.1f %5.2f   %2d       %4.0f %4.0f  %2d  %5s %3d   %s" % (
                f["y"], f["rel_y"], f["lean"], f["r0"], f["ratio"], f["reach"], f["reach_crown"], f["arc"], f["chord"], f["tort"],
                f["turns"], f["turn_mean"], f["turn_max"], f["n_side"], fmt(f["first_side"], "%.1f"), f["twigs"], " ".join("%.2f" % p for p in f["pipes"])))
        sa = [a for f in r["first"] for a in f["side_angles"]]
        sr = [a for f in r["first"] for a in f["side_ratio"]]
        if sa:
            print("  side branches off the main axes: %d, angle off the parent %.0f..%.0f (mean %.0f) deg; radius / parent's %.2f..%.2f (mean %.2f)" % (
                len(sa), min(sa), max(sa), sum(sa) / len(sa), min(sr), max(sr), sum(sr) / len(sr)))
        bl = r["bark_limbs"]
        print("  bark on limbs: copies round %.0f..%.0f (median %.0f); drawn tile width at mid %.2f..%.2f m (median %.2f) x %.1f m; stretched %.1f..%.1fx the photo; photo shrunk %.1f..%.1fx" % (
            min(b["copies"] for b in bl), max(b["copies"] for b in bl), sorted(b["copies"] for b in bl)[len(bl) // 2],
            min(b["width"] for b in bl), max(b["width"] for b in bl), sorted(b["width"] for b in bl)[len(bl) // 2], bl[0]["height"],
            min(b["stretch"] for b in bl), max(b["stretch"] for b in bl), min(b["scale"] for b in bl), max(b["scale"] for b in bl)))
        bt = r["bark_trunk"]
        print("  bark on the trunk: %d copies round; drawn tile width at 1 m, 3 m, the fork: %s m (x 2.0 m)" % (bt["copies"], ", ".join("%.2f" % w for w in bt["width_at"])))
    if pines:
        for p in pines:
            ls = p["limbs"]
            print("PINE %s: trunk %d copies round, tile width at 1 m, 3 m, half height %s m (x 2.0 m)" % (p["name"], p["trunk"]["copies"], ", ".join("%.2f" % w for w in p["trunk"]["width_at"])), end="")
            if ls:
                print("; limbs %d: copies round %.0f..%.0f, tile width at mid %.2f..%.2f m, limb radius %.2f..%.2f m" % (
                    len(ls), min(b["copies"] for b in ls), max(b["copies"] for b in ls), min(b["width"] for b in ls), max(b["width"] for b in ls),
                    min(b["rmid"] for b in ls), max(b["rmid"] for b in ls)))
            else:
                print()
    if "--json" in args:
        json.dump({"oaks": res, "pines": pines}, open(args[args.index("--json") + 1], "w"), indent=1, default=str)


if __name__ == "__main__":
    main()
