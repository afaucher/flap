# Draws tests/probe_floor_map.gd's JSON: the mound heights in steps beside how the fine floor mesh draws each cell.
#   python tools/floor_map.py <map.json> <out.png>
import json, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
n, res = d["n"], d["res"]
ox, oz = d["origin"]
H = np.array(d["heights"], dtype=np.float32).reshape(n, n)  # [j (z), i (x)]
segs, step = d["segs"], d["step"]
fcx, fcz = d["fine_centre"]
half = d["fine_size"] * 0.5
cells = np.array(d["cells"], dtype=np.uint8).reshape(segs, segs)

# World window: the fine field's square.
X0, X1 = fcx - half, fcx + half
Z0, Z1 = fcz - half, fcz + half
PX = 5  # px per metre
W = int(round((X1 - X0) * PX))
F = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 22)
FB = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 30)
FS = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 18)


def to_px(x, z):
    return ((x - X0) * PX, (z - Z0) * PX)


# --- Panel 1: heights in steps ---
BANDS = [  # (upper bound m, colour, label)
    (0.0, (236, 236, 228), "flat (0)"),
    (0.02, (253, 231, 178), "up to 2 cm"),
    (0.05, (250, 196, 120), "2 - 5 cm"),
    (0.10, (232, 146, 66), "5 - 10 cm"),
    (0.15, (196, 98, 42), "10 - 15 cm"),
    (0.20, (140, 60, 32), "15 - 20 cm"),
    (0.2201, (70, 32, 22), "20 - 22 cm (mound tops)"),
    (1.00, (150, 40, 170), "over 22 cm (root humps)"),
]
xs = X0 + (np.arange(W) + 0.5) / PX
zs = Z0 + (np.arange(W) + 0.5) / PX
gi = np.clip(np.round((xs - ox) / res).astype(int), 0, n - 1)
gj = np.clip(np.round((zs - oz) / res).astype(int), 0, n - 1)
inside_x = (xs >= ox) & (xs <= ox + (n - 1) * res)
inside_z = (zs >= oz) & (zs <= oz + (n - 1) * res)
h = H[np.ix_(gj, gi)] * (inside_z[:, None] & inside_x[None, :])
img1 = np.zeros((W, W, 3), np.uint8)
lo = -1.0
for up, col, _ in BANDS:
    m = (h > lo) & (h <= up) if up > 0 else (h <= 0)
    img1[m] = col
    lo = up
p1 = Image.fromarray(img1)

# --- Panel 2: how the fine mesh draws each cell ---
COL = {0: (196, 214, 236), 1: (236, 236, 228), 4: (120, 196, 170), 8: (30, 130, 110)}
ci = np.clip(((xs - (fcx - half)) / step).astype(int), 0, segs - 1)
cj = np.clip(((zs - (fcz - half)) / step).astype(int), 0, segs - 1)
c = cells[np.ix_(cj, ci)]
img2 = np.zeros((W, W, 3), np.uint8)
for k, col in COL.items():
    img2[c == k] = col
# faint height relief on panel 2 so the joins read against the mounds
mound = h > 0
img2[mound & (c == 1)] = (214, 200, 180)
p2 = Image.fromarray(img2)


def overlay(p, tiles=False):
    dr = ImageDraw.Draw(p)
    if tiles:
        for t in d["tiles"]:
            a = to_px(t[0], t[1]); b = to_px(t[2], t[3])
            dr.rectangle([a, b], outline=(90, 90, 110), width=1)
    for o in d["openings"]:
        a = to_px(o[0] - o[2], o[1] - o[2]); b = to_px(o[0] + o[2], o[1] + o[2])
        dr.ellipse([a, b], outline=(70, 140, 60), width=2)
    for t in d["trees"]:
        x, z = to_px(t[0], t[1]); r = max(1.5, t[2] * PX)
        dr.ellipse([x - r, z - r, x + r, z + r], fill=(40, 60, 40))
    for o in d["outposts"]:
        x, z = to_px(o[0], o[1])
        dr.rectangle([x - 5, z - 5, x + 5, z + 5], fill=(200, 40, 40), outline=(255, 255, 255))
    r = d["hole"] * PX
    cx, cz = to_px(0, 0)
    dr.ellipse([cx - r, cz - r, cx + r, cz + r], outline=(30, 70, 200), width=3)
    e = d["half_extent"]
    a = to_px(-e, -e); b = to_px(e, e)
    dr.rectangle([a, b], outline=(0, 0, 0), width=1)
    # scale bar: 20 m
    dr.rectangle([20, W - 30, 20 + 20 * PX, W - 24], fill=(0, 0, 0))
    dr.text((20, W - 58), "20 m", font=FS, fill=(0, 0, 0))


overlay(p1)
overlay(p2, tiles=True)

PAD, TOP, LEG = 30, 70, 250
canvas = Image.new("RGB", (PAD * 3 + W * 2, TOP + W + LEG), (250, 250, 247))
canvas.paste(p1, (PAD, TOP))
canvas.paste(p2, (PAD * 2 + W, TOP))
dr = ImageDraw.Draw(canvas)
dr.text((PAD, 20), "Floor height (mounds, in steps)", font=FB, fill=(20, 20, 20))
dr.text((PAD * 2 + W, 20), "How the fine floor mesh draws it", font=FB, fill=(20, 20, 20))


def swatch(x, y, col, label, outline=None):
    dr.rectangle([x, y, x + 26, y + 26], fill=col, outline=outline or (120, 120, 120))
    dr.text((x + 36, y - 2), label, font=F, fill=(20, 20, 20))


y0 = TOP + W + 20
for k, (_, col, label) in enumerate(BANDS):
    swatch(PAD + (k % 3) * 310, y0 + (k // 3) * 36, col, label)
tot = cells.size
cnt = {k: int((cells == k).sum()) for k in (0, 1, 4, 8)}
mx = PAD * 2 + W
swatch(mx, y0, COL[8], f"joined, 8 x 8 cell fans  ({100 * cnt[8] / tot:.1f} % of cells)")
swatch(mx, y0 + 40, COL[4], f"joined, 4 x 4 cell fans  ({100 * cnt[4] / tot:.1f} %)")
swatch(mx, y0 + 80, (236, 236, 228), f"plain 0.4 m cells, 2 triangles each  ({100 * cnt[1] / tot:.1f} %)")
swatch(mx, y0 + 120, (214, 200, 180), "  (plain cells over a mound)")
swatch(mx, y0 + 160, COL[0], f"dropped: drawn by the flat ring instead  ({100 * cnt[0] / tot:.1f} %)")
dr.text((PAD, y0 + 112), f"Highest mound {H.max() * 100:.0f} cm. Outside this square the floor is flat out to {d['outer']:.0f} m (the ring).", font=FS, fill=(40, 40, 40))
dr.text((PAD, y0 + 136), f"Blue circle: the ring's hole, {d['hole']:.1f} m (was 127 m, the fine mesh's corner). Black square: the arena, +/-{d['half_extent']:.0f} m.", font=FS, fill=(40, 40, 40))
dr.text((PAD, y0 + 160), "Dark dots: trunks. Red squares: outposts. Green circles: clearings / openings. Grey boxes (right): the 8 x 8 cull tiles.", font=FS, fill=(40, 40, 40))
dr.text((PAD, y0 + 184), "Fine mesh triangles: 472k before, 310k now (ring cut ~148k, joins ~15k). GPU 12.56 -> 12.28 ms.", font=FS, fill=(40, 40, 40))
canvas.save(out, quality=92)
print(canvas.size, cnt)
