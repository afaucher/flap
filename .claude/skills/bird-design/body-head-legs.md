# Body, head, eyes, legs, poses, tack

Rig space: -Z the bill, +X right, +Y up. L = `BirdProfile.body_length` (about field-guide total length).

## The body (`scripts/bird/body_shape.gd`, `docs/design/body_rig_plan.html`, `docs/research/body_anatomy.md`)

- The trunk is rigid (notarium, synsacrum, keel fused) and lofted once through rings placed from **landmarks**:
  throat, front of breast, shoulders (through the shoulder joints, from WingShape), keel (deepest ring, z -0.04 L),
  hips plus thigh padding, vent, tail base. Joints and outline drifted apart when the body was a hand-placed
  capsule; with rings from landmarks they can't.
- Cross-section: two superellipse halves -- back exponent 2.6 (flat, square shoulders), breast 1.8 (deeper to the
  keel). "A bird's trunk is not an oval."
- Per species `DATA[id]` (shares of L): `neck` [rest, reach] (`neck_bone` = reach/2.7: never quite straight),
  `depth` (undersides scale by depth/0.32), `head` (head_r), `legs` [tibiotarsus, tarsus], `neck_flight` (0..1),
  `zygo`, `fluff` (perched), `skull` (head ellipsoid x, y, z), `brow` (0..1; a hawk's 1). `head_yaw` here is dead
  data: the limit is `Face`'s.
- Proportions are estimates `[E]` tuned by eye; the sourced parts are the contrasts (the owl's big head and long
  hidden neck, its reversible toe, the measured leg bones). The tables in `body_rig_plan.html` section 5 and
  `body_anatomy.md` 8.4 are stale: the code is the truth.

## Head size and shape

- **About 1.2x life** (crow 0.06 L, hawk 0.065, falcon 0.07, sparrow 0.08), the owl at life size (0.15): heads at 2x
  life forced stubby beaks (`eyes_and_beaks.md` 4.1 option A). Readability from the chase camera, real proportions
  for the bill.
- Skulls (`eyes_and_beaks.md` 4.2): crow long (0.88, 0.9, 1.15), hawk flat-crowned (1.0, 0.88, 1.08), falcon
  (1.0, 0.95, 1.02), sparrow round, owl flat-faced (1.0, 1.05, 0.7).
- The head mesh (`BirdRig._head_point`): the skull ellipsoid, plus `Face.snout` (the front drawn out to the bill's
  base; `bills.md`) and the owl's disc. It's lofted round a neck axis tipped back (`NECK_TILT`), the ring high on the
  nape (no notch behind the head) and just under the bill at the throat (`NECK_THROAT`; lower, the throat curled in
  and the head looked thrust forward).
- Brow (hawk, falcon): a squashed sphere over each eye, in the head's colour and feather texture (a bare blob read
  wrong).

## The neck

- Three bones from the neck base, solved as an S (lower bone forward, middle back up), reach clamped to 2.95 bones.
- Head target (`_neck_target`): retracted, up and along the body's own forward axis; reaching, level ahead in the
  world. (Placed in world terms, an upright owl's retracted head sat off its nape.) **`Saddle._heads()` duplicates
  this formula**: change both.
- The surface doesn't follow the bones -- "the feathers smooth over the vertebrae's S": `_loft_neck` lofts between
  the trunk's open front ring and the head's own ring (the same vertices and colours), each line a cubic leaving
  and entering along the surfaces. Seam rules (`test_neck_seam`): flush (under 10 deg), normals equal (1 deg), no
  nape notch, the perched throat not dipping, head colours handed over along the neck's middle, head texture at
  full strength by the ring. The GPU loft (`neck_place.gdshaderinc`) mirrors it (`gpu_test_neck`).
- Neck extension by state: perched 0.05, flight `neck_flight`, landing eases to 0.25, at least 0.85 for 0.3 s after
  take-off. The head is stabilised in the world (lags the trunk, capped at 0.1 L perched / 0.05 L flying).

## Eyes and gaze (`scripts/bird/face.gd`, `eyes_and_beaks.md`)

- An eye is a lens cap (only the cornea shows; the globe isn't built), domed 0.25 er, vertex-coloured rings: pupil,
  iris, eye-ring (bare skin -- the falcon's yellow), dark lid rim.
- `Face.DATA[id].eye`: `r` (head radii), `az` / `el` (the optic axis: crow 62/14 from Itahara's Large-billed Crow,
  owl 31/8 Barn Owl, the rest `[E]`), `back` (degrees further round than the axis, so the eye sits as far behind the
  bill as in the photo; `Face.eye_seat`). The eye faces out from its seat -- a cap turned off the surface sinks into
  it on one side. Eyes sit at 0.97 hr on the unscaled skull; the owl's are fixed in its disc.
- Also per species: `iris`, `pupil`, `pupil_frac`, `ring`, `ring_w`; `head_yaw` (crow, sparrow 150; hawk, falcon 130;
  owl 135 -- live barn owls measured past 180), `head_pitch`, `fix_s` (mean fixation), `sac_speed`, `blink_pm`, `disc`
  ("heart", the owl), `cere_col`, `bill`, `bill_tip`.
- Gaze: log-normal fixations (sigma 0.5; Ochs), halved in flight; saccade time = amplitude / `sac_speed`; a saccade
  over 17 deg blinks with p 0.75 (Yorzinski); idle perched birds scan +-35 deg yaw.
- **Owl's disc** (`Face`, `_head_point`): a heart outline from 0.65 r above the head's centre (on the forehead) to 0.8 r
  below, raised into a ruff at the rim and wrapping back onto the head -- part of the head surface, not a mask (the
  first one sat low, "a face plate on a brown dome"). Pale to the forehead, no dark band under the chin (`test_face`).

## Legs and feet (`scripts/bird/leg_rig.gd`, `docs/design/legs_and_feet.md`, `docs/research/legs_and_feet.md`)

- Bones in `BodyShape.DATA.legs`, measured: **tibiotarsus 1.3-1.9x the tarsus**, so a perched bird's ankle hangs
  below its belly (the old rig's tarsus was too long everywhere). Femur 0.09 L for all (hidden; places the knee).
- `LegRig.SPEC[id]`: `skin`, `claw`, `trouser` ("" = the body's colour), `feathered` (ankle | foot), `flag` (trouser
  overhang: hawk 0.22, falcon 0.15), radii `thigh` / `shank` / `tars_r`, `toe` (middle toe 0.075-0.09 L; old toes
  were 30-40% short), `toe_r`, `claws` [I, II, III, IV] (Fowler 2009 family ratios), `arc` (owl 95 deg least hooked,
  falcon 118), `pads` (joint: raptors; bone: perchers) + `bulge`, `scutes` (0 = reticulate: the falcon), `bristles`
  (owl), `pad_r`, `curl`, `toe_len`, `end_r`.
- Toes II, III, IV, I at headings -36, 6, 50, 190 deg; phalanges 2/3/4/5. The owl is semi-zygodactyl: its outer toe
  swings back (125 deg) as it grips; only the owl.
- Perching: pad on the bark; each toe curls in its own plane onto the branch's ellipse, claw tip onto the bark;
  hips ride `POSE.stance` x reach above the branch (0.78; the owl 0.68, or its long legs leave the trunk at the tail).
- Tucked in flight the foot turns with the tarsus into a fist, toes trailing (level in the body, they looked on
  backwards); the knee pole swings from world to body frame past the side (else the owl's legs flipped through its
  back in a flare).
- Every join is an edge loop on the surface it leaves (trunk -> trousers -> hem = tarsus ring -> pad; toes -> pad;
  toe -> claw one tube). Scales are baked (`ScaleTile`, `leg_skin.gdshader`). Legs are GPU-skinned: they cost 3.9 ms a
  bird a tick when first built -- measure (`probe_legs`).

## Poses (`BirdRig.POSE`, `scripts/app/rig_poses.gd`, `body_poses_and_folded_wings.md`)

| | perch pitch | ground pitch | tail down |
|---|---|---|---|
| Sparrow | 25 | 10 | 15 |
| Crow | 35 | 10 | 20 |
| Hawk | 60 | 30 | 5 |
| Falcon | 65 | 35 | 5 |
| Owl | 72 | 45 | 5 |

Angles are `[E]`, to tune against photos; the sourced contrast is upright raptors and owls vs horizontal crows and
songbirds. `Bird` copies perch and ground pitch into the game. Driven by telemetry: neck, fluff (sleeks with speed),
breath (0.3/sqrt(L) Hz), tail pump after touchdown, the touchdown dip, the feet reaching on the landing's clock. The
drawn attitude turns at most 400 deg/s (no one-tick snaps: `probe_pose_jerks`). `RigPoses` (glide, flap, upstroke,
folded, flare) sets controls directly for the gallery; folded puts each foot to its own side (legs crossed once).

## Tack fit (`scripts/tack/`)

`Tack.fit(rig, bird, pods)`; the species must be in `Tack.RIDDEN`. The rider is 8.5 cm (1:20.6), the largest all five
carry (`probe_rider_scale`; at 9 cm the owl fails). The saddle is laid out on `BackSurface` (the BodyShape rings as
z x arc from the spine), above 50 deg round the trunk (wings reach ~35), panels narrowing on narrow backs, the seat
behind the shoulder (or the head, where it rides over the shoulders: the owl), mounts raised until every line of fire
clears the head by 0.35 head_r. The rider stands or kneels by the back's tilt. A new body must pass `test_tack`
(pad on the trunk never in it, straps flat, no wing feather in the saddle space, the head missing the launcher and
rider, lines of fire clear). `HeadShape` is the rider's head, not the bird's.
