# Numbers and the wing planform

## BirdProfile (`scripts/flight/bird_profile.gd`)

One static preset per species (`crow()`, `owl()`, `hawk()`, `falcon()`, `sparrow()`), listed in `IDS` and `by_id`.

**Set by hand (the readable numbers):**
- `id`, `display_name`, `blurb` (menus).
- `mass` (kg); `wing_area` (m^2, both wings plus the body strip, spread); `span` (m) -- written as `sqrt(AR * S)`:
  choose the aspect ratio and area, the span follows; `oswald` (e); `glide_ratio` (L/D max); `cl_max` (with the alula:
  the stall); `body_length`, `tail_length` (m; looks, collision, the WingShape shoulder and body width, the bullet
  hit radius `max(0.6 body_length, 0.25 span)`).
- Handling: `max_bank_deg`, `roll_rate_deg`, `alpha_rate_deg`, `alpha_push_deg`, `alpha_pull_over_deg`, the tuck's
  `fold_area_cut` / `fold_span_cut` / `fold_drag_cut` (only the falcon deepens it).
- Flapping: `flap_period` (fastest beat, s), `downstroke`, `flap_accel`, `flap_speed_cap` (thrust fades as
  (1 - v/cap)^2), `flap_tilt_deg`, `flap_tilt_slow_deg`.
- Energy: `burst_max`, `burst_regen`, `stamina_flaps`, `stamina_regen_glide`, `stamina_regen_perch`, `weak_flap`.
- Ground effect, perching: `grab_radius`, `grab_speed_factor`, `hop_speed`.

**Derived -- never set** (`derive()`): AR = b^2/S; K = 1/(pi e AR); CD0 = 1/(4 (L/D)^2 K) (so L/D max is exactly the
glide ratio); CL_alpha = 2 pi AR/(AR+2); CL* = sqrt(CD0/K), alpha* = CL*/CL_alpha, alpha_stall = CL_max/CL_alpha;
V* = sqrt(2mg/(rho S CL*)), V_stall likewise with CL_max (rho 1.225); glide angle atan(1/(L/D));
`grab_speed_max` = factor x V_stall; ground effect height max(1.5 m, 1.5 span). Change an input: call `derive()`.

**The design inversion** (`bird_aerodynamics_by_species.md` section 3): pick L/D and CL* for feel, keep AR near the
real bird's, let e absorb body and tail losses (0.55-0.65 is legitimate for small birds and the falcon). Sources:
section 4a (the proposed-profile table the code copies), 4b (flap period, bank, roll and pitch rate), section 2
(real species), section 1 (Tucker & Heine's Harris' hawk L/D 10.9, CL max 1.6; Mills' peregrine AR 8.49);
wingbeats from Pennycuick 2001 (~15%). Estimates are good to about +-25%.

## The tests that hold it

- `test_bird_profiles` (every species): polar L/D at CL* = glide ratio within 0.01; CL* x0.8 and x1.2 both worse;
  v* > 1.1 v_stall; alpha* < 0.85 alpha_stall; glide angle < 12 deg; v_stall < catch speed < 1.2 v*; neutral stick =
  alpha*; full pull past the stall, full push below 0; the tuck cuts drag. Between species: glide hawk > crow >
  sparrow; the owl stalls slowest; the falcon is the most wing-loaded of falcon, crow, owl.
- `test_glide_trim`: launched at 0.8x and 1.6x v*, 25 s at neutral stick: on the glide path within 0.2 deg, at v*
  within 8%, not stalled, steady.
- `test_wing_shape`: drawn half-span = span/2 within 1%, area within 3%, AR within 4%; folded under 0.45 of the
  half-span; bone lengths fixed through the fold; the longest primary is the one named; arm:hand falcon < crow <
  hawk; hawk 5 slots, falcon 0.
- **Don't loosen these to make a tuning pass.** The polar is exact by construction, so integration errors show as
  glide-angle error (an unsplit lift rotation steepened every glide ~0.6 deg).

## The five species (as coded)

| | Crow | Owl | Hawk | Falcon | Sparrow |
|---|---|---|---|---|---|
| mass kg | 0.55 | 0.8 | 1.2 | 0.8 | 0.06 |
| S m^2 | 0.16 | 0.22 | 0.28 | 0.107 | 0.018 |
| AR / span m | 5.8 / 0.96 | 5.5 / 1.10 | 6.0 / 1.30 | 8.0 / 0.93 | 6.0 / 0.33 |
| e | 0.82 | 0.89 | 0.89 | 0.63 | 0.55 |
| L/D (glide) | 10 (5.7 deg) | 9 (6.3) | 12 (4.8) | 10.5 (5.4) | 6.5 (8.7) |
| CL max | 1.7 | 1.9 | 1.6 | 1.4 | 1.5 |
| V* / V_stall m/s | 8.6 / 5.7 | 8.3 / 5.5 | 9.9 / 6.5 | 12.6 / 9.2 | 8.2 / 6.0 |
| wing loading N/m^2 | 34 | 36 | 42 | 73 | 33 |
| body / tail m | 0.45 / 0.18 | 0.38 / 0.12 | 0.55 / 0.22 | 0.42 / 0.16 | 0.15 / 0.07 |
| bank / roll deg/s | 80 / 320 | 75 / 180 | 65 / 120 | 85 / 240 | 85 / 420 |
| flap period s | 0.28 | 0.4 | 0.45 | 0.2 | 0.1 |

The same table is in `docs/design/flight_model.md` section 8 (plus the climb trim per bird, section 1): keep them in
step. Read the code for the current values before quoting them.

**Gameplay departures, on purpose** (`bird_aerodynamics_by_species.md`): the sparrow's mass doubled (0.06 vs 0.03 kg)
and span scaled to read in a tree arena, its L/D raised from 4-6 to 6.5 "so gliding is not a brick"; the falcon's
wing loading raised (~7.5 kg/m^2 vs ~5.9) to set it apart; the owl a barn owl / great horned blend; the hawk a scaled
red-tail. Catch speed is far above real landing speed (1.15-1.3 x V_stall). To speed the whole game up: scale
every mass by k^2 with S fixed (speeds scale by k, glide angles stay).

**Species behaviour to watch:** the sparrow's beat lifts more than its weight when slow (why the climb trim has
`CLIMB_ALPHA_MARGIN`); a 0.1 s beat quantizes at 60 Hz (duty 0.57); the falcon's high stall makes landing hard (the
AI falcon can't yet land on the race rail) and its turning circle is its weakness in the canopy. Changing roll rate
or stall changes the combat AI's style (`CombatStyle`) and the race courses (planned on the birds' envelope):
re-check them.

## The wing planform (`scripts/bird/wing_shape.gd`)

Top-view plane of the right wing, x outboard, y aft. Three bones whose angles come from `fold` alone (elbow and
wrist coupled as by the radius/ulna: humerus 30->80 deg, forearm -25->-165, hand 8->92). Feathers are defined on a
bone as (bone, t, rel angle, length, width).

`DATA[id]`: `arm` (humerus, forearm, hand as shares of the half-span), `pmax` (longest primary), `longest` (which:
p7-p9), `cin` / `cout` (how fast primaries shorten inward / outward, `primary_shape`), `slots` (emarginated outer
primaries: they splay with `slot`, drawn from a notched mesh), `nsec` (secondaries, 9-14), `tail_shape` (fan,
rounded, notched, narrow; anything else draws square), `tail_fan` (resting deg, to `TAIL_FAN_MAX` 100 -- the widest
12 feathers a fifth as wide still close), `vestigial10` (the sparrow's p10 at 0.18).

**Calibration** (`calibrate`): fits `scale` (tip at span/2) and `chord` (2 x outline + body strip = `wing_area`). The
drawn wing *is* the flight model's wing: never hand-tune scale or chord.

| | Arm : hand | Longest | Tip | Slots | Secondaries | Tail |
|---|---|---|---|---|---|---|
| Hawk | 4.1 : 1 | p7 | rounded | 5 | 14 | broad fan |
| Owl | 3.9 : 1 | p7 | rounded, soft | 4 | 14 | square |
| Crow | 2.9 : 1 | p8 | blunt | 4 | 11 | rounded |
| Falcon | 1.9 : 1 | p9 | pointed | 0 | 10 | long, narrow |
| Sparrow | 2.4 : 1 | p7 | short, rounded; p10 vestigial | 0 | 9 | notched |

Choose from the wing classes in `wing_shapes_and_articulation.md` section 1 (elliptical, high-speed, high-AR soaring,
slotted high-lift, with AR and loading ranges); primary attachment (p1-6 carpometacarpus, p7 minor digit, p8-10 major)
in `wing_anatomy.md` section 4. Mind AR conventions across papers. `docs/design/wing_rig.md` (species table) and
`wing_rig_plan.html` repeat these: keep them in step.
