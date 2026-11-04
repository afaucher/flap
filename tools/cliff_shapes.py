"""The shapes in a cliff's zoned plan (tools/cliff_segment.py): the edges between the zones, and the ledges.

    python tools/cliff_shapes.py <out dir> concept=<segmented png> model=<probe_cliff_plan dir>

Both maps are cleaned the same way first (speckle filled from its neighbours, each zone smoothed at SMOOTH m, islands
under MIN_AREA m^2 given to their surroundings), so what's measured is the zones' shapes, not the colour test's noise.

Every edge is traced and typed by what lies on each side, the plateau at the top of the frame and the wood at the
bottom: the plateau's rim (flat above a face), a ledge's lip (its drop to the face below) and its back (where the face
above rises from it), the wall's foot (face above talus), flat ground meeting talus. For each type, in metres: how
much of it there is per 100 m of cliff, how long each run is, how straight (sinuosity: path over chord), how rough
across scales (divider dimension: 1 smooth, 1.2+ ragged), how angular (corners over CORNER deg per 10 m on the edge
simplified to TOL m, and the straight lengths between them), its heading against the cliff's line, and which way its
sharp points face (the skew of its wander about an 8 m running mean: + tips point down the plan, toward the wood; -
up, into the cliff: scallops). For each ledge: length, depth, how full (area over length x depth: a lens ~0.6, a
rectangle 1), how its ends taper (the share of its length from each end to half its depth), where it's deepest along
it, its tilt, and which of its edges is the straighter.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.stats import skew
from skimage.measure import approximate_polygon, find_contours

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cliff_segment as seg  # noqa: E402

H, W = seg.H, seg.W
M = 40.0 / H          # m per pixel (the frame is 40 m deep)
SMOOTH = 0.4          # m
MIN_AREA = 3.0        # m^2
MIN_RUN = 3.0         # m: shorter runs of an edge are not counted
TOL = 0.25            # m: the simplified edge stays this close to the traced one
CORNER = 25.0         # deg
TYPES = {"plateau_rim": (20, 20, 20), "ledge_lip": (240, 140, 20), "ledge_back": (150, 60, 200),
         "wall_foot": (20, 60, 160), "flat_talus": (0, 170, 190), "talus_over_face": (120, 120, 120)}
PALE = {0: (205, 228, 180), 1: (240, 190, 185), 2: (195, 200, 240), 3: (255, 255, 255)}


def clean(lab):
    unk = lab == 3
    cc, n = ndimage.label(unk)
    sizes = ndimage.sum(unk, cc, range(1, n + 1))
    nodata = np.isin(cc, 1 + np.nonzero(sizes > 0.01 * lab.size)[0])
    idx = ndimage.distance_transform_edt(unk, return_distances=False, return_indices=True)
    filled = lab[idx[0], idx[1]]
    prob = np.stack([ndimage.gaussian_filter((filled == k).astype(float), SMOOTH / M) for k in range(3)])
    out = prob.argmax(0).astype(np.int8)
    for k in range(3):
        m = out == k
        cc, n = ndimage.label(m)
        sizes = ndimage.sum(m, cc, range(1, n + 1))
        for i, sl in enumerate(ndimage.find_objects(cc)):
            if sizes[i] * M * M >= MIN_AREA:
                continue
            sl = tuple(slice(max(s.start - 3, 0), s.stop + 3) for s in sl)
            own = cc[sl] == i + 1
            ring = ndimage.binary_dilation(own, iterations=2) & ~own
            vals = out[sl][ring]
            vals = vals[vals != k]
            if vals.size:
                out[sl][own] = np.bincount(vals, minlength=3).argmax()
    out[nodata] = 3
    return out


def sample(a, p, fill):
    r = np.round(p[:, 0]).astype(int)
    c = np.round(p[:, 1]).astype(int)
    ok = (r >= 0) & (r < a.shape[0]) & (c >= 0) & (c < a.shape[1])
    v = np.full(len(p), fill, dtype=a.dtype)
    v[ok] = a[r[ok], c[ok]]
    return v


def mode_filter(t, k=9):
    out = t.copy()
    h = k // 2
    for i in range(len(t)):
        w = t[max(0, i - h): i + h + 1]
        w = w[w >= 0]
        if w.size:
            out[i] = np.bincount(w).argmax()
    return out


def plateau_ids(lab, fcc):
    """The flat ground that's the plateau: touching the frame's top, or the no-data there (the concept's speckle)."""
    top = np.zeros_like(lab, dtype=bool)
    top[:4] = True
    top |= ndimage.binary_dilation(lab == 3, iterations=3) & (np.arange(H)[:, None] < H * 0.4)
    return [i for i in np.unique(fcc[top & (lab == 0)]) if i]


def edges(lab):
    flat = lab == 0
    fcc, _ = ndimage.label(flat)
    plateau = np.isin(fcc, plateau_ids(lab, fcc))
    names = list(TYPES)
    runs = []
    for a in (0, 1):
        mask = np.pad((lab == a).astype(float), 1)
        for c in find_contours(mask, 0.5):
            c = c - 1.0
            if len(c) < MIN_RUN / M:
                continue
            t = np.gradient(c, axis=0)
            t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-9)
            nrm = np.stack([-t[:, 1], t[:, 0]], 1)
            l1, l2 = sample(lab, c + nrm * 3, 3), sample(lab, c - nrm * 3, 3)
            other = np.where(l1 == a, l2, np.where(l2 == a, l1, -1))
            to_other = nrm * np.where(l1 == a, -1.0, 1.0)[:, None]   # (row, col): toward the other zone
            down = to_other[:, 0] > 0   # (the other zone lies below: toward the wood)
            inside_plateau = sample(plateau.astype(np.int8), c - to_other * 2, 0) == 1
            ty = np.full(len(c), -1)
            if a == 0:
                f = other == 1
                ty[f & down & inside_plateau] = names.index("plateau_rim")
                ty[f & down & ~inside_plateau] = names.index("ledge_lip")
                ty[f & ~down & ~inside_plateau] = names.index("ledge_back")
                ty[other == 2] = names.index("flat_talus")
            else:
                f = other == 2
                ty[f & down] = names.index("wall_foot")
                ty[f & ~down] = names.index("talus_over_face")
            ty = mode_filter(ty)
            start = 0
            for i in range(1, len(c) + 1):
                if i == len(c) or ty[i] != ty[start]:
                    if ty[start] >= 0 and (i - start) * M >= MIN_RUN:
                        runs.append((names[ty[start]], c[start:i]))
                    start = i
    return runs


def run_metrics(c):
    p = np.stack([c[:, 1], c[:, 0]], 1) * M   # (x along the cliff, y down the plan), m
    d = np.linalg.norm(np.diff(p, axis=0), axis=1)
    length = float(d.sum())
    chord = float(np.linalg.norm(p[-1] - p[0]))
    rep = {"length": length, "sinuosity": length / max(chord, 1e-6)}
    v = p[-1] - p[0]
    ang = math.degrees(math.atan2(v[1], v[0]))
    ang = (ang + 90.0) % 180.0 - 90.0
    rep["heading"] = ang
    # Divider dimension: walk the edge with rulers; the length it measures falls as the ruler grows on a rough edge.
    rulers = [r for r in (0.5, 1.0, 2.0, 4.0) if r <= length / 4.0]
    if len(rulers) >= 3:
        ls = []
        for r in rulers:
            n, cur = 0, p[0]
            for q in p[1:]:
                if np.linalg.norm(q - cur) >= r:
                    n += 1
                    cur = q
            ls.append(max(n, 1) * r)
        rep["dimension"] = 1.0 - float(np.polyfit(np.log(rulers), np.log(ls), 1)[0])
    poly = approximate_polygon(p, tolerance=TOL)
    segs = np.diff(poly, axis=0)
    sl = np.linalg.norm(segs, axis=1)
    turns = []
    for s0, s1 in zip(segs, segs[1:]):
        cs = np.dot(s0, s1) / max(np.linalg.norm(s0) * np.linalg.norm(s1), 1e-9)
        turns.append(math.degrees(math.acos(np.clip(cs, -1, 1))))
    turns = np.array(turns)
    corners = int((turns > CORNER).sum()) if turns.size else 0
    rep["corners_per_10m"] = corners / length * 10.0
    rep["straight"] = float(length / (corners + 1))
    rep["vertices"] = poly
    rep["corner_at"] = [poly[i + 1] for i in np.nonzero(turns > CORNER)[0]] if turns.size else []
    # Which way its points face: its wander about an 8 m running mean, perpendicular to the chord.
    if length > 12.0:
        u = v / max(chord, 1e-6)
        n = np.array([-u[1], u[0]])
        if n[1] < 0:
            n = -n
        off = (p - p[0]) @ n
        k = max(int(8.0 / max(length / len(p), 1e-6)), 3)
        mean = ndimage.uniform_filter1d(off, k, mode="nearest")
        rep["points"] = float(skew(off - mean))
        rep["wander"] = float(np.std(off - mean))
    return rep


def ledges(lab):
    flat = lab == 0
    cc, n = ndimage.label(flat)
    top = set(plateau_ids(lab, cc))
    out = []
    for i, sl in enumerate(ndimage.find_objects(cc), start=1):
        if i in top or sl is None:
            continue
        m = cc[sl] == i
        area = m.sum() * M * M
        if area < MIN_AREA * 2:
            continue
        depth = m.sum(0) * M
        cols = np.nonzero(depth > 0)[0]
        depth = depth[cols[0]: cols[-1] + 1]
        L = len(depth) * M
        dmax = float(depth.max())
        half = np.nonzero(depth >= dmax * 0.5)[0]
        ends = ((half[0]) * M / L + (len(depth) - 1 - half[-1]) * M / L) * 0.5
        rows = np.arange(m.shape[0])[:, None]
        sub = m[:, cols[0]: cols[-1] + 1]
        has = sub.any(0)
        topr = np.where(has, np.argmax(sub, 0), np.nan)
        botr = np.where(has, m.shape[0] - 1 - np.argmax(sub[::-1], 0), np.nan)
        xs = np.arange(len(depth))[has] * M
        mid = (topr[has] + botr[has]) * 0.5 * M
        tilt = math.degrees(math.atan(np.polyfit(xs, mid, 1)[0])) if len(xs) > 3 else 0.0
        def rough(r):
            r = r[has] * M
            return float(np.std(r - np.polyval(np.polyfit(xs, r, 2), xs))) if len(xs) > 4 else 0.0
        out.append({"length": L, "depth": dmax, "aspect": L / dmax, "fullness": area / (L * dmax), "ends_to_half": ends,
                    "deepest_at": float(np.argmax(depth) / max(len(depth) - 1, 1)), "tilt": tilt,
                    "back_rough": rough(topr), "lip_rough": rough(botr), "area": area,
                    "x": ((sl[1].start + cols[0]) * M, (sl[1].start + cols[-1]) * M), "y": float(np.mean(mid) + sl[0].start * M)})
    # Stacking: ledges overlapping along the cliff, one above another.
    stack = []
    for a in out:
        for b in out:
            if a is b or a["y"] >= b["y"]:
                continue
            ov = min(a["x"][1], b["x"][1]) - max(a["x"][0], b["x"][0])
            if ov > 0:
                stack.append({"overlap_share": ov / min(a["length"], b["length"]), "gap": b["y"] - a["y"]})
    return out, stack


def summarise(runs, ledge_list, stack, width_m):
    rep = {}
    for t in TYPES:
        rs = [r for k, r in runs if k == t]
        if not rs:
            continue
        L = np.array([r["length"] for r in rs])
        def wm(key, absval=False):
            v = [(abs(r[key]) if absval else r[key], r["length"]) for r in rs if key in r]
            if not v:
                return None
            a, w = np.array(v).T
            return round(float((a * w).sum() / w.sum()), 2)
        rep[t] = {"m_per_100m": round(float(L.sum() / width_m * 100.0), 1), "runs": len(rs),
                  "run_median_m": round(float(np.median(L)), 1), "run_longest_m": round(float(L.max()), 1),
                  "sinuosity": wm("sinuosity"), "dimension": wm("dimension"), "corners_per_10m": wm("corners_per_10m"),
                  "straight_m": wm("straight"), "heading_abs_deg": wm("heading", True), "wander_m": wm("wander"), "points": wm("points")}
    def st(key):
        a = np.array([l[key] for l in ledge_list])
        return {"median": round(float(np.median(a)), 2), "p10": round(float(np.percentile(a, 10)), 2), "p90": round(float(np.percentile(a, 90)), 2)} if a.size else None
    rep["ledges"] = {"n": len(ledge_list), **{k: st(k) for k in ("length", "depth", "aspect", "fullness", "ends_to_half", "deepest_at", "tilt", "back_rough", "lip_rough")}}
    if ledge_list:
        rep["ledges"]["lip_rougher_share"] = round(float(np.mean([l["lip_rough"] > l["back_rough"] for l in ledge_list])), 2)
    if stack:
        rep["ledges"]["stacked_pairs"] = len(stack)
        rep["ledges"]["stack_overlap_share"] = round(float(np.median([s["overlap_share"] for s in stack])), 2)
        rep["ledges"]["stack_gap_m"] = round(float(np.median([s["gap"] for s in stack])), 2)
    return rep


def draw(lab, runs, path):
    rgb = np.zeros((H, W, 3), dtype=np.uint8)
    for k, c in PALE.items():
        rgb[lab == k] = c
    im = Image.fromarray(rgb)
    d = ImageDraw.Draw(im)
    for t, r in runs:
        pts = [(x / M, y / M) for x, y in r["vertices"]]
        d.line(pts, fill=TYPES[t], width=3)
        for x, y in r["corner_at"]:
            d.ellipse([x / M - 3, y / M - 3, x / M + 3, y / M + 3], fill=(255, 255, 255), outline=TYPES[t])
    return im


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    reps, ims = {}, []
    for arg in sys.argv[2:]:
        name, src = arg.split("=", 1)
        raw = seg.from_concept(src) if name == "concept" else seg.from_model(src)
        lab = clean(raw)
        runs = [(t, run_metrics(c)) for t, c in edges(lab)]
        lg, stack = ledges(lab)
        width = float((lab != 3).any(0).sum() * M)
        reps[name] = summarise(runs, lg, stack, width)
        ims.append((name, draw(lab, runs, os.path.join(out, name + "_shapes.png"))))
    sheet = Image.new("RGB", (W, (H + 24) * len(ims) + 30), "white")
    d = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(ims):
        sheet.paste(im, (0, i * (H + 24) + 20))
        d.text((6, i * (H + 24) + 4), name.upper() + " (cleaned; white dots: corners over %d deg)" % CORNER, fill="black")
    x = 6
    for t, c in TYPES.items():
        d.rectangle([x, sheet.height - 18, x + 24, sheet.height - 8], fill=c)
        d.text((x + 30, sheet.height - 20), t, fill="black")
        x += 190
    sheet.save(os.path.join(out, "shapes.png"))
    print(json.dumps(reps, indent=1))
    json.dump(reps, open(os.path.join(out, "shapes_report.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
