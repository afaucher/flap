# Flap: instructions for agents

Flap is a bird flight combat demo in Godot 4.7: a greybox arena of trees and perches, mouse + space controls,
five bird species. Start with `README.md`, then `docs/design/flight_model.md` (how everything works and why)
and `docs/research/` (the bird and flight-sim research behind the numbers). The build system is ported from
`..\cast`.

## This file overrides `scratch/AGENTS.md` for this project
The `AGENTS.md` one level up describes a different, networked project (host-only simulation, 2D raycasts,
a `receive_perceived_state` RPC). **Its guardrails 1-3 do not apply to Flap**, which has no networking yet.
What Flap keeps in their spirit:
- The HUD, camera and bird rig read only `Bird.telemetry()` (a snapshot), never the `FlightModel`.
- Every controller (`PlayerController`, `AIPilot`, test `ScriptedInput`) produces a `FlightInput` and nothing
  else: the AI has exactly the player's authority.
- AI planning uses `ArenaLayout`'s geometry queries (no per-frame physics queries); the chase camera's one
  ray uses `PhysicsDirectSpaceState3D.intersect_ray`.

Guardrail 4 applies: **build and run the tests after any code change** (`.\build.ps1`, or
`.\test_runner.ps1 -TestAll` while iterating).

## Layout
- `scripts/flight/`: `BirdProfile` (species numbers, derived polar), `FlightModel` (pure, headless-testable),
  `EnergyModel` (burst + stamina), `FlightInput`.
- `scripts/world/`: `Perch`, `ArenaLayout` (pure data + generator + geometric queries), `ArenaBuilder` (meshes,
  collision).
- `scripts/bird/`: `Bird` (CharacterBody3D: perch state machine, collision, telemetry), `BirdRig` (greybox
  articulated mesh), `PlayerController` (mouse virtual stick), `ChaseCamera`.
- `scripts/ai/`: `AIPilot` (goal, guidance, avoidance), `FlightPlanner` (lattice A*).
- `scripts/ui/flight_hud.gd`, `scripts/app/` (boot, game, input setup), `scripts/test_support/`.
- `tests/test_*.gd` run in `-TestAll`; `tests/probe_*.gd` are diagnostics, run by name.

## Rules
- Profile numbers: set the readable ones (mass, span, area, e, glide ratio, CL max) and let `derive()` compute
  the polar. `test_bird_profiles` and `test_glide_trim` hold the polar honest; don't loosen their tolerances
  to make a tuning change pass.
- Any assist (pitch damping, turn assist, auto-sweep, perch assist) must stay switchable to 0.
- New tests extend `TestCase`; set `timeout_sec` in `_init()` (not `setup()`) for long ones.
