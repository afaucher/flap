# The wing rig, feathers and plumage

Docs: `docs/design/wing_rig.md` (as built), `wing_rig_plan.html` (the plan; partly stale), research
`feather_rendering.md`, `feather_texture_study.md`, `flight_feather_look.md`, `plumage_coloring.md`.

## The wing rig (`scripts/bird/bird_rig.gd`, `scripts/bird/wing_shape.gd`)

- Bones in one plane, driven by `fold` alone (elbow and wrist coupled). Controls per wing: `flap`, `fold`, `sweep`,
  `twist`, `alula`, plus `hand_lift` (upstroke), `slot`, `tail_spread` / `pitch` / `twist`, `flex` (feather bend).
  Their sources: `wing_rig.md` "Control values".
- Flight is forward kinematics; folding blends in an analytic two-bone IK (`smoothstep(0.55, 1, fold)`): the wrist to
  `fold_anchor`, the elbow pole `fold_elbow`, both slid onto the species' flank at build (`body.onto_flank`). The solve
  is GDScript, not Godot's IK nodes, so feathers stay in step and it tests headless (the plan said otherwise).
- Folding, feathers blend toward their designed folded direction (aft), take the panel's common normal and lose their
  arch. (Folded by plain rotation, the pale underside turned outward; per-kind layers z-fought; the fairings stood up
  as a slab above the back.)
- Per species: `WingShape.DATA` (`numbers-and-wings.md`) and `BirdRig.POSE`.

## Feathers

- Per wing (`WingShape.feathers`): 10 primaries on the hand, `nsec` secondaries on the forearm, 3 tertials, greater
  coverts over p1-7 and every secondary, 10 lesser coverts, 3 alula feathers on the hand (at t 0.04 -- on the forearm's
  end they floated), optional under-coverts and axillaries. About 120 a bird. Tail: 12 rectrices, the central pair on
  top, spread capped at 100 deg.
- Widths: shared ratios (`W_*`: primaries 0.20 -> 0.13, secondaries 0.27, tertials 0.30, greater coverts 0.55, lesser
  0.60, alula 0.22; tail 0.2 -- "a hawk's ~22 cm tail feather is ~4.5 cm wide"). Wide enough that neighbours overlap
  into one surface. Outlines broad nearly to a rounded tip (pointed left saw-tooth gaps); camber 3% of length; outer
  primaries flex most.
- **One stacking order, open or folded**, innermost first: under-coverts, primaries, primary coverts, secondaries,
  tertials, forearm greater coverts, lesser coverts, alula; within a row each inner feather a `FOLD_STEP` above its
  outer neighbour. `probe_coplanar` finds z-fighting pairs.
- Drawn as one shared mesh in two MultiMeshes (plain, emarginated), each with a mirrored underside copy for two-sided
  colour. UV.x -1..1 across the vane, UV.y base to tip. Silhouette cards (~66: scapular, flank, rump, vent tracts) in
  the body's colour, kept flat and small (lifted, they stood off the back as a shelf); `--no-cards`.
- **GPU placement** (`feather_place.gdshaderinc`, default) from the joints; each feather's angle is linear in fold and
  slot so it's defined once. The GDScript placement is the reference (headless); `gpu_test_feathers` compares them per
  feather (0.2 um), `gpu_test_feather_image` per pixel. Change both.

## The atlas (`scripts/bird/feather_atlas.gd`, `tools/bake_feathers.gd`)

Masks, not colours (2048 x 1536): R shade / layer shadow, G rachis, B spot field, A edge distance. Six feather types
with variants: the shaft toward the leading edge (`asym`), `overlap` (how far the row in front covers), barb angles
24 / 40 deg outer / inner ("leading vanes have the smaller barb angles"), chevron bars following the barbs. Neighbours
never repeat a variant. Bake headless:
`& $godot --path . --headless --script res://tools/bake_feathers.gd [-- --feathers]`; the bake stamps the baker's MD5
(`test_feather_texture` checks it).

Shaders: `feather_texture.gdshader` (level 6, default: a light pass with transmission, edge glow, barb sheen, per-row
gloss), `feather_marks.gdshader` (level 5), `body_feathers.gdshader` (the contour tile over the shared chart; fray at
the outline). `feather.gdshader` is parked (looked worse than flat colour: its sheen flooded the cards). Use
transmittance, not `BACKLIGHT` (the feather above shadows it).

## Plumage (`scripts/bird/plumage.gd`, `plumage_coloring.md`)

- Built in comparable levels 0-6 (`--plumage N`); the plate is about **top vs under, zones and big marks** first, fine
  texture last.
- `DATA[id]`: `body` (back, rump, breast, belly, vent, flanks; countershade `line` / `soft`; `band`, `bib`, `scap`),
  `head` (crown, nape, face, throat, `cap`; `malar`, `disc`), `wing` (lesser, greater, tertial, alula, under,
  patagial, carpal), `groups` ([top, under] for primary, secondary, tail), `fingers` ([n outer primaries, darken top,
  under]), `marks` per group side: `tip`, `base`, `subterm`, `bars`, `bars_tip`, `fringe`, `streak` (averaged to a flat
  mid-tone below level 5).
- `TEXTURE[id][group_side]` (spot, fringe, shaft, detail, cup, vane, body tile) and `GLOSS[id]` (roughness, specular,
  transmission, tint: the crow glossy blue-violet, the owl's flight feathers matte).
- Sources: `plumage_coloring.md` section 1 (field marks, sourced), 4 (the data format), 5 (per-species hex). Hex values
  are estimates, not measured reflectance. **Record which bird you're matching** (the falcon is a male kestrel; the doc
  still lists peregrine).
- Colour rules: "white" about `#f2ece2`, "black" about `#1c1c22` so form still shades; fine bars average to a mid-tone
  at game distance; at 1080p a pixel is ~1.25 mm per metre of distance, a mark needs 2 px, barbs never resolve
  (`flight_feather_look.md`). Judge in game light and from the chase camera, not the gallery's top view.
- Randomise per feather and over patches -- never bars, direction or tracts. A busy body tile read as
  "pinecone / leopard"; square covert tips as tombstones; a mirrored projection made a herringbone down the keel.
- No photo-comparison tool exists for plumage: A/B sheets of gallery shots (`docs/images/*_ab.*`), and
  `tools/light_match.py <ref.jpg> <sheet.png>` for luminance / highlight / warmth stats against a concept.
- Tests: `test_plumage` (countershading, the red-tail's top and under, the patagial bar and wrist comma, fingers, the
  kestrel's head and moustache, the sparrow's bib, the owl's disc, dark tips, the subterminal band, level gating),
  `test_feather_texture` (the stamp, mipmaps, variants differ, the outer vane on the leading side both wings and tail
  halves, gloss ordering, cards rooted and mirrored, chart continuity across neck, trunk, head, wing).
