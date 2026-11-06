# Flap: flight model design (v0.1)

This doc covers the flight model, the energy model, catching and releasing perches, how perches sit in space, the arena and its flight paths, and the AI pilot.
Research behind it is in `docs/research/`:
- `flight_simulation_models.md`: arcade vs point-mass vs 6DOF, plus the recommended hybrid.
- `bird_aerodynamics_by_species.md`: species data and the derivation of each profile.
- `wing_shapes_and_articulation.md`: wing classes, joints, perching, and the greybox rig.

Goal: flight that feels natural and is easy to pick up, not maximum realism.

---

## 1. The flight model (`scripts/flight/flight_model.gd`)

**Model: a point mass with an attitude state.** There are no rigid-body torques. The bird's attitude is two numbers measured against its own flight path:

| State | Meaning | Driven by |
|---|---|---|
| `alpha` | angle of attack: how far the nose sits above the flight path | stick Y, slewed at `alpha_rate` |
| `bank` | roll about the flight path | stick X × `max_bank`, slewed at `roll_rate` |
| `fold` | wing tuck, 0 (spread) to 1 (tucked) | push past half stick, plus auto-sweep with speed |

The research recommends this hybrid. Because attitude is defined relative to the velocity, the bird is **always coordinated**: it never sideslips, never tumbles, and needs no rudder.

**Forces.** Each tick (60 Hz) applies these:
- Lift: L = q·S·CL(α), along the lift vector. The lift vector is perpendicular to the path and tilted by `bank`.
- Drag: D = q·S·(CD0 + K·CL² + stall drag), opposite the path.
- Gravity.
- Flap thrust, during a downstroke only.

Here q = ½ρv². CL rises linearly up to the stall angle, then sags to 65% of its peak over the next 10°, while drag climbs sharply.

**The derived polar is exact.** Designers set mass, span, area, Oswald efficiency e, glide ratio L/D, and CL_max. `BirdProfile.derive()` computes the rest:
- K = 1/(π·e·AR)
- CD0 = 1/(4·(L/D)²·K), which makes L/D max equal the designed glide ratio exactly
- CL* = √(CD0/K) and α* = CL*/CL_α
- V* = √(2mg/(ρ·S·CL*)) and V_stall = √(2mg/(ρ·S·CL_max))
- glide angle = atan(1/(L/D))

`test_glide_trim` checks that every bird settles onto its ideal glide slope to within 0.2°, from both too slow and too fast.

**Controls map to physics:**
- **Neutral stick = best-glide α.** Let go of the mouse and the bird settles onto its ideal glide slope; the virtual stick drifts back to centre. The HUD's pitch ladder marks the ideal glide line, and the flight-path circle turns green when you're on it.
  - **With flap held, neutral stick climbs** instead: it eases over to the climb trim and back when you stop (see "Flapping trim" below).
- **Pull back:** more CL, so the path curves up while induced drag bleeds speed. This gives the speed penalty you described. At 85% pull the wing reaches its stall angle. The last 15% of travel is the flare: post-stall, a big airbrake. The HUD stick box marks that line.
- **Push forward:** less CL, so the path drops and speed builds. Past half push the wings tuck, reducing area, span and parasitic drag. That's the falcon stoop.
- **Bank-and-yank:** bank tilts the lift vector, which turns the path. Pulling in a bank tightens the turn: turn rate ω = n·g·sin(φ)/V, verified in `test_flight_controls`.
  - Bank limits are per species, from 65° (hawk) to 85° (falcon, sparrow). The HUD shows them as red ticks.
  - `turn_assist` supplies 60% of the extra lift a bank needs, so a pure bank doesn't sink much.

**Assists that make it feel easy.** Set any of these to 0 to turn it off.
- `pitch_damping`: a phugoid damper. Without it, speed and height trade back and forth ("the bob") for half a minute.
  - It feeds the unpowered along-path acceleration back into α. That works out to about 0.7 of critical damping.
  - Feeding back the path's rate of change instead only changes the bob's stiffness, and it chatters at 60 Hz. We tried it; the test caught it.
  - With flap held, the wingbeat's mean thrust along the path is added in, so a steady flapping climb reads as steady. Without it the damper took that climb for speed bleeding away and held the nose about 5° low, so flapping flew fast and shallow.
- `turn_assist`: described above.
- `auto_sweep`: the wings tuck up to 35% by themselves at twice best-glide speed. Gliding pigeons do this (wing research).
- Stall **hysteresis**: the stall sets in past the stall angle and only ends once α is clearly back below it.

### Flapping trim (`FlightModel.climb_alpha`, `best_climb`)

Gliding, neutral stick holds best glide (α*): the flattest path, the most distance per metre of height. With flap held you're adding energy, and the intent is to go up, so neutral stick holds the efficient climb instead. This is part of the stick mapping, not an assist: there is no switch. Full pull and full push are the same as ever; the travel between them is laid out from whichever trim is current.

**Why not just keep α\*?** At cruise a wingbeat's thrust tilts 30° up from the path (65° when slow), so part of it is lift. At α\* the wing then has more lift than it needs, and the bird slows until it doesn't. The crow ends up at its stall speed, and the falcon just under it. The sparrow, whose wingbeat lifts more than its weight when slow, tips into a stalled, near-vertical hovering climb. Before this change, flapping at neutral flew fast and shallow instead (crow 2.1 m/s up at 12 m/s), but only because the phugoid damper misread the thrust (see `pitch_damping` above).

**Which climb.** There are two classic choices:
- the steepest climb (best angle, Vx), for clearing an obstacle;
- the fastest climb (best rate, Vy).

A real bird's muscle power is roughly flat with speed, so its fastest climb is at the minimum-power speed Vmp, about 0.76 of its max-range speed (Pennycuick). Here, a held wingbeat spends one burst flap per wingbeat period whatever the bird does. Height per flap is therefore climb rate × period, and the fastest climb is also the most efficient. Best angle is at the slowest speed, which in this model means the stall and the hover, so it stays a pull away.

This model's thrust isn't constant power: T = A·(1 − v/cap)², so its Vy isn't the polar's Vmp. `best_climb()` works it out from the model itself. Per kg, a steady flapping flight at airspeed v holds:

```
T̄ cos θ − D/m = g sin γ          L/m + T̄ sin θ = g cos γ
T̄ = A · strength · duty · (1 − v/cap)²
θ = tilt(v) − (1 − min(1, v/v*)) · γ      (slow thrust is aimed from the heading, not the path)
L = q S CL,  D = q S (CD0 + K CL²)        (the auto-sweep's tuck included)
```

- `duty` is the share of ticks that drive. The downstroke and the beat each round up to whole 60 Hz ticks, so the sparrow's is 4/7.
- `steady_flapping(v)` bisects for γ and reads off α = CL/CLα.
- `best_climb()` scans v and keeps the fastest climb v·sin γ that is:
  - no slower than `CLIMB_MIN_SPEED` × v\* (1.0);
  - on the stable side, where a slower speed needs more α, so slowing drops the nose;
  - under `CLIMB_ALPHA_MARGIN` (0.9) of the most α any slower steady flight needs. Past that the sparrow tips into its hovering climb.

It is worked out once per set of numbers, in about 20 ms.

**Why floor it at best-glide speed?** The unconstrained Vy is slow, at 1.0–1.3× stall speed. In a test build with the trim at Vy:
- letting go dived the bird to the edge of the stall (the owl to 0.92×);
- the combat AI, which flaps when it's slow, stayed slow and flapped itself out (test_combat_team's birds rested 300 of 400 s).

At v\* the climb is only 2–9% slower, the bird flaps at the speed it glides at, and letting go is a gentle nose-over back to the glide.

**Easing.** `flap_trim` follows the held wingbeats' strength with time constant `FLAP_TRIM_TIME`, 0.4 s, both ways. Neutral α is lerp(α\*, `climb_alpha`, `flap_trim`). The nose moves at under 25°/s at the first wingbeat and on letting go; a jerk would slew it at 135–210°/s. A weak, tired wingbeat (an empty burst, strength about 0.2) trims only that share of the way: its best climb is near the glide's. The damper adds the same share of the wingbeat's mean thrust along the path.

| | Crow | Owl | Hawk | Falcon | Sparrow |
|---|---|---|---|---|---|
| Best glide α\* / v\* | 9.2° / 8.6 m/s | 10.6° / 8.3 | 8.5° / 9.9 | 8.6° / 12.6 | 9.7° / 8.2 |
| **Climb trim α / speed** | **6.0° / 8.6 m/s** | **7.5° / 8.3** | **6.5° / 9.9** | **5.8° / 12.6** | **4.6° / 10.1** |
| Climb trim: climb rate (path) | 3.35 m/s (22.9°) | 2.71 (19.2°) | 2.66 (15.6°) | 4.70 (21.9°) | 3.06 (17.6°) |
| Fastest climb Vy (≥ 1.2 V_stall) | 3.41 at 7.3 m/s | 2.91 at 6.8 | 2.92 at 8.0 | 4.83 at 11.1 | 3.02 at 10.1 |
| Flown at neutral (`test_flap_trim`) | 3.37 at 8.7 | 2.72 at 8.4 | 2.67 at 10.0 | 4.78 at 13.0 | 2.86 at 10.4 |
| Before (damper misreading thrust) | 2.08 at 12.3 | 1.51 at 11.1 | 1.70 at 12.6 | 2.91 at 17.7 | 1.37 at 12.2 |

The sparrow's trim is set by the hover margin, not the floor: its stable climbs start at about 7.8 m/s. A small pull while it flaps (0.12 of the stick) still tips it into the hovering climb, which is the sparrow's own wingbeat, not the trim.

`test_flap_trim` flies each bird from a settled glide:
- flap held at neutral climbs at the predicted rate, no slower than v\*, never stalled and never under 1.2× stall speed;
- a little pull flies slower, and a little push faster and shallower;
- flapping in a 45° bank, left and right, stays on the wing;
- the nose eases over both ways;
- letting go never stalls and returns to the ideal glide slope;
- on its own burst it climbs 12–23 m in 15 s and the trim slides back as the wingbeats weaken.

**Integration.** Semi-implicit Euler. Lift is applied as a speed-preserving rotation of the velocity, which keeps it stable at low speed. The rotation is split half before the linear forces and half after (Strang splitting); applying it all first steepened every glide by about 0.6°. Drag can remove at most half the speed in one tick. Aero forces fade out below 2 m/s, for example when dropping off a perch.

**Wing area for the HUD.** It's already computed: press F3. Two numbers:
- `wing_area_eff`: the planform area after the tuck. It's the lifting area, and it shrinks in a stoop.
- `frontal_area` = S_eff·|sin α|: the wing area facing the oncoming air. It's near 0 in cruise and large in a flare, so it reads as airbrake.

The research suggests labelling these "lifting area" and "airbrake area" in the full HUD.

### Moving air: thermals and ridge lift (`scripts/flight/air_field.gd`)

The air has its own movement (`AirField.at(p, t)`, the arena's `layout.air`): the bird is flown through it. Each tick
`FlightModel.step` works in the air's frame -- the velocity through the air is what the wing feels, so airspeed,
the angle of attack, the lift vector and the body all follow the air -- and the air's own velocity is added back to
carry the bird over the ground. A bird in air rising at w keeps its glide through the air and rises with the air:
in a thermal stronger than its sink rate (a crow's is about 0.7 m/s at best glide, more in a turn) it climbs.
`path_angle` and `flight_dir()` are over the ground (what the HUD shows and the AI steers by); `speed` is airspeed.

- **Thermals** (Pinewood: over the clearing 2.6 m/s, the glade 2.0, the gaps 1.0, each about as wide as its opening):
  a bell-shaped core (exp(-2 (r/R)^2)) ringed by gently sinking air; weak below treetop height (the warm air still
  gathering: birds landing on low limbs aren't thrown about), full above it, dying away at the top; bubbles pulse
  it by +-25% every 18 s. A crow circling about 8 m round in the clearing's core gains about 16 m in 20 s where it
  would lose 24 in still air (`test_air`).
- **Ridge lift** (`add_ridge(top edge a..b, outward face normal, height, lift)`): rising air in front of a cliff and
  over its edge, strongest a quarter of the height out and up to about the height above the top; none in the lee
  nor past the face's ends. Ready for the cliff in the new setting.
- **Seen**: `AirFx` draws fluff rising in each thermal (and up a ridge's face); the HUD says LIFT / SINK and the
  bird's climb when the air moves more than 0.3 m/s.
- `--calm` turns it off. The combat AI doesn't read the air yet (its aim and stoops reckon on still air: over 16
  woods the thermals cost the hawk about a quarter of its hits), so the range and the duels fly in still air
  (`CombatWorld.calm_air`) until it does.

## 2. The energy model (`scripts/flight/energy_model.gd`)

There are two reserves, so you can't flap forever and can't flap infinitely fast.

| Reserve | Scale | Spent by | Refills | Effect when low |
|---|---|---|---|---|
| **Burst** (short term, about 5–8 s of held flapping) | full-strength flaps (crow: 16) | 1 per flap; hard pulls over 2 g also drain it | `burst_regen` flaps/s whenever the wings aren't driving; scaled by stamina; doubled when perched | under 1 flap left, flaps are weak (25% strength) |
| **Stamina** (medium term, about 1 minute of flapping) | 0 to 1 | 1/`stamina_flaps` per flap, doubled on an empty burst | slowly while gliding (0.4%/s), fast while perched (8%/s) | caps the burst at 30% to 100% of max, and slows burst refill to as little as 5% |

**Hard caps on flapping:**
- **Rate:** a wingbeat can't start before the last one finishes (`flap_period`: sparrow 0.1 s, hawk 0.45 s).
- **Speed:** thrust fades as (1 − v/flap_speed_cap)², so flapping has a natural top speed. Diving does not.
- **Direction:** at a standstill a wingbeat mostly lifts (65° up from the bird's heading, which makes takeoff work). At cruise it mostly drives forward (30°). Slow thrust is aimed from the heading, not the flight path. That keeps a slow bird from flying straight up like a helicopter.

**Gameplay loop this creates.** Flap to climb and sprint. When tired, glide to a perch to rest: about 10 s on a perch restores most stamina. So the game is flying from perch to perch, which is what you described.

The HUD energy bars show:
- burst (yellow)
- the part of the burst lost to fatigue (dark red)
- stamina (blue)

`test_energy` checks each of these behaviors for every species.

**Long term (not built yet).** A third, "fed" reserve that caps stamina, refilled by food or kills, could carry the combat loop.

## 3. Catching and releasing perches (`scripts/bird/bird.gd`)

Flap and catch are separate controls:
- **Flap:** Space, or the gamepad's left trigger.
- **Catch:** Ctrl, or A.

You **hold catch** through the approach, and the bird catches the moment a perch is in reach and slow enough. Flying and catching no longer compete for one button.

```
FLYING --CATCH held, perch in reach and slow enough--> LANDING (blend, 0.15–0.45 s) --> PERCHED
PERCHED --FLAP--> FLYING (push off the way you face, free wingbeat)
PERCHED --CATCH (a fresh press)--> FLYING (let go: drop off the way you face, no wingbeat)
FLYING --settle slowly onto anything flat--> GROUNDED --FLAP--> FLYING (jump up, free wingbeat, ground effect)
```

**Perched or on the ground, the steering stick turns the bird** (150°/s at full stick) so you can look around. Its pitch tilts the camera. The bird leaves the way it faces.

**Leaving along a branch.** If you've turned to face along the branch, the bird would drop onto it. To avoid that, the bird passes through its own tree for 0.35 s after leaving.

**Takeoff grace.** For 0.5 s after taking off, touching down doesn't count as landing. That stops the take off, touch, re-land loop that used to trap AI birds on the ground.

- **Landing point.** The **aim point**: the grip point closest to the bird's line of flight. The path straight ahead is checked out to 2.5 catch radii, and the aim point is where that path passes closest to the branch's grip line (or the treetop's disc). It is the spot you're flying at, not the spot nearest your body.
  - The highlight lights the whole grip line and puts the ring on the aim point.
  - Flying across a branch, you land where your path crosses it.
- **Catch area: an envelope that follows the relative motion** (`Perch.in_reach`), not a sphere. The feet swing forward and down from the flight line, so the envelope's reach depends on direction, where R is `grab_radius` (1.5 m for most birds, 1.0 m for the sparrow):

  | Direction | Reach |
  |---|---|
  | Ahead | up to R × (1 + 0.4 × speed / catch speed): a faster bird starts its flare earlier |
  | Sideways | about 0.55 R, narrowing further out |
  | Below the flight line | 0.9 R |
  | Above the flight line | 0.35 R |
  | Behind | nothing |
  | Hovering | a small sphere of 0.6 R |

  Above and below are measured from the **flight line**, not the world. A bird swooping up carries itself to a perch above it, but a glide that passes under a perch misses it.

  If a further perch is in reach, it wins over a nearer one that isn't.
- **Catch speed.** Speed must be ≤ `grab_speed_max` = `grab_speed_factor` × V_stall. That works out to about 6.8 m/s for the crow and 10.6 m/s for the falcon.
  - Every bird's catch speed sits between its stall speed and its best-glide speed. Coming in at glide speed is slightly too fast, so you have to flare a little. That's the skill: dive under the perch and swoop up into it, the way hawks do.
  - The HUD speed tape has a cyan "catch" mark.
- **Feedback.**
  - A ring on the candidate perch: white while approaching, **green** when catch will catch now, **red** when the perch is in reach but you're too fast.
  - Prompts:
    - "perch ahead – hold CTRL/A to catch", or "catch armed" once you're holding it
    - "CTRL/A: CATCH"
    - "TOO FAST – pull up"
  - Audio: you hear a falling whoosh as you drop under catch speed (section 7).
- **Forgiveness.**
  - **Hold to catch:** catch can be held the whole way in.
  - **Tap buffer:** a quick tap stays live for 0.25 s, so a tap a touch early still catches.
  - **Perch assist** (`perch_assist`, default 0.6) works in the last 5 m: it auto-flares when closing faster than 85% of catch speed, and pulls the bird gently onto the perch line.
- **Transition: the flare.** A cubic Hermite blend runs from the bird's position and velocity to rest at the seat over the aim point.
  - **Timing.** The landing lasts 2 × distance / speed (braking evenly), clamped to 0.3–0.8 s.
  - **Body.** It pitches up into the flare, peaking at 55° about two-thirds of the way through. Meanwhile it turns to face across the branch toward the side it came from, so its feet wrap the branch. On a treetop it faces the way it was flying. Finally it settles to the perched posture.
  - **Rig.** Two braking wingbeats with the wings swept forward at a high angle of attack, alula out, tail fanned and pitched down, feet reaching for the grip point. In the last fifth the wings start to fold.
  - **Perch assist.** It starts 6 m out. It flares when the bird is closing faster than 80% of catch speed, and steers the flight line toward where the body will sit, just above the grip.
  - **Lift through the flare.** A flaring bird holds its lift near its weight, topped up by up to 1.6 × CL max, so it brakes without dropping. Perching studies see no lift spike and no sag.

  Before/after: `docs/images/landing_before_after.png` (`scenes/landing_reel.tscn`). The rig spreads the wings forward, fans and drops the tail, and swings the legs forward.
- **Release.**
  - The bird leaves the way it faces at `hop_speed` (2.5–3.5 m/s): about 6° down when it takes off with a flap, 20° down when it lets go.
  - It starts clear of the branch.
  - Flap gives one free wingbeat.
  - It can't re-catch the same perch for 0.6 s.
- **Collisions.**
  - Trunks and branches, from the side (at most 40 deg off along the surface, at any speed, not on the back): a **glance**. No stun; the speed into the wood stops, the claws drag 0.4 x that off the speed along it (a hard side hit costs a lot), the legs push off (0.3 x hop speed) and the bird steers away for 0.35 s (`glance_assist`). The feet strike the bark (the rig: `brace` / `glance` telemetry, the claws on the wood) and the claws scrape (`claw_scrape`).
  - Squarer: a **bonk**. 0.18 of the speed into the wood comes back out, the speed along it loses 0.6 x the hit, and the stun grows with the hit, 0.1 s at 1 m/s into it to 0.35 s at 9 (about head-on at cruise). Touches under 0.4 m/s into it (under 1 m/s, squarer) just slide.
  - **Wings** strike too: each, shoulder to tip as spread or folded, against the layout's wood each tick; a strike costs 35% of the speed for the whole wing (a tip clip about a third of that), no stun (`wing_struck`, `wing_strike`).
  - **Reflexes** (`Bird._reflexes`: 0.25 s of flight looked ahead at the layout's wood, `ArenaLayout.wood_near` / `first_touch_among`): wood coming from the side, or into a spread wing's reach, pulls the wings in (`tuck_reflex`, `FlightModel.tuck` at 10/s: less lift, it sinks); wood square ahead flares the bird (`flare_reflex`); a novice's bird also rolls away from either at a speed cost (`avoid_assist`, `FlightAssist.AVOID`). None while catching or leaving a perch. Each switches off at 0. `test_glance` checks them all, both sides; `.
un.ps1 --scene res://scenes/bird_lab.tscn --scenario glance_left|wing_clip|head_on` shows them.
  - Settling slowly onto the ground or a trunk top: you stand there (GROUNDED), and flap jumps you up (at least 3.5 m/s upward) with a free wingbeat.

Tests:
- `test_perching` covers hold-to-catch (caught on entering reach), staying perched while still holding, the too-fast refusal, the early tap, the assisted flare, turning on the perch, flap take-off versus catch let-go, leaving along a branch with no bonk, re-catch lockout, and resting.
- `test_ground_takeoff` checks that every species climbs out from standing on the ground, and from a slow skim, using ground effect.
- `test_collision` covers trunk bounces and landing on the ground.

### Ground effect

Within `ground_effect_height` of the ground (1.5 spans, at least 1.5 m), ground effect does three things:
- Induced drag drops by up to 50%.
- Lift rises by up to 25%.
- Wingbeats push up to 80% harder.

All three fade linearly with height. The real effect is smaller. It's exaggerated on purpose so a bird that's down can always flap back up: from standing, every species reaches 7–19 m within 4 s. The HUD shows "ground effect" under the speed tape while it's active.

## 4. How perches are defined in space (`scripts/world/perch.gd`)

A perch is a **grip set**, not a point. There are two kinds:
- **Branch perch:** the grip line along the top of the branch. It runs from 12 cm clear of the trunk's surface to 8 cm short of the tip.
- **Treetop perch:** a grip disc on top of the trunk.

The queries:
- `closest_grip(p)`: the grip point nearest `p`.
- `aim_grip(pos, dir, ahead)`: the grip point nearest the flight path. This is where a bird lands.
- `distance_to(p)`: distance from `p` to the grip set.
- `facing_for(travel)`: which way a bird sits after arriving moving along `travel`. On a branch that's across it, toward the side the bird came from. On a treetop it's the travel direction.

Each perch also keeps a representative `position` (the middle of the line, or the centre of the disc). Spatial lookups and spawning use it. Each also has a default `facing`:
- Branches face across the branch, at a random side.
- Treetops face the arena centre.

Spawning uses the default facing, and so does the AI's approach side. The AI aims at an approach anchor on the outer part of the branch, where there's the most room. The bird still lands where its path meets the branch.

Perched birds can turn freely with the stick. Leaving a perch, the bird passes through its own tree for 0.35 s. That way, facing along the branch can't drop it onto the branch.

Perches are generated with the trees:
- Each tree grows `height / 4.5` branches, spiralling up the trunk between 35% and 88% of its height.
- Each branch carries one grip line.
- Each tree gets one treetop disc.
- Grip lines are drawn as pale strips along the branch tops, and discs on the trunk tops.

A spatial hash on 8 m cells, keyed by each perch's middle and padded by the longest half grip line, serves `perches_near()`. That returns perches by their nearest grip point. Seed 7 gives 137 trees and 375 perches. Most perches are low, with a handful above 20 m.

## 5. The arena and its flight paths (`scripts/world/arena_layout.gd`)

The arena is a circle 85 m in radius. A soft wall pushes birds back past the edge, and a soft ceiling sits at 60 m. Trees are placed by seeded rejection sampling in three tiers, tallest first:

| Tier | Count | Height | Spacing | Role |
|---|---|---|---|---|
| Understory | 90 | 4–9 m | 5.5 m | dense low slalom |
| Canopy | 38 | 10–18 m | 11 m | mid layer, room to turn |
| Emergent | 9 | 22–34 m | 26 m | lone pylons in open sky |

So **trunk density falls with height**: 6.0, 2.1 and 0.4 trunks per 1000 m² above 2, 10 and 20 m.

**Flight paths** are open lanes carved through the lower tiers. They're drawn on the ground as pale strips so you can read them from the air.
- **The clearing:** 16 m radius at the centre. It's open air, and the start perch is the tallest treetop beside it.
- **Two crossing avenues:** 10 m-wide straight lanes. These are the long fast glide lines.
- **The ring:** a 10 m-wide circular lane at 56 m radius. It's free of low trees, but emergents may stand in it, so it's a racing loop with occasional pylons.
- **Above 20 m:** open sky with a few emergent pylons, for altitude, scouting and stoops.
- **The understory:** below 9 m, a dense trunk forest for close-quarters chases.

That gives three distinct altitude bands that play differently. Those bands are where combat will live (section 9).

**The pine wood** (`Pinewood`, the game's default arena) has the structure of an old stand instead of lanes. Its
pines grow in clumps, 5.5 m apart inside one and 13 m in the thin ground between. A noise field about 34 m across
sets where the clumps are. The open ground:
- **The clearing:** 40 m across round the big oak.
- **A sunlit glade:** about as big, 40 to 55 m out.
- **Gaps:** seven smaller ones, 12 to 20 m across.
- **The oaks' glades:** an open space round each oak.

Young pines seed in groups where the light gets in, and bracken grows thicker there too. `test_pinewood` holds
this: no pine stands in an opening, the counts in 16 m squares vary more than a random scatter's, and fewer than a
fifth of the young pines are in shade. `tests/probe_layout_map.gd` draws the plan.

The trees are shaped for perching, with clear branches below the crown that a bird can reach:
- **Oaks** (`Pinewood._grow_oak`, `OAK_FORM`, 2026-11-06): a short trunk that forks low (a quarter of the height).
  The solid trunk stops just above the fork (`TreeData.stem`, `trunk_top()`), so collision and every wood query see
  no pillar up through the crown. From the fork:
  - big scaffold limbs, each in three curved pieces (`_bend`);
  - long low limbs with side limbs, the open perches under the crown;
  - crown limbs that climb from the fork and hold up the top.

  Leaf clouds sit over the crown tips, with rings that close the top. An outpost deck sits in the fork, its way in
  kept clear of the oak's own limbs (`_way_in`, `OWN_BERTH`). The leaves are English oak's (`FoliageTex` `oak_leaf`):
  obovate, lobed, eared at the stalk.
- **Pines:** whorled crowns, with one more whorl and three or four limbs to a whorl on the mature pines and the
  veterans (`_grow_pine`'s `more`), each long limb tufted at its tip.

Oaks, mature pines and veterans each draw from their own random numbers, so a change to one tree's shape moves no
other tree (`probe_wood_print` fingerprints the trees' places alone). `tests/probe_tree_paths.gd` +
`tools/tree_side_map.py` draw a tree's limbs from the side, against a reference photo.

## 6. The AI pilot (`scripts/ai/ai_pilot.gd`, `scripts/ai/flight_planner.gd`)

> **Trunk bumps (closed 2026-11-02).** The AI used to clip trees about once per perch: 25 bumps for 25
> perches in the greybox (seed 7) and 25 for 20 in the pine wood, which `test_ai_flight` let off at 1.3 a
> perch. Three causes: the whiskers didn't fly the turn the bird was really in (a bird in a steep bank, or one
> that needed half a second to roll the other way, saw the trunk too late, and its escape's climb never
> reached the pitch); the planner and the whiskers ignored the tree being left and the one being landed on
> outright (so first legs ran through the bird's own trunk and approaches through the perch tree's limbs);
> and a bird with no route glided on blind. Avoidance now predicts the flight (layer 4 below), and the 1.3 is
> gone (the rule is bumps <= perches again). Seed 7, 90 s: the greybox 35 perches and no bumps (was 25 and 25),
> the pine wood 21 perches and 9 bumps (was 25 and 22 with today's limbs). Over nine arenas (the test's three and
> seeds 3, 11, 21 of each): 256 perches and 38 bumps, against 253 and 154 before. The pine wood alone still
> perches about a seventh less than the old whiskers did (98 against 113 over four seeds): the falcon, which
> used to reach a perch by bouncing off the trunks on the way in, now rarely makes one there at all.
> `tests/probe_pinewood_bonks.gd` lists what each bump hits and what the pilot was doing.

The AI drives a bird with **exactly the player's inputs** (`FlightInput`: stick, flap, catch). While perched, it turns to face its route out before taking off. On final, it holds catch. It sees only the bird's own state and the arena geometry. It works in four layers:

1. **Goal.** Pick a perch it can reach on its energy.
   - Reach = glide reach from its current height, plus a climb budget from stamina and burst.
   - It prefers hops of about 30 m that lose a little height, and perches up in the trees.
   - It skips perches too low for its stall speed, and the tree it just left.
   - Perched, it rests until stamina is back above 50%.
2. **Route.** A* over a free-air lattice (6 m spacing, 7 altitude levels).
   - Nodes and edges are checked against trunk and branch capsules geometrically (`ArenaLayout.segment_clear`); no physics queries.
   - The cost is energy-aware: climbing a metre costs as much as 4 m of flight, and descending is free.
   - The route runs through a **pre-approach point** and an **approach point** out along a **way in**, ending below the perch by the height the bird zooms slowing from cruise to its catch speed (0.7 m for the sparrow, 1.9 for the falcon). The bird arrives lined up and swoops up into the catch. A branch can be come in to from either side across it, square on or 35° off; a treetop from anywhere. A flying bird takes the way it can turn onto soonest (a turn-straight-turn path from where it is), preferring ones it can line up on clear of the wood and whose pre-approach leg is open. Details and measurements: `docs/design/flight_exam.md`.
   - The route is string-pulled (any waypoint the previous point can see past is dropped).
   - The tree it leaves and the one it lands on aren't ignored, just passed closer (0.4 m), leaving out the perch's own branch and the first and last metre (the push-off, the catch). A perch whose swoop in from the approach point crosses its own tree's other limbs gets no route (and is set aside for a minute).
   - Out of a tight spot: deep in its own crown, with another of its limbs near every way out, it leaves through them (it passes through its own tree as it lets go); wedged nearer another tree than its planning berth, the first leg may pass at 0.6 m.
3. **Guidance.**
   - Bank toward the next waypoint (bank-to-turn). The bank limit shrinks near the ground, because steep banks shed vertical lift.
   - Pitch to hold the path angle that reaches the waypoint.
   - Flap when it needs to climb or is slow.
   - Push when near the stall.
   - Bank no harder than the lift holds at this speed (`AIPilot.held_bank`: (v / v_stall)² with a 15% margin); the falcon holds about 51° at cruise.
   - Near the approach point, **line up** on a turn-straight-turn path on the circle it holds, arriving heading in (if it's clear of the wood); the planned route doesn't know which way the bird is flying.
   - Energy: no wingbeats above 1.1 × cruise (above cruise on the approach leg, slowing to it); with more height and speed than the way left can lose, **circle down** first. On final, pull to bleed speed toward the middle of its catch window (stall to fastest catch), holding catch once the target is the bird's catch candidate (the target is held as the candidate, as the novice assist holds the player's).
4. **Avoidance.** It predicts the next stretch of flight the way the bird will really fly it, in 0.1 s chords, and checks them against the geometry (0.6 m clearance).
   - The prediction steers by the guidance law: the bank slews at the species' roll rate (after the stick's lag), only as far as guidance allows at that height, and turns the path at g·tan(bank)/v. The path angle eases toward the one asked for, less what a steep bank sheds. A bird already banked hard, or one that needs half a second to roll the other way, sees what its turn curves into in time.
   - If the route's path stays clear, it flies the route. Otherwise it tries a fan of headings (out to 150° either way), level, then climbing, then sinking, and flies the clear one that ends nearest the way it wants to go. The escape sets the path angle too, so a climb really climbs. If nothing is clear, it takes the one that stays clear longest; if it is hemmed in from the first metre, it keeps to the route (which was planned clear).
   - Coming in to land (within 8 m, or anywhere on the final leg), the perch's own tree counts too, at 0.3 m and without the perch's branch (a rail: without its deck's outer strip). The prediction ends where it passes closest to the perch if the feet can reach it (the catch), so the trunk behind a branch doesn't wave it off. Just after take-off (within 12 m), the tree it left counts the same way, past the first metre.
   - With no route (no perch reachable), it still glides round trunks.
   - A watchdog re-plans if the bird makes no progress for 8 s. It goes around if it overshoots, or if the perch leaves its forward cone on final: out and up, away from the perch's tree, for about a turning circle and a half, then a fresh plan. A perch not reached in 25 s (circling one it can't make the approach to) is given up and left alone for 60 s.
   - Cost: the path is flown first and checked against only the trees whose reach overlaps it. In the pine wood that's about 0.7 ms a bird per tick, against 1.15 ms for the whiskers it replaced.

**Fitted to the bird's turning circle.** The AI computes each species' turn radius at cruise: v*² / (g·tan(85% of its bank limit)).

| Species | Turn radius |
|---|---|
| Hawk | about 7 m |
| Falcon | about 5 m |
| Crow, owl | about 3 m |
| Sparrow | about 2 m |

That radius shapes three things:
- **Planning clearance:** 0.9 m + 0.15 × radius.
- **Perch floor:** birds that turn wider than 4.5 m only pick perches above the 9 m understory. If nothing up there is in reach, they fall back to any perch with a bigger climb allowance.
- **Prediction reach:** the larger of 1.1 s of flight or 1.3 turn radii, plus a quarter second.

The climb budget is scaled by the species' sprint × wingbeat strength, so the hawk climbs less than the crow.

**Recovering low down.** When slow below 6 m, the AI flaps hard along a near-level path with wings nearly level, instead of pushing. It used to push, which flew high-stall birds such as the falcon into the ground. It only flaps on full-strength wingbeats, unless it's recovering.

**Status.** `test_ai_flight` flies all five species for 90 s in two greybox arenas (seeds 7 and 3) and the pine wood; each must touch trees no more often than it perches:

| Species | Seed 7 | Seed 3 |
|---|---|---|
| Crow | 9 | 7 |
| Owl | 9 | 6 |
| Hawk | 7 | 6 |
| Falcon | 3 | 6 |
| Sparrow | 7 | 7 |
| **Flock** | **35** (0 bonks) | **32** (3 bonks) |

and in the pine wood (seed 7, clumped): crow 8, owl 6, hawk 4, falcon 0, sparrow 3; **21** (1 bonk).

Every species must chain at least 4 perches across both arenas.

**Before the fit,** the hawk and falcon managed 0. They were choosing low perches in the 4–9 m understory, where trunks are about 5.5 m apart, but the hawk needs about 7 m to turn. Straight whiskers missed the trunks that a steady turn curved into. Pushing to recover speed near the ground flew the falcon into it.

**Landings planned by speed and turn (2026-11-06).** The falcon perched least by far, worst in the pine wood: its turns at 85% of its bank limit sank it, it came to every final too fast, and the route's corners were tighter than its 13 m circle. The flight exam (`docs/design/flight_exam.md`, `test_flight_exam`) now measures each species on every perch of each kind of tree, rails, heights, groves, hops and gate courses in places of their own; with the changes above every species lands on at least 82% of the attempts in every scene, most on all of them (the falcon was at 11-57% on perches), and the flock in `test_ai_flight` chains 48 and 52 perches in the greybox arenas (was 33 and 34) and 32 in the pine wood with 4 bonks (was 30 and 6; the falcon 4, was 0).

**Why this shape.** The same input surface gives three things:
- AI and players are interchangeable (autopilot is the P key, and a player can take over any AI bird).
- AI behaviour is bounded by the same physics and energy.
- Later, a networked host can run AI the same way. Once networking arrives, the HUD, rig and camera already read only a telemetry snapshot (`Bird.telemetry()`).

## 7. Controls and audio

### Devices (`scripts/bird/player_controller.gd`, `scripts/app/input_setup.gd`)

**Gamepad (recommended).**
- The left stick is the steering stick. It's absolute and springs to centre, so centre is always wings level at best glide.
  - A gentle response curve, v·(0.35 + 0.65|v|), keeps small corrections fine.
  - The deadzone is 0.12.
- The right stick orbits the camera, up to 75° to the side and 35° up or down, and springs back.
- Left trigger flaps; A catches.
- Back cycles the bird, Start respawns, Y toggles the autopilot.

**Mouse.** A virtual stick that drifts back to centre. The mouse has no natural centre, which is why the gamepad is preferred.

**Active device.** Whichever device moved last is in charge, and the HUD's hints and prompts follow it.

The right stick has no gameplay job yet. It's camera-only for now, and the obvious candidate for combat aiming or a head-look later.

### Speed bands and audio (`scripts/flight/speed_bands.gd`, `scripts/audio/flight_audio.gd`)

Airspeed falls into six bands, cut at the speeds that matter for flying:

| Band | Speed range |
|---|---|
| STALL | below stall speed |
| CATCH | stall speed to catch speed |
| SLOW | catch speed to best glide |
| GLIDE | best glide to 1.5× |
| FAST | 1.5× to 2.2× |
| DIVE | above 2.2× |

A 3% hysteresis keeps a speed sitting on a cut from chattering between bands. The HUD names the current band under the speed tape.

The audio is procedural: an `AudioStreamGenerator`, driven only by telemetry. It has three parts:
- **Wind:** low-passed noise whose cutoff and level rise with speed. It flutters below the stall, and a thin whistle joins in a dive.
- **Whoosh** on every band crossing: a band-passed noise sweep, rising when speeding up and falling when slowing. Each cut has its own pitch, so the crossings become recognisable by ear. For example, "slow enough to catch" is the low one, and best glide sits in the middle.
- **Thump** on each wingbeat.

`test_speed_audio` checks:
- the band edges and hysteresis
- one whoosh per crossing, in the right direction (a ramp up and down crosses 10 times)
- wind loudness rising with speed
- the wingbeat thump

## 8. Bird profiles

Numbers come from the species research, scaled for gameplay where noted there.

| | Crow | Owl | Hawk | Falcon | Sparrow |
|---|---|---|---|---|---|
| Glide ratio (angle) | 10 (5.7°) | 9 (6.3°) | 12 (4.8°) | 10.5 (5.4°) | 6.5 (8.7°) |
| Best-glide speed (m/s) | 8.6 | 8.3 | 9.9 | 12.6 | 8.2 |
| Stall / catch speed (m/s) | 5.7 / 6.8 | 5.5 / 7.2 | 6.5 / 7.8 | 9.2 / 10.6 | 6.0 / 7.2 |
| Bank limit / roll rate | 80° / 320°/s | 75° / 180°/s | 65° / 120°/s | 85° / 240°/s | 85° / 420°/s |
| Wingbeat period | 0.28 s | 0.4 s | 0.45 s | 0.2 s | 0.1 s |
| Burst / stamina (flaps) | 16 / 260 | 12 / 200 | 8 / 130 | 14 / 240 | 40 / 800 |
| Character | all-rounder | floats, gentle catches | glides forever, flapping is costly | fast, deep stoop, thin margin | steep glide, rapid cheap wingbeats |

Keys 1–5 switch bird in game.

## 9. Open questions and next steps

- **Combat.** Not designed yet. Hooks this model already offers:
  - Energy advantage: height and speed are the currency.
  - A stoop from above as the attack, using the tuck.
  - Grabbing another bird with the same catch rule, in a "talon" mode.
  - Knocking birds off perches.
  - Contesting perches for resting.
  - The understory as an escape layer where big birds can't follow.
- **Mouse feel.** Return-to-centre rates and sensitivity need playtesting. A "mouse aim" mode, where the bird auto-banks toward a cursor, could be an option for new players.
- **Thermals or updrafts** over the clearing would give the hawk its niche and add a long-term energy source.
- **Wing-area HUD** (section 1) is ready to promote from the F3 panel.
- **Alula, slotted-tip splay and tail twist** are currently visual only. The research suggests giving them small control effects at low speed.
