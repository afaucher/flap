"""A cliff's profile from a side-on cross-section picture (the rock on the left, the face looking right, white beyond).

    python tools/cliff_section.py <out dir> <name>=<png> [<name>=<png> ...]
    python tools/cliff_section.py <out dir> <name>=plan:<probe_cliff_plan dir>@<m along> ...   # ours, cut from the model
    python tools/cliff_section.py <out dir> <name>=wall:<probe_cliff_edges json>@<m along> ...  # ours, with the overhangs

A plan cut: our ground's height (the probe's exact height field, so no overhangs) along the line out from the cliff at
<m along> the middle 120 m of probe_edge_view's top_aligned frame (0: its middle, - left), drawn as a picture of the
same kind (PX px per m, the plateau on the left) and then measured as any other. A plan cut can't show an overhang (the
height field is the rock's envelope, solid under every lip); a wall cut can: the wall's own sheet (probe_cliff_edges:
how far back the face stands at each height) for the face, the height field for the talus in front of it and the
plateau behind its top, at <m along> the cliff from the sector's middle.

Traces the profile (per row, the rock's outermost pixel, thin grid lines opened away), simplifies it to straight
pieces (TOL of the cliff's height), and classes each piece by its angle from horizontal: ledge (under LEDGE deg),
talus (LEDGE..FACE, below the face's foot), face (over FACE), overhang (the rock juts out above). Measures, in shares
of the cliff's height (lip to the ground in front) and in degrees: the overall angle lip to toe, the face's angle lip to
its foot (where the talus starts), the talus's angle and how much of the height it buries, each face piece's angle and
height, each ledge's width, and the overhangs. Draws the traced profile and its pieces over the picture.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from skimage.measure import approximate_polygon

TOL = 0.01      # of the cliff's height
COARSE = 0.05   # of the cliff's height
LEDGE = 20.0    # deg
FACE = 50.0     # deg
COL = {"face": (220, 60, 50), "ledge": (40, 160, 40), "talus": (60, 80, 220), "overhang": (200, 0, 200)}


def profile(path):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im, dtype=float)
    lum = a.mean(2)
    rock = lum < 238
    rock = ndimage.binary_opening(rock, structure=np.ones((7, 7)))
    rock = ndimage.binary_fill_holes(rock)
    H, W = rock.shape
    xs = np.full(H, np.nan)
    for y in range(H):
        r = np.nonzero(rock[y])[0]
        if r.size and r[0] < W * 0.2:   # (rock that reaches in from the left: the cut)
            # (the outermost pixel of the run joined to the left edge)
            gaps = np.nonzero(np.diff(r) > 3)[0]
            xs[y] = r[gaps[0]] if gaps.size else r[-1]
    ys = np.nonzero(~np.isnan(xs))[0]
    top = ys[0]
    # (the ground in front: the profile runs out to the right edge)
    ground = ys[-1]
    for y in ys:
        if xs[y] >= W - 8:
            ground = y
            break
    return im, xs, top, ground


def _pieces(pts, tol):
    poly = approximate_polygon(pts, tolerance=tol)
    out = []
    for (x0, y0), (x1, y1) in zip(poly, poly[1:]):
        dx, dy = x1 - x0, y1 - y0   # (down the cliff: dy > 0; outward: dx > 0)
        ang = math.degrees(math.atan2(dy, abs(dx))) if dx != 0 else 90.0
        kind = "overhang" if dx < -1 and dy > 1 else "face" if ang > FACE else "ledge" if ang < LEDGE else "talus"
        out.append({"kind": kind, "angle": ang, "dx": dx, "dy": dy, "p0": (x0, y0), "p1": (x1, y1)})
    return out


def pieces(xs, top, ground):
    """The profile in coarse pieces (COARSE of the plateau-to-ground drop: which part is the face, which the talus) and
    fine ones (TOL: the face's own steps, lips and overhangs)."""
    pts = np.array([(xs[y], y) for y in range(top, ground + 1) if not np.isnan(xs[y])])
    h = ground - top
    coarse = _pieces(pts, COARSE * h)
    # The lip: where the first steep coarse piece starts. The face's foot: where the last steep one ends, and the talus
    # runs from there down to where the slope flattens out onto the ground (the toe).
    steep = [k for k, p in enumerate(coarse) if p["kind"] in ("face", "overhang")]
    lip = coarse[steep[0]]["p0"]
    foot = coarse[steep[-1]]["p1"]
    # (the toe: where the ground in front starts, the last near-level run reaching the picture's right side)
    k = len(coarse)
    while k > steep[-1] + 1 and coarse[k - 1]["kind"] == "ledge":
        k -= 1
    toe = coarse[k - 1]["p1"] if k > steep[-1] + 1 else foot
    fine = _pieces(pts, TOL * h)
    return coarse, fine, lip, foot, toe


def measure(coarse, fine, lip, foot, toe):
    h = toe[1] - lip[1]   # (the cliff's height: lip to the ground in front)
    rep = {"height_px": int(h)}
    rep["overall_deg"] = round(math.degrees(math.atan2(toe[1] - lip[1], toe[0] - lip[0])), 1)
    rep["face_deg_lip_to_foot"] = round(math.degrees(math.atan2(foot[1] - lip[1], max(foot[0] - lip[0], 1e-6))), 1)
    rep["face_height"] = round((foot[1] - lip[1]) / h, 3)
    rep["face_setback"] = round((foot[0] - lip[0]) / h, 3)
    rep["talus_deg"] = round(math.degrees(math.atan2(toe[1] - foot[1], max(toe[0] - foot[0], 1e-6))), 1)
    rep["talus_buries"] = round((toe[1] - foot[1]) / h, 3)
    rep["talus_reach"] = round((toe[0] - foot[0]) / h, 3)
    face = [p for p in fine if lip[1] - 1 <= p["p0"][1] and p["p1"][1] <= foot[1] + 1]
    steep = [p for p in face if p["kind"] in ("face", "overhang")]
    fh = np.array([p["dy"] for p in steep])
    fa = np.array([p["angle"] if p["kind"] == "face" else 180.0 - p["angle"] for p in steep])   # (an overhang: past 90)
    rep["face_pieces"] = [{"deg": round(float(a), 1), "height": round(float(d / h), 3)} for a, d in zip(fa, fh)]
    if fh.size:
        rep["face_deg_height_weighted"] = round(float((fa * fh).sum() / fh.sum()), 1)
        rep["face_share_80_to_90"] = round(float(fh[(fa > 80) & (fa <= 90)].sum() / fh.sum()), 2)
        rep["face_share_overhanging"] = round(float(fh[fa > 90].sum() / fh.sum()), 2)
        rep["face_share_under_65"] = round(float(fh[fa < 65].sum() / fh.sum()), 2)
        rep["face_piece_height_median"] = round(float(np.median(fh) / h), 3)
    rep["ledges_width"] = [round(p["dx"] / h, 3) for p in face if p["kind"] == "ledge" and p["dx"] > 0.01 * h]
    rep["steepness_of_whole_face_share_flat"] = round(float(sum(p["dx"] for p in face if p["kind"] == "ledge") / max(foot[0] - lip[0], 1)), 2)
    return rep


def draw(im, xs, fine, lip, foot, toe, path):
    im = im.copy()
    d = ImageDraw.Draw(im)
    pts = [(x, y) for y, x in enumerate(xs) if not np.isnan(x)]
    d.line(pts, fill=(0, 0, 0), width=1)
    for p in fine:
        in_talus = p["p0"][1] >= foot[1] - 1
        kind = "talus" if in_talus and p["p1"][1] <= toe[1] + 1 else p["kind"]
        d.line([p["p0"], p["p1"]], fill=COL[kind], width=5)
        if p["dy"] > 8:
            mx, my = (p["p0"][0] + p["p1"][0]) / 2, (p["p0"][1] + p["p1"][1]) / 2
            d.text((mx + 8, my - 6), "%.0f" % p["angle"], fill=COL[kind])
    for q, c in ((lip, (0, 0, 0)), (foot, (0, 0, 0)), (toe, (0, 0, 0))):
        d.ellipse([q[0] - 7, q[1] - 7, q[0] + 7, q[1] + 7], outline=c, width=3)
    d.line([lip, foot], fill=(0, 0, 0), width=2)
    d.line([foot, toe], fill=(0, 0, 0), width=2)
    im.save(path)


PX = 12.0   # px per m, a plan cut's picture


def cut_from_plan(d, along, path):
    meta = json.load(open(os.path.join(d, "plan.json")))
    g = meta["grids"]["mid"]
    n = g["n"]
    h = np.fromfile(os.path.join(d, "plan_mid.bin"), dtype=np.float32).reshape(n, n)
    at = meta["at"]
    o = np.array([math.sin(at), math.cos(at)])   # (out from the arena: toward the plateau)
    right = np.array([-o[1], o[0]])
    centre = np.array([g["cx"], g["cz"]])
    ys = np.arange(30.0, -40.0, -1.0 / PX)
    prof = np.zeros(len(ys))
    for i, y in enumerate(ys):
        w = centre + right * along + o * y
        ci = int((w[0] - (g["cx"] - g["half"])) / g["step"])
        rj = int(((g["cz"] + g["half"]) - w[1]) / g["step"])
        if 0 <= ci < n and 0 <= rj < n:
            prof[i] = h[rj, ci]
    hpx = int((prof.max() + 10.0) * PX)
    img = np.full((hpx, len(ys), 3), 255, np.uint8)
    for x, v in enumerate(prof):
        img[max(int(hpx - (v + 4.0) * PX), 0):, x] = (205, 205, 200)
    Image.fromarray(img).save(path)
    return path


def cut_from_wall(path_json, along, path):
    j = json.load(open(path_json))
    step, na, nz, nr = j["step"], j["arcs"], j["nz"], j["nr"]
    ci = int(round((along - j["arc0"]) / step))
    front = np.array(j["front"], dtype=float).reshape(nz, na)[:, ci]
    ground = np.array(j["plan"], dtype=float).reshape(nr, na)[:, ci]
    r_lo = j["foot"] + j["r0"]
    r0 = j["r0s"][ci]
    rs = r_lo + np.arange(nr) * step
    face = r0 + front   # (m out from the middle at each height; NaN above the top)
    ok = ~np.isnan(face)
    top_z = np.nonzero(ok)[0].max() * step
    r_out = np.nanmin(face)           # (the farthest out the wall comes: in front of it, the talus)
    r_back = face[np.nonzero(ok)[0].max()]   # (the top's edge: behind it, the plateau)
    tal_top = float(np.interp(r_out - 0.5, rs, ground))
    r_max, r_min = rs[-1], max(rs[0], r_out - 40.0)
    W = int((r_max - r_min) * PX)
    Hpx = int((top_z + 14.0) * PX)
    img = np.full((Hpx, W, 3), 255, np.uint8)
    xs = np.arange(W)
    r_at = r_max - xs / PX   # (the plateau on the left: x grows toward the wood)
    g_at = np.interp(r_at, rs, ground)
    for y in range(Hpx):
        z = (Hpx - y) / PX - 4.0
        zi = int(round(z / step))
        wall = np.zeros(W, bool)
        if 0 <= zi < nz and ok[zi]:
            wall = r_at >= face[zi]
        z_ok = z <= g_at
        rock = wall | (z < 0.0) | (z_ok & ((r_at < r_out) | (r_at > r_back))) | (z_ok & (z <= tal_top))
        img[y, rock] = (205, 205, 200)
    Image.fromarray(img).save(path)
    return path


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    reps = {}
    for arg in sys.argv[2:]:
        name, src = arg.split("=", 1)
        if src.startswith("plan:"):
            d, along = src[5:].rsplit("@", 1)
            src = cut_from_plan(d, float(along), os.path.join(out_dir, name + "_cut.png"))
        elif src.startswith("wall:"):
            d, along = src[5:].rsplit("@", 1)
            src = cut_from_wall(d, float(along), os.path.join(out_dir, name + "_cut.png"))
        im, xs, top, ground = profile(src)
        coarse, fine, lip, foot, toe = pieces(xs, top, ground)
        reps[name] = measure(coarse, fine, lip, foot, toe)
        draw(im, xs, fine, lip, foot, toe, os.path.join(out_dir, name + "_profile.png"))
    print(json.dumps(reps, indent=1))
    json.dump(reps, open(os.path.join(out_dir, "sections_report.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
