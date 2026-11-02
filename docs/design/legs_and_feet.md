# Legs and feet: the detailed leg

A higher detail level for everything below the body shell: the trousers, the bare tarsus, the foot pad, the toes and
their claws. The research behind every number is in `docs/research/legs_and_feet.md`. The body it joins is in
`docs/design/body_rig_plan.html`, and its feather chart in `docs/research/feather_texture_study.md`.

**Status.** It is a working prototype behind a switch, `LegRig.enabled`, which is off by default. In the rig gallery
it is `--legs detail`. The code is in:
- `scripts/bird/leg_rig.gd` (`LegRig`);
- `scripts/bird/leg_skin.gdshader`;
- a few lines of `bird_rig.gd`'s leg code.

`tests/test_leg_rig.gd` measures every join on the drawn meshes, and `tests/probe_legs.gd` measures the cost. Four of
the join bugs found while building it are in `tests/regressions/mutations.json`, and all four come back KILLED.

What is built and what is only designed is listed in §9.

A/B sheets, capsules on the left and detailed legs on the right:

| Sheet | View |
|---|---|
| `docs/images/legs_ab_side.png` | perched, side view, `--zoom 2.2 --ortho` |
| `docs/images/legs_ab_feet.png` | perched, feet close up |
| `docs/images/legs_ab_flare.png` | landing flare, feet reaching |

---

## 1. What was there

Each leg was six `CapsuleMesh`es:
- a body-coloured tibia;
- a tan tarsus;
- four tan toe stubs.

Every capsule poked into the next one, and none of them joined the body. There were no claws, scales or trousers,
every species had the same tan legs, and the toes were 30 to 40 % too short. `BodyShape.DATA`'s tarsus is also too
long for every species: the real tibiotarsus is 1.3 to 1.9 times the tarsus, the rig's 0.9 to 1.15 times (research §1.3).

## 2. Per species

The numbers are `LegRig.SPEC` and `LegRig.BONES`, fractions of body length L, picked from the research's tables (§7.2).

| | Crow | Owl | Hawk | Falcon | Sparrow |
|---|---|---|---|---|---|
| Tibiotarsus / tarsus (L) | 0.19 / 0.13 | 0.25 / 0.16 | 0.20 / 0.15 | 0.19 / 0.12 | 0.18 / 0.12 |
| Feathered to | the ankle | the toes | the ankle, flags hanging over the tarsus | the ankle, barred trousers | the ankle |
| Trousers | the belly's own black | pale buff `#e6d8bd`, down to the pad | pale `#e2d4bc`, flags 0.22 of the tarsus | `#bdb6ae`, 0.15 | the flanks' own grey |
| Tarsus skin | black `#232327` (lifted from `#121214` so the scales read) | not seen | yellow `#e3c04a` | yellow `#e8c547` | pinkish brown `#b38b7c` |
| Tarsus scales | scutes in front | none (feathered) | scutes in front, reticulate behind | reticulate all round | finer scutes in front |
| Toes | perching, flat pads under the bones | feathered (soft streaks), 2 + 2 grip, bulging pads | pads bulging under the joints | long thin toes, bulging pads | perching, flat pads |
| Claws, I : II : III : IV | 1.31 : 1.08 : 1.29 : 1, 115° | 1.05 : 1.19 : 1.16 : 1, 95° | 1.8 : 1.65 : 1.2 : 1, 115° | 1.27 : 1.13 : 1.11 : 1, 118° | 1.31 : 1.08 : 1.29 : 1, 110° |
| Claw colour | black | blackish grey | black | black | dark horn |

The claw ratios are Fowler et al. 2009's family means. The arcs follow the research's §5.2: owls are the least hooked
and falcons the most.

## 3. The rule: every join is an edge loop on the surface it leaves

The body already joins this way. The arm wing lofts from a loop on the trunk (`_loft_arm`), and the neck from the
trunk's front ring to the head's ring (`_loft_neck`). In both, the feather chart's UV and UV2 run on across the join.
The legs follow the same rule, through five joins:

```
trunk shell ──loop on the shell──▶ trousers ──hem ring = tarsus's first ring──▶ bare tarsus ──loop on the pad──▶ foot pad
                                                                                                                  ▲
                                         claw ◀──same tube── toe (phalanges, pads) ──────────loop on the pad──────┘
```

| Join | How | What agrees across it (tested) |
|---|---|---|
| Body shell → trousers | A loop of points ON the trunk's surface round where the leg leaves it, then a fillet onto the leg | Position (on the drawn trunk), colour, the feather chart (UV, UV2), the shading normal |
| Trousers → bare tarsus | The trousers' last ring IS the tarsus's first ring (the same points); the feather skirt hangs below and outside it | Position (identical). The feathers overlap the skin there, as on a bird; the colour changes at the feather line |
| Tarsus → foot pad | The tarsus's last ring slid along the tarsus onto the pad | Position (on the drawn pad), colour, the scale coordinates |
| Toe → foot pad | The toe's first ring slid back along the toe onto the pad; neighbouring toes' loops never overlap | Position, colour, the scale coordinates |
| Toe segments → pads | One tube per toe; the pads are bulges of its rings' soles | Continuous by construction |
| Toe tip → claw | The same tube: the toe's last ring runs on into the claw's rings | Continuous by construction; the colour turns to horn in one short step |

## 4. Geometry

### 4.1 Trunk → trousers

- **Where the leg leaves the body.** The polyline knee → ankle → foot is walked against `BodyShape.gap` (the knee is
  always inside). The exit can be on the tibia or, when the ankle is tucked in the belly, on the tarsus. If barely any
  tibia shows (less than 1.7 shank radii), the trousers hang from the ankle instead.
- **The loop.** An ellipse of the leg's size × `LOOP_FLARE` (1.6) is laid on the trunk's tangent plane at the exit and
  dropped onto the shell along its normal. The first version slid the leg's own ring along the bone onto the shell.
  On a perched hawk, whose tibia leaves the belly at a glancing angle by the vent, that smeared the loop about 10 cm
  along the body and across the midline (mutation `leg-loop-off-shell`). The loop is also clamped clear of the
  midline, so the two legs' loops never touch. It is turned to match the leg's first ring point for point.
- **What the loop carries.** Each point gets the trunk's feather coordinates from `BodyShape.uv_at`. Its colour and
  shading normal are read from the drawn trunk mesh's grid (`_trunk_at`), so the join shows no seam in colour or
  light.
- **The fillet.** Each column is a cubic from the loop to the leg's first ring: it leaves the loop along the trunk's
  surface and arrives along the leg. The surface meets the belly tangentially, with no crease.
- **Feather coordinates.** On the fillet the trunk's chart runs on, as if the belly continued. Over the first two
  rings it hands over (`HANDOVER`) to the leg's own chart:
  - u runs round the leg, with its seam on the inner side;
  - v runs down the leg;
  - feathers shrink from the trunk's size to `LEG_FEATHER` (0.55 of the body tile).

  The chart turns 90° there (the belly's feathers point back, the leg's down), so the texture strength dips to 0.45
  where it turns. Without that dip the turn read as a band.
- **Fluff and breathing.** The loop is kept on the unscaled shell and drawn × the trunk's scale this pose, so it lies
  on the drawn trunk however the bird fluffs or breathes. `BirdRig` sets the trunk's scale after the legs, so LegRig
  computes it the same way.

### 4.2 The trousers

- **Rings along the bone.** The radius goes from `thigh` by the knee to `shank` at the ankle, measured along the
  bone, not from where it leaves the body.
- **The ankle is rounded.** The tube's centreline turns on an arc no tighter than its radius (`bend_r` = 1.15 ×
  shank), and the rings closer to the joint than the arc's tangent length give way to one ring on the arc. Without it,
  the rings crossed on the inside of a sharply bent ankle and the surface folded over itself (mutation
  `leg-ankle-fold`). A per-column pass then makes sure each ring lies further along its own axis than the ring before.
- **The skirt.** Below the ankle the trousers hang as a skirt: longer behind than in front (the "flags"), and
  narrowing. Its hem tucks back up onto the tarsus. Hawk 0.22 and falcon 0.15 of the tarsus; crow and sparrow 0.06.
  When the ankle is tucked in the belly, the belly's feathers hang at least 0.12 of the tarsus over its top.
- **The owl.** The tube runs on down the tarsus, narrowing to `end_r`, and ends on a loop on the foot pad: it is
  feathered to the toes.

### 4.3 Bare tarsus and foot pad

- **The tarsus** starts from the hem ring, tapers from 1.08 to 0.94 × `tars_r`, and is a little narrower side to side.
  Its last ring widens by 1.45 (where the toes' bones spread at the base) and is slid along the tarsus onto the pad.
- **The foot pad** is an ellipsoid at the foot point: half-width `pad_r` (0.018 to 0.024 L), half as high, its poles up
  and down. Little of it shows: the tarsus covers its top, the toes its sides, the branch its sole.

### 4.4 Toes

- **Layout.** BirdRig's order is inner (II), middle (III), outer (IV), hallux (I). Their headings off the bird's level
  forward are −36°, 6°, 50° and 190° (the hallux back and a little in). The inner toe splays less, so it stays clear
  of the other foot's.
- **The owl** swings its outer toe to 125° as it grips: BirdRig's existing `toe_grip` and `zygo` give 2 + 2.
- **Frame.** Toes are laid out in the world-level frame (`_world_frame`, as the femur is), so they stay level on a
  branch whatever the body's pitch.
- **Phalanges.** Toe I has 2, II 3, III 4, IV 5; the last one is inside the claw. Lengths are given as shares of the
  toe, and the middle toe is 0.075 to 0.09 L without its claw: the research's §1.4 found the old toes 30 to 40 %
  short.
- **Curl.** `toe_grip` × the species' total (100 to 120°): 15 % at the root and the rest shared between the joints.
  The root stays nearly flat, so the toes' bases stay apart on the pad. Each joint's ring sits on the bisector of its
  two bones, so a curled toe doesn't pinch.
- **Bases on the pad.** Each toe's first ring is slid back along the toe onto the pad, with no flare. The headings
  are spread so the four loops never overlap; the test checks this in a gnomonic view from the pad's centre
  (mutation `toe-base-off-pad` covers the loop leaving the pad).
- **Pads.** Each ring's sole radius is bulged by `bulge` × a bump:
  - under each joint for raptors ("arthral", Pittman et al. 2022; bulge 0.4 to 0.5);
  - under the middle of each bone for perchers ("mesarthral", bulge 0.25).

  There are four rings per phalanx, so either rhythm shows.
- **Claws.** The toe's last ring runs on along an arc that curves down (ventrally) through the species' angle,
  tapering to a point. Its length is the species' claw for that digit. Its cross-section is flattened side to side
  (0.62 of its depth), with a narrower underside. The vertex colour turns to horn 6 % of the way along, and COLOR.a
  (keratin) switches the shader to smooth and glossy.

### 4.5 Curling round a branch (designed, not built)

The prototype curls each toe by a fixed total angle. On the gallery's branch the claws sink a little into the bark.
That is in the A/B sheets and is close to how talons grip, but it doesn't follow the branch's size. The design:

1. Pass the grip's branch radius to the rig. `Bird` knows the perch's radius, and `telemetry()` carries the grip
   point already.
2. For each toe, solve its joint angles so its joints lie on a circle of radius (branch + toe radius) round the
   branch's axis, from where the root meets the top of the branch:
   - each phalanx is a chord of that circle;
   - the claw's arc ends touching the bark.
   This is a closed form: each chord turns by 2·asin(length / 2R).
3. The hallux wraps the back of the branch, opposite the middle toe. The owl's outer toe joins it.
4. On a branch thicker than the foot can wrap, the curl saturates at the species' total, and the toes lie on top.
5. On the ground, grip is 0 and the toes lie flat, as now.

This needs the branch radius in `telemetry()`, a small change to `bird.gd` that is outside this branch's leg-only
scope.

## 5. Feathering

- **Built: a textured shell.** The trousers are a shell that shares the body's contour-feather material
  (`body_feathers.gdshader`, plumage level 6) and the body's chart where it leaves the trunk, so the pattern runs on.
  Below level 6 it is the plain vertex-colour material, as the trunk is. It reads well at game scale.
- **Designed: fringe cards.** The skirt's hem is a clean edge where real trousers end in a ragged fringe of feather
  tips. The plan:
  - put 8 to 12 small contour-feather cards round the skirt's edge ring, using the existing feather card and atlas
    (the lesser-covert cells, which have rounded, slightly ragged tips);
  - give them the trouser colour;
  - lay them along the ring's own axis, tips down, staggered in two rows;
  - hand the hawk and falcon longer cards behind, for the flags;
  - give the owl a second, looser ring over the toes' bases.

  Cost: 16 to 24 cards a bird in the existing feather MultiMesh, so no new draw call. Not built yet, because the shell
  alone already reads as trousers in the gallery. Worth trying next for close-ups (open choice 3).
- **Marks.** The falcon's barred trousers and the Red-tail's western barring would use the body shader's spot field.
  The trousers' UV2.y is set to −0.8 ("belly"), so they take the species' belly spots today. True bars across the leg
  need a `bars` term in `body_feathers.gdshader`: a sine band in v. That shader is the body agent's file, so it is
  left to them.

## 6. Texturing

**Built: procedural** (`leg_skin.gdshader`). It is read through coordinates every skin piece carries:
- UV is (u round the tube, v along it), in scales: u = 0 on the tarsus's front and the top of each toe;
- UV2 is (u's period, how much front plates may show);
- COLOR.a is keratin: 0 for skin, 1 for claw.

The shader draws:
- **Scutes:** transverse plates, each overlapping the next one down, in a band down the front (|u| < 0.2 of the
  girth) where `scutes` × UV2.y allows (hawk, crow, sparrow; the falcon has none);
- **Reticulate scales** elsewhere: a jittered cell pattern, its edges as grooves;
- **The owl's feathered toes** (`fuzz`): soft streaks instead.

Height bumps the normal through screen derivatives, so the meshes need no tangents. The whole pattern fades out where
a scale drops under about two pixels, so a distant leg is its plain colour and does not shimmer.

**Alternative: baked.** This would follow `feather_atlas.gd` and `tools/bake_feathers.gd`:
- a 512 × 512 `scale_tile.png`, baked by a `FeatherAtlas.bake_scales()`:
  - R height;
  - G groove;
  - B a random value per scale;
  - A a front-plate mask in u;
- the same MD5 stamp so `test_feather_texture` catches a stale bake.

Baking buys hand-tuned shapes (scutes that taper round the sides, papillae on the soles) and a cheaper fragment. It
costs a texture fetch and a new asset. The procedural version costs about 18 hash evaluations a pixel, but only on a
few hundred pixels per bird, and the GPU measurement (§7) shows no difference. Switch if the legs ever fill the
screen in gameplay, or if the scales need to look drawn rather than generated (open choice 4).

## 7. Cost

These numbers are from `tests/probe_legs.gd` and the rig gallery's `--measure`. They are console-build times on the dev
machine.

| Per bird | Capsules | Detailed legs |
|---|---|---|
| Meshes / draw calls | 12 `CapsuleMesh` instances | 4 (feathers and skin per leg) |
| Vertices / triangles | 12 default capsules | 1,770 to 2,070 / 2,960 to 3,470 |
| GPU, 5 birds perched | 1.54 to 1.65 ms | 1.34 to 1.46 ms (no measurable cost) |
| CPU `apply_pose`, legs still (perched, flying straight) | 1.8 to 2.5 ms | the same (cached) |
| CPU, legs moving every frame | — | **+3.1 to 3.3 ms** (both legs rebuilt) |

The rebuild is the cost to watch. LegRig rebuilds a leg only when an input moves more than `REBUILD_TOL` (0.5 mm, or
a few hundredths of a degree), and keeps the trunk loop until the leg moves 0.2 % of L. Legs move during landings and
take-offs and, because the femur follows the world frame, a little as a flying bird pitches.

That is fine for the player's bird and the gallery. It is not fine for six AI birds landing at once. Options, cheapest
first:
1. **Level of detail.** Beyond about 1,000 px² on screen, draw the capsules, or a frozen copy of the last mesh.
2. **Rebuild budget.** At most N legs rebuilt a frame (round-robin, nearest first).
3. **Skinning (production).** Build each leg mesh once in its rest pose with bone weights, and let the GPU deform it:
   - toe bones go under `tarsus.L/R`, 14 a foot;
   - the trouser loop is weighted to `body`, the fillet blends to `tibia`.

   The per-frame cost then falls to posing about 18 bones a leg. The joins stay exact at rest and close in motion; the
   trunk loop would no longer slide along the shell as the leg swings, which is what a bird's skin does anyway. This
   is the way to ship it. The procedural loft stays as the generator of the rest mesh.

## 8. Testing (`tests/test_leg_rig.gd`)

Following `AGENTS.md`, every check measures what is drawn: the ArrayMeshes' vertices, colours, UVs and normals, not
the constants that build them. Every species is checked, both legs, perched, flaring and gliding:

- **Trunk → trousers.** The trousers' first ring lies on the drawn trunk (closest point on its triangles, < 0.4 % L).
  It has the trunk's interpolated colour (< 0.05), feather coordinates (u compared modulo its period, < 0.06 tiles)
  and shading normal (dot > 0.95) there.
- **Trousers → tarsus.** The hem ring is the tarsus's first ring (< 1 µm). Every column of the skirt's edge lies
  further down and further out than the hem: the feathers overlap the skin. The owl's tube instead ends on the drawn
  pad.
- **Tarsus → pad, toes → pad.** Each loop lies on the drawn pad (< 4 % of its radius), with its colour and scale
  coordinates (< 0.25 scales; the pad's coordinates are interpolated over its tessellation). The four toe loops share
  no area in a gnomonic view from the pad's centre.
- **Toe → claw.**
  - The claw's rings run on from the toe's last ring.
  - The skin's keratin is 0 and the claw's 1.
  - The tip collapses to a point.
  - The drawn arc is within 30° of the species' (measured between ring centres).
  - The hallux claw against the outer one matches the species' ratio within 12 %.
- **Pads.** The sole's radius against the side's varies along each toe by at least 0.6 × the species' bulge.
- **Mirror and normals.** The left leg mirrors the right point for point (< 0.01 % L). Normals face out of their
  rings along the tubes. In the perched pose, the tarsus's front plates face forward.
- **The bones and the game's path.** The tibiotarsus is the measured one. A perched `Bird` with the detailed legs on
  (hawk, owl) has its feet on the perch, both feet drawn, and the outer toe back only on the owl.
- **Regressions.** `tests/regressions/mutations.json` has four entries, all KILLED by `test_leg_rig`:
  `leg-loop-off-shell`, `leg-hem-not-shared`, `leg-ankle-fold` and `toe-base-off-pad`.
- **Other tests.** The rest of the suite runs with the switch off (the capsules), including `test_bird_rig`. Its
  owl-toe check now reads `BirdRig.toe_tips`, which both paths fill. The runner's rule that any engine `ERROR:` or
  `WARNING:` fails a test caught two format-string bugs in the test itself.

## 9. Built and designed

| | State |
|---|---|
| Lofted, tapered trousers and tarsus; the trunk loop and fillet; the hem; the rounded ankle; the owl's feathered tarsus | **built** |
| Foot pad; toes with phalanges, curl at the joints, arthral and mesarthral pads; curved, tapered, horn-coloured claws by Fowler's ratios | **built** |
| Procedural scutes, reticulate scales and feathered toes; per-species colours | **built** |
| The measured bone proportions, applied while the switch is on | **built** |
| Join tests, mirror, normals, four mutation entries; cost probe | **built** |
| Toes fitted to the branch's radius (§4.5) | designed |
| Fringe cards on the trousers' hem (§5) | designed |
| Barred trousers (falcon, western Red-tail) | designed (a body shader term) |
| Baked scale tile (§6) | designed |
| Skinned legs and a level of detail (§7) | designed |

## 10. Open choices

1. **Turn it on by default?** The A/B sheets are in `docs/images/legs_ab_*.png`. The CPU cost while legs move (§7) is
   the reason it is off.
2. **Take the measured bone lengths into `BodyShape.DATA`** for everyone, not only while the switch is on. They lift
   a perched bird's ankle below its belly so the trousers show, and they shorten the tarsus about 25 to 50 %.
   `body_shape.gd` is shared with the body work, so this is left as a choice.
3. **Fringe cards on the trousers' hem** for close-ups (§5).
4. **Procedural or baked scales** (§6).
5. **Fit the toes to the branch** (§4.5). This needs the branch radius in `telemetry()`.
6. **Which owl?** The owl is a blend:
   - the barn owl has a long tarsus with bare, bristled toes;
   - the great horned owl has a short tarsus and is feathered to the claws.

   The prototype's owl is feathered to the claws, with the barn owl's longer legs.
7. **The juvenile Peregrine's greenish feet and the crow's blacker legs.** The research's hexes are used as given,
   except the crow's skin, which is lifted to `#232327` so its scutes read.
