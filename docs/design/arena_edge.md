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
- **Its stone**: photoscans (assets/LICENSES.md) on triplanar in `rock.gdshader`, toned cooler and greyer than they
  come: marble_cliff_05 on the faces, rock_boulder_dry on the blocks, gray_rocks on the scree's gentle ground; the
  painted bedding, stains, lichen, joints and cracks laid lighter over them.
- **Its dressing**: heather and small pines on the ledges, a few taller ones along the top, placed on the rock's grid
  as drawn.
- **The heath**: from the last trees the ground shader turns from needle litter to heath (`heath.gdshaderinc`), under
  a sward of grass tussocks (FoliageTex's painted grass on three crossed cards each) with heather in patches, thick by
  the fence and thinning out to 130 m; low rolling hills from there to the horizon (`EdgeBuilder._hills`), with stands of pines on them.
- **The fence**: two strands of wire from post to post, sagging between them.

Only the rock is solid. The ledge pines, boulders, tufts, heather and far pines are drawn only.

- **The fence**: the edge posts at fence height (1.4 m, still a perch on each top), weathered, two strands of wire.
- **The light**: `ForestLight.LOOKS.clear` is the concepts' light (high-key midday, blue sky, thin air); the golden
  default warms the rock to cream and hazes the heath. Compare: `probe_edge_view --look clear --heading cliff|fence`.

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

## Structure: what makes it read as rock (round six)

Traced against the concept, ours was a grid: the skyline, one ledge and the scree each one straight line across
the frame, verticals evenly spaced between. The concept's lines are short, tilted and staggered. Now: the lower
tiers' beds dip in fault blocks 30-60 m long (`Escarpment.dip`: a straight ramp in each, a step at each fault), so
the ledges run on a slant, cross and end (a ledge runs out here and there and two faces meet in one); the top steps
and tilts on its own (`skyline`); the face blocks lie in courses at fixed fractions of their tier (dipping with
it), each course with its own joints (staggered), tilted to the bed's local slope (at most `BED_TILT`), longer
than they're high; the top tier's beds run on level from below, cut by the skyline. The heath: a near ridge whose
height swings round the ring (its crest on a slant), a valley, a long far ridge; a fence post every 2.8 m (drawn
only) between the edge posts; the grass thinning in among the last trees and ending at the hills' foot.

## Next for the cliff (research, round six)

What games and tools do (sources in the session notes: Houdini strata and fracture breakdowns on 80.lv, Gaea's
Stratify, Paris et al. 2020 "Modeling Rocky Scenery using Implicit Blocks", Peytavie et al. 2009 rock piles, DICE and
Far Cry 5 GDC talks): cliffs are separate meshes over the terrain, cut by a fracture network -- bedding planes with
uneven thickness and a dip, two near-vertical joint sets with uneven spacing, joints stopping at beds -- each panel
(between joints, within a bed) set back by its bed's hardness, so hard beds over soft ones make the lips. Ranked
for us: (1) the wall as its own displaced sheet r(theta, z) from such a joint-and-bed model (overhangs possible; the
height field kept for the AI as its envelope); (2) blocks cut from the same planes (baked variants) instead of
chamfered boxes, talus laid Peytavie-style; (3) the shader's bands, stains and joint lines driven by the same model.

## Cost

Building it adds about 0.6 s to loading the wood (now about 2 s with the sward and the fence: to bring down) (the rock's tier layout is worked out once per column of the grid,
`Escarpment.column`; the dressing is placed on the built grid; the instance buffers are filled in one go). Drawn: the
rock (90k triangles, one draw), the hills, and six instanced batches.

## Open

- **The haze.** In the golden look the volumetric fog turns everything past 50 m cream; the clear look matches the
  concepts. Which is the game's default is a call for the look.
- The wood doesn't thin toward the heath (the concept's bottom right): that changes the layout the AI tests fly.
- A wooden platform on a ledge, as in the concept: an outpost on the rock.

## Looking at it

`.\run.ps1`-style, windowed: `Godot --path . -- --run-test probe_edge_view --out-dir <dir> --heading cliff|heath|away`
(chase shots at crown height, among the trunks, over the canopy, an overview; `--no-fog`, `--look <name>`).
