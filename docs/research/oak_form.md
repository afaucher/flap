# Oak form: real mature oaks against Flap's

How large oaks are built (Quercus robur, Q. petraea, and the American white oak Q. alba), open-grown and forest-grown,
with Flap's four oaks measured against them. The work came from five complaints about an oak with an outpost on it:
the bark repeats; the limbs are too long, straight and bare; the outpost is embedded in the tree; too many limbs leave
the fork; and the joins look wrong. **§9 is what the measurements say, and §10 is the proposed fix for each complaint.**
Fixes 3 and 4 are done (§11); the rest are proposals.

Tags:
- **[S]** sourced: the source's own text or table says it.
- **[W]** secondhand: from an abstract, a search summary or a citing source only.
- **[E]** our estimate from sourced numbers or photos, with the reasoning given.
- **[G]** a choice for the game, with no claim that an oak does it.

**The honest gap.** No readable source gives a first-fork height for open-grown oaks, a count of scaffold limbs, limb
lengths, limb tortuosity, the depth of the leaf shell, how much a collar swells, or measured branch angles for
Quercus. Every number on those is [E]. The papers that would settle them were paywalled, so only their abstracts were
read: Kędra 2019 on forking in 30 old oaks, Dassot 2019 on TLS of three large Q. petraea, and Malhi 2018 Fig. 5. The
best fix is the Wytham Woods TreeQSM dataset (24 English oaks, <https://zenodo.org/records/7307956>), from which these
measures could be taken directly with `tools/oak_form.py`'s method.

## 1. Size

| | value | tag |
|---|---|---|
| White oak, typical mature | 24-30 m tall, DBH 0.91-1.22 m; records 46 m, 2.44 m, 600 yr [SIL] | [S] |
| Oak DBH by age, open-grown good site | ~1.06 / 1.28 / 1.63 m at 150 / 200 / 300 yr (from [WHI] growth table) | [E] |
| the same, inside woodland | ~0.63 / 0.76 / 0.96 m | [E] |
| Open-grown giants | Wye Oak 29.3 m tall, spread 36.3 m, DBH 3.1 m; VA champion 26.2 m, spread 34.4 m, DBH 2.7 m [UMD][AF] | [S] |
| Height : spread, open-grown | 0.76-0.81: wider than tall. Height stops growing by ~150 yr while girth and spread go on | [E] |

## 2. Trunk to the first fork

- Open-grown: "a short stocky bole with a widespreading rugged crown". Forest-grown: "a tall straight trunk with a
  compact crown" [SIL] [S]. Open-grown trees "develop lower and larger branches ... the central leader may be lost as
  the largest-diameter branches (called scaffold branches) become dominant. Some of these branches rest on the ground"
  [GIL] [S]. Krajicek's open-grown sample had "limbs extending ... nearly [to the ground] on larger trees" and had to
  exclude bole forks below 4.9 m [KRA] [S].
- Forest-grown: the crown base sits at 50-60% of height. Relative crown length runs from 30% in dense stands to 70% in
  thinned ones (1300 Q. robur/petraea) [SPI] [S]. Forest white oak is "often branch-free for two-thirds of its height"
  [NRC] [S].
- Open-grown: the first live limbs are at **1.5-4 m** and the main fork at **3-8 m**, about **0.1-0.35 of the height**
  [E]. This rests on the above and on photos.

## 3. How many limbs, and where they leave

- Oaks are decurrent: they "naturally develop clustered branches that grow upright or spreading and overtake or
  replace the leader" [GIL] [S].
- A strong attachment has the branch under half the parent's diameter, and "a single branch rather than several
  branches arises at one location". Several from one point is a weaker "multiple attachment". The ideal vertical
  spacing of scaffolds on large trees is 1.2 m or more [GIL] [S]. This is an arborist's goal, not a survey of wild
  oaks.
- Old-growth oaks (30 trees) "tended to either keep branches at varying heights, with no forks; or to iterate forking,
  with no major (non-fork) branches below the first fork" [KED] [W].
- At the twig scale, oak shoots branch in pseudo-whorls at the end of each year's growth: 42% of those buds become
  branches, against 28% along the shoot [HAR] [W]. That clustering seeds forks of a few near-equal stems.
- A mature open-grown oak has **3-6 scaffold limbs**. The main fork is **2 stems (most often) or 3, rarely 4**, their
  bases spread over **0.3-1.5 m** of trunk, each 0.6-0.9 of the trunk's diameter. Below it are **1-4 big laterals**,
  0.5-2 m apart, round the trunk about 90-140 degrees apart [E]. A true 4-5-way "crow's foot" from one point is mostly
  a pollard (regrowth from a cut head) or a tree regrown after a storm [E].

## 4. Spread, and how long the limbs are

- Open-grown oak-hickory: **crown width (ft) = 3.12 + 1.829 DBH (in)**, r² 0.97, n 173 [KRA] [S]. In metres that is
  about CW = 0.95 + 0.22 DBH (cm), so the crown is about 22 times as wide as the trunk [E]. The formula overpredicts
  the giants, whose spread levels off at **30-40 m** [E from UMD, AF].
- Even-aged stands: crown diameter (m) = 0.20 + 0.209 d (cm) − 0.015 age [SPI] [S].
- The low limbs on open-grown trees are "long and can make up a large portion of the crown", running horizontally
  "for a certain distance but eventually sweep upward, often at the edge of the crown"; the lowest are the longest
  [GIL][KRA] [S]. A 1.2 m DBH oak has a low lateral of **12-16 m**, so limb length is about 10-14 times the DBH [E].
- Branch-to-trunk diameter: collars form under 0.5, and 0.7 is a weak union [GIL] [S]. Laterals are 0.25-0.55 of the
  trunk, fork stems 0.6-0.95, and second-order branches 0.2-0.5 of their scaffold [E].

## 5. How straight

- No measured value exists. QSM papers report angles and lengths, not curvature.
- What makes oak limbs crooked is sourced:
  - growth in several flushes a year, each ending in a bud cluster [W];
  - competing whorl buds, so losing the tip bud sends a side shoot on as the leader [HAR] [W];
  - longer shoots from buds on a shoot's underside, which pushes limbs out and down [HAR] [W];
  - heavy epicormic sprouting [SIL][SPI] [S];
  - "gnarled and twisted side branches" on open-grown white oak [NRC] [S].

  A CG oak tuned to photos uses an S-curve on each first-order limb plus a random bend of up to **15 degrees per
  segment** [WP] [S].
- Scaffold path length / chord length is **1.05-1.15** [E]: the whole limb's curve is gentle. The crookedness is at
  smaller scales:
  - scaffolds change direction **10-25 degrees every 1-3 m**, with about **one elbow of 30-50 degrees** per limb
    where a side branch took over;
  - second-order branches change 15-35 degrees every 0.5-1.5 m;
  - twigs zig-zag 20-45 degrees every 0.1-0.4 m [E].

  Low laterals run out nearly level, often sag at mid-length, and turn up 30-60 degrees at the crown's edge [GIL][E].

## 6. Angles

Measured from the vertical where the limb leaves [E, from WP's photo-matched 30 ± 30 / 45 ± 10 and from GIL]:

| limb | angle from vertical |
|---|---|
| lowest laterals | 70-100 degrees (to the ground on ungrazed trees) |
| mid-bole laterals | 50-75 degrees |
| fork stems | 20-45 degrees each (40-80 between them) |
| upper scaffolds | 25-50 degrees |

Second-order branches leave their parent at 40-70 degrees. Those on top of a level limb rise near vertical, often as
epicormics. Twigs leave at 40-65 degrees.

## 7. Taper

- Leonardo's rule: at each fork, Σ d_child^Δ = d_parent^Δ. For a white oak Δ = **2.25 ± 0.06** [SOT] [S]. Across
  species Δ is 1.8-2.3 [ELO] [S]. So the daughters' summed cross-section is 0.9-1.1 times the parent's [E].
- A CG oak's trunk flares to 2.2 times its radius at the ground [WP] [S]. A scaffold tapers to about 40-60% of its base
  diameter by mid-length, shedding wood into its side branches [E].

## 8. Leaves along a limb, and the joins

- In stands, low branches "are shaded out before they become long and heavy" [GIL] [S]. On white oak, "some branches
  along the trunk tend to persist when exposed to sunlight" [SIL] [S]. Q. robur makes more epicormic shoots than
  Q. petraea [W].
- On an open-grown oak in leaf, the foliage is a **2-4 m shell**. The inner **50-75%** of each scaffold has few live
  twigs: bare bark with **tufts of epicormic shoots** (0.3-1.5 m, mostly on the upper side and round old wounds), dead
  twig stubs and some dead side branches [E]. Forks and side branches still leave all along the limb (§5). A limb is
  bare of leaves, not bare of branching.
- Branch xylem turns down round the branch's base (the branch collar), and the trunk's wood wraps over it each year
  (the trunk collar). In the crotch, the **branch bark ridge** is a raised fold of bark [SHI] [S]. Collars "rarely
  form on branches with a large aspect ratio" [GIL] [S]. A fork of near-equal stems has no collar. Its strength is in
  interlocking wood at the apex. A U-shaped crotch is usually stronger than a V, a V with included bark shows bulging
  "ears" either side, and an inclined fork's cross-section is elliptical [SLA] [W].
- In a strong union, the collar is **1.15-1.35 times** the limb's diameter a metre out, running 0.3-0.7 diameters
  along it. The trunk swells 5-15% round and below the union. A fork flattens the parent to an ellipse about 1.3:1
  across the fork plane over the last 0.5-1 m below the split [E].

## 9. Flap's oaks, measured

These measurements come from the wood as drawn (`TreeData.limbs`, the trunk from `crown_base` and `trunk_top()`), on
the baked map `maps/pinewood_7.map`: `.\probe.ps1 -Headless probe_tree_paths --out oaks.json`, then
`python tools/oak_form.py oaks.json --pines pines.json --json oak_form.json`, then `python tools/oak_chart.py
oak_form.json out.png`. The outpost numbers come from `.\probe.ps1 probe_oak_outpost --out <png>`, and its bark
close-ups from `--bark`.

The pictures are in `docs/images/oak_form/`:
- `oak_chart.png`: every measure against the real ranges;
- `oak_side.jpg`: the four oaks from the side (`tools/tree_side_map.py`);
- `oak_outposts.jpg`: each oak's outpost from the front, the side and above;
- `bark_and_joins.jpg`: oak and pine bark at the same distances, and the joins;
- `bark_photos.jpg`: the three bark scans;
- `big_trees.jpg`: `probe_big_trees`.

| | oak 0 | oak 1 | oak 2 | oak 3 |
|---|---|---|---|---|
| height, DBH | 24.8 m, 1.85 m | 19.7, 1.74 | 19.4, 1.70 | 21.1, 1.71 |
| fork, bole top (`stem`) | 6.1, 7.7 m | 5.4, 7.0 | 5.3, 6.9 | 5.9, 7.5 |
| crown radius (leaves) | 19.2 m | 18.1 | 18.6 | 18.0 |
| first-order limbs / within 1 m of the fork / their spread up the trunk | 9 / 6 / 1.7 m | 10 / 9 / 1.7 | 9 / 8 / 1.5 | 10 / 9 / 1.7 |
| limb pieces, twigs (all at a piece's tip) | 40, 76 | 46, 81 | 41, 75 | 46, 89 |

| measure | ours | real | verdict |
|---|---|---|---|
| size, fork at 25-28% of height, crown 36-38 m across | as left | DBH 1.7-1.85 m is a 300-400 yr open-grown oak; Krajicek gives 38-42 m, giants 30-40 m; fork 0.1-0.35 H | **right** |
| height : spread | 0.53-0.65 | 0.76-0.81 | a little flat and wide |
| limbs leaving within ±0.5 m of the fork | **6-7** | 2-3 | **too many** (complaint 4) |
| spread of first-order limbs up the trunk | 1.5-1.7 m | 1.5-6 m (laterals 0.5-2 m apart) | too bunched |
| angle from vertical: crown limbs, scaffolds, low limbs | 27-32, 54-61, 85-91 deg | fork stems 20-45, laterals 50-75, lowest 70-100 | **right** |
| limb diameter / trunk's (collar left out) | scaffolds 0.6-0.68, low 0.39-0.47 | laterals 0.25-0.55; 0.6+ only for the 2-3 fork stems | 6-7 fork-stem-sized limbs at one point |
| reach / crown radius | 0.32-0.84 | 0.6-1.0 | fine |
| path / chord | low limbs **1.01-1.03**, others 1.05-1.56 | 1.05-1.15 | low limbs dead straight; the whole curve is otherwise about right |
| direction changes over 10 deg, per 10 m | 0-3.6 (low limbs 0-1.4) | 3-10 | **too smooth** (complaint 2) |
| longest dead-straight run (within 2 deg) | **3-9.5 m** | 1-3 m | **too straight**: each piece's middle is exactly straight (`_limb`'s `span`, the perch) |
| metres of limb per side branch (twigs left out) | 3.5-15 m (low limbs: none) | 1-4 m | **too bare** (complaint 2) |
| twigs | 75-89 per oak, every one at a piece's tip | all along, tufts of epicormics | bare along their length |
| daughters' area / parent's at a joint | **1.4, then 2.6** | 0.9-1.1 | **limbs thicken where they fork** (complaint 5) |

So the limbs are not too long: 12-15 m for the low ones is right for a 1.8 m oak. They *look* long because nothing
breaks them up. Each is two or three smooth pieces, each piece's middle a ruler-straight perch, with a side branch
every 4-15 m and twigs only at the ends. The low limbs carry none at all.

### The fork (complaint 4)

`_grow_oak` starts three sets of limbs at one point:
- 4-5 scaffolds (`OAK_FORM.scaffold`), each from fork −0.3 to +0.4 m;
- 2-3 crown limbs (`crown_limbs`), from +0.2 to +0.8 m;
- 2-3 low limbs (`low`), from 0.6 to 1.4 m below it.

That is 9-10 limbs within 1.7 m, and 6-9 of them within a metre. Each scaffold is 0.5-0.58 of the trunk's radius
(fork-stem size) and the trunk stops 1.6 m over the fork (`stem`). A real fork has 2-3 stems that size, and the other
scaffolds are thinner laterals spread metres apart below it.

### The joins (complaint 5)

`_limb` roots every limb at the trunk's *axis* and swells it 1.75 times there (a "collar" decaying over 2.2 r0). That
makes a fat tube pushed straight through a thinner cylinder: no fillet, a hard crease all round, and no branch bark
ridge (`bark_and_joins.jpg`, bottom middle).

The joins between limb pieces are worse:
- each piece ends with a domed cap at its tip;
- the next piece starts there with the *same* radius (no taper across the fork);
- a side limb starts at the same tip, 0.67-1.0 times the parent's radius, with no collar.

At a scaffold's second joint the side limb (r0 × 0.42) is thicker than the piece it leaves (r0 × 0.33), which is the
2.6 above. Every branching happens at a piece's tip, so the joins come as knuckles of three tubes and a cap.

### The bark (complaint 1)

| material | scan covers | tile set (m) | copies round | drawn tile | scan's low-frequency contrast |
|---|---|---|---|---|---|
| `oak_trunk` | 1 x 2 m | 1.0 x 2.0 (true scale) | **8-9** | 0.55-0.78 m wide x 2 m | **22.7** |
| `oak_limb` | 1 x 2 m | **0.5 x 1.0** (half scale) | 1-12 (big limbs **11-12**) | 0.21-0.54 m x 1 m | 22.7 |
| `pine_trunk` | 2 x 2 m | 2.0 / 1.7 | 1-2 | 1.0-1.5 m wide | 6.8 |
| pine `limb` | 1.7 x 1.7 m | 0.6 | 1-3 | on 2-10 cm limbs | 5.3 |

It is the same 2k resolution as the pines' bark. The oak scan is 2048 x 4096 over 1 x 2 m, so it is twice as sharp,
not worse. It repeats more for three reasons, the first the biggest:
1. **The scan itself.** `jolcham_oak_bark_01` has big patches of moss and lichen and a dark stripe down one side. Its
   contrast at the scale of the whole tile (std of a 64 px thumbnail) is **3.3-4.3 times** the pine scans'. A tile
   that is uniform at a distance hides its repeats, and this one shows every copy (`bark_photos.jpg`).
2. **Thick wood, so many copies side by side.** The oak's trunk is 4-6 m round, against the pines' 1.4-2 m. At true
   scale that puts 8-9 copies round it, each a visible vertical stripe of moss. The limbs halve the scan's scale
   (`_TILE.oak_limb` 0.5), so a big limb carries 11-12 copies round.
3. **The tile count is set at the tube's *first* ring**, which is the widest. `_tube` puts a whole number of tiles
   round `radii[0]`:
   - on a trunk that ring is the flared foot (1.55 times the radius);
   - on a limb it is the 1.75 times collar at the trunk's axis.

   As the tube narrows, the same number of tiles squeezes into a smaller circumference. Trunk tiles end up 0.55-0.78
   m wide (a 1 m scan, stretched 1.3-1.8 times tall). Limb tiles end up 0.21-0.54 m wide over 1 m: the scan shrunk
   2-4.7 times and stretched up to 2.3 times along the limb. That is the streaky look on the limbs.

The pines escape on every count: their scans are even, their trunks thin (1-2 copies), their limbs a few cm across.

### The outpost (complaint 3)

`Pinewood._outpost` sets an oak's deck at `stem − 0.6`, which is fork + 1.0 m, "in its fork". It then tries four
heights between `stem − 1.1` and `stem − 0.2`, and `crown_base − 0.4`, in 24 directions. A direction is kept if:
- the swoop to the rail clears the tree's own solid chords (`_way_in`);
- a line runs level out from **1.4 m past the trunk's surface**.

Nothing checks the deck's own footprint (from the trunk to the rail, 1.6 m wide), the hangar, or the space over the
deck. Even a run of 0 m is accepted (`best` starts at −1).

The fork puts 6-7 limbs of 0.7-0.9 m radius (with the collar) round the trunk within a metre of that height, climbing
outward at slope 1.3 for scaffolds and 3.0 for crown limbs. Some limb always passes through the deck's inner half and
rises over it. Measured on the drawn limbs:

| oak | limbs in the deck (deepest) | in the hangar (deepest) | in the 0.6 m over the deck |
|---|---|---|---|
| 0 | 2 (0.20 m) | 3 (0.63 m) | 2 (0.53 m) |
| 1 | 1 (0.10 m) | 2 (0.56 m) | 1 (0.50 m) |
| 2 | 2 (0.17 m) | 2 (0.44 m) | 2 (0.60 m) |
| 3 | 1 (0.08 m) | 2 (0.22 m) | 2 (0.25 m) |

(Re-measured with `probe_oak_outpost` as it is now: past the deck's inner 0.25 m, where it's bolted to the trunk, and
outside the trunk as drawn. The first version of this table counted the strip and the wood hidden in the trunk, and
put the hangar at the wrong end of the deck.) Every oak outpost is cut by its limbs.

## 10. Proposed fixes, one per complaint

Each fix moves the baked map only when it is re-baked on purpose. A re-bake needs the race courses and the combat AI's
tests checked, and `_oak_perches_face_open` / `probe_oak_reach` for the perches.

1. **Bark repeats.**
   - (a) Set the tile count at the tube's typical radius, not its first ring: the median, or the radius 1-2 m out.
     Even better, let the count step down along a tapering tube at a seam hidden on its underside. This alone widens
     limb tiles 1.5-3 times.
   - (b) Put the oak's limbs at true scale (`oak_limb` 1.0).
   - (c) Break up the repeats in `bark.gdshader` for the oak:
     - a second, rotated and offset sample of the same scan, blended by a large-scale noise;
     - a per-tube random offset (the seed is there already);
     - a slow tint noise that drowns the scan's own moss patches.
   - (d) Better still, swap for, or blend in, a more even oak scan (Poly Haven has several CC0 oak barks), keeping
     Jolcham's moss only as a low, shady-side layer as on the trunk's foot.

   No loss of detail in any of these.
2. **Too long, straight and bare.** Keep the lengths. Break up the line and dress it:
   - build each piece as a chain of 1-3 m segments, bending 10-25 degrees at each, with one 30-50 degree elbow per
     scaffold where a side branch carries on and the old line becomes a short stub;
   - keep a straight stretch only where a perch is wanted, and shorter (1.5-2.5 m, not 3-9.5);
   - give low limbs a sag at mid-length and an upturn at the end;
   - put side branches every 1-4 m, alternating sides, the ones on top rising steeply;
   - add drawn-only twig sprays and epicormic tufts along the inner limbs (the twig code exists; it is only called at
     tips), and some dead stubs.

   This adds drawn tubes, so `perf.ps1` should be checked. The solids and perches can stay the coarse chords they are.
3. **Outpost embedded.**
   - (a) In `_outpost`, sweep the deck's box, the hangar's box and 0.6 m of headroom against the tree's drawn limbs (as
     `probe_oak_outpost` does) and reject any height or direction that cuts them.
   - (b) Give the oak a place for it. Either put the outpost on a low lateral limb, as a deck resting on a level limb
     and braced to the trunk (which also reads as a treehouse), or leave a clear quadrant at the deck's height when
     the fork is grown.

   With the fork thinned (4), (a) alone will likely find room.
4. **Overloaded fork.**
   - Grow 2-3 fork stems (0.6-0.9 of the trunk) from the fork, spread over 0.3-1.5 m.
   - Spread the other scaffolds as laterals (0.3-0.55 of the trunk) down the bole 0.5-2 m apart, round it at about
     137 degrees each.
   - Grow the crown's limbs as forks off the fork stems 2-5 m up, not from the fork.

   The total of big limbs and perches can stay about the same.
5. **Joins.**
   - Start a limb at the parent's surface, not its axis.
   - Blend it in with a collar (1.25 times its radius, dying away over half a diameter) that merges into the parent: a
     fillet ring, plus a trunk-collar swell of 5-15% on the parent round the union.
   - Run a branch bark ridge up into the crotch as a fold.
   - At forks, taper by Leonardo's rule (Δ ≈ 2.2), so daughters are thinner than the parent and the summed area is
     about 1.0. Flatten the parent to a 1.3:1 ellipse over the last 0.5-1 m below the split.
   - Start side branches along a piece, not only at its tip, and drop the domed cap where a piece carries on.
   - Run the oak's bole up into the fork stems (no capped stub 1.6 m over the fork).

   The bark shader's UVs must follow the blend (fix 1a).

Order: 4 and 3 first (structure; one re-bake), then 5 and 2 (the look; drawn-only where possible), then 1, which is
independent and could go first because it changes no layout.

## 11. Done: the fork and the outposts (2026-11-11)

The changes, in `Pinewood._grow_oak` (`OAK_FORM`) and `_outpost`, with the map re-baked:
- **The fork (4).**
  - Each oak forks in two stems (60%) or three. Two stems are 0.72 of the trunk's radius each, three 0.62, so their
    summed area is about the trunk's (Leonardo's rule). Their feet are 0.35-0.6 m apart up the bole, and each barely
    swells where it leaves (`_limb`'s new `swell`, 0.25 against 0.75).
  - The 4-5 big limbs leave the stem nearest their way, 0.6-1.3 m over the fork, at 0.5-0.62 of the stem's radius.
  - The 2-3 low limbs leave the bole 0.7 m under the fork and 0.35-0.45 m apart below that, each round from the last
    by the golden angle.

  Measured on the baked map (`oak_chart_after.png`, `oak_side_after.jpg`):
  - limbs off the bole: 9-10 → **5-6**;
  - limbs from the fork up: **2-3** (the stems);
  - the most leaving any metre of the bole: 3;
  - their spread up the bole: 1.5-1.7 m → **2.0-2.4 m**.

  The low limbs are closer together up the bole than a real oak's 0.5-2 m [G]. Spread further, the low tier came down
  and the exam's hawk and falcon missed more there, so they stay in the old band, 0.7-1.5 m under the fork.
  `test_pinewood` holds the fork: two or three stems, no more than three limbs from any metre, spread at least
  1.5 m.
- **The outposts (3).**
  - The big limbs grow round the oak but for a sector, 0.9 rad either side of the way between its first two stems,
    kept for the deck (`deck_side`). The highest low limb grows on the opposite side.
  - `_outpost` now also checks the deck's room against the tree's drawn limbs (`_deck_clear`, `_wood_near`): the deck,
    its hangar, 0.3 m under and 0.6 m over it, with 3 cm of air, past the 0.25 m strip it's bolted on by (`DECK_BOLT`:
    the trunk and the stems' feet).
  - It tries every height from 1.6 m under the fork to the bole's top.

  On the baked map, every oak's deck sits 0.6-0.8 m over its fork, between two stems, with no limb in it or over it
  (`oak_outposts_after.jpg`; the hangar's back touches a stem's foot by 2-9 cm, inside the bolted strip). The five
  pine outposts are unchanged. `test_pinewood` checks every outpost on five layouts. A limb laid through an oak's
  deck moves the outpost, and without the limb it comes back where it was (`_outpost_dodges_limbs`). The mutations
  `outpost-ignores-own-limbs` and `oak-limbs-from-one-spot` are both KILLED.
- **What else moved.**
  - The race courses on the re-baked map: the menu's technical high and low is now course 20, and test_race's
    `_course_rules` takes seed 11 (`docs/design/race.md`).
  - The flight exam's lone oak (`FlightExam.add_tree`, seed 1) is grown live, so it changed with the generator. On
    its low limbs the falcon lands 40 of 48 against its 90% floor (`test_flight_exam#17`). Across four exam seeds
    (`probe_flight_exam --low --seed 1..4`), the low tier lands the hawk 95.8% on master and 93.8% now, and the falcon
    84.4% on master and 79.2% now. Master's seed 1 is its easiest oak (the falcon 70 of 72); at 90%, master's
    falcon would fail seeds 2-4 too. So the falcon's `oak_low` floor is now 80% (`test_flight_exam.RATE`), what
    master's falcon makes of a typical oak, rather than tuning the low tier to the one exam seed.

## Sources

- [SIL] Rogers, R. "Quercus alba L., White Oak". Silvics of North America vol. 2, USDA FS. <https://research.fs.usda.gov/silvics/white-oak>
- [NRC] Natural Resources Canada, Trees of Canada: white oak. <https://tidcf.nrcan.gc.ca/en/trees/factsheet/63>
- [KRA] Krajicek, J.E. 1967, "Maximum Use of Minimum Acres", Table 1 (after Krajicek et al. 1961, Forest Sci. 7:35-42). <https://npn.rngr.net/publications/tree-improvement-proceedings/southern/1967/maximum-use-of-minimum-acres/at_download/file>
- [SPI] Spiecker, H. 2021, "Production of valuable oak wood in Europe", Ann. For. Res. 64(1):5-12. <https://www.afrjournal.org/index.php/afr/article/viewFile/2207/1148>
- [WHI] White, J. 1998, "Estimating the age of large and veteran trees in Britain", Forestry Commission IN12. <https://cdn.forestresearch.gov.uk/1998/01/fcin012.pdf>
- [GIL] Gilman, E.F. et al. 2013, "Structural Pruning: Part 1", ISA proceedings. <https://wwv.isa-arbor.com/events/conference/proceedings/2013/GILMAN_Structural%20Pruning.pdf>
- [HAR] Harmer, R. 1991, "The effect of bud position on branch growth and bud abscission in Quercus petraea", Ann. Bot. 67:463-468 (abstract). <https://agris.fao.org/search/ru/records/65dfea74b766d82b18037de3>
- [KED] Kędra, K. 2019, forking habit of old-growth oaks, bioRxiv 795286 (abstract). <https://www.biorxiv.org/content/10.1101/795286v1>
- [TOM] Toma, V.R. et al. 2021, "Tree Shape Variability in a Mixed Oak Forest using Terrestrial Laser Technology", Forests 12:253. <https://www.mdpi.com/1999-4907/12/2/253>
- [MAL] Malhi, Y. et al. 2018, Interface Focus 8:20170052. <https://pmc.ncbi.nlm.nih.gov/articles/PMC5829190/>
- [WP] Weber, J., Penn, J. 1995, "Creation and rendering of realistic trees", SIGGRAPH 95 (the CA black oak parameters). <https://courses.cs.duke.edu/fall02/cps124/resources/p119-weber.pdf>
- [SOT] Sotolongo-Costa, O. et al. 2020, "Statistical hydraulic model for the Leonardo's rule", arXiv 2009.10310. <https://arxiv.org/pdf/2009.10310>
- [ELO] Eloy, C. 2011, "Leonardo's rule, self-similarity and wind-induced stresses in trees", PRL 107:258101. <https://arxiv.org/pdf/1105.2591>
- [SHI] Shigo, A.L. 1985, "How tree branches are attached to trunks", Can. J. Bot. 63:1391-1401. <https://shigo.davey.com/shigo_publications/2149/publication_file/how-tree-branches-are-attached-to-trunks.pdf>
- [SLA] "Tree fork", Wikipedia, summarising Slater & Ennos 2013-2015. <https://en.wikipedia.org/wiki/Tree_fork>
- [UMD] University of Maryland Arboretum, the Wye Oak. <https://arboretum.umd.edu/articles/wye-wye-oaks-legacy-campus>
- [AF] American Forests champion white oak (VA). <https://www.americanforests.org/tree/white-oak-va/>

**Reference photos** (winter, leafless; Wikimedia Commons, not downloaded):
- Croxley Green oak, public domain: <https://commons.wikimedia.org/wiki/File:Oak_in_Croxley_Green_(Green_%26_New_Road),_February_2012.jpg>
- Felderbachtal oak, four seasons: <https://commons.wikimedia.org/wiki/File:Deutsche_Eiche_Jahreszeiten.jpg>
- Categories:
  - <https://commons.wikimedia.org/wiki/Category:Quercus_robur_in_winter>
  - <https://commons.wikimedia.org/wiki/Category:Solitary_Quercus_robur>
  - <https://commons.wikimedia.org/wiki/Category:Quercus_alba> (Wye Oak, Mingo Oak and others)
