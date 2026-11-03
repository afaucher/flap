## The numbers behind a grade (docs/design/color_grading.md): luma percentiles and spread, mean colour and
## saturation, the warmth (R - B) of the shadows, mids and highlights, the top quarter's colour (sky, canopy) and
## local contrast -- the reference first, then each image (its top 100 px cut off: the HUD).
##   python tools/grade_stats.py <reference.jpg> <ours.png> ...
import sys, numpy as np
from PIL import Image
def load(p, crop=None):
    im = Image.open(p).convert('RGB')
    if crop: im = im.crop(crop)
    im = im.resize((688, int(688*im.height/im.width)))
    return np.asarray(im).astype(np.float32)/255.0
def lin(c): return np.where(c<=0.04045, c/12.92, ((c+0.055)/1.055)**2.4)
def report(name, a):
    L = 0.2126*a[...,0]+0.7152*a[...,1]+0.0722*a[...,2]
    mx, mn = a.max(-1), a.min(-1)
    sat = np.where(mx>0, (mx-mn)/np.maximum(mx,1e-4), 0)
    q = np.percentile(L, [5, 25, 50, 75, 95])
    print(f"== {name}")
    print("  luma p5/25/50/75/95: " + " ".join(f"{v:.2f}" for v in q) + f"   std {L.std():.3f}")
    print(f"  mean rgb {a[...,0].mean():.3f} {a[...,1].mean():.3f} {a[...,2].mean():.3f}   sat mean {sat.mean():.2f} (p90 {np.percentile(sat,90):.2f})")
    for lo, hi, tag in [(0,25,'shadows'),(25,75,'mids'),(75,100,'highs')]:
        m = (L>=np.percentile(L,lo)) & (L<=np.percentile(L,hi))
        r,g,b = [a[...,i][m].mean() for i in range(3)]
        print(f"  {tag:8s} rgb {r:.3f} {g:.3f} {b:.3f}   warmth R-B {r-b:+.3f}  G-mag {g-(r+b)/2:+.3f}  sat {sat[m].mean():.2f}")
    top = a[:a.shape[0]//4]
    print(f"  top quarter (sky/canopy) rgb {top[...,0].mean():.3f} {top[...,1].mean():.3f} {top[...,2].mean():.3f}")
    # local contrast: mean abs laplacian
    lap = np.abs(4*L[1:-1,1:-1]-L[:-2,1:-1]-L[2:,1:-1]-L[1:-1,:-2]-L[1:-1,2:]).mean()
    print(f"  local contrast {lap:.4f}")
report('concept', load(sys.argv[1]))
for p in sys.argv[2:]:
    report(p.split('/')[-1], load(p, (0, 100, 1376, 768)))
