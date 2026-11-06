# The cliff lab: what it found, and what to take into the game

A standalone lab (`tests/probe_cliff_lab.gd`; its renders and how each was made: [cliff_lab_walkthrough.md](cliff_lab_walkthrough.md)) built cliff models from the geology up, away from
the game's constraints, to find out what makes a limestone cliff read as real. This is what it found, judged against
the user's reviews, and how each finding maps onto `Escarpment` / `EdgeBuilder` (`cliff_from_concept.md` describes
those; read it first). Nothing here is in the game yet.

**Status in one line:** the build order (bedrock -> chipped back -> deposited -> weathered) and the big joint-bounded
blocks set into the face were judged "a fantastic start, much better than we had before". The incipient cracks,
the flat stone surface and the cliff's ends were judged not yet realistic; they are open below, with what nature does.

Running it (renders to `test_logs/cliff_lab/`, about 25 PNGs, off screen):

```powershell
$flap = 'c:\Users\alexa\.gemini\antigravity\scratch\flap'; $edge = "$flap\.claude\worktrees\edge"
. "$flap\godot_env.ps1"; . "$flap\test_lib.ps1"
Invoke-FlapHidden (Get-FlapEngine $godot) @('--path', $edge, '--', '--run-test', 'probe_cliff_lab')
```

(`probe.ps1` lives in the main checkout only; `test_runner.ps1 -TestName` runs headless and can't render.)

---

## 1. The build order: model the processes, in the order they happened

The single biggest improvement came from building in the order the cliff formed and checking each stage on its own
render (clay first, materials last):

| Stage | What it adds | Lab renders |
| :--- | :--- | :--- |
| 1. Bedrock, chipped back | beds (hard / soft), joints, retreat tiers, master clefts, big blocks | `checkpoint1_bedrock_clay_*` |
| 2. Mass wasting | soil on benches, talus cones under the clefts, sorted boulders | `checkpoint2_deposition_clay_*` |
| 3. Weathering | materials driven by the stage-1/2 state (`rock.gdshader`, `rocky_trail` dirt) | `checkpoint3_weathered_lit_*` |

**For the game:** keep this order as the review process. A clay render of stage 1 alone shows straight away whether
the rock reads as blocks; the materials can't fix a stage-1 problem, and in past rounds they hid it.

## 2. Stage 1: what made the face read as big blocks

`cliff_from_concept.md`'s first open item ("the face reads as one wall with fine bedding ... separate block meshes set
into the face along the joints are the obvious next try") is what the lab tried, and it's what worked.

- **Two layers: a sheet plus block volumes.** A single-valued wall sheet (`_z_rock(x, y)`, lab line 583: like
  `Escarpment.column()`, radius against height) carries the beds, joints, clefts and tiers. Over it sit
  **separate faceted crag volumes** (`_sculpted_crag_mesh`, line 922: a unit box cut by 11 fracture planes -- 3 broad
  front dihedrals, 4 steep conjugate sides, 4 top / bottom wedge bevels), each pushed into the face by 12-24% of its
  depth (`_spawn_geological_crag_architecture`, line 1324). The volumes give the deep shadow between blocks, the
  overhanging lower lips and blocks standing proud, which the game's per-panel set-back (`PANEL` 0.45 m) can't.
- **Block sizes that read at 40 m:** 5-10 m wide, 4-6 m deep, 6-19 m tall. Tall unbroken pillars (12-18 m, roll near
  0) for a fluted headwall; leaning slabs (roll 13-18 deg) for a monolith; squat 5-6 m blocks below a bench. The game's
  joint spacing (8 / 14 m) is about right for widths; what was missing is depth and height per block.
- **Master clefts:** a few deep ones at uneven spacing (9 in 164 m), 2.8-5.6 m deep, about 2.8 m wide, slightly aslant
  (`MASTER_JOINTS`, line 400). The blocks skip a cleft (`_cleft_depth_at(...) > 2.2`) so it stays an open shadow slot.
  The game's `GULLY` is the same idea; make it deeper and keep blocks out of it.
- **Benches stay open.** Blocks are capped below a bench's height (the lab's lists stop at 13.0 m under a 13.4 m bench)
  so the soil shelf is never hidden by the blocks standing on the tier below.
- **Zones.** The concept's front view has 5 zones (stepped crags, a leaning monolith over a basal cave, a recessed bay,
  a wide earth bench, a fluted headwall). The lab hand-places them at fixed `x` to match the concept: **a port must
  make them procedural**: a zone type per stretch of the cliff, its block rules (pillar / slab / squat) from the table
  above.

**Mapping:** `Escarpment` stays the model (collision, AI clearance, tests read it). Add the block volumes as data in
the model -- per joint-bounded panel: a box, its cut planes' seed, its pull out -- and have `height_in` / `rock_clear`
take each block's envelope, so collision and `ArenaLayout.path_blocked_at` see what is drawn. `EdgeBuilder` draws
them as MultiMesh batches (the lab: 14 shapes). Cost to watch: the lab's 164 m builds in about 0.9 s; the game's
sector is several times longer (`HALF` 115 deg at `foot`).

## 3. Stage 2: deposition

- **Soil on the benches**, not rock: wall triangles in a bench band facing up (`n.y > 0.24`) go to the ground mesh
  with the earth material (`_emit_cliff_tri`, line 865). Benches then read as shelves of earth and boulders, as in
  the concept. A heaped mound on the widest bench (3.6-5.5 m) sells "material collects here".
- **Talus cones under the clefts**, not an even apron: one Gaussian lobe per cleft / zone, crest 5-10 m up the face,
  laid at **27.5 deg** (the concept's sections measure 26-30; the game uses 33), toe blended into the valley floor with
  a softplus (`_build_base_talus`, line 1494: `0.55 * log(1 + exp(h / 0.55))`), so the cone runs out with no crease.
  Radial ribs fade with distance out (gullies down the cone). Laid from a smoothed foot line -- the same lesson the game
  already learned (`talus_from`).
- **Sorted boulders** (`_spawn_sorted_boulders`, line 1604): size grows toward the toe (0.5 m -> 2.5 m, and 14% at
  1.55x); big ones get a smaller companion leaning on them (clumps); the **apex of an active chute is bare** (falling
  rock clears it); sparse low boulders out on the valley floor. Each boulder is set into the ground (`up` jittered off
  the slope normal, its centre 14-38% of its height above the surface, so about a sixth of it buried on average). The game's `_scree_blocks` sorts by size already; add the clumps, the
  bare chute apex and the sinking.

## 4. Stage 3: shading -- do cracks and clefts need shadow maps?

From the 3-panel comparison (`study1_crack_geometry_comparison.png`: clay without shadows, clay with, lit with):

- **Geometry that faces away from the sun reads without shadow maps.** A groove whose two walls point opposite ways
  gets `N.L <= 0` on one wall by itself, and a chamfered lip on the other side catches a highlight; a dark vertex
  colour at the groove root adds the cavity. So narrow features (cracks, joints, 10-30 cm slots) don't depend on
  shadow-map resolution, which at the game's camera distances is too coarse for them anyway.
- **Shadow maps add the big things:** a block stepping forward over its neighbour, the clefts, the basal cave. Keep
  them on for the cliff; don't rely on them below about half a metre.
- **For the game:** bake cavity darkening into vertex colour (or a per-vertex AO) at groove roots and block contacts;
  `rock.gdshader` can multiply it in.

## 5. The land around it

- **Over the cliff** (Study 2): bare limestone **pavement** for the first 0-12 m back from the brow (clints 1.6-4.2 m
  wide, 0.3-0.7 m thick, separated by soil-filled grikes), a few clints at the very edge tilted or detached (the next
  rockfall), then soil thickening into heath with wind-stunted pines (6-11 m against 16-21 m in the valley). The game's
  `_slabs` pavement strip (`SLAB.z` 12 m) matches; add the grikes, the tilted edge clints and the stunted pines.
- **Around it** (Study 5), rock comes out of the ground in four ways, all on the same beds as the cliff:
  1. **dip-slope ribs** (whalebacks): a hard bed breaking the surface, soil lapping up its gentle back, a 2 m broken face
     on the other side with a few spalled cobbles;
  2. **pavement knolls**: on a swell, the soil stripped to flat clints 0.25-0.75 m proud; trees ring them, not on them;
  3. **earth-fast boulders**: old rockfall 30-90 m out, 2-4 m across, **40-55% sunk in a raised soil collar**, darker
     and mossy on top -- not fresh blocks dropped on the grass;
  4. **dry wash gullies**: running out from the clefts, 1.5-2 m deep, low bedrock steps in their banks, a cobble bed.

  These tie the forest floor to the cliff structurally. In the game they belong to the heath and the wood's edge
  (`EdgeBuilder._heath_cover`, `Pinewood`), and any that stand up need to be in the layout's clearance queries
  (and `path_blocked_at`, per `cliff_from_concept.md`'s keep-in-step list).

## 6. Plants by rooting depth (Study 6)

Plants follow soil depth and rockfall disturbance, not chance:

| Soil | Where | What grows |
| :--- | :--- | :--- |
| < 2 cm, or an active chute | steep and overhanging faces, bare rim clints, the apex of each talus cone | lichen only |
| 5-25 cm | bedding partings (where water seeps out along the bed), narrow cracks | ferns, grass tufts |
| 25-75 cm | narrow ledges 1-2.5 m, rim grikes, stable talus flanks | shrubs, prostrate juniper |
| > 0.8 m | the wide bench, deep cleft pockets, the plateau past the pavement, valley soil between cones | trees: stunted 6-11 m on the rock, 15-21 m in the valley |

- Valley trees advance **up between the talus cones** and part around the bare boulder aprons.
- **Ground every plant on the actual mesh.** The lab's first pass placed plants from an analytic guess at the surface
  and they floated over recessed bays; it was fixed by placing on real surface vertices and sinking 0.12-0.35 m along
  the normal, with a root skirt below each shrub's origin. The game's `_ledge_growth` should place from the same
  column data the wall is drawn from, and a test should ray each plant's base to the surface.

## 7. Heights and landforms

- **Lift heights** (Study 3): 3.5-4 m (one bed: a micro-outcrop inside the arena, below the crowns), 9-10 m (two beds,
  one undercut parting: mid-trunk shelves), 18 m (two tiers with a bench, rim at canopy height: birds skimming the
  canopy can drop onto it), 35 m (three tiers: the boundary wall, ridge lift). Small lifts can go **inside** the arena
  as clearing edges and cover, each with its own small apron (1-3 m). Their ends are visible from everywhere, so they
  need the end treatment in section 9 more than the main cliff does.
- **Landforms** (Study 4, renders `study4_plan_*` / `study4_bird_*`): a crescent amphitheatre, a box gorge, a sinkhole,
  and a stepped escarpment with outcrop spurs inside the arena. **They only read once the full erosion runs along their
  curved spine** (`_build_eroded_cliff_along_spine`, line 2079); the first versions, smooth curves of stacked boxes,
  looked artificial. The game's escarpment already bends along the ring, so any of these is the same model with a
  different foot line; the spurs are the lift study's outcrops placed in the clearing.

---

## 8. Open: the incipient cracks and the flat stone surface

What the lab has: true recessed V-groove cracks cut into a block's facet (`_emit_facet_with_recessed_cracks`,
line 1030: the facet split along a plane, a 4-strip groove between, arrested tips, T-junction branches, one side
stepped forward a little). The user's review: *they improve the look but don't look realistic -- the cracks don't
follow natural patterns, and the stone surface is too flat, so they stand out.*

Why, from the code:

1. **Random directions per facet.** Each facet picks its own crack angle; nothing continues across a facet edge or
   onto the next block. Real cracks belong to the joint sets (two near-vertical conjugate sets and the bedding), so
   neighbouring cracks are near parallel, they run on across arrises, and a younger crack ends **against** an older one
   (a T) far more often than in the open.
2. **Cut in unit space, then stretched.** The cracks are cut into the unit-box crag mesh and the instance is scaled up
   to, say, 6 x 15 x 5 m, so the crack angles, widths and depths are distorted per block (vertical cracks stretched,
   flat ones squashed), and their width doesn't match the block's size.
3. **Only 14 shapes.** Every crag is one of 14 meshes, so the same crack pattern repeats across hundreds of blocks.
4. **The facets are perfect planes.** Next to a mathematically flat face any groove is the only detail, so it reads as
   drawn on. In the concept every block face is rough at 5-50 cm: pitted, chipped, its arrises rounded and broken.

What to do (not built yet; in this order):

- **Surface relief first.** Subdivide each large facet (to about 0.3-0.5 m) and displace it along its normal with a
  few octaves of noise, about 2-4% of the block's size, plus a second level of small planar facets (as
  `Escarpment.FRACTURES`' small set) so it stays rocky rather than lumpy. Round and chip the arrises (pull edge
  vertices in by 5-15 cm with noise). Godot 4 has no tessellation shader, so this has to be real vertices; a stronger
  detail normal (`scan_normal_depth`) helps up close but doesn't change the silhouette.
- **Cracks from the joint sets, in world space.** Cut cracks after the block is placed and scaled (bake the block, or
  a few dozen pre-scaled variants), in the directions of the cliff's joint sets and bedding, continuing across
  facet edges, ending at T-junctions with an older crack or at a facet edge. Lay them into the rough surface so the
  groove's lips follow the relief.
- **Fewer, longer, better placed.** Most incipient cracks run parallel to the cliff face behind a block (they show as
  the block's outline beginning to open), or follow a bedding parting; a few cross the face.

## 9. Open: the cliff's ends

The lab's ends (`study2_rim_pavement_and_taper.png`) were judged poor. Why: the lab scales the whole height down
(`_skyline_y` x a taper), so the beds droop, the plateau just stops at the edge of the model, and the plateau never meets
the valley floor.

What nature does where a cliff dies out:

- **The beds stay level; the ground comes up to meet them.** The slope at the foot rises (soil and colluvium, 18-26
  deg) while the plateau's brow rolls down (8-14 deg), until they're one hillside you could walk up. The cliff is
  buried from the bottom bed up: the lowest beds go under first, the middle ones poke out as long level ribs with dirt
  ramps between (stepping back en echelon), and last the caprock alone runs on as a broken line of blocks with moss
  and soil over them, then sinks under the turf.
- **Stepped buttress noses** where the cliff turns a corner: each major joint drops the wall by about a bed, with a
  soil-and-scree gully round each step, and a spine of earth-fast boulders running on along the line.
- **A plunging dip:** where the beds tilt along the cliff, each one dives under the ground in turn and the face ends in
  a sloping slab nosing into the soil.

**Mapping:** the game's `Escarpment.taper` already brings the top down through beds that keep their thickness
(`_column`: "the cliff ends as a low wall of a bed or two"), and `BED_DIP` gives the plunge. What it lacks is the
ground rising at the foot: near the ends, raise the talus and soil in front (`talus_from` / `height_in`) to bury the
lower beds, and let the ledges there become the level ribs. The main cliff's ends are mostly hidden behind its own face
(`BEND`), so this matters most for small lifts inside the arena (section 7). A lab study of it was agreed but not
built.

---

## 10. Taking it in: suggested order

1. **Block volumes in the model** (section 2), drawn by `EdgeBuilder`, seen by collision and the AI. Measure with
   `tools/cliff_measure.ps1`; expect the "one wall" items on the scorecard to move.
2. **Surface relief on blocks and boulders** (section 8), before any more crack work.
3. **Deposition** (section 3): bench soil, cones under clefts at 27.5 deg, clumped and sunk boulders, bare chute apices.
4. **Cracks from joint sets**, in world space (section 8).
5. **Ends** (section 9), with the in-arena outcrops (section 7).
6. **Surroundings and plants** (sections 5, 6).

Each step through the gate in `cliff_from_concept.md`'s keep-in-step list: `test_arena_edge`, `path_blocked_at` kept
equivalent, outposts reachable, `mutation_check.ps1 -Changed`; and the user's OK before downloads or concept renders.

## What the lab is not

- A hand-placed model of one concept picture: the zone lists, slab tables and bench heights are fixed numbers tuned to
  `concept_cliff_ortho.png`. Take the rules, not the numbers.
- Not measured: no `cliff_measure.ps1` scorecard was run on it. Its renders were judged by eye.
- Not budgeted for the game: no collision, no LOD, no load-time limit, one 164 m stretch.
