# The arena's edge

The pine wood is a circle 85 m across its radius (`ArenaLayout.boundary`): a ring of edge posts stands just
inside it, and a soft wall pushes birds back past it (`Bird._apply_assists`). Until now there was nothing beyond
but bare ground and haze to the horizon, so nothing said where the edge was. This is what stands there now.

The concept: `docs/images/concepts/r5_edge_split.jpg` (Gemini, from our own chase shot `docs/images/edge/today_chase_canopy.jpg`),
its top left (a broken limestone escarpment) and bottom right (open heath). Of the four edges tried, those two;
the river and rival wood and the balloon line were set aside (`docs/design/...` round five in the session notes).

## What's there

- **The escarpment** (`Escarpment`, built by `EdgeBuilder._rock` and `_blocks`): one sector of the ring, 104 deg wide,
  its foot 14 m past the boundary. It stands on the side away from the sun, turned 50 deg round (`RAKE`) so the light
  falls across its face and every block casts a shadow (head-on light made it a flat cream wall). As in the concept:
  a scree heap with flat stones on it, a lower broken tier and its heathery ledge, a second short tier, then the
  tall wall to a top about 40 m up (the tallest pines are 32 m), cleft by deep gullies every 30 m or so; then a
  plateau that levels off and runs into the hills. Underneath it is one height field over a polar grid -- the
  mesh, its collision (the same grid), the AI's clearance queries and the tests all read `Escarpment.height` --
  and over it, the rock as limestone breaks: squared, sharp-edged blocks (chamfered, corners knocked off;
  `_block_mesh`) set into the faces in courses, longer than they're high, whole masses of them standing proud or
  set back, harder beds jutting as lips with a shadow under them; and fallen into the scree, sorted by size as
  talus is (small against the foot, the biggest rolled out to the toe), the big ones solid. Height-field faces
  alone can't have a sharp corner or an overhang: the blocks are what make it read as rock.
- **Its dressing**: heather and small pines on the ledges, a few taller ones along the top, placed on the rock's grid
  as drawn.
- **The heath**: past the posts the ground shader turns from needle litter to heath (`heath.gdshaderinc`: straw and
  olive grass, heather patches, bare earth), with grass tufts and heather thick by the fence and thinning out to
  130 m; low rolling hills from there to the horizon (`EdgeBuilder._hills`), with stands of pines on them.
- **The fence**: two strands of wire from post to post, sagging between them.

Only the rock is solid. The ledge pines, boulders, tufts, heather and far pines are drawn only.

## Perches on the rock, and the wall

In the escarpment's sector the soft wall stands 24 m past the cliff's foot (`ArenaLayout.reach`, `Escarpment.reach`),
just past the top's edge, so birds can fly in to the rock. The rock has perches (`Escarpment.perch_spots`, added by
`ArenaLayout.add_rock` under one `Kind.ROCK` entry in `trees`):

- the flat stones on the scree, 2-3 m up (9; no scree block falls on them or across the way in from the wood);
- spots just back from the ledges' lips, `PERCH_EVERY` apart along each tier: every 11 m on the lowest ledge, 26 m
  on the second, none on the wall or the top (seed 7: 9 at about 10 m, 3 at 18 m, none above).

Many low and few high, on purpose: the cliff is somewhere to drop in on and duck behind, not a gallery to sit
above the fight. A perch keeps a metre clear of a joint between blocks (the ledge level either side of it).

The AI sees the rock: `ArenaLayout.rock_clear` is part of `clear_by` and `segment_clear` (skipped only for the rock's
own perches, coming in or leaving), and the planner's lattice reaches out to the wall.

## Cost

Building it adds about 0.6 s to loading the wood (the rock's tier layout is worked out once per column of the grid,
`Escarpment.column`; the dressing is placed on the built grid; the instance buffers are filled in one go). Drawn: the
rock (90k triangles, one draw), the hills, and six instanced batches.

## Open

- **The haze.** The golden look's volumetric fog turns everything past 50 m cream: the heath and hills read as in
  the concept with the fog off (`tests/probe_edge_view.gd --no-fog`), the rock less so. The concept has clear
  air and a blue sky. Matching it means less haze outside the wood (or a look change), which is a call for the look.
- A limestone photoscan for the rock (Poly Haven has several) would do more than any more noise in its shader.
- The wood doesn't thin toward the heath (the concept's bottom right): that changes the layout the AI tests fly.
- A wooden platform on a ledge, as in the concept: an outpost on the rock.

## Looking at it

`.\run.ps1`-style, windowed: `Godot --path . -- --run-test probe_edge_view --out-dir <dir> --heading cliff|heath|away`
(chase shots at crown height, among the trunks, over the canopy, an overview; `--no-fog`, `--look <name>`).
