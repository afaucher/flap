"""A cliff's plan in three zones -- flat ground and ledges, cliff faces, talus -- and how they're laid out.

    python tools/cliff_segment.py concept <segmented png> <out dir>          # a picture coloured green / red / blue
    python tools/cliff_segment.py model <probe_cliff_plan dir> <out dir>     # ours, exactly, from the heights
    python tools/cliff_segment.py model <probe_cliff_edges json> <out dir>   # ours unrolled along the cliff (from_wall)

Both in the same frame: the cliff across, the plateau at the top, 120 m along by 40 m out (model: centred 6 m behind
the middle of the foot, as probe_edge_view --heading top_aligned frames it). Ours is zoned by its wall's foot and its
slope: in front of the foot, talus (or flat ground where it has run out); behind it, flat under 20 deg, face over. Then, with every length a share of the frame's depth: each zone's
share; up each column, how many bands it crosses (ledges between faces) and how wide each band is; the talus's depth
and how it varies; and the ledges as patches (how many, how big, how long along the cliff).
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

W, H = 1536, 512
COL = {0: (150, 200, 90), 1: (220, 90, 80), 2: (120, 130, 220), 3: (255, 255, 255)}   # flat, face, talus, unknown


def from_concept(path):
    im = Image.open(path).convert("RGB").resize((W, H))
    a = np.asarray(im, dtype=float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lab = np.full((H, W), 3, dtype=np.int8)
    lab[(g > r + 8) & (g > b + 8)] = 0
    lab[(r > g + 25) & (r > b + 15)] = 1
    lab[(b > r + 8) & (b > g + 4)] = 2
    lab[int(H * 0.72):, int(W * 0.8):] = 3   # (the legend)
    # (fill what the colour test left out from its neighbours)
    for _ in range(3):
        m = lab == 3
        m[int(H * 0.72):, int(W * 0.8):] = False
        if not m.any():
            break
        for k in (0, 1, 2):
            grow = ndimage.binary_dilation(lab == k) & m
            lab[grow] = k
            m &= ~grow
    return lab


def from_model(d):
    meta = json.load(open(os.path.join(d, "plan.json")))
    g = meta["grids"]["mid"]
    n, step = g["n"], g["step"]
    h = np.fromfile(os.path.join(d, "plan_mid.bin"), dtype=np.float32).reshape(n, n)   # (row 0: +z)
    gy, gx = np.gradient(h, step)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    at = meta["at"]
    o = np.array([math.sin(at), math.cos(at)])
    right = np.array([-o[1], o[0]])
    mid = np.array([g["cx"], g["cz"]])
    centre = mid + o * 6.0
    lab = np.full((H, W), 3, dtype=np.int8)
    xs = (np.arange(W) + 0.5) / W * 120.0 - 60.0
    ys = 20.0 - (np.arange(H) + 0.5) / H * 40.0
    X, Y = np.meshgrid(xs, ys)
    wx = centre[0] + right[0] * X + o[0] * Y
    wz = centre[1] + right[1] * X + o[1] * Y
    ci = ((wx - (g["cx"] - g["half"])) / step).astype(int)
    rj = (((g["cz"] + g["half"]) - wz) / step).astype(int)
    ok = (ci >= 0) & (ci < n) & (rj >= 0) & (rj < n)
    s = np.full((H, W), np.nan)
    hh = np.full((H, W), np.nan)
    s[ok] = slope[rj[ok], ci[ok]]
    hh[ok] = h[rj[ok], ci[ok]]
    # In front of the wall's foot (the model's own line, probe_cliff_plan's "foot": its lowest row, per angle) all the
    # rock is talus -- its slope, and the flat stones and their rims on it -- and the rest flat ground; behind it, flat
    # under 20 deg, face over (the broken rock between ledges counts as face).
    foot = np.array(meta["lines"]["foot"], dtype=float)
    th_f = np.arctan2(foot[:, 0], foot[:, 1])
    r_f = np.hypot(foot[:, 0], foot[:, 1])
    o_ = np.argsort(th_f)
    th = np.arctan2(wx, wz)
    rr = np.hypot(wx, wz)
    in_front = rr < np.interp(th, th_f[o_], r_f[o_]) - 0.3
    lab[ok & ~in_front & (s < 20.0)] = 0
    lab[ok & ~in_front & (s >= 20.0)] = 1
    lab[ok & in_front] = 0
    lab[ok & in_front & (hh > 0.3)] = 2
    return lab


def from_wall(path):
    """Ours unrolled: along the cliff (m from the sector's middle, -60..60) across, out from the foot down (the plateau
    at the top, 26 m behind the mean foot, to 14 m in front), from probe_cliff_edges' ground grid (arc x radius), so the
    cliff's curve doesn't cut its ledges short in a straight frame."""
    j = json.load(open(path))
    step, na, nz, nr = j["step"], j["arcs"], j["nz"], j["nr"]
    g = np.array(j["plan"], dtype=float).reshape(nr, na)   # (row: r_lo + i * step; column: arc0 + k * step)
    front = np.array([np.nan if v is None else v for v in j["front"]], dtype=float).reshape(nz, na)
    r_lo = j["foot"] + j["r0"]
    r0s = np.array(j["r0s"], dtype=float)
    low = np.where(np.isnan(front[: int(2.0 / step)]), np.inf, front[: int(2.0 / step)]).min(0)   # (the foot: its lowest rows)
    foot_r = r0s + np.where(np.isfinite(low), low, 0.0)
    gy, gx = np.gradient(g, step)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))
    arcs = j["arc0"] + np.arange(na) * step
    xs = (np.arange(W) + 0.5) / W * 120.0 - 60.0
    ys = (j["foot"] + 26.0) - (np.arange(H) + 0.5) / H * 40.0   # (radius, the top row farthest out)
    ci = np.clip(np.round((xs - j["arc0"]) / step).astype(int), 0, na - 1)
    ri = np.round((ys - r_lo) / step).astype(int)
    lab = np.full((H, W), 3, dtype=np.int8)
    okr = (ri >= 0) & (ri < nr)
    for y in np.nonzero(okr)[0]:
        s_ = slope[ri[y], ci]
        h_ = g[ri[y], ci]
        front_of = ys[y] < foot_r[ci] - 0.3
        row = np.where(s_ < 20.0, 0, 1).astype(np.int8)
        row[front_of] = np.where(h_[front_of] > 0.3, 2, 0)
        lab[y] = row
    return lab


def measure(lab):
    rep = {}
    known = lab != 3
    for k, name in ((0, "flat"), (1, "face"), (2, "talus")):
        rep[name + "_share"] = round(float((lab[known] == k).mean()), 3)
    runs = {0: [], 1: [], 2: []}
    bands = []
    talus_depth = []
    for x in range(W):
        col = lab[:, x]
        if (col == 3).mean() > 0.5:
            continue
        r = []
        cur, start = col[0], 0
        for y in range(1, H + 1):
            if y == H or col[y] != cur:
                if cur != 3 and y - start >= 3:
                    r.append((int(cur), (y - start) / H))
                if y < H:
                    cur, start = col[y], y
        # merge tiny interruptions
        merged = []
        for k, w in r:
            if merged and merged[-1][0] == k:
                merged[-1] = (k, merged[-1][1] + w)
            else:
                merged.append((k, w))
        bands.append(len(merged))
        for i, (k, w) in enumerate(merged):
            top_plateau = k == 0 and i == 0
            if not top_plateau:
                runs[k].append(w)
        talus_depth.append(sum(w for k, w in merged if k == 2))

    def st(a):
        a = np.asarray(a, dtype=float)
        if a.size == 0:
            return {"n": 0}
        return {"n": int(a.size), "median": round(float(np.median(a)), 3), "p90": round(float(np.percentile(a, 90)), 3), "mean": round(float(a.mean()), 3)}
    rep["bands_per_column"] = st(bands)
    rep["ledge_band_width"] = st(runs[0])
    rep["face_band_width"] = st(runs[1])
    rep["talus_depth"] = {**st(talus_depth), "sd": round(float(np.std(talus_depth)), 3)}
    # Ledges as patches (not the plateau along the top).
    flat = lab == 0
    cc, n = ndimage.label(flat)
    top_ids = set(np.unique(cc[:3][flat[:3]]))
    sizes, longs = [], []
    for i, sl in enumerate(ndimage.find_objects(cc), start=1):
        if i in top_ids or sl is None:
            continue
        a = (cc[sl] == i).sum() / H ** 2
        if a < 0.002:
            continue
        sizes.append(a)
        longs.append((sl[1].stop - sl[1].start) / max(sl[0].stop - sl[0].start, 1))
    rep["ledge_patches"] = {"n": len(sizes), "area": st(sizes), "length_over_depth": st(longs)}
    return rep


def save(lab, path):
    rgb = np.zeros((H, W, 3), dtype=np.uint8)
    for k, c in COL.items():
        rgb[lab == k] = c
    Image.fromarray(rgb).save(path)


def main():
    mode, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    lab = from_concept(src) if mode == "concept" else from_wall(src) if src.endswith(".json") else from_model(src)
    save(lab, os.path.join(out, mode + "_segments.png"))
    rep = measure(lab)
    print(json.dumps(rep, indent=1))
    json.dump(rep, open(os.path.join(out, mode + "_segments.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
