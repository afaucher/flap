# The cliff: its design, and matching it to its concept

Everything about the escarpment at the arena's edge so far: what the concept asks for, how the cliff is built now and
why, how we measure it against the concept, what the measures found, what was tried and how it went, and what's
still open. `arena_edge.md` covers the edge as a whole (the heath, the hills, the fence, perches, cost).

**After any change to the cliff:** `.\tools\cliff_measure.ps1` (under a minute; writes `test_logs\cliff\score.md`),
then a look in the game (below).

**Where it stands (2026-11-03):** on branch `edge-views` (worktree `.claude/worktrees/edge`). The scorecard: 8 of 14
rows within tolerance -- every cross-section row but the overhang share; along the cliff the ledges and edges are
still too short. Lit, it reads as a stepped, leaning wall with ledges at many heights, the talus heaped in places
and thin between, faceted boulders on stony dirt -- but the face still reads as one wall with fine bedding lines,
not the concept's big joint-bounded blocks (`now_concept_front_trunks.jpg`: the concept, our front view, our view
from among the trunks). On hold while the heath is worked on.

## The concept

- `docs/images/concepts/r5_edge_split.jpg` (Gemini, from our own chase shot): its top left is the cliff -- a broken
  grey limestone escarpment, taller than the trees, stepped with ledges, scree and boulders at its foot.
- `docs/images/edge/concept_cliff_ortho.png`: that cliff extended by Gemini into a straight-on front view, trees
  removed: the main target for its look and its structure up the face.
- `concept_cliff_plan.png` / `concept_plan_segmented.jpg`: Gemini's "plan" of it, and that zoned (green flat ground and
  ledges, red faces, blue talus). **Not a true plan** (below): trust it only along the cliff.
- `concept_section_{left,bay,right}.png`: Gemini cross-sections, square to the face, side-on, gridded
  (`tools/cliff_section_prompts.ps1`): the target profile -- face angles, ledges, talus.

The user's asks along the way, all still standing: no regular-looking cliff (traced lines must look as irregular as
the concept's); blocks and boulders with flat facets and sharp edges, not boxes; the cliff extends to the sides so
its ends can't be seen from anywhere a bird can fly (not a ridge over the top); low perches plenty, high ones few
(don't encourage sitting above the fight); smooth transitions from the forest floor to the grass and from the grass
to the hills; the talus heaped in places, thin in others; ledges at many heights, not all level.

## How it's built now

**The model** (`scripts/world/escarpment.gd`, pure; what EdgeBuilder draws and what collision, the AI's queries and
the tests read):

- **Where:** a sector of the ring `HALF` (115 deg) either side of `at`, standing on the side away from the sun, turned
  `RAKE` so the light rakes across it; its foot `FOOT` past the boundary, wandering in bays (`BAY`, `BUTTRESS`); from
  `BEND_FROM` of the way along it curves away from the wood (`BEND` m by its ends), so its ends lie hidden behind its
  own face. It comes down into the heath at its very ends (`taper`).
- **The rock:** horizontal beds of lognormal thickness (`BED`), hard and soft in long runs (`_hard`), dipping along
  the cliff (`BED_DIP`) and thrown at faults (`FAULT`, the step taken over `FAULT_RAMP` m so it bends, not a wall);
  two joint sets per bed at uneven spacings (`JOINTS`), a share running on into the bed above (`RUN_ON`), some aslant
  (`SLANT`). A panel is a bed between two joints: set back by its bed's softness (`SOFT`: hard over soft juts as a
  lip), its own amount (`PANEL`), now and then a lost block (`LOSS`), its own turn (`PANEL_TILT`); its face broken
  into planar Voronoi facets at two sizes (`FRACTURES`) and swelling gently (`BULGE`).
- **The lean:** the whole wall leans back `LEAN` per m up, and each bed leans its own way on top from where the bed
  below left off (`BED_LEAN`, -0.08 to 0.26: from just overhanging to well back) -- one face bending bed by bed.
  (Leaning each bed about its own middle made a step at every bedding plane: benches everywhere. Don't.)
- **The ledges:** three sets (`LEDGES`, height ranges 2-9, 9-19, 18-29 m), each a run of strips along the cliff, one
  per `LEDGE_RUN.x` m cell where there is one (chance `LEDGE_RUN.y`), 45-95% of its cell long, each on a bed of its own
  at a height of its own within its set's range. The beds above a strip stand back `TIER_BACK` m (2.5-6, varying
  along it), pinching straight back in over its last 6-14 m (`LEDGE_RUN.z`): sharp tips, 20-45 deg. A strip's back
  wanders (`TIER_WANDER`) and its bed loses blocks there (`TIER_NOTCH`): notched back, straight lip. Strips change bed
  only where they've pinched out, so nothing steps across the cliff. (`ledge(k, arc)`.)
- **Clefts:** deep gullies every `GULLY.x` m or so, `GULLY.y` deep, their sides sloping over 3 m.
- **The top:** level stretches with gentle steps between (`SKYLINE`: 40 m stretches, 35-39 m high, half of each
  stretch a slope), the plateau behind rising a little and evening out over `PLATEAU` m into the hills.
- **The talus:** heaped in piles where a slow noise runs high (`TALUS_PILE`: 34 m scale, threshold 0.55 -- about a
  third of the cliff), up to `TALUS.y` of the cliff's mean height on a crest, `TALUS.x` between (2-3 m), a narrow cone
  under each cleft; sloping at `TALUS.z` (33 deg), a little concave and lumpy, laid from the foot's smooth line
  (`talus_from`) -- not the wall's lowest row, which steps panel to panel and put a step across the slope at each.
- **The wall as data:** per angle a column (`column()`: rows up each bed, `ROW_F`), cached; the ground's height
  (`height_in`) is its envelope -- solid under every lip, for collision and the AI -- with the talus in front and the
  plateau behind. The soft wall stands `REACH` past the foot in the sector.
- **Perches** (`perch_spots`): flat-topped stones on the talus (`STONES`), and spots on the ledges `PERCH_EVERY` apart
  at two height bands above the talus (`LEDGE_BANDS`: 10 m apart low, 32 m higher, none on the top), each level
  around its disc; the finder looks up to 4.5 m either way along for a strip.

**The drawing** (`scripts/world/edge_builder.gd`):

- The wall as one sheet mesh from the columns (double-sided), the ground's height field under it; collision only
  within `REACH` + 6 m.
- **Boulders** (`_block_mesh`): a unit cube cut by 5-9 planes of its own (`BLOCK_CUTS`; `_cut`, Sutherland-Hodgman),
  eight shapes (`BLOCK_SHAPES`): flat faces, sharp edges, no two square. On the talus sorted by size down it (small at
  the foot, big at the toe), none on the perch stones or their way in, clear of the fence; the big ones solid (boxes
  at 0.8 of the block).
- **Slabs** (`_slabs`): block tops tiled over the ledges and a strip of limestone pavement past the top's edge
  (`SLAB`), a little proud, gaps between: drawn only.
- Ledge heather and ledge pines; the hills (`_hills`) take the plateau out to the horizon.
- **Rock shader** (`rock.gdshader`, triplanar): the faces on `marble_cliff_05`, the blocks on `rock_boulder_dry`; the
  gentle ground low down (the talus, below `scree_top`) on `rocky_trail` (stony dirt, two scales turned apart, toned
  grey-brown) with `gray_rocks` rubble in patches; soil and thin grass on the ledges and the top; fracture lines and
  bands from the same noise. Scans: Poly Haven, CC0 (`assets/LICENSES.md`).

## Measuring it against the concept

1. Change one group of parameters.
2. `.\tools\cliff_measure.ps1`: probes our cliff headless (`probe_cliff_plan`: heights from above;
   `probe_cliff_edges`: the wall's own sheet, arc x height, and the ground on arc x radius), zones it, traces its
   edges and ledges, cuts three cross-sections, all against the concept's, and writes the scorecard.
3. Read `score.md`: each row the concept's number, ours, ok / low / high, and how far to trust it. Look at its
   pictures (`zones/`, `shapes/shapes.png`, `sections/*_profile.png`): a number off is a reason to look, not a verdict.
4. Look at it lit, windowed:
   `Godot --path . -- --run-test probe_edge_view --out-dir <dir> --heading cliff | ortho | top_aligned --look clear`
   (`ortho` is the straight-on front view to set beside `concept_cliff_ortho.png`; `cliff` gives the chase views).
5. Log the count and the change below; gate before committing.

If the concept changes, remake its targets: the zoning and the sections (`.\tools\cliff_section_prompts.ps1`,
Antigravity open: `render_art.ps1` finds its `agy.exe` hub).

| Tool | Reads | Measures |
|---|---|---|
| `tools/cliff_measure.ps1` | -- | runs all of the below |
| `tests/probe_cliff_plan.gd` | the model | the ground's height on a world grid from above; the face's line at each height |
| `tests/probe_cliff_edges.gd` | the model | the wall's sheet (how far back the face stands at each arc and height), the ground on arc x radius, beds, joints, lips, ledges |
| `tools/cliff_segment.py` | the zoned concept plan; our wall probe (unrolled along the cliff) | each zone's share; bands up each column; talus depth |
| `tools/cliff_shapes.py` | the same | every edge between zones, typed (plateau rim, ledge lip, ledge back, wall foot, across the cliff): run length, sinuosity, divider dimension, corners, heading; each ledge's length, depth, fullness, taper, tilt, stacking |
| `tools/cliff_section.py` | a section picture; a cut through our wall (`wall:<json>@<m>`) or heights (`plan:<dir>@<m>`) | the profile in pieces: face angle (height-weighted, lip to foot), overhangs, ledge widths, talus angle, burial, reach |
| `tools/cliff_score.py` | the reports | the scorecard |
| `tools/cliff_plan.py`, `cliff_edges.py`, `cliff_zones.py`, `cliff_depth.py` | plan, front views, the model | plan hillshade and face lines; line segments by direction; colour zones; relative depth (Depth Anything V2 Small, model outside the repo in `build/deps/models`) |

**What we learned about measuring:**

- **The concept's plan is not a plan.** Fitted onto the front view it lines up nearly row for row (correlation 0.58
  against 0.13 for a misfit; `plan_over_front.jpg`): Gemini redrew the front view's layout as if from above. Its
  up-down axis is mostly the cliff's height, so depths, shares and headings from it don't compare with our true plan;
  lengths along the cliff and where ledges pinch out do. The scorecard marks those rows "across" (reference only).
- **Ours unrolled.** Our zones are taken along the cliff (arc) by distance out, not in a straight frame: a straight
  120 m frame cuts across the curving cliff and chops its ledges short.
- **Classify ours by the model's own wall foot,** not by slope alone: in front of it is talus (and the stones on it),
  behind it flat under 20 deg, face over. A perch stone's steep rim had turned whole columns into "face".
- **Cut our sections from the wall's sheet,** not the height field: the height field is the envelope, solid under
  every lip, so it can't show an overhang.
- **One number can mislead.** A fullness of 0.68 read as "ovals"; profiled along their length the ledges are strips
  that pinch out. Profile a shape before naming it.
- **Clean both maps the same way** before tracing edges (speckle filled, 0.4 m smoothing, islands under 3 m^2 merged).
- **The depth model is relative:** it ranks our render's true depth at 0.61 (0.12 for local relief): good for which way
  creases run, not for angles. The sections give angles.
- **Gemini's sections are drawings,** but three cuts agree with each other and with geology: targets, give or take.

## What the concept is

**Along the cliff** (from the zoned plan; lengths along it are real):

| | Concept |
|---|---|
| Edges across the cliff | none |
| Median run: ledge back, lip, wall foot | 34, 14, 70 m |
| Straight between corners | 4-6 m |
| Ledges: length | median 29 m (5-36) |

The ledges are **strips that pinch out**: about constant depth along most of their length, then a sharp tip over
their last tenth (17-50 deg where lip and back meet); the lip straighter, the back notched (it wanders about twice as
far, 1.2 m against 0.5); the long ones level, short slivers (5-10 m) pointed both ends and tilted about 16 deg;
stacked one over another.

**Cross-sections:**

| Cut | Face, height-weighted | Face, lip to foot | Overhanging | Whole, lip to toe | Talus | Talus buries | Talus reach |
|---|---|---|---|---|---|---|---|
| Concept left (stepped blocks, a leaning block) | 81 | 69 | 19% | 47 | 26 | 0.32 | 0.66 |
| Concept bay (a bench at mid height) | 79 | 52 | 10% | 43 | 29 | 0.29 | 0.52 |
| Concept right (tall fluted face) | 86 | 85 | 0 | 53 | 30 | 0.40 | 0.70 |

(degrees; talus as shares of the cliff's height, lip to the ground in front; `sections_concept_vs_ours.jpg`.) The
faces aren't vertical: pieces from 58 to 101 deg, each a bed package about a tenth of the height, stepping back from
the one below; in the stepped parts a tenth to a fifth overhangs.

**The geology** -- horizontally bedded, heavily jointed limestone, a Dales-style scar:

- **Joint-bounded block fall:** blocks topple and slide out along the joints and bedding planes -- rectangular faces,
  sharp arrises, missing-block notches, flat block tops, angular talus; a block left leaning is an overhang.
- **Differential retreat:** soft partings weather back faster than the hard beds, so each hard unit's front retreats
  on its own; a ledge is the strip between two fronts, pinching out where they meet. The lip is the lower unit's
  edge, worn evenly (straight); the back is where blocks dropped out of the face above (notched).
- **Frost and talus:** frost wedging feeds the talus, which buries the lowest tier and fans into lobes under gullies.
- **Solution:** vertical runnels on tall faces (the right bay's flutes); the plateau's joints opened into grikes.
- **The surface:** fresh fracture planes pale, flat, sharp-edged; older ones grey, lichened, pitted, edges rounded to
  a few decimetres; dark water streaks under each lip; soil and grass only on what's flat.

## The scorecard now

| Row | Concept | Ours | |
|---|---|---|---|
| Edges across the cliff (m per 100 m) | 0 | 0 | ok |
| Median run: ledge back / lip / wall foot (m) | 34 / 14 / 70 | 5 / 4 / 6 | low |
| Straight between corners, ledge lip (m) | 5.8 | 4.1 | ok |
| Ledges: median length (m) | 29 | 7 | low |
| Ledges: ends to half depth (share of length) | 0.09 | 0.15 | high |
| Face, height-weighted / lip to foot (deg) | 82 / 68 | 83 / 73 | ok |
| Whole cliff, lip to toe (deg) | 48 | 49 | ok |
| Face overhanging (share) | 0.10 | 0.23 | high |
| Talus angle (deg) / buries / reach | 28 / 0.33 / 0.63 | 26 / 0.34 / 0.69 | ok |

## Tuning parameters

| Parameter | Controls | Target | Now |
|---|---|---|---|
| `LEDGES` | ledge sets and their height ranges | 2-3 ledges up a column, at heights of their own | 3 sets: 2-9, 9-19, 18-29 m |
| `LEDGE_RUN` | strip cell, chance, tip length | ledges median 29 m (5-36), sharp tips | 38 m, 0.85, 10 m (x 0.6-1.4) |
| `TIER_BACK` | ledge depth | at most a quarter of the height | 2.5-6 m |
| `TIER_NOTCH`, `TIER_WANDER` | notched back, lip wander | back wanders twice the lip | 0.3 / 1.2 m; 1 m |
| `JOINTS` | panel size, straight between corners | 4-6 m | 8 / 14 m spacing |
| `LEAN`, `BED_LEAN` | face lean, overhang | 79-86 deg, 10% overhanging | 0.06; -0.08..0.26 |
| `SOFT` | hard-over-soft lips | (part of the overhang) | 0.55 m |
| `TALUS`, `TALUS_PILE` | where the talus heaps, how high, its slope | piles and thin stretches; buries 0.3-0.4 where piled, 26-30 deg | 0.07-0.48, 33 deg; 34 m, 0.55 |
| `FAULT_RAMP`, `GULLY`, `SKYLINE` | steps along the cliff | no walls across it | 9 m; 3 m sides; 35-39 m, half-stretch slopes |
| `BLOCK_CUTS`, `BLOCK_SHAPES` | boulder shapes | faceted, not square | 5-9 cuts, 8 shapes |

## What was tried, and how it went

- **Rounds one to five** (before the measures): chamfered face blocks were too regular ("giant blocks sticking out");
  fracture noise on the surface was first too much, then still read smooth -- planar facets in the model (`FRACTURES`)
  fixed that. A ridge behind the cliff to hide its ends was wrong: the cliff was extended and bent outward at its ends
  instead.
- **Measured round one:** baseline 1 of 17. Tiers by bed index (`TIER_H`) gave one 16 m-deep shelf instead of strips.
- **Retune:** strips by a zero-crossing setback, faces leaning, talus 33 deg: 9 of 14 -- but the measures had bugs
  (a straight frame, slope-only zones, height-field cuts), fixed as above.
- **Things that broke and why:** each bed leaning about its middle made benches at every bedding plane; the talus laid
  from each column's lowest row stepped across the slope; gully fans 12 m wide merged into one apron covering most of
  the cliff; smoothstep tips were steep enough (70 deg) that test_arena_edge's joint check took them for joints; the
  lowest ledge set at 8-17 m left too few low perches (the beds dip, and the talus buries them) -- now 2-9 m.
- **From the game:** the talus covered too much of the cliff along its length -> piles; the ledges all at the same
  heights -> each strip on its own bed; the boulders square -> cut polyhedra; the talus drawn like forest floor ->
  `rocky_trail` dirt.
- **Not the cliff:** the combat tests timing out at the runner's 120 s cap was machine load (they take 86 s on an
  idle machine; the cliff's cost is unchanged: generation 2.4 s, 20k `rock_clear` 0.85 s). The combat AI session owns
  those tests and is bringing them under the cap; `-TimeoutSec 240` meanwhile.

## Open, for whoever picks it up

- **The look.** The face reads as one wall with fine bedding, not the concept's big joint-bounded blocks with deep
  shadow between them and blocks standing proud. Joint spacing (8 / 14 m) and panel set-backs (`PANEL` 0.45 m) may be
  too small to read at 40 m; bigger, deeper panels -- or separate block meshes set into the face along the joints --
  are the obvious next try. Seen straight on, the ledges are only thin lines (a level camera; the concept's front
  view looks down a little).
- **Ledges too short** (7 m median against 29): missing-block notches (`LOSS`, `TIER_NOTCH`) cut them into small
  rectangles; the bed lean makes small benches count too. Ends taper slower than the concept's.
- **Overhang 0.23 against 0.10:** short lip undersides (hard beds jutting over soft) dominate, not the bed lean.
- **A front-view zoning of ours** would compare like with like with the concept's plan picture (which is really its
  front view): headings and the across rows could then count.
- **The talus mound** on the right of the front view shows the buried wall's rows as curved stripes through it.
- **Load time:** the edge takes about 6 s to build (the rock about 2.5-3 s).
- **Ridge lift:** `AirField.add_ridge` (master) could take lift from the cliff's face (`top()`, `foot_r()`): the Pretty
  Birds session owns AirField; nothing in combat reads the air yet (`CombatWorld.calm_air`).

**Keep in step:**

- `test_arena_edge` guards the cliff: it runs on round the ring (ends far out), the plateau levels off, flat stones
  stand proud, ledges over 15 columns, perches by height above the talus (`BANDS`: plenty low, fewer higher, none on
  top), joints at uneven spacings that stop (not shared two beds up), lips in many columns, no rock within 2 m of the
  boundary, blocks clear of the fence, the AI's clearance sees the rock. `tests/regressions/mutations.json` has the
  edge's bugs (`edge-*`); `.\mutation_check.ps1 -Changed` after a change.
- If rock goes into the layout's clearance queries (`segment_clear`, `segment_clear_among`, `tree_clear`, `clear_by`,
  `obstacle_distance`), add it to `ArenaLayout.path_blocked_at` too -- the combat AI's whole-path version, which must
  stay equivalent or the AI flies into the cliff while its planner avoids it. Outposts must stay reachable
  (`CombatWorld.far_base`; test_pinewood checks every species can swoop onto every rail).
- Downloads (scans, models) need the user's OK first; record each in `assets/LICENSES.md`. Concept renders (Gemini,
  `render_art.ps1`) need the user's OK too.

## Log

- 2026-11-03: the process built; baseline 1 of 17.
- 2026-11-03: retuned (strips, leaning faces, talus 33 deg from the foot's line, gentler steps); the measures fixed
  (unrolled, foot-zoned, wall cuts; headings to reference): 9 of 14.
- 2026-11-03: talus piled and thin between; each ledge strip on a bed of its own, three sets; tips straight over 6-14 m;
  faceted boulders; rocky_trail dirt on the talus: 8 of 14 (ledge ends taper slower than the concept's; overhang 0.23).
