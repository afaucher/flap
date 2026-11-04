"""A cliff's plan view (from straight above, the cliff across, the plateau at the top) traced into lines and zones.

    python tools/cliff_zones.py <out dir> <name>=<png> [<name>=<png> ...]

For each picture: the line segments (OpenCV's line detector), drawn by direction (blue along the cliff, red across, green
oblique); the picture cut into zones (Felzenszwalb regions, each a patch of one surface -- a block top, a ledge, a soil
patch, a talus block) and each zone sorted by kind from its colour (bare rock: pale grey; soil and grass: brown,
green; shadow: dark), drawn in false colour. Then the numbers: for each kind, its share of the picture and the
distribution of its zones' sizes (as shares of the picture's height squared, so pictures at different scales compare:
median, 90th percentile, how many make up half its area), and the zones' shapes (long along the cliff, or across).
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from skimage.measure import regionprops
from skimage.segmentation import felzenszwalb, find_boundaries

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cliff_edges import segments, segment_stats  # noqa: E402

KINDS = {"rock": (205, 205, 200), "soil": (150, 110, 60), "shadow": (40, 40, 60)}


def kind_of(mean_rgb):
    r, g, b = mean_rgb
    v = max(r, g, b)
    s = (v - min(r, g, b)) / max(v, 1e-3)
    if v < 0.33:
        return "shadow"
    if s < 0.16 and v > 0.45:
        return "rock"
    return "soil"


def analyse(path, out, name):
    im = Image.open(path).convert("RGB").resize((1536, 512))
    rgb = np.asarray(im, dtype=float) / 255.0
    H = rgb.shape[0]
    segs = segments((rgb.mean(2) * 255).astype(np.uint8))
    lines = im.copy()
    d = ImageDraw.Draw(lines)
    for x0, y0, x1, y1, length, ang in segs:
        c = (60, 120, 255) if min(ang, 180 - ang) < 20 else (255, 60, 60) if abs(ang - 90) < 20 else (60, 220, 90)
        d.line([(x0, y0), (x1, y1)], fill=c, width=2)
    lines.save(os.path.join(out, name + "_lines.png"))
    seg = felzenszwalb(rgb, scale=300, sigma=0.9, min_size=60)
    zones = {k: [] for k in KINDS}
    shapes = {k: [] for k in KINDS}
    false = np.zeros_like(rgb)
    for r in regionprops(seg + 1):
        rr, cc = r.coords[:, 0], r.coords[:, 1]
        k = kind_of(rgb[rr, cc].mean(0))
        a = r.area / H ** 2
        zones[k].append(a)
        h0, w0, h1, w1 = r.bbox
        shapes[k].append((w1 - w0) / max(h1 - h0, 1))
        false[rr, cc] = np.array(KINDS[k]) / 255.0 * (0.75 + 0.5 * np.random.RandomState(r.label).rand())
    false[find_boundaries(seg)] = 0.0
    Image.fromarray((np.clip(false, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out, name + "_zones.png"))
    rep = {"lines": segment_stats(segs)}
    total = float(H * rgb.shape[1]) / H ** 2
    for k in KINDS:
        a = np.sort(np.array(zones[k]))[::-1]
        if a.size == 0:
            rep[k] = {"share": 0.0}
            continue
        half = int(np.searchsorted(np.cumsum(a), a.sum() * 0.5)) + 1
        sh = np.array(shapes[k])
        rep[k] = {"share": round(float(a.sum() / total), 3), "zones": int(a.size),
                  "median": float(f"{np.median(a):.3g}"), "p90": float(f"{np.percentile(a, 90):.3g}"),
                  "largest": float(f"{a[0]:.3g}"), "zones_for_half_its_area": half,
                  "long_along": round(float((sh > 2).mean()), 2), "long_across": round(float((sh < 0.5).mean()), 2)}
    return rep


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    reps = {}
    for arg in sys.argv[2:]:
        name, path = arg.split("=", 1)
        reps[name] = analyse(path, out, name)
    print(json.dumps(reps, indent=1))
    json.dump(reps, open(os.path.join(out, "zones_report.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
