# Bills, from traced photos

The bills were generic (one parametric cone with a hook, the colour smeared per vertex) until each was lofted on its
species' own side profile traced from a photo. The pipeline:

```
tools/beak_profiles.py (REFS: traces)  ->  tools/bill_profiles_emit.py  ->  scripts/bird/bill_profiles.gd (generated)
                                                                           ->  Face.beak_meshes (loft) + bill.gdshader
tests/probe_beak_profile.gd (the drawn bill as JSON)  ->  tools/beak_profiles.py  ->  a chart against the photo
```

## 1. Trace the photo (`tools/beak_profiles.py`, `REFS[id]`)

- A side-on Wikimedia Commons photo at 1600 px wide, the bill shut (or open: `open_lower` turns the lower mandible
  shut, as the sparrow's), the licence in `src`. `mirror` for a bird facing left.
- Points in the photo's pixels (x right, y down), a few px on a grid at 1-2x zoom: `base` (the culmen's base, where
  the feathers end on the bill's top), `tip`, `eye` (x, y, radius), `gape_line` (two points along the cutting edge:
  the bill's x axis), `lines`: `culmen`, `gape` (the upper's cutting edge), `under` (the lower's underside), `head`,
  `throat`; `marks`: `cere ends` (raptors), `bristles end` (crow).
- `mm`: (from, to, millimetres) -- the measured bill length between two named points (`base` / a mark, `tip`). This
  scales the photo.
- `LIFE_R[id]`: the life head's half-width in mm (`eyes_and_beaks.md` 2.2; crow 23, sparrow 10.5, hawk 30, falcon 24.5
  -- an estimate --, owl 55). The bill goes into head radii by it, so it keeps its proportion to our ~1.2x head.
  Measured against the head, not in metres: getting this wrong made every bill look 20% long once.
- Add the id to `ORDER` and `NAMES`.

## 2. Emit the ribs (`python tools/bill_profiles_emit.py [--ribs <png>]`)

- The traces are scaled into the bill's frame (origin the culmen's base, x forward along the gape line, y up; the
  owl, with no gape seen, along the base-to-tip chord), Catmull-Rom splined and lightly smoothed.
- Ribs: upper -- points along the culmen paired with the cutting edge; lower -- along the underside, paired with its
  cutting edge. Over the base they run straight across the gape line; from 0.4 to 0.85 of the length they turn to the
  culmen's normal, so they follow a raptor's hook (the owl: normals throughout, it is all hook). Along the hook the
  partners are spread evenly to the tip and never run backward. **Check the pairing with `--ribs <png>`**: fanned ribs
  at the base or the hook make a twisted loft.
- The lower's cutting edge is the gape line as far as the lower's tip (shut, it meets the upper's); the sparrow's
  open jaw is turned shut; the owl's lower bill is synthesized under the upper's front half (it's hidden in the disc).
- Writes `scripts/bird/bill_profiles.gd` (`BillProfiles.DATA[id]`: upper, lower ribs, marks, the photo's eye).
  Generated: don't edit; re-run after any trace change. **No crow fallback**: a species without a trace errors.

## 3. The loft (`Face.beak_meshes`) and its numbers (`Face.DATA[id].beak`)

- Ribs splined into `BILL_RINGS` (44) rings; round each a half-ellipse of half-width `w` (head radii, at the base)
  tapering by `wp`, narrowed toward the culmen by `ridge`; closed under by the palate (vaulted `PALATE`) or the mouth's
  floor. `lw` the lower's width to the upper's; the lower tucked inside the upper by `LOWER_TUCK`.
- The base's section is carried in toward the head's centre (`BILL_BURY` 0.6, 4 rings, shrinking) so the bill grows
  out of the face and nothing shows past the head.
- `pitch` turns the bill's frame down (the owl -70); `at` = [the culmen base's height, how far it stands ahead of the
  head's front] (`Face.bill_base`).
- Vertex data for the shader: UV (share to the tip, height up the rib), UV2 (the point in the bill frame), COLOR.r
  (across), COLOR.g (the surface: 0 upper outside, 1/3 palate, 2/3 lower outside, 1 mouth floor). Normals from grid
  differences, outward; triangles wound clockwise from outside (Godot's front faces).
- Current values: crow `w` .3 `wp` .75 `ridge` .3 `lw` .92 `at` [0.55, 0.1]; hawk `w` .22 `ridge` .35 `at` [0.4, 0.4];
  falcon `w` .2 `at` [0.15, 0.18] with the `tubercle`; sparrow `w` .36 `wp` .85 `at` [0.25, 0.22]; owl `w` .08
  `pitch` -70. Read `face.gd` for the rest.

## 4. The look (`scripts/bird/bill.gdshader`, set by `Face.bill_material`)

Per pixel from the mesh's coordinates, so edges stay sharp: `bill` at the base to `bill_tip` over `tip_range`,
keratin growth lines and mottle, a paler cutting edge (`edge`), `gloss`; the cere's front edge from the traced mark,
leaning back `cere_lean` per unit down, in `cere_col`; the `nostril` [x, y, rx, ry] in the bill frame (the kestrel's
`tubercle` in it); the crow's bristles to the traced `bristles end`, leaning `bristle_lean`; the `mouth` lining.

## 5. The face round it

- **Snout** (`Face.snout`, applied in `BirdRig._head_point`): where the bill's base stands ahead of the head (`at`'s
  second number), the head's front is pushed out toward the middle of the bill's base -- flat-topped out to the nearer
  of the culmen base's angle and the bill's side (`0.8 atan(w r / |mid|)`: wider poked through the kestrel's bill),
  then easing `(1-t^2)^2` to nothing by `outer`, kept short of the eyes and the neck's ring. A dome aimed at the
  culmen left a shelf; aimed at the base's middle without the flat top, a block showed.
- **Eye seat** (`Face.eye_seat`): the eye `back` degrees further round than its optic axis (crow 3, hawk 8, falcon 4,
  sparrow 5) so it sits as far behind the bill as in the photo, facing out from its seat. Moving it back while it
  still faced the optic axis buried it. Keep `back` small; the snout makes up the rest.

## 6. Chart and test

- Chart (iterate on this):
  ```
  & $godot --path . --headless --script res://tests/probe_beak_profile.gd -- --out <scratch>\new.json
  python tools/beak_profiles.py <scratch>\new.json <scratch>\new_profiles.jpg
  ```
  Left panel: the face, ours filled, the photo's outline in orange, scaled to our head with its gape line and culmen
  base on ours (length, depth, pitch, hook, the eye's place). Right: the bill alone, chord = 1 (shape whatever the
  length). Printed: chord and eye distance, ours vs photo.
- Close-ups: `.\run.ps1 --scene res://scenes/rig_gallery.tscn --only <id> --view head|profile --pose folded --zoom 3
  --ortho --time 1 --shot <png>` (ortho: a perspective close-up clips on the near plane).
- `tests/test_bill_profile.gd` holds it: the silhouette's top and bottom at five stations (0.25-0.85 of the culmen's
  reach) within `0.03 + 0.04 x length`, the tip, the mandibles meeting along the gape, both sides the same, the eye
  0.85-1.15 of the photo's distance behind the base (not the owl), the eyes facing out from their seats, the head
  surface reaching the bill's base, the cere ending on the drawn culmen, the nostril on the upper's side. Its `REF` is
  read off the traces (`bill_profiles_emit.curves(id)` in head radii: the culmen's and the underside's y at those x,
  the tip, the eye's centre), **not the ribs** -- re-read it when a trace changes; never from the mesh.
- `tests/test_face.gd` holds only that the bill stands out ahead of the head.
- Mutations: `bill-generic-profile`, `bill-no-snout`, `eye-seat-ignored`, `eye-cap-off-seat`, `bill-gape-gap`.

## Known limits (as of the rebuild)

The owl's eye is about half the photo's distance from its bill (its bill is set in the disc; left); the sparrow's
buried lower-jaw heel shows a small facet under the chin in close side views; eyes face up to 8 deg more sideways
than the optic-axis estimates; the kestrel's `LIFE_R` is estimated.
