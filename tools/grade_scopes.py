## Colourist's scopes for a set of images, one row each: the picture, an RGB histogram, the RGB parade (a waveform
## per channel), the vectorscope (hue and saturation, with the 75% colour targets and the skin-tone line) and the
## shadows / mids / highlights chips (the mean colour of each third of the tones), with the numbers.
##   python tools/grade_scopes.py <out.jpg> "concept=docs/images/concepts/r4_aces_outpost.jpg" "golden=<png>" ...
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
out = sys.argv[1]
items = [a.split('=', 1) for a in sys.argv[2:]]   # label=path
F = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 20)
Fs = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 15)
TH, PW = 260, 300           # row height, panel width
BG = (24, 24, 26)

def load(p):
    im = Image.open(p).convert('RGB')
    return im, np.asarray(im.resize((480, int(480 * im.height / im.width)))).astype(np.float32) / 255.0

def hist(a):
    img = Image.new('RGB', (PW, TH - 40), BG); d = ImageDraw.Draw(img)
    for x in range(0, PW, PW // 4): d.line([(x, 0), (x, TH)], fill=(45, 45, 48))
    hs = [np.histogram(a[..., c], 128, (0, 1))[0].astype(float) for c in range(3)]
    m = max(h.max() for h in hs)
    layer = np.zeros((TH - 40, PW, 3))
    for c, h in enumerate(hs):
        for i, v in enumerate(h):
            x0, x1 = int(i * PW / 128), int((i + 1) * PW / 128)
            layer[int((TH - 40) * (1 - v / m)):, x0:x1, c] = 1
    base = np.asarray(img).astype(float) / 255
    mix = np.where(layer.any(-1, keepdims=True), 0.25 + 0.65 * layer, base)
    return Image.fromarray((mix * 255).astype(np.uint8))

def parade(a):
    H = TH - 40; w = PW // 3
    img = np.zeros((H, PW, 3)); img[:] = np.array(BG) / 255
    small = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((w, 120))).astype(float) / 255
    for c in range(3):
        for x in range(w):
            h = np.histogram(small[:, x, c], H, (0, 1))[0]
            col = np.clip(np.log1p(h) / np.log1p(12), 0, 1)[::-1]
            img[:, c * w + x, c] = np.maximum(img[:, c * w + x, c], col)
            img[:, c * w + x, :] += (col * 0.15)[:, None]
    for y in (0.25, 0.5, 0.75):
        img[int(H * (1 - y)), :, :] = 0.3
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))

def cbcr(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return (b - y) / 1.8556, (r - y) / 1.5748

def vscope(a):
    S2 = TH - 40; img = Image.new('RGB', (S2, S2), BG); d = ImageDraw.Draw(img)
    c0 = S2 / 2; R = S2 / 2 - 6; k = R / 0.5
    d.ellipse([c0 - R, c0 - R, c0 + R, c0 + R], outline=(70, 70, 74))
    d.line([(c0 - R, c0), (c0 + R, c0)], fill=(50, 50, 54)); d.line([(c0, c0 - R), (c0, c0 + R)], fill=(50, 50, 54))
    # skin-tone line: the hue of a typical skin colour
    sb, sr = cbcr(np.array([[0.8, 0.6, 0.5]]))
    ang = np.arctan2(sr[0], sb[0]); d.line([(c0, c0), (c0 + R * np.cos(ang), c0 - R * np.sin(ang))], fill=(110, 90, 70))
    cb, cr = cbcr(a.reshape(-1, 3))
    H2, _, _ = np.histogram2d(-cr, cb, S2 // 2, [[-0.5, 0.5], [-0.5, 0.5]])
    H2 = np.clip(np.log1p(H2) / np.log1p(H2.max() / 6 + 1), 0, 1)
    sc = Image.fromarray((H2 * 255).astype(np.uint8)).resize((S2 - 12, S2 - 12))
    tint = Image.new('RGB', sc.size, (150, 255, 160))
    img.paste(tint, (6, 6), sc)
    for name, rgb in [('R', (0.75, 0, 0)), ('Y', (0.75, 0.75, 0)), ('G', (0, 0.75, 0)), ('C', (0, 0.75, 0.75)), ('B', (0, 0, 0.75)), ('M', (0.75, 0, 0.75))]:
        b_, r_ = cbcr(np.array([rgb]))
        x, y = c0 + b_[0] * k, c0 - r_[0] * k
        d.rectangle([x - 5, y - 5, x + 5, y + 5], outline=(160, 160, 160)); d.text((x + 7, y - 9), name, fill=(170, 170, 170), font=Fs)
    return img

def chips(a):
    img = Image.new('RGB', (PW, TH - 40), BG); d = ImageDraw.Draw(img)
    L = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    mx, mn = a.max(-1), a.min(-1); sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-4), 0)
    q = np.percentile(L, [0, 33, 66, 100])
    for i, tag in enumerate(['shadows', 'mids', 'highs']):
        m = (L >= q[i]) & (L <= q[i + 1]); c = a[m].mean(0)
        # chip, normalised up so its hue is readable, and its real level beside
        d.rectangle([8, 8 + i * 66, 70, 64 + i * 66], fill=tuple(int(v * 255) for v in c))
        cn = c / max(c.max(), 1e-3) * 0.85
        d.rectangle([74, 8 + i * 66, 104, 64 + i * 66], fill=tuple(int(v * 255) for v in cn))
        d.text((112, 10 + i * 66), f"{tag}  R-B {c[0] - c[2]:+.2f}", fill=(220, 220, 220), font=Fs)
        d.text((112, 30 + i * 66), f"luma {L[m].mean():.2f}  sat {sat[m].mean():.2f}", fill=(160, 160, 160), font=Fs)
    p = np.percentile(L, [5, 50, 95])
    d.text((8, TH - 62), f"luma p5 {p[0]:.2f}  p50 {p[1]:.2f}  p95 {p[2]:.2f}   contrast {L.std():.2f}", fill=(200, 200, 200), font=Fs)
    return img

W = 440 + PW + PW + (TH - 40) + PW + 50
sheet = Image.new('RGB', (W, 44 + TH * len(items)), (14, 14, 16)); d = ImageDraw.Draw(sheet)
for i, t in enumerate(['picture', 'RGB histogram', 'RGB parade (waveform)', 'vectorscope', 'tones (actual, hue)']):
    d.text(([10, 460, 470 + PW, 480 + 2 * PW, 490 + 2 * PW + TH - 40][i], 10), t, fill=(200, 200, 200), font=F)
for r, (label, path) in enumerate(items):
    im, a = load(path); y = 44 + r * TH
    th = im.resize((440, int(440 * im.height / im.width))); th = th.crop((0, 0, 440, min(th.height, TH - 40)))
    sheet.paste(th, (10, y)); d.text((10, y + TH - 36), label, fill=(240, 220, 170), font=F)
    sheet.paste(hist(a), (460, y)); sheet.paste(parade(a), (470 + PW, y))
    sheet.paste(vscope(a), (480 + 2 * PW, y)); sheet.paste(chips(a), (490 + 2 * PW + TH - 40, y))
sheet.save(out, quality=88)
print(out, sheet.size)
