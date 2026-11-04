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
  collision). The outposts (as `docs/images/concepts/r4_aces_outpost.jpg`): `ArenaBuilder.PLANKS` hand-sawn planks + one
  `TimberMesh` each (framing, ironwork, rail, the hangar back-right seen from the rail, ammo boxes, and drawn-only
  props: rope coil, windsock, pennants; every vertex carries its piece's grain frame, so `planks.gdshader`
  draws end grain on end faces and maps the planks scan at its true scale). Collision: deck box, rail capsule,
  hangar box only. Look with `tests/probe_timber.gd` (close-ups, `--warm`) and `tests/probe_outpost_concept.gd`
  (the menu's outpost framed like the concept, `--view`, `--warm`). The arena's edge (`Escarpment`, `EdgeBuilder`;
  `docs/design/arena_edge.md`; on hold: off unless `--cliff`, `Pinewood.cliff`, the heath all round): after changing the cliff, `.\tools\cliff_measure.ps1` scores it against its concept
  (`docs/design/cliff_from_concept.md`: the process, what it measures and how far to trust each number).
- `scripts/bird/`: `Bird` (CharacterBody3D: perch state machine, collision, telemetry), `BirdRig` (skeleton,
  wing FK + fold IK, leg IK, head look, feathers; `docs/design/wing_rig.md`), `WingShape` (per-species planform,
  calibrated to the flight model's span and area), `PlayerController` (gamepad + mouse), `ChaseCamera`.
- `scripts/ai/`: `AIPilot` (goal, guidance, avoidance), `FlightPlanner` (lattice A*).
- `scripts/ui/flight_hud.gd`, `scripts/app/` (boot, game, input setup; the rig gallery and the bird lab: `bird_lab.gd` with `LabScenarios`, `LabPilot`, `RigPoses`), `scripts/test_support/`.
- `scripts/bird/body_shape.gd`: `BodyShape`, the body's landmarks and lofted shell (`docs/design/body_rig_plan.html`).
- `scripts/tack/`: the war tack, visual only (`Tack.fit(rig, bird)`): `Saddle` (harness, seat, launcher, laid out on
  `BackSurface`), `Rider` (head, helmet and goggles fitted to `HeadShape`), `TackMesh` + the leather/metal/
  cloth/skin/eye shaders. Look at it with
  `.\run.ps1 --scene res://scenes/tack_gallery.tscn [--bird crow] [--sheet <png> [--macros | --heads | --mounts]]`.
  Weapons: a pod each side of the rider (`Saddle` loadout: rockets x3 / seekers x2, tilted in a trunnion); a bird
  carries one kind, six rockets or four seekers (`.\range.ps1 [-Seekers]`), each fired from its tube.
- Damage: a hit knocks out the flight feathers nearest it (`Bird.lose_feathers`, 2.5 on average); the wing loses
  that area and drops (`FlightModel.wing_loss`); eight down the bird; your base (`Launcher.rearm_perch`) rearms and mends. The HUD shows a health bar.
- Teams: `CombatWorld.add_bird(b, controller, team)` (unset: a team of its own), `friends()`, `friend_in_line()`;
  locks and the HUD's target take enemies only (`Launcher.is_enemy`), bursts hurt anyone (friendly fire on). The
  HUD: enemies warm (`CombatHud.ENEMY`), teammates a teal caret (`FRIEND`), a teal cross over the gunsight while a
  teammate is in the line of fire; trails in team colour. Bases per team (`CombatWorld.bases`, `respawn()`:
  a downed bird comes back on its base, mended and rearmed), `score` (enemies downed, shown top right). The
  range: you and a wingman v the target, your base by the clearing and theirs the farthest outpost. Warnings:
  `CombatWorld.warnings_for(bird)` (rounds coming at it, locks on it) -- what the HUD shows and all an AI may
  know of threats; `--return-fire` has the target shoot back.
- HUD (`FlightHud`, `CombatHud`): `FlightHud.style` classic (default: status top left, a green / red landing bar on the perch while
  catch is held, instruments under F3), ring, or dev (`--hud`).
- `scripts/app/menu.gd`: run with no arguments, the menu (Flight: the game without the tack; Fight: a screen
  to pick your bird, rockets or seekers, the 3 v 3 match (at recruit | pilot | ace) or target practice, with the
  mode's rules; `Menu.fight_options()`; Lab), in `MenuStyle`'s brass-on-leather look over `MenuBackdrop` (birds
  with riders idling on an outpost rail; `--no-backdrop`, `--shot <png>`, `--page fight`). The scenes read
  `Boot.args()` (the command line plus the menu's choice).
- `scripts/combat/`: the combat proof of concept (`.\range.ps1`). `CombatFx` (visual only): a burst's flash, light,
  smoke and embers; knocked-out feathers leave the wing as copies of the rig's own cards (`BirdRig.feather_copy`)
  and flutter to the ground; down; ruffled coverts; shedding.
- `scripts/combat/ai/`: the combat AI (`docs/design/combat_ai.md`, section 11 for what's built): `CombatSense` (what a
  bird can see) -> `CombatBrain` (a Beehave tree, `CombatTree`, built in code; `addons/beehave`) -> an `Intent` that
  `CombatPilot` flies through `AIPilot.steer()` and `AICombat` fires by (`FireControl` flies the real `Projectile`).
  `Duel` (`scripts/test_support/`) runs headless matches; `tests/probe_duels.gd` prints duel traces and cost
  (`DUEL=hawk,crow DUEL_TARGET=circuit DUEL_TRACE=1`). Teams share a `TeamBoard`; `.\range.ps1 -Match` is a 3 v 3.
  `tests/probe_team_cost.gd`: a 3 v 3's cost per tick and section, the worst tick, and a fingerprint of every bird's
  flight (a speedup meant to change nothing must leave it the same).
- GPU-built surfaces, on by default where there is a RenderingDevice (`BirdRig.gpu_feathers`, `gpu_body`; `--cpu-feathers` /
  `--cpu-body` turn them off): flight and tail feathers placed by `feather_place.gdshaderinc`, the neck, arm wings and
  trousers built by `neck_place` / `arm_place` / `trouser_place.gdshaderinc`. Headless runs use the GDScript builds,
  which stay the reference: `tests/gpu_test_*` (run windowed) read the shader's vertices back and compare.
- `scripts/bird/leg_rig.gd`: `LegRig`, the detailed legs and feet, on by default (`LegRig.enabled`; trousers joined to the trunk,
  bare tarsus, foot pad, segmented toes fitted to the branch, claws; `leg_skin.gdshader` over `ScaleTile`'s baked
  scales; `docs/design/legs_and_feet.md`).
- `scripts/audio/`: `GameAudio` (what plays when, from telemetry and the Bird / CombatWorld signals; `events` records every
  cue for tests), `Sfx` (pooled cue players), `FlightAudio` (live wind, whooshes, wingbeats), `SoundRecipes` +
  `SoundDsp` (every other sound, baked to `assets/audio/sfx/` by `tools/bake_sounds.gd`: re-run after changing a recipe;
  `test_sounds` checks the stamp). Plan and status: `docs/design/audio_plan.md`.
- `scripts/app/perf.gd` + `.\perf.ps1`: the frame profiler. Code marks sections (`Perf.t()` / `Perf.add()`); the
  game's `--perf <s>` writes per-frame CSV and a summary (sections per frame and per physics tick, frame pacing,
  ticks per frame, worst frames, the machine's load while it ran). Rules and numbers: `docs/design/performance.md`.
- Looks: `ForestLight.LOOKS` (golden by default, afternoon, misty_morning, overcast; `--look`, F6), graded as in
  `docs/design/color_grading.md` (`tests/probe_grade.gd` renders fixed views; `tools/grade_scopes.py` charts them
  beside the concept art).
- `tests/test_*.gd` run in `-TestAll`; `tests/probe_*.gd` are diagnostics, run by name.
- `tests/regressions/mutations.json` + `.\mutation_check.ps1`: every bug we've fixed, as an edit that puts it
  back. The script applies each in a scratch tree and requires the named tests to fail (KILLED); a
  SURVIVED bug is a test gap, a STALE entry needs its find text updated to today's code. Entries run in
  parallel (`-Jobs`, 12 test processes by default), each stopped at its first failing line, the test (shard)
  that killed it last time first (`test_logs\mutation_kills.csv`); `-Changed` checks only the entries the branch
  could affect; tests `test_runner.ps1` just passed on the same tree (`test_logs\passed.txt`) skip the baseline.
  Shared process handling and the pass rule: `test_lib.ps1`. Each run writes every verdict and the line that
  decided it to `test_logs\mutation_results.csv`; `-AllChecks` (~10 min) runs every named test to the end and
  records every failing line, to audit that each entry is caught by a check about its bug (not a parse error, a
  crash, or a check that happens to fail first).

## Rules
- Profile numbers: set the readable ones (mass, span, area, e, glide ratio, CL max) and let `derive()` compute
  the polar. `test_bird_profiles` and `test_glide_trim` hold the polar honest; don't loosen their tolerances
  to make a tuning change pass.
- Any assist (pitch damping, turn assist, auto-sweep, perch assist) must stay switchable to 0.
- New tests extend `TestCase`; set `timeout_sec` in `_init()` (not `setup()`) for long ones. The suite takes as
  long as its slowest test: split a long one with `const SHARDS := N` and `if in_shard(i):` round each part (the
  runner starts N processes), and hide a bird's rig (`b.rig.visible = false`) where only its flight is checked.
- Fixing a bug: add an entry to `tests/regressions/mutations.json` that reintroduces it, and run
  `.\mutation_check.ps1 -Only <id>` -- it must come back KILLED. A test that passes with the bug back in
  proves nothing.
- **Before merging to master** (the gate, about 3 min on an idle machine): `.\test_runner.ps1 -TestAll`, then
  `.\mutation_check.ps1` -- the whole check, all KILLED (about 1.5 min: the tests `-TestAll` just passed on the
  same tree skip its baseline, so run them in that order with nothing edited in between). While iterating,
  `.\mutation_check.ps1 -Changed` checks only the entries the branch could affect (the edited files, the
  named tests, new or changed entries; 20-40 s); it can miss a change that blunts a test against a bug in
  another file, which is why the gate runs them all. If the gate outgrows 5 minutes (each entry adds about
  0.6 s), make `-TestAll` + `-Changed` the gate and run the whole check once a day on master instead.
- Tests measure what is drawn or simulated (the feather mesh's outline, the body mesh), not copies of the
  constants that build it, and check behaviour both ways (left and right, pull and push).
- The test runner fails on any engine `ERROR:`/`WARNING:` line, not just failed checks.
