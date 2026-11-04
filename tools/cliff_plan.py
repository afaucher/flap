"""The escarpment in plan, from straight above (tests/probe_cliff_plan.gd's exact heights).

    python tools/cliff_plan.py <probe out dir> <out dir>

Draws plan_wide.png (the whole wrap: hillshade, contours every 5 m, the boundary, the reach, the wall's foot, its top
edge and the talus toe) and plan_mid.png (the middle 120 m close up: hillshade, contours every 2 m, and the face's
line at each height every 4 m, low warm to high cool), and prints the plan's numbers: how much the face wanders in
plan at each height, how far the face steps back between heights (lips and ledges in plan), the bays' size.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage


def load(d, name, meta):
    g = meta["grids"][name]
    a = np.fromfile(os.path.join(d, "plan_%s.bin" % name), dtype=np.float32).reshape(g["n"], g["n"])
    return a[::-1].copy(), g   # (seen from above: +x right, so +z down the image; the probe wrote +z first)


def shade(h, step):
    gy, gx = np.gradient(h, step)
    # (lit from the upper left, low: the faces show as sharp light and dark)
    az, alt = math.radians(315), math.radians(35)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    v = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
    return np.clip(v, 0, 1), slope


def contours(h, every):
    lv = np.floor(h / every)
    e = (lv != np.roll(lv, 1, 0)) | (lv != np.roll(lv, 1, 1))
    return e


def to_px(g, x, z):
    return ((x - (g["cx"] - g["half"])) / g["step"], (z - (g["cz"] - g["half"])) / g["step"])


def draw(h, g, meta, path, every, face_lines):
    v, slope = shade(h, g["step"])
    hn = np.clip(h / 50.0, 0, 1)
    rgb = np.dstack([0.55 + 0.35 * hn, 0.58 + 0.25 * hn, 0.5 + 0.2 * hn]) * (0.35 + 0.75 * v[..., None])
    steep = slope > math.radians(55)
    rgb[steep] = rgb[steep] * 0.55 + np.array([0.15, 0.13, 0.12]) * 0.45   # (the faces: dark)
    rgb[h < 0.05] = np.array([0.42, 0.5, 0.3])   # (the heath and the wood: flat green)
    c = contours(h, every) & (h > 0.05)
    rgb[c] = rgb[c] * 0.45
    im = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    L = meta["lines"]

    def poly(pts, colour, width):
        p = [to_px(g, a[0], a[1]) for a in pts]
        p = [q for q in p if -50 < q[0] < g["n"] + 50 and -50 < q[1] < g["n"] + 50]
        if len(p) > 1:
            d.line(p, fill=colour, width=width)

    r = meta["boundary"]
    poly([(math.sin(t) * r, math.cos(t) * r) for t in np.linspace(0, 2 * math.pi, 400)], (240, 240, 240), 2)
    if face_lines:
        levels = sorted(int(k[1:]) for k in L if k.startswith("z"))
        for i, lv in enumerate(levels):
            u = i / max(len(levels) - 1, 1)
            col = (int(255 * (1 - u)), int(120 + 60 * math.sin(u * math.pi)), int(255 * u))
            pts = L["z%d" % lv]
            run = [pts[0]] if pts else []
            for a, b in zip(pts, pts[1:]):   # (break the line where the face jumps: a lip, a cleft)
                if math.hypot(b[0] - a[0], b[1] - a[1]) > 1.5:
                    poly(run, col, 2)
                    run = []
                run.append(b)
            poly(run, col, 2)
    else:
        poly(L["reach"], (255, 60, 60), 2)
        poly(L["toe"], (230, 180, 60), 2)
        poly(L["foot"], (40, 90, 230), 2)
        poly(L["top"], (20, 20, 20), 2)
    im.save(path)
    return im


def numbers(meta):
    L = meta["lines"]
    rep = {}
    foot = np.array([math.hypot(a[0], a[1]) for a in L["foot"]])
    n = len(foot)
    mid = foot[int(n * 0.3): int(n * 0.7)]   # (the middle, not the curving arms)
    rep["foot_wander_middle_m"] = {"range": round(float(mid.max() - mid.min()), 1), "sd": round(float(mid.std()), 2)}
    big = ndimage.uniform_filter1d(mid, 40)
    rep["bays_m"] = round(float(np.percentile(big, 95) - np.percentile(big, 5)), 1)
    per = {}
    for k in L:
        if not k.startswith("z"):
            continue
        pts = L[k]
        if len(pts) < 20:
            continue
        rr = np.array([math.hypot(a[0], a[1]) for a in pts])
        th = np.array([a[2] for a in pts])
        m = (th > np.percentile(th, 30)) & (th < np.percentile(th, 70))
        rr = rr[m]
        steps = np.abs(np.diff(rr))
        per[int(k[1:])] = {"wander_sd": round(float(rr.std()), 2), "steps_over_0.5m_per_100m": round(float((steps > 0.5).sum() / (m.sum() * 0.5 / 100.0)), 1),
                           "mean_back_of_foot": round(float(rr.mean() - mid.mean()), 2)}
    rep["face_by_height"] = dict(sorted(per.items()))
    return rep


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    meta = json.load(open(os.path.join(src, "plan.json")))
    h, g = load(src, "wide", meta)
    draw(h, g, meta, os.path.join(out, "plan_wide.png"), 5.0, False)
    h, g = load(src, "mid", meta)
    draw(h, g, meta, os.path.join(out, "plan_mid.png"), 2.0, False)
    draw(h, g, meta, os.path.join(out, "plan_mid_faces.png"), 2.0, True)
    rep = numbers(meta)
    print(json.dumps(rep, indent=1))
    json.dump(rep, open(os.path.join(out, "plan_report.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
