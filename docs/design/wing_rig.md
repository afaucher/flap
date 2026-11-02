# Wing rig plan

The visual plan for the bird model, with drawings generated from the profile numbers: `docs/design/wing_rig_plan.html` (published at https://claude.ai/artifact/T5am6pwmLP3LoQ1uJwkdQo). This file is the short spec. The research behind it is in `docs/research/wing_shapes_and_articulation.md`.

## Bones and joints (per wing)

| Joint | Bones | Degrees of freedom | Range |
|---|---|---|---|
| Shoulder | body → humerus | flap (elevate/depress), sweep (protract/retract), twist (pronate/supinate) | flap −40…+60°, sweep −15…+80°, twist ±25° |
| Elbow | humerus → ulna + radius | flex/extend in the wing plane | 0…140° |
| Wrist | forearm → carpometacarpus | flex/extend, **coupled to the elbow** (the radius slides along the ulna); a little pronation on the upstroke | 0…150°, upstroke +50° |
| Alula (digit I) | hand → alula | deploy forward as a slat | 0…30° |
| Primary fan | hand → p1–p10 | spread; the emarginated tips splay on slotted species | splay 0…12° |
| Tail | pygostyle → 12 rectrices | spread, pitch, twist | fan 10…120°, pitch ±25°, twist ±30° |
| Legs | tibiotarsus → tarsometatarsus → toes | reach, grip | |
| Neck/head | body → head | look, stabilise | yaw ±110°, pitch ±60° |

One value, `fold`, drives elbow and wrist together, because the anatomy does too. Each wing therefore needs five control values: flap, sweep, twist, fold and alula. The primary fan, the slots and the tail follow from those values and the airspeed.

## Control values and their sources

| Control value | Source |
|---|---|
| `flap` | wingbeat phase |
| `fold` | wing tuck (push past half stick, auto-sweep); perched |
| `sweep` | flare (forward), dive (back) |
| `twist` | angle of attack |
| `alula` | angle of attack above 12° at low speed; the flare |
| `slot` | (1 − fold) × slowness |
| `tail.spread`, `tail.pitch`, `tail.twist` | slowness, turn rate, flare, bank |
| `look` | catch candidate, right stick, threats |
| `foot` ×2 | perch grip point, ground |

All of these come from `Bird.telemetry()`, as the rig's inputs do today.

## Where IK goes (Godot 4.7 modifiers)

| Chain | Solver | Why |
|---|---|---|
| Legs | `TwoBoneIK3D`, pole forward | Feet land exactly on the perch's grip point from any approach. |
| Arm wing when folding | `TwoBoneIK3D`, blended by `fold` | The wrist lands on a flank anchor, so the folded wing hugs that species' body instead of clipping through it. |
| Head and neck | `LookAtModifier3D` | Head stabilisation, and looking at the perch or target. |
| Forearm twist | `BoneTwistDisperser3D` | Spreads pronation along the arm. |
| Primary and tail tips | `SpringBoneSimulator3D` | Secondary motion. |
| Wing in flight | forward kinematics | The linkage plus five values defines it fully. IK would fight it. |
| Talons (combat) | `TwoBoneIK3D` | Grabbing a target. |

## Feathers

| Group | Count | Attached to |
|---|---|---|
| Primaries p1–p10 | 10 | hand (p1–p6 on the carpometacarpus, p7–p10 on the major digit) |
| Secondaries | 9–14 by species | ulna |
| Tertials | 3 | end of the humerus |
| Coverts (greater, median, lesser) | rows | over the flight feather bases; the lesser coverts form a band behind the leading edge |
| Alula | 3 | digit I |
| Scapulars | about 6 | shoulder |
| Rectrices | 12 | pygostyle |

**Build:**
- A `Skeleton3D` made in code from each species' proportions.
- One shared tapered feather mesh, placed per bone with its own length, width and notch. That's about 70 feathers per bird, drawn as one `MultiMesh`.
- The coverts as a few skinned strips.

**Test:** the rig's drawn wing area must match the profile's `wing_area`. The plan page already checks this for every species: the drawn area is fitted to the model's area, and the drawn aspect ratio matches the model's.

## Wing shape by species

The arm, hand and primary numbers below are fractions of the half-span.

| | Arm : hand | Longest primary | Tip | Slots | Secondaries | Tail |
|---|---|---|---|---|---|---|
| Hawk | 4.1 : 1 | p7 | rounded | 5 | 14 | broad fan |
| Owl | 3.9 : 1 | p7 | rounded, soft | 4 | 14 | short, square |
| Crow | 2.9 : 1 | p8 | blunt | 4 | 11 | rounded |
| Falcon | 1.9 : 1 | p9 | pointed | 0 | 10 | long, narrow |
| Sparrow | 2.4 : 1 | p7 | short, rounded; p10 vestigial | 0 | 9 | notched |

## Ground effect scales with span, not area

Ground effect works on the wingtip vortices, which sit about one span apart. The ground acts like a mirror image of those vortices, and its effect fades with the ratio h/b (height over span). McCormick's fit for the induced-drag factor is:

φ = (16h/b)² / (1 + (16h/b)²)

Wing area sets how much lift there is, not how high the effect reaches. Chord only matters when the bird is skimming lower than its chord, which is a few centimetres for a bird.

The model uses 1.5 spans with a 1.5 m minimum, a deliberate exaggeration so downed birds can get back up. In reality the drag benefit is small above about a quarter of a span. The 1.5 m minimum only matters for the sparrow (it gets about 4.5 spans); every other bird already spans more than 1 m.

## As built

- **`scripts/bird/wing_shape.gd` (`WingShape`)** holds the per-species planform. It defines the bones, the feathers on each bone (bone, position along it, angle relative to it, length, width), and the 2D outline.
  - `calibrate()` fits an overall scale and a chord factor.
  - The drawn wing then matches the flight model's span, area and aspect ratio exactly. `test_wing_shape` checks this.
- **`scripts/bird/bird_rig.gd` (`BirdRig`)** is the model.
  - A `Skeleton3D` holds the bones: body, three neck bones, head, tail, and per side the humerus, forearm, hand, femur, tibia and tarsus.
  - The body (`BodyShape`, `scripts/bird/body_shape.gd`; plan in `body_rig_plan.html`) is a rigid trunk whose shell is lofted through rings placed from the landmarks (shoulders, keel, hips, tail base). The neck retracts into an S on the perch and reaches out in flight (`neck_ext`); its feather tube runs straight from inside the trunk to the head. The folded wing's elbow and wrist are slid onto the shell.
  - Every tick, `apply_pose()` solves the wing, legs and head, writes the skeleton, and lays out about 120 feathers. Feathers use one shared tapered mesh in two `MultiMesh`es, plain and emarginated (slotted).
  - The solve is analytic, in GDScript:
    - The wing is FK from the control values, plus a two-bone IK onto the flank anchor as it folds.
    - The legs are a short femur held near level in the world (the knee stays inside the belly), then two-bone IK with the ankle bending aft. An owl's outer toe swings back when it grips.
    - The head look is clamped to ±110° yaw (owl ±135°) and ±60° pitch, and the head stays level with the world. It also holds still in world space through the trunk's jolts (the touchdown dip, the pitch from flare to perch) and catches up within a few frames.
    - Small motion: the trunk dips on touchdown while the feet stay on the grip; the tail pumps a few times; the plumage fluffs perched (owl most) and sleeks fast; the bird breathes. On take-off the feet keep pushing on the perch for 0.15 s, so the legs extend.
  - Godot's own `TwoBoneIK3D` / `LookAtModifier3D` give the same result. Solving in code keeps the feathers, which ride on the solved bones, in step with the pose in the same tick, and keeps the solve testable headless.
  - While folding, feather directions blend from following their IK-moved bone to their designed folded direction (aft along the body), so the folded wing lies flat.
- **Telemetry** now also carries `look_target` and `grip`:
  - `look_target`: the catch candidate or the perch, else ahead.
  - `grip`: the perch's grip point while landing or perched, the ground while grounded, or a catchable perch within 3 m.
- **Cost and level of detail.** A rig update costs about 150 µs per bird. Birds update their rig every tick within 30 m of the camera, every 2nd tick out to 60 m, then every 4th. Hidden rigs don't update.
- **Look at it:**
  ```
  .\run.ps1 --scene res://scenes/rig_gallery.tscn --pose glide|flap|upstroke|folded|flare --view top|front|three
  ```
- **Tests:** `test_wing_shape` (calibration) and `test_bird_rig`. The rig test covers bone lengths in every pose, span, the fold-anchor IK, mirror symmetry, flap direction, leg IK, head clamp, the skeleton matching the solve, and a perched bird's feet on its perch.
- **Wing thickness: muscle, tendon and skin.** The arm isn't a cylinder. Four pieces per wing, each lofted once as a unit mesh with an airfoil section (round and thick at the front where the bone or tendon runs, thin behind, slightly cambered) and laid along its bones every tick:

  | Piece | Anatomy | Thickness, root → tip (× root chord) | Chord |
  |---|---|---|---|
  | Propatagium | Skin fold shoulder → wrist, held taut by the tensor propatagialis tendon: a straight leading edge in front of the elbow | 0.06 → 0.035 | Deepest mid-span, reaching back over the elbow; set per pose |
  | Humerus | Biceps, triceps, deltoid | 0.12 → 0.08, belly at 35% | 0.40 → 0.32 |
  | Forearm | Muscle bellies by the elbow, tendons to the wrist | 0.11 → 0.045, belly at 15% | 0.34 → 0.24 |
  | Hand | Bone and tendon | 0.05 → 0.022 | 0.22 → 0.10 |

  - The flight feathers behind form the thin trailing edge. The breast muscles that power the wingbeat are part of the body shell (its deep breast ring).
  - The propatagium slackens away as the wing folds. `test_bird_rig` checks its straight edge, that it covers the elbow, that it's gone folded, and that every piece thins outward.
  - Gallery close-ups: `--view wing` (the arm wing from ahead and above) and `--view lead` (head-on). A/B in `docs/images/wing_limbs_before_after.png`.
  - Flight feathers arch by 3% of their length, so they aren't flat cards.
- **Feather widths and outlines.** Each feather type has a width/length ratio:

  | Feather | Width / length |
  |---|---|
  | Primaries | 0.20 (inner) to 0.13 (outer) |
  | Secondaries | 0.27 |
  | Tertials | 0.30 |
  | Greater coverts | 0.55 |
  | Lesser coverts | 0.60 |
  | Alula | 0.22 |
  | Tail feathers | 0.20 |

  - The outlines are broad nearly to a rounded tip.
  - Emarginated primaries narrow sharply past their middle, so the only gaps on the wing are the slotted fingers.
  - Tail feather bases spread across the tail stump (0.05 body lengths), and the central pair sits on top.
  - The full tail spread is 100°: the widest fan that 12 feathers of that width still close.
  - `test_bird_rig` checks that neighbouring tail feathers overlap at both spreads, and so do neighbouring secondaries.
  - The earlier rig drew every feather at half its intended width: the outline's widest point was half the feather's width. A/B: `docs/images/tail_wing_width_before_after.png`.
