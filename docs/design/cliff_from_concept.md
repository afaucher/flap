# Matching the cliff to its concept

How we measure the escarpment (`Escarpment`, `EdgeBuilder`; `arena_edge.md`) against its Gemini concept, what the
measures found, and the generator they point to. The aim: a cliff whose structure measures like the concept's, so it
reads like it, not one tuned by eye shot by shot.

**After any change to the cliff:** `.\tools\cliff_measure.ps1` (under a minute; writes `test_logs\cliff\score.md`).

## The process

1. Change one group of parameters (below, "Tuning parameters").
2. `.\tools\cliff_measure.ps1`: our cliff's exact height field (`probe_cliff_plan`, headless), zoned, its edges and
   ledges traced, three cross-sections cut, all against the concept's, and the scorecard.
3. Read `score.md`: each row the concept's number, ours, and ok / low / high. Look at the pictures it names
   (`zones/`, `shapes/shapes.png`, `sections/*_profile.png`) -- a number off is a reason to look, not a verdict.
4. Look at it lit, in the game's own views: windowed,
   `Godot --path . -- --run-test probe_edge_view --out-dir <dir> --heading cliff | ortho | top_aligned --look clear`,
   beside `docs/images/edge/concept_cliff_ortho.png`.
5. Note the scorecard's count and what changed in the log at the bottom; then the gate before committing.

If the concept changes, remake its targets: the plan's zoning (`concept_plan_segmented.jpg`: green flat ground and
ledges, red faces, blue talus) and the cross-sections (`.\tools\cliff_section_prompts.ps1`, Antigravity open); the
scorecard reads them from `docs/images/edge/`.

## The pictures

| File | What it is | Trust |
|---|---|---|
| `concept_cliff_ortho.png` | the front view: the concept's cliff (`r5_edge_split.jpg`) extended by Gemini, trees removed | the target's look and structure up the face |
| `concept_cliff_plan.png` | Gemini's "plan" of it | along the cliff only (below) |
| `concept_plan_segmented.jpg` | that plan zoned: flat / face / talus | along the cliff only |
| `concept_section_{left,bay,right}.png` | Gemini cross-sections, square to the face, side-on, gridded | the profile: angles, talus |

## The tools

| Tool | Reads | Measures |
|---|---|---|
| `tests/probe_cliff_plan.gd` | the model | the ground's height on a world grid, from above |
| `tools/cliff_plan.py` | the probe | plan hillshade, contours, the face's line at each height |
| `tools/cliff_segment.py` | the zoned concept plan; our heights | each zone's share; bands up each column and their widths; talus depth |
| `tools/cliff_shapes.py` | the same | every edge between zones, typed (plateau rim, ledge lip, ledge back, wall foot, across the cliff): length per 100 m, run length, sinuosity, divider dimension, corners per 10 m and the straight between, heading, which way its points face; each ledge's length, depth, fullness, taper, tilt, stacking |
| `tools/cliff_section.py` | a cross-section picture; or a cut through our heights (`plan:<dir>@<m>`) | the profile in pieces: face angle (height-weighted, lip to foot), overhangs, ledge widths, talus angle, how much it buries, its reach |
| `tools/cliff_score.py` | the reports | the scorecard |
| `tools/cliff_edges.py`, `cliff_zones.py`, `cliff_depth.py` | front views; the model | line segments by direction; colour zones; relative depth (Depth Anything V2 Small) |

## What we learned about measuring

- **The concept's plan is not a plan.** Fitted onto the front view it lines up nearly row for row (correlation 0.58
  against 0.13 for a typical misfit; vertical scale 1.05; `plan_over_front.jpg`): Gemini redrew the front view's layout
  as if from above. Its up-down axis is mostly the cliff's height, so the depths and shares across the cliff it gives
  are face heights, not plan depths. Lengths and headings along the cliff, and where ledges pinch out, are real. The
  scorecard marks those rows "across" and never fails them.
- **One number can mislead.** A fullness of 0.68 read as "ovals"; profiled along their length, the ledges are strips
  that pinch out. Profile a shape before naming it.
- **Classify ours by true slope.** A wall is over 65 deg; our talus lies at up to about 50, so a 50 deg threshold
  counted the talus as face.
- **Clean both maps the same way** before tracing edges (speckle filled, 0.4 m smoothing, islands under 3 m^2 merged),
  so edges measure the zones, not the colour test's noise.
- **The depth model is relative.** Depth Anything ranks our render's true depth at 0.61 (0.12 for local relief): good
  for which way creases run, not for angles. The cross-sections give angles.
- **Gemini's sections are drawings,** but three cuts agree with each other and with geology (talus 25-30 deg, faces
  about 80 deg): treat them as targets, give or take.
- **Rendering:** Antigravity now runs as the `agy.exe` hub; `render_art.ps1` finds it (its `--hub-port`, its csrf token,
  the conversations under `.gemini\antigravity\brain`).

## Findings (2026-11-03)

### Along the cliff

| | Concept | Ours |
|---|---|---|
| Edges' heading off the cliff's line | 3-11 deg | 26-40 deg |
| Edges across the cliff, m per 100 m | 0 | 157 (fault steps, gully walls, tier jumps) |
| Median run: ledge back, lip, wall foot | 34, 14, 70 m | 6, 4, 5 m |
| Straight between corners | 4-6 m | 3.5-5 m |
| Divider dimension (1 smooth) | 1.00-1.05 | 1.04-1.10 |
| Ledges: length (median, range) | 29 m (5-36) | 5 m (4-10) |

The ledges are **strips that pinch out**: about constant depth along most of their length, then a sharp tip over
their last tenth (17-50 deg where lip and back meet); the lip (the drop's edge) straighter, the back (the face rising
behind) notched, wandering about twice as far (1.2 m against 0.5); the long ones level, within 5 deg of the cliff's
line; short slivers (5-10 m) pointed both ends and tilted about 16 deg; stacked one over another, overlapping almost
fully.

### Cross-sections

| Cut | Face, height-weighted | Face, lip to foot | Overhanging | Whole, lip to toe | Talus | Talus buries | Talus reach |
|---|---|---|---|---|---|---|---|
| Concept left (stepped blocks, a leaning block) | 81 | 69 | 19% | 47 | 26 | 0.32 | 0.66 |
| Concept bay (a bench at mid height) | 79 | 52 | 10% | 43 | 29 | 0.29 | 0.52 |
| Concept right (tall fluted face) | 86 | 85 | 0 | 53 | 30 | 0.40 | 0.70 |
| Ours left | 88 | 42 | 0 | 41 | 38 | 0.34 | 0.44 |
| Ours bay | 86 | 37 | 0 | 36 | 35 | 0.45 | 0.63 |
| Ours right | 87 | 83 | 0 | 27 | 18 | 0.63 | 1.93 |

(degrees; talus shares of the cliff's height, lip to the ground in front; `sections_concept_vs_ours.jpg`.)

The concept's faces are **not vertical**: steep pieces from 58 to 101 deg, each a bed package about a tenth of the
height, averaging 79-86; about 40% of the face lies between 80 and 90 deg; in the stepped parts a tenth to a fifth
overhangs (blocks jutting, a block leaning on the face). Each face piece steps back from the one below. Ours: every
piece 86-90 deg, nothing overhanging, and ledges far wider (up to 0.7 of the height against at most 0.26), so the
cliff as a whole lies back far more (27-41 deg lip to toe against 43-53). The concept's talus lies at 26-30 deg (low
for angular blocks, which rest at 34-40: the artist's), buries 0.3-0.4 of the height and reaches out 0.5-0.7 of it;
ours is steeper, and where a wide ledge has the talus on it, it reaches nearly twice the cliff's height.

### What made it: the geology

Horizontally bedded, heavily jointed limestone -- a Dales-style scar.

- **Joint-bounded block fall.** Blocks topple, slide and fall out along the vertical joints and the bedding planes:
  rectangular faces, sharp arrises, missing-block notches, flat block tops, the angular talus. A block left leaning
  is the left cut's overhang.
- **Differential retreat.** Thin shaly partings weather back faster than the hard beds, so each hard unit's front
  retreats on its own. A ledge is the strip between two fronts, and it pinches out where they meet: the strips. The
  lip is the lower unit's edge, worn back evenly (straight); the back is the foot of the face above, where blocks have
  dropped out (notched).
- **Frost and talus.** Frost wedging on the joints feeds the talus, which buries the lowest tier and fans into lobes
  below the gullies.
- **Solution.** Vertical runnels on the tall faces (the right bay's flutes); the plateau's joints opened into grikes.
- **The surface:** fresh fracture planes pale, flat, sharp-edged; older surfaces grey, lichened, pitted, edges rounded
  to a few decimetres; dark water streaks under each lip; soil and grass only on what's flat.

### The generator it points to

1. **Tiers:** a stack of hard units, each with a thickness drawn at random.
2. **Fronts:** each tier's front in plan is the one below's plus `max(0, A * noise(x / lambda) - c)`. Where that
   crosses zero, a pinch-out; the slope there sets the tip's angle. `lambda` sets the ledges' length, `c` how much of
   the cliff carries one, `A` how wide they get.
3. **Lip and back:** the lip is that smooth front; the back adds missing-block notches, one block per joint spacing.
4. **Faces:** within a tier each bed steps back by `b` (the batter) and its face leans from 80 deg to just past 90;
   now and then a block juts (an overhang). Face pieces follow the two joint sets.
5. **Talus:** an apron burying a share of the lowest tier, lobes below the gullies, at its own angle.
6. **Nothing across the cliff:** faults may throw beds up or down but not change the setback.

### Tuning parameters

| Parameter | Controls | Target (scorecard row) | Now |
|---|---|---|---|
| Tier heights, count | ledges per column | 2-3 | `TIER_H` (2 tiers) |
| `lambda` | ledge length | median 29 m, 5-36 (Ledges: median length) | `_tier_back`'s noise, 47 m |
| `c` | share of the cliff with a ledge | about half | (none: smoothstep) |
| `A` | ledge width | at most a quarter of the height (sections) | `TIER_BACK` 1.5-20 m |
| Joint spacing | straight between corners | 4-6 m | `JOINTS` 8 / 14 m |
| Notch depth, chance | back rougher than the lip | back wanders twice the lip | (none) |
| Lip wander | lip straightness | about 0.5 m | `TIER_WANDER` 3 m |
| Bed batter `b`, face lean | face angle | 79-86 height-weighted, 10% overhanging | vertical |
| Fault setback | edges across the cliff | 0 m per 100 m | faults move the face |
| Talus height share, reach, angle | talus | buries 0.3-0.4, reach 0.5-0.7, 26-30 deg | `TALUS`, `REACH` |

## Log

- 2026-11-03: the process built; baseline scorecard 1 of 17 rows within tolerance (the talus's angle). The tiers and
  block-top slabs then in the working tree (`TIER_H`, `TIER_BACK`; `EdgeBuilder._slabs`) are what it measured.
