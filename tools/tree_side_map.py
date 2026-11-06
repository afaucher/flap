"""Side view of each tree's wood (the limbs as drawn, the trunk, perches, leaf masses) beside reference images, all at
the same scale: every panel's tree is drawn the same height, with guides at fractions of that height and width.

Usage: python tools/tree_side_map.py <tree_paths.json> <out.png> [--ref <img> <ground_y> <top_y> <trunk_x> <label>]...
  tree_paths.json comes from .\\probe.ps1 -Headless probe_tree_paths [--kind pine]. A reference's ground_y, top_y and
  trunk_x are pixel positions in that image (the trunk's foot, the crown's top), so it can be scaled and lined up.
"""
import json
import math
import sys

from PIL import Image, ImageDraw, ImageFont

PANEL_H = 620          # px: ground to treetop is TREE_PX in every panel
TREE_PX = 460
MARGIN_TOP = 70
WOOD_NEAR = (60, 40, 25)
WOOD_FAR = (190, 165, 140)
LEAF = (110, 160, 90, 38)


def font(size):
    for name in ("arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def lerp_col(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def trunk_path(oak):
    """The trunk as ArenaBuilder._trunk draws it, to its top (an oak's ends over the fork): [(y, r)]."""
    h, r0, cb = oak["height"], oak["radius"], oak["crown_base"]
    top = oak.get("stem", h)
    out = []
    for i in range(40):
        y = top * i / 39
        r = r0 * (1 + (0.4 - 1) * min(max(y / h, 0), 1))
        if cb > 0 and y > cb:
            r = r0 * (0.9 + (0.6 - 0.9) * min(max((y - cb) / max(top - cb, 0.1), 0), 1))
        r *= 1 + 0.55 * math.exp(-y / 0.9)
        out.append((y, r))
    return out


def best_azimuth(oak):
    """The view direction that spreads the limbs widest across the picture (as the concept is framed)."""
    cx, cz = oak["base"]
    pts = [(p[0] - cx, p[2] - cz) for l in oak["limbs"] for p in l["pts"]]
    best, best_w = 0.0, -1.0
    for k in range(72):
        a = math.pi * k / 72
        e = (math.cos(a), math.sin(a))
        us = [x * e[0] + z * e[1] for x, z in pts]
        w = max(us) - min(us)
        if w > best_w:
            best, best_w = a, w
    return best


def draw_oak(oak, w_px):
    h = oak["height"]
    s = TREE_PX / h                      # px per metre
    img = Image.new("RGBA", (w_px, PANEL_H), (250, 248, 242, 255))
    leaves = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(leaves)
    d = ImageDraw.Draw(img)
    gx, gy = w_px / 2, MARGIN_TOP + TREE_PX
    cx, cz = oak["base"]
    a = best_azimuth(oak)
    e = (math.cos(a), math.sin(a))
    n = (-math.sin(a), math.cos(a))

    def proj(p):
        x, z = p[0] - cx, p[2] - cz
        return gx + (x * e[0] + z * e[1]) * s, gy - p[1] * s, x * n[0] + z * n[1]

    guides(d, gx, gy, s, h, w_px)
    for f in oak["leaves"]:
        u, v, _ = proj(f["c"])
        rx = math.hypot(f["r"][0] * e[0], f["r"][2] * e[1]) * s
        ry = f["r"][1] * s
        ld.ellipse([u - rx, v - ry, u + rx, v + ry], fill=LEAF)
    img = Image.alpha_composite(img, leaves)
    d = ImageDraw.Draw(img)
    # Every drawn segment, far to near, shaded by depth.
    segs = []
    for l in oak["limbs"]:
        pts = [proj(p) for p in l["pts"]]
        for i in range(len(pts) - 1):
            segs.append(((pts[i][2] + pts[i + 1][2]) / 2, pts[i], pts[i + 1], l["r"][i] * s, l["r"][i + 1] * s))
    depth = max((abs(sg[0]) for sg in segs), default=1.0) or 1.0
    trunk = trunk_path(oak)
    tr = [(gx, gy - y * s, r * s) for y, r in trunk]
    segs.sort(key=lambda sg: -sg[0])
    drawn_trunk = False
    for dep, p0, p1, r0, r1 in segs:
        if not drawn_trunk and dep < 0:
            stem(d, tr)
            drawn_trunk = True
        col = lerp_col(WOOD_NEAR, WOOD_FAR, (dep / depth + 1) / 2 * 0.85)
        tube(d, p0, p1, r0, r1, col)
    if not drawn_trunk:
        stem(d, tr)
    for p in oak["perches"]:
        a0, a1 = proj(p["a"]), proj(p["b"])
        d.line([a0[0], a0[1], a1[0], a1[1]], fill=(230, 120, 20) if p["outpost"] else (20, 170, 60), width=3)
    d.text((10, 8), "%s %d   h %.1f m   crown from %.1f m   %d perches" % (oak.get("name", "oak"), oak["id"], h, oak["crown_base"], len(oak["perches"])),
           fill=(30, 30, 30), font=font(17))
    d.text((10, 30), "wood shaded by depth (near dark), perches green, outpost rail orange, leaf masses faint",
           fill=(90, 90, 90), font=font(13))
    return img.convert("RGB")


def stem(d, tr):
    for i in range(len(tr) - 1):
        tube(d, tr[i][:2], tr[i + 1][:2], tr[i][2], tr[i + 1][2], (85, 65, 50))


def tube(d, p0, p1, r0, r1, col):
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy)
    if L < 1e-6:
        return
    nx, ny = -dy / L, dx / L
    r0, r1 = max(r0, 0.6), max(r1, 0.6)
    d.polygon([(p0[0] + nx * r0, p0[1] + ny * r0), (p1[0] + nx * r1, p1[1] + ny * r1),
               (p1[0] - nx * r1, p1[1] - ny * r1), (p0[0] - nx * r0, p0[1] - ny * r0)], fill=col)
    d.ellipse([p1[0] - r1, p1[1] - r1, p1[0] + r1, p1[1] + r1], fill=col)


def guides(d, gx, gy, s, h, w_px):
    """Lines at quarters of the tree's height and every half height across, labelled in tree heights."""
    f = font(12)
    for q in range(5):
        y = gy - q * 0.25 * h * s
        d.line([0, y, w_px, y], fill=(205, 200, 190) if q else (120, 110, 100), width=1)
        d.text((4, y - 14), "%.2fh" % (q * 0.25), fill=(140, 130, 120), font=f)
    k = 1
    while k * 0.5 * h * s < w_px / 2:
        for sg in (-1, 1):
            x = gx + sg * k * 0.5 * h * s
            d.line([x, MARGIN_TOP - 10, x, gy], fill=(215, 210, 200), width=1)
            d.text((x + 3, gy + 4), "%+.1fh" % (sg * k * 0.5), fill=(140, 130, 120), font=f)
        k += 1
    d.line([gx, MARGIN_TOP - 10, gx, gy], fill=(215, 210, 200), width=1)


def draw_ref(path, ground_y, top_y, trunk_x, label, w_px):
    src = Image.open(path).convert("RGB")
    k = TREE_PX / (ground_y - top_y)
    src = src.resize((max(1, int(src.width * k)), max(1, int(src.height * k))), Image.LANCZOS)
    img = Image.new("RGB", (w_px, PANEL_H), (250, 248, 242))
    ox = int(w_px / 2 - trunk_x * k)
    oy = int(MARGIN_TOP + TREE_PX - ground_y * k)
    img.paste(src, (ox, oy))
    d = ImageDraw.Draw(img, "RGBA")
    gx, gy = w_px / 2, MARGIN_TOP + TREE_PX
    s = TREE_PX / 1.0                    # one tree height
    f = font(12)
    for q in range(5):
        y = gy - q * 0.25 * s
        d.line([0, y, w_px, y], fill=(255, 255, 255, 150) if q else (255, 60, 60, 220), width=1)
        d.text((4, y - 14), "%.2fh" % (q * 0.25), fill=(255, 255, 255, 230), font=f)
    k2 = 1
    while k2 * 0.5 * s < w_px / 2:
        for sg in (-1, 1):
            x = gx + sg * k2 * 0.5 * s
            d.line([x, MARGIN_TOP - 10, x, gy], fill=(255, 255, 255, 110), width=1)
        k2 += 1
    d.line([gx, MARGIN_TOP - 10, gx, gy], fill=(255, 255, 255, 110), width=1)
    d.rectangle([0, 0, w_px, 52], fill=(250, 248, 242, 235))
    d.text((10, 8), label, fill=(30, 30, 30), font=font(17))
    return img


def main(argv):
    data = json.load(open(argv[1]))
    out = argv[2]
    refs = []
    i = 3
    while i < len(argv):
        if argv[i] == "--ref":
            refs.append((argv[i + 1], float(argv[i + 2]), float(argv[i + 3]), float(argv[i + 4]), argv[i + 5]))
            i += 6
        else:
            i += 1
    w = 1100
    panels = [draw_ref(*r, w) for r in refs] + [draw_oak(o, w) for o in data["oaks"]]
    cols = 2
    rows = (len(panels) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols + 10 * (cols - 1), PANEL_H * rows + 10 * (rows - 1)), (60, 60, 60))
    for k, p in enumerate(panels):
        sheet.paste(p, ((k % cols) * (w + 10), (k // cols) * (PANEL_H + 10)))
    sheet.save(out, quality=90)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv)
