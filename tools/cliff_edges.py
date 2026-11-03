"""The escarpment's structure as diagrams, and its numbers.

    python tools/cliff_edges.py model <probe json> <out dir>      # our cliff, exactly (tests/probe_cliff_edges.gd)
    python tools/cliff_edges.py image <png/jpg> <out dir> [name]  # any picture of a cliff: its line segments

model: draws the front elevation (along the cliff x height: how far back the face stands, shaded; the beds' feet,
the joints, the lips, the ledges, the skyline, the clefts drawn over it) and the top view (along the cliff x out
from the foot: the ground's height, shaded, with the foot, the ledges' lips and the top's edge), and measures them:
bed thicknesses, joint spacings, how far joints run, how much of the cliff has lips and how deep, how far blocks
stand proud of the face around them. Then runs the image measure on its own front shading.

image: OpenCV's line segment detector (cv2.createLineSegmentDetector) on the picture: each segment's length and
angle, how much of the edge length is near horizontal, near vertical, oblique; drawn over the picture. The same
measure for our diagram, our render and the concept, so they compare.
"""
import json
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

SCALE = 4  # px per sample in the diagrams


def stats(xs):
    xs = np.asarray(xs, dtype=float)
    if xs.size == 0:
        return {"n": 0}
    return {"n": int(xs.size), "median": round(float(np.median(xs)), 2), "mean": round(float(xs.mean()), 2),
            "cv": round(float(xs.std() / max(xs.mean(), 1e-6)), 2), "p10": round(float(np.percentile(xs, 10)), 2),
            "p90": round(float(np.percentile(xs, 90)), 2)}


def segments(gray, min_len=12):
    """Line segments in an 8-bit grayscale image: [(x0, y0, x1, y1, length, angle deg 0..180 from horizontal)]."""
    lsd = cv2.createLineSegmentDetector(cv2.LSD_REFINE_STD)
    lines = lsd.detect(gray)[0]
    out = []
    if lines is None:
        return out
    for l in np.asarray(lines).reshape(-1, 4):
        x0, y0, x1, y1 = (float(v) for v in l)
        length = math.hypot(x1 - x0, y1 - y0)
        if length < min_len:
            continue
        ang = math.degrees(math.atan2(-(y1 - y0), x1 - x0)) % 180.0
        out.append((x0, y0, x1, y1, length, ang))
    return out


def segment_stats(segs):
    """How the edge length splits by direction, and the segments' lengths."""
    total = sum(s[4] for s in segs) or 1.0
    near_h = sum(s[4] for s in segs if min(s[5], 180 - s[5]) < 15) / total
    near_v = sum(s[4] for s in segs if abs(s[5] - 90) < 15) / total
    hist = [0.0] * 12
    for s in segs:
        hist[int(s[5] // 15) % 12] += s[4] / total
    return {"segments": len(segs), "length": stats([s[4] for s in segs]), "horizontal": round(near_h, 2),
            "vertical": round(near_v, 2), "oblique": round(1 - near_h - near_v, 2),
            "angle_hist_15deg": [round(h, 3) for h in hist]}


def draw_segments(img, segs, path):
    im = img.convert("RGB")
    d = ImageDraw.Draw(im)
    for x0, y0, x1, y1, length, ang in segs:
        near_h = min(ang, 180 - ang) < 15
        near_v = abs(ang - 90) < 15
        c = (60, 120, 255) if near_h else (255, 60, 60) if near_v else (60, 220, 90)
        d.line([(x0, y0), (x1, y1)], fill=c, width=2)
    im.save(path)


def image_mode(src, out, name):
    img = Image.open(src).convert("L")
    gray = np.asarray(img)
    segs = segments(gray)
    st = segment_stats(segs)
    draw_segments(Image.open(src), segs, os.path.join(out, name + "_segments.png"))
    return st


def model_mode(src, out):
    d = json.load(open(src))
    step, na, nz, nr = d["step"], d["arcs"], d["nz"], d["nr"]
    arc0 = d["arc0"]
    front = np.array(d["front"], dtype=float).reshape(nz, na)   # m back from r0, NaN: no wall
    plan = np.array(d["plan"], dtype=float).reshape(nr, na)     # ground height, m
    report = {}

    # Front elevation: the face's setback shaded (near: light, back: dark), z up.
    valid = ~np.isnan(front)
    f = np.where(valid, front, np.nanmax(front))
    lo, hi = np.nanpercentile(front, 2), np.nanpercentile(front, 98)
    shade = np.clip((hi - f) / max(hi - lo, 1e-6), 0, 1)
    # (and lit from the left, as a relief: the setback's slope along the cliff)
    gx = np.gradient(f, axis=1) / step
    relief = np.clip(0.55 + 0.6 * shade - 0.35 * np.tanh(gx), 0, 1)
    rgb = np.dstack([relief * 205 + 30] * 3).astype(np.uint8)
    rgb[~valid] = (200, 225, 245)
    rgb = rgb[::-1]   # (z up)
    base = Image.fromarray(rgb).resize((na * SCALE, nz * SCALE), Image.NEAREST)
    base.save(os.path.join(out, "front_shaded.png"))
    ann = base.copy()
    dr = ImageDraw.Draw(ann)

    def px(arc, z):
        return ((arc - arc0) / step * SCALE, (nz - 1 - z / step) * SCALE)

    by_bed = {}
    for b, arc, zf, back in d["feet"]:
        by_bed.setdefault(b, []).append((arc, zf))
    for b, pts in by_bed.items():
        pts.sort()
        run = [pts[0]]
        for p in pts[1:]:
            if p[0] - run[-1][0] > step * 1.5:
                if len(run) > 1:
                    dr.line([px(*q) for q in run], fill=(40, 90, 230), width=2)
                run = []
            run.append(p)
        if len(run) > 1:
            dr.line([px(*q) for q in run], fill=(40, 90, 230), width=2)
    for b, ja, z0, z1 in d["joints"]:
        dr.line([px(ja, z0), px(ja, z1)], fill=(230, 40, 40), width=2)
    for b, arc, zf, depth in d["lips"]:
        x, y = px(arc, zf)
        dr.rectangle([x, y - 2, x + SCALE, y + 2], fill=(255, 150, 0))
    for arc, h, r_from, r_to in d["ledges"]:
        x, y = px(arc, h)
        dr.rectangle([x, y - 1, x + SCALE, y + 1], fill=(40, 190, 60))
    sk = sorted(d["skyline"])
    dr.line([px(a, z) for a, z in sk], fill=(0, 0, 0), width=2)
    for a in d["clefts"]:
        x, _ = px(a, 0)
        dr.line([(x, 0), (x, 6)], fill=(150, 40, 200), width=SCALE)
    ann.save(os.path.join(out, "front_edges.png"))

    # Top view: the ground's height from above (along the cliff across, out from the middle up the image), with the
    # foot, the ledges' lips and the top's edge.
    ph = plan[::-1]
    shade = np.clip(ph / max(np.percentile(ph, 99), 1e-6), 0, 1)
    gy = np.gradient(ph, axis=0) / step
    relief = np.clip(0.25 + 0.65 * shade + 0.25 * np.tanh(gy * 0.5), 0, 1)
    rgbp = np.dstack([relief * 220 + 20] * 3).astype(np.uint8)
    top = Image.fromarray(rgbp).resize((na * SCALE, nr * SCALE), Image.NEAREST)
    dt = ImageDraw.Draw(top)
    r_base = d["r0"]

    def pp(arc, back):
        return ((arc - arc0) / step * SCALE, (nr - 1 - (back - r_base) / step) * SCALE)

    for arc, h, r_from, r_to in d["ledges"]:
        dt.line([pp(arc, r_from), pp(arc, r_to)], fill=(40, 190, 60), width=SCALE)
    for b, arc, zf, back in d["feet"]:
        x, y = pp(arc, back)
        dt.rectangle([x, y - 1, x + SCALE, y + 1], fill=(40, 90, 230))
    top.save(os.path.join(out, "top_edges.png"))

    # Numbers.
    beds = np.diff(np.array(d["beds"]))
    report["bed_thickness_m"] = stats(beds)
    spacing = []
    per_bed = {}
    for b, ja, z0, z1 in d["joints"]:
        per_bed.setdefault(b, []).append(ja)
    for b, js in per_bed.items():
        js = sorted(js)
        spacing += list(np.diff(js))
    report["joint_spacing_m"] = stats(spacing)
    report["joints_per_bed"] = stats([len(v) for v in per_bed.values()])
    run_through = 0
    for b, js in per_bed.items():
        up = set(round(x, 3) for x in per_bed.get(b + 1, []))
        run_through += sum(1 for x in js if round(x, 3) in up)
    report["joints_running_on"] = round(run_through / max(len(d["joints"]), 1), 2)
    feet_n = len(d["feet"])
    report["lip_fraction_of_bed_feet"] = round(len(d["lips"]) / max(feet_n, 1), 2)
    report["lip_depth_m"] = stats([l[3] for l in d["lips"]])
    # How far the face stands proud of its own surroundings (6 m along, 3 m up): the "blocks sticking out".
    med = ndimage.median_filter(f, size=(int(3 / step), int(6 / step)))
    proud = (med - f)[valid]
    report["proud_of_surroundings_m"] = {"p50": round(float(np.percentile(proud, 50)), 2),
                                         "p90": round(float(np.percentile(proud, 90)), 2),
                                         "p99": round(float(np.percentile(proud, 99)), 2),
                                         "over_0.5m": round(float((proud > 0.5).mean()), 3),
                                         "over_1m": round(float((proud > 1.0).mean()), 3)}
    # Edge directions in the front shading: where the setback changes sharply (a crease), which way the crease runs.
    gz, gxx = np.gradient(f)
    mag = np.hypot(gz, gxx)
    edge = (mag > 0.25) & valid
    ang = (np.degrees(np.arctan2(gz, gxx)) + 90.0) % 180.0   # (the crease runs across the gradient)
    if edge.any():
        a = ang[edge]
        report["crease_dirs"] = {"horizontal": round(float(((a < 15) | (a > 165)).mean()), 2),
                                 "vertical": round(float((abs(a - 90) < 15).mean()), 2),
                                 "of_face": round(float(edge.sum() / max(valid.sum(), 1)), 3)}
    report["image_segments_front_shaded"] = image_mode(os.path.join(out, "front_shaded.png"), out, "front_shaded")
    return report


def main():
    mode, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    if mode == "model":
        rep = model_mode(src, out)
    else:
        rep = image_mode(src, out, sys.argv[4] if len(sys.argv) > 4 else "image")
    print(json.dumps(rep, indent=1))
    json.dump(rep, open(os.path.join(out, (sys.argv[4] if len(sys.argv) > 4 else mode) + "_report.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
