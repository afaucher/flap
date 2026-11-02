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
- **Pull back:** more CL, so the path curves up while induced drag bleeds speed. This gives the speed penalty you described. At 85% pull the wing reaches its stall angle. The last 15% of travel is the flare: post-stall, a big airbrake. The HUD stick box marks that line.
- **Push forward:** less CL, so the path drops and speed builds. Past half push the wings tuck, reducing area, span and parasitic drag. That's the falcon stoop.
- **Bank-and-yank:** bank tilts the lift vector, which turns the path. Pulling in a bank tightens the turn: turn rate ω = n·g·sin(φ)/V, verified in `test_flight_controls`.
  - Bank limits are per species, from 65° (hawk) to 85° (falcon, sparrow). The HUD shows them as red ticks.
  - `turn_assist` supplies 60% of the extra lift a bank needs, so a pure bank doesn't sink much.

**Assists that make it feel easy.** Set any of these to 0 to turn it off.
- `pitch_damping`: a phugoid damper. Without it, speed and height trade back and forth ("the bob") for half a minute.
  - It feeds the unpowered along-path acceleration back into α. That works out to about 0.7 of critical damping.
  - Feeding back the path's rate of change instead only changes the bob's stiffness, and it chatters at 60 Hz. We tried it; the test caught it.
- `turn_assist`: described above.
- `auto_sweep`: the wings tuck up to 35% by themselves at twice best-glide speed. Gliding pigeons do this (wing research).
- Stall **hysteresis**: the stall sets in past the stall angle and only ends once α is clearly back below it.

**Integration.** Semi-implicit Euler. Lift is applied as a speed-preserving rotation of the velocity, which keeps it stable at low speed. The rotation is split half before the linear forces and half after (Strang splitting); applying it all first steepened every glide by about 0.6°. Drag can remove at most half the speed in one tick. Aero forces fade out below 2 m/s, for example when dropping off a perch.

**Wing area for the HUD.** It's already computed: press F3. Two numbers:
- `wing_area_eff`: the planform area after the tuck. It's the lifting area, and it shrinks in a stoop.
- `frontal_area` = S_eff·|sin α|: the wing area facing the oncoming air. It's near 0 in cruise and large in a flare, so it reads as airbrake.

The research suggests labelling these "lifting area" and "airbrake area" in the full HUD.

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
  - Trunks and branches: hitting one bounces you off at 0.3 restitution, keeps 60% of your speed, and stuns you for 0.35 s. Grazes under 1 m/s just slide.
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

## 6. The AI pilot (`scripts/ai/ai_pilot.gd`, `scripts/ai/flight_planner.gd`)

The AI drives a bird with **exactly the player's inputs** (`FlightInput`: stick, flap, catch). While perched, it turns to face its route out before taking off. On final, it holds catch. It sees only the bird's own state and the arena geometry. It works in four layers:

1. **Goal.** Pick a perch it can reach on its energy.
   - Reach = glide reach from its current height, plus a climb budget from stamina and burst.
   - It prefers hops of about 30 m that lose a little height, and perches up in the trees.
   - It skips perches too low for its stall speed, and the tree it just left.
   - Perched, it rests until stamina is back above 50%.
2. **Route.** A* over a free-air lattice (6 m spacing, 7 altitude levels).
   - Nodes and edges are checked against trunk and branch capsules geometrically (`ArenaLayout.segment_clear`); no physics queries.
   - The cost is energy-aware: climbing a metre costs as much as 4 m of flight, and descending is free.
   - The route runs through a **pre-approach point** and an **approach point** out along the perch facing, ending 1.2 m below the perch. The bird arrives lined up and swoops up into the catch.
   - The route is string-pulled (any waypoint the previous point can see past is dropped).
3. **Guidance.**
   - Bank toward the next waypoint (bank-to-turn). The bank limit shrinks near the ground, because steep banks shed vertical lift.
   - Pitch to hold the path angle that reaches the waypoint.
   - Flap when it needs to climb or is slow.
   - Push when near the stall.
   - On final, pull to bleed speed below the catch speed, holding catch once the target is the bird's catch candidate.
4. **Avoidance.** Whiskers sweep the next second of flight against the geometry.
   - If the sweep is blocked, it steers to the nearest clear direction: sideways, then climbing.
   - A watchdog re-plans if the bird makes no progress for 8 s. It goes around if it overshoots, or if the perch leaves its forward cone on final.

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
- **Whisker reach:** the larger of 1 s of flight or 1.3 turn radii. The whiskers also sweep the **arc** the bird is turning along, not just a straight line.

The climb budget is scaled by the species' sprint × wingbeat strength, so the hawk climbs less than the crow.

**Recovering low down.** When slow below 6 m, the AI flaps hard along a near-level path with wings nearly level, instead of pushing. It used to push, which flew high-stall birds such as the falcon into the ground. It only flaps on full-strength wingbeats, unless it's recovering.

**Status.** `test_ai_flight` flies all five species for 90 s in two arenas (seeds 7 and 3):

| Species | Seed 7 | Seed 3 |
|---|---|---|
| Crow | 7 | 6 |
| Owl | 6 | 5 |
| Hawk | 6 | 5 |
| Falcon | 4 | 2 |
| Sparrow | 5 | 8 |
| **Flock** | **28** (10 bonks) | **26** (9 bonks) |

Every species must chain at least 4 perches across both arenas.

**Before the fit,** the hawk and falcon managed 0. They were choosing low perches in the 4–9 m understory, where trunks are about 5.5 m apart, but the hawk needs about 7 m to turn. Straight whiskers missed the trunks that a steady turn curved into. Pushing to recover speed near the ground flew the falcon into it.

**Still weak:** the falcon bonks the most. Next steps:
- A speed-planned final approach that starts its flare by distance rather than by a fixed gain.
- Trajectory sampling for avoidance: roll the model forward for candidate stick inputs.

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
