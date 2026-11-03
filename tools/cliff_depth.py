"""Depth from a single picture of a cliff (Depth Anything V2 Small, ONNX Runtime), and what it says of the cliff's shape.

    python tools/cliff_depth.py analyze <png/jpg> <out dir> <name>
    python tools/cliff_depth.py validate <our ortho png> <probe json> <out dir>

The model (Apache-2.0; onnx-community/depth-anything-v2-small) lives at build/deps/models/depth-anything-v2-small/
model.onnx, outside the repo. It gives relative inverse depth (larger: nearer), up to an unknown scale and offset, so
every measure here is relative: shares of the cliff's height and of its depth range.

analyze: the depth map (shaded), the face's profile up its height (how far forward each height stands: the talus in
front of the foot, the lean, the lips), its plan along the width at mid height (bays and buttresses: a top view),
the local relief (how far blocks stand proud of their surroundings), and the depth edges (creases) by direction.

validate: our own straight-on render (probe_edge_view --heading ortho, the middle 60%) against our exact depth from the
model (probe_cliff_edges): how well the estimate's ranks and its local relief follow the truth -- how far to trust
it on the concept.
"""
import json
import math
import os
import sys

import numpy as np
import onnxruntime as ort
from PIL import Image
from scipy import ndimage, stats as sst

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(HERE, "..", "..", "..", "..", "build", "deps", "models", "depth-anything-v2-small", "model.onnx")
if not os.path.exists(MODEL):
    MODEL = os.path.join(HERE, "..", "build", "deps", "models", "depth-anything-v2-small", "model.onnx")


def estimate(img):
    """Relative inverse depth (H x W, larger nearer) for a PIL image."""
    sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    W, H = img.size
    h = 518
    w = max(14, int(round(518 * W / H / 14.0)) * 14)
    x = np.asarray(img.convert("RGB").resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0
    x = (x - np.array([0.485, 0.456, 0.406], np.float32)) / np.array([0.229, 0.224, 0.225], np.float32)
    x = x.transpose(2, 0, 1)[None]
    name = sess.get_inputs()[0].name
    d = sess.run(None, {name: x})[0][0]
    return np.asarray(Image.fromarray(d.astype(np.float32)).resize((W, H), Image.BILINEAR))


def sky_mask(rgb):
    ref = np.median(rgb[:3].reshape(-1, 3), axis=0)
    near = np.linalg.norm(rgb - ref, axis=2) < 0.07
    lab, _ = ndimage.label(near)
    ids = np.unique(lab[0][near[0]])
    return ndimage.binary_opening(np.isin(lab, ids[ids > 0]), iterations=2)


def shade(d, mask, path):
    lo, hi = np.percentile(d[mask], 2), np.percentile(d[mask], 98)
    v = np.clip((d - lo) / max(hi - lo, 1e-6), 0, 1)
    rgb = np.dstack([v * 255, v * 200 + 30, (1 - v) * 200 + 40]).astype(np.uint8)
    rgb[~mask] = (230, 230, 230)
    Image.fromarray(rgb).save(path)


def profile_png(values, path, horizontal):
    """A 1-D profile as a small chart (values 0..1)."""
    n = len(values)
    W, H = (900, 300) if horizontal else (300, 600)
    im = Image.new("RGB", (W, H), "white")
    from PIL import ImageDraw
    d = ImageDraw.Draw(im)
    pts = []
    for i, v in enumerate(values):
        if np.isnan(v):
            continue
        if horizontal:
            pts.append((i / max(n - 1, 1) * (W - 20) + 10, H - 10 - v * (H - 20)))
        else:
            pts.append((10 + v * (W - 20), i / max(n - 1, 1) * (H - 20) + 10))
    if len(pts) > 1:
        d.line(pts, fill=(30, 60, 200), width=2)
    im.save(path)


def analyze(d, rgb, out, name):
    sky = sky_mask(rgb)
    rock = ~sky
    H, W = d.shape
    top = np.array([np.argmax(rock[:, x]) for x in range(W)], dtype=float)
    top_y = float(np.median(top))
    ch = H - top_y
    lo, hi = np.percentile(d[rock], 5), np.percentile(d[rock], 95)
    n = np.where(rock, (d - lo) / max(hi - lo, 1e-6), np.nan)   # (0: far, 1: near, over the rock)
    rep = {}
    # Up the height: how far forward each height stands (median over the width).
    rows = np.nanmedian(n[int(top_y):], axis=1)
    k = max(int(ch * 0.03), 1)
    rows_s = ndimage.uniform_filter1d(np.nan_to_num(rows, nan=np.nanmean(rows)), k)
    face = float(np.median(rows_s[: int(ch * 0.5)]))   # (the upper half: the face)
    talus = rows_s > face + 0.25
    y = len(rows_s) - 1
    while y > 0 and talus[y]:
        y -= 1
    rep["profile_up"] = {"face_level": round(face, 3), "bottom_level": round(float(rows_s[-int(ch * 0.05):].mean()), 3),
                         "talus_share_of_height": round(float((len(rows_s) - 1 - y) / ch), 3),
                         "lean_top_v_mid": round(float(rows_s[: int(ch * 0.15)].mean() - rows_s[int(ch * 0.35): int(ch * 0.5)].mean()), 3)}
    profile_png(rows_s, os.path.join(out, name + "_profile_up.png"), horizontal=False)
    # Along the width at mid height (35-60% down the cliff): the plan, a top view of the face.
    band = n[int(top_y + ch * 0.35): int(top_y + ch * 0.6)]
    plan = np.nanmedian(band, axis=0)
    plan_s = ndimage.uniform_filter1d(np.nan_to_num(plan, nan=np.nanmean(plan)), max(int(ch * 0.02), 1))
    detr = plan_s - ndimage.uniform_filter1d(plan_s, max(int(W * 0.5), 3))
    big = ndimage.uniform_filter1d(plan_s, max(int(ch * 0.25), 3))
    rep["plan_along"] = {"range": round(float(np.percentile(plan_s, 95) - np.percentile(plan_s, 5)), 3),
                         "rough": round(float(detr.std()), 3),
                         "bays_and_buttresses_range": round(float(np.percentile(big, 95) - np.percentile(big, 5)), 3)}
    profile_png(np.clip(plan_s, 0, 1), os.path.join(out, name + "_plan.png"), horizontal=True)
    # Local relief: how far each spot stands proud of its surroundings (a fifth of the cliff's height round it).
    nf = np.where(rock, n, np.nanmean(n))
    relief = nf - ndimage.gaussian_filter(nf, ch * 0.05)
    r = relief[rock]
    rep["relief"] = {"p90": round(float(np.percentile(r, 90)), 3), "p99": round(float(np.percentile(r, 99)), 3),
                     "share_proud_over_0.08": round(float((r > 0.08).mean()), 3), "share_sunk_over_0.08": round(float((r < -0.08).mean()), 3)}
    # Creases: where the depth turns sharply, and which way they run.
    gy, gx = np.gradient(ndimage.gaussian_filter(nf, 1.5))
    mag = np.hypot(gx, gy) * ch
    edge = (mag > np.percentile(mag[rock], 85)) & rock
    ang = (np.degrees(np.arctan2(gy, gx)) + 90.0) % 180.0
    a = ang[edge]
    rep["creases"] = {"horizontal": round(float(((a < 15) | (a > 165)).mean()), 3), "vertical": round(float((abs(a - 90) < 15).mean()), 3),
                      "oblique": round(float(1 - ((a < 15) | (a > 165)).mean() - (abs(a - 90) < 15).mean()), 3)}
    shade(d, rock, os.path.join(out, name + "_depth.png"))
    rv = np.clip(relief * 5 + 0.5, 0, 1)
    rim = np.dstack([rv * 255] * 3).astype(np.uint8)
    rim[~rock] = (200, 225, 245)
    Image.fromarray(rim).save(os.path.join(out, name + "_relief.png"))
    return rep


def validate(png, probe, out):
    """Our render's estimated depth against our true depth."""
    img = Image.open(png).convert("RGB")
    rgb = np.asarray(img, dtype=float) / 255.0
    d_est = estimate(img)
    j = json.load(open(probe))
    step, na, nz = j["step"], j["arcs"], j["nz"]
    front = np.array(j["front"], dtype=float).reshape(nz, na)
    r0s = np.array(j["r0s"], dtype=float)
    foot = float(j["foot"])
    H, W = d_est.shape
    # (o.png: the middle 60% of a 162 x 54 m orthographic frame centred on the cliff's middle, z from -4 to 50)
    half_w = 162.0 * 0.6 / 2.0
    truth = np.full((H, W), np.nan)
    for yy in range(H):
        z = 50.0 - yy / (H - 1) * 54.0
        zi = int(round(z / step))
        if zi < 0 or zi >= nz:
            continue
        for xx in range(W):
            xv = -half_w + xx / (W - 1) * half_w * 2.0
            dth = math.asin(max(-1.0, min(1.0, xv / foot)))
            for _ in range(2):   # (the face's radius there, then the angle again)
                ai = int(round((dth * foot - j["arc0"]) / step))
                if ai < 0 or ai >= na or np.isnan(front[zi, ai]):
                    break
                r = r0s[ai] + front[zi, ai]
                dth = math.asin(max(-1.0, min(1.0, xv / r)))
            else:
                truth[yy, xx] = -(r * math.cos(dth))   # (nearer: larger)
    m = ~np.isnan(truth)
    rho = sst.spearmanr(d_est[m], truth[m]).statistic
    # Local structure: both high-passed (a twentieth of the cliff's height), then compared.
    def hp(a):
        f = np.where(m, a, np.nanmean(a[m]))
        return f - ndimage.gaussian_filter(f, H * 0.05)
    rho_local = sst.spearmanr(hp(d_est)[m], hp(truth)[m]).statistic
    shade(d_est, m, os.path.join(out, "ours_est_depth.png"))
    shade(np.nan_to_num(truth, nan=np.nanmin(truth)), m, os.path.join(out, "ours_true_depth.png"))
    rep = {"rank_correlation_whole": round(float(rho), 3), "rank_correlation_local_relief": round(float(rho_local), 3),
           "pixels": int(m.sum())}
    rep["analysis_est"] = analyze(d_est, rgb, out, "ours_est")
    return rep


def main():
    mode = sys.argv[1]
    if mode == "analyze":
        src, out, name = sys.argv[2], sys.argv[3], sys.argv[4]
        os.makedirs(out, exist_ok=True)
        img = Image.open(src).convert("RGB")
        rep = analyze(estimate(img), np.asarray(img, dtype=float) / 255.0, out, name)
    else:
        png, probe, out = sys.argv[2], sys.argv[3], sys.argv[4]
        os.makedirs(out, exist_ok=True)
        rep = validate(png, probe, out)
        name = "validate"
    print(json.dumps(rep, indent=1))
    json.dump(rep, open(os.path.join(out, name + "_depth_report.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
