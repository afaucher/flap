"""light_match.py: how an in-engine shot's light compares with a reference image (a concept render).

    python tools/light_match.py <reference.jpg> <sheet.png> [cell ...]

<sheet.png> is a forest preview sheet (800x450 cells, two per row); the cells are the views to measure (by index,
default all). For each image it prints: mean luminance, the brightest 5% (its mean), the share brighter than 0.8,
warmth (red minus blue) of the highlights, the midtones and the shadows, the darkest 10%, and saturation -- the
numbers that say whether we have the reference's warm, contrasty light.
"""
import sys

import numpy as np
from PIL import Image


def stats(im):
    a = np.asarray(im.convert("RGB").resize((640, 360))).astype(float) / 255.0
    a = a[30:, :]  # (the sheet's label strip)
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    hi = lum > np.percentile(lum, 95)
    sh = lum < np.percentile(lum, 10)
    mid = (lum > 0.3) & (lum < 0.6)
    warm = lambda m: float((a[..., 0][m] - a[..., 2][m]).mean()) if m.any() else 0.0
    return {
        "mean": lum.mean(), "top5": lum[hi].mean(), "over.8": 100.0 * (lum > 0.8).mean(),
        "warm_hi": warm(hi), "warm_mid": warm(mid), "warm_sh": warm(sh),
        "dark10": lum[sh].mean(), "sat": (a.max(-1) - a.min(-1)).mean(),
    }


def row(name, s):
    return (f"{name:28s} mean {s['mean']:.2f}  top5% {s['top5']:.2f}  >0.8 {s['over.8']:4.1f}%  warm hi {s['warm_hi']:+.2f}"
            f" mid {s['warm_mid']:+.2f} sh {s['warm_sh']:+.2f}  dark10% {s['dark10']:.2f}  sat {s['sat']:.2f}")


def main():
    ref = Image.open(sys.argv[1])
    sheet = Image.open(sys.argv[2])
    cells = [int(c) for c in sys.argv[3:]] or list(range((sheet.height // 450) * 2))
    print(row("reference", stats(ref)))
    for i in cells:
        c = sheet.crop(((i % 2) * 800, (i // 2) * 450, (i % 2) * 800 + 800, (i // 2) * 450 + 450))
        print(row(f"view {i}", stats(c)))


if __name__ == "__main__":
    main()
