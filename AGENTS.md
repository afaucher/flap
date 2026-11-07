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
  `EnergyModel` (burst + stamina), `FlightInput`, `AirField` (the air's movement: thermals over the clearings, ridge
  lift for a cliff; the bird flies through it, `FlightModel.wind`; `AirFx` draws it; `--calm`; the combat range
  is calm until the combat AI reads the air: `CombatWorld.calm_air`). The chase camera zooms with the mouse wheel.
  TAA over 2x MSAA by default (`Antialias`; `--no-taa`, F7): it clears the speckle on feather cards' edges and fine
  texture that MSAA leaves.
- `scripts/world/`: `Perch`, `ArenaLayout` (pure data + generator + geometric queries), `ArenaBuilder` (meshes,
  collision). `Pinewood` grows a mixed-age wood: mature pines, pole-stage pines and a few veterans, and oaks forking low with their
  solid trunk ending at the fork (`TreeData.stem`, `trunk_top()`: collision and wood queries use it; `docs/design/flight_model.md`
  section 5), shaped for clear perches below the crown (`tests/probe_tree_paths.gd` + `tools/tree_side_map.py` draw one from the side) (`TreeData.form`;
  `Pinewood.ages` off for an A/B; `tests/probe_pine_ages.gd` renders them, `probe_tree_stats` counts them). The game's arena is a baked map, not a seed: `maps/pinewood_7.map` (`MapFile`: the whole `ArenaLayout`, trees,
  limbs, branches, perches, outposts, openings, the floor's field, thermals), which `Pinewood.generate` reads when it's
  there and the generator's options are as baked (`Pinewood.baked`, `as_baked()`), so changing the generator
  (`Pinewood.grow`) doesn't move it. Re-bake on purpose with
  `& $godot --path . --headless --script res://tools/bake_map.gd -- 7`, then check what was tuned on it (race courses,
  the combat AI's tests). Tests of the generator itself use `Pinewood.grow`; `test_map_file` holds the round trip. The floor: `FloorField` (mounds, moss, dirt) drawn by `forest_floor.gdshader`
  on `ArenaBuilder.floor_tiles` (8 x 8 tiles, culled one by one; flat blocks of 8 x 8 and 4 x 4 cells joined in
  crack-free fans where `FloorField.flat_cells` says the floor is flat, `FLOOR_JOIN`) inside `floor_ring` (the big
  plane, a real hole from where the floor is flat for good, `FloorField.flat_beyond`; no discard); `tests/probe_floor_still.gd` renders the floor alone and still, to check a change leaves its look; `tests/probe_floor_map.gd` + `tools/floor_map.py` map its heights and how the mesh draws them. The outposts (as `docs/images/concepts/r4_aces_outpost.jpg`): `ArenaBuilder.PLANKS` hand-sawn planks + one
  `TimberMesh` each (framing, ironwork, rail, the hangar back-right seen from the rail, ammo boxes, and drawn-only
  props: rope coil, windsock, pennants; every vertex carries its piece's grain frame, so `planks.gdshader`
  draws end grain on end faces and maps the planks scan at its true scale). Collision: deck box, rail capsule,
  hangar box only. Look with `tests/probe_timber.gd` (close-ups, `--warm`) and `tests/probe_outpost_concept.gd`
  (the menu's outpost framed like the concept, `--view`, `--warm`). The arena's edge (`Escarpment`, `EdgeBuilder`;
  `docs/design/arena_edge.md`; on hold: off unless `--cliff`, `Pinewood.cliff`, the heath all round): after changing the cliff, `.\tools\cliff_measure.ps1` scores it against its concept
  (`docs/design/cliff_from_concept.md`: the process, what it measures and how far to trust each number).
- Touching wood (`Bird`, `docs/design/flight_model.md` Collisions): a side touch (within `GLANCE_DEG`, 40, of along it, any
  speed) glances -- no stun, speed lost by how hard, the feet kick off the bark (the rig's claws on it), `claw_scrape`; squarer
  bonks, the stun scaled 0.1-0.35 s by the speed into the wood (full at `BONK_HARD`, 9 m/s). Wings strike too (shoulder to
  tip against the layout's wood each tick: speed lost, no stun, `wing_strike`). Reflexes look 0.25 s ahead
  (`ArenaLayout.wood_near` / `first_touch_among`): the wings tuck for wood from the side or in a wing's way (`tuck_reflex`,
  `FlightModel.tuck`), a flare for wood square ahead (`flare_reflex`), and a novice's bird rolls away at a speed cost
  (`avoid_assist`, `FlightAssist.AVOID`); each off at 0. `test_glance`; lab scenarios `glance_left` / `_right`,
  `bonk_steep`, `bonk_slow`, `head_on`, `wing_clip`; probes `probe_bonk_angles` (how birds hit wood, braces and false
  alarms, the look-ahead's cost), `probe_glance_close` (renders a glance up close), `probe_reflex_trace`, `probe_touch_cost`.
- `scripts/bird/`: `Bird` (CharacterBody3D: perch state machine, collision, telemetry), `BirdRig` (skeleton,
  wing FK + fold IK, leg IK, head look, feathers; `docs/design/wing_rig.md`), `WingShape` (per-species planform,
  calibrated to the flight model's span and area), `PlayerController` (gamepad + mouse), `ChaseCamera`.
- `scripts/ai/`: `AIPilot` (goal, guidance, avoidance; turns within what the lift holds, lines up for the final on its own
  turning circle, manages its energy for the catch), `FlightPlanner` (lattice A*, the ways in to a perch), `Dubins`
  (turn-straight-turn paths). What the AI must be able to do is the flight exam (`docs/design/flight_exam.md`):
  `FlightExam` (scripts/test_support: lone trees, the oak's crown and low tier, rails, a grove, hops, close in on the line,
  gate courses), `test_flight_exam` (each species' share and median time by scene, its time banked past the lift's hold,
  the speed its finals begin at), `tests/probe_flight_exam.gd` (every attempt; `--trace` one; `--stamina` tired). Judge an
  AI change there, not on one run in the wood.
- `scripts/race/`: race mode, a prototype (`docs/design/race.md`; the menu's Race screen, or `.\run.ps1 --race
  [--race-ai recruit|pilot|ace] [--course <n>] [--plan-for <birds>]`; the pause menu's Start over restarts the race). `RaceCourse` generates 10 gates from the layout (posts on
  open ground, low or tall; between two pines; hoops hung from a limb or a rope between two pines) from an outpost's
  rail, by a beam search under planning rules from the birds' performance (`Envelope`: the widest turning circle and
  wings of the birds racing, the hawk's by default): a clear way in and out of each window, each leg's flown line
  (`flown_line`) clear by half a wingspan and turning no tighter than that circle, posts and ropes off the line, the
  next gate seen from the one before (and the one after it, unless the turn is tight: `marked`), the way home straight
  from the last gate to a run-in in front of the rail (`home_problem`, `home_in`); styles (`STYLES`, `--course-style`:
  technical | long, level | high-low): legs, turns, gate count, heights, the birds it's planned for, and long legs
  routed through the wood by the AI's planner between clear lanes (`route_line`); technical courses are figure-eights
  where one fits (`eight`, `crossings()`: the search follows a guide, two lobes joined across the way out, `_guide_for`,
  tried round the two nearest rails, `_eight_guides`; 14-18 gates; `RaceCourse.eights` off, or `--no-eights` in
  `probe_courses`, for the free search's; `probe_race --guides` draws the tries); `problems()` lists
  any rule broken. `apply()` puts the posts into the layout (solid). `RaceRun` the rules (a gate through its window
  the way it faces, in order; the clock from leaving the start rail to landing back on it, every gate taken (landing there
  sooner resets the run); misses;
  splits within the tick), `RacePilot` an
  AI racer (a FlightInput only): it follows the course's planned line by an L1 pursuit, its skill (`CombatSkill`
  presets) degrading look-ahead, bank, reaction, aim and pace; a missed gate it goes round on a planned Dubins path
  (`RacePilot.dubins`) to the gate's way in; AIPilot.steer only for wood ahead and low-speed recovery; home to the
  rail, AIPilot.go_to_perch lands it; `RaceView` placeholder gates,
  `RaceHud` (the clock top centre; best and the average of the last three top right), `RaceRecord` best and recent
  times. `RaceTrial` (test_support) races birds headless; `tests/probe_courses.gd` sums up many course seeds (full, kinds, heights,
  the way home); `tests/probe_combat_rest.gd` watches a 3 v 3's base landings (`--ai-seed`); `tests/probe_race_home.gd` lands each bird on the rail from
  the last gate (the AI falcon can't yet; `--trace <bird>`: its final approaches); `tests/probe_race.gd` prints a
  course leg by leg against each bird's turning circle, races every bird at every skill, writes an SVG map
  (`.\probe.ps1 -Headless probe_race [--seed n] [--plan-for crow,owl,sparrow]`). Flyability apart from the AI:
  `LinePilot` (test_support) flies the planned line exactly through the bird's own flight model, leg by leg;
  `tests/probe_flyable.gd` marks each leg for each bird (a leg no bird can fly is the course's, one the AI misses the
  AI's). `test_race` (every bird flies the course, by LinePilot).
- `scripts/ui/flight_hud.gd`, `scripts/app/` (boot, game, input setup; the rig gallery and the bird lab: `bird_lab.gd` with `LabScenarios`, `LabPilot`, `RigPoses`; its combat scenes, `LabFight`: a gun
  burst, a rocket hit, a seeker lock and launch, a bird downed (fluttering down to the ground), rearming on the base -- the real CombatWorld and tack;
  its route scenarios, `rail_front` / `rail_behind` (AIPilot sent to land on the race's start rail) and `ai_wander`, fly the AI in
  the pine wood under the route view, `RouteView` (`scripts/ai/`; P or `--no-route`, L or `--route-rejected`, `--lattice-at
  target`): the planner's lattice round the bird (usable nodes teal, rejected red: `FlightPlanner.node_usable`), `AIPilot.route`
  and the waypoint it's on, the perch and its approach points, the path its avoidance predicts (`AIPilot.predicted`, red from
  where it meets wood) and the escape it flies instead (`AIPilot.escape`); visual only, `test_route_view` reads it back), `scripts/test_support/`.
- Bills (`Face.beak_meshes`): lofted on each species' profile traced from a photo (`tools/beak_profiles.py` REFS ->
  `tools/bill_profiles_emit.py` -> the generated `scripts/bird/bill_profiles.gd`: re-run it after changing a trace),
  drawn by `bill.gdshader` (keratin, the cere's edge, the nostril, the crow's bristles, the cutting edge, per pixel from
  the mesh's bill-frame coordinates); the head's front drawn out to the bill's base (`Face.snout`, `BirdRig._head_point`)
  and the eyes seated back (`Face.eye_seat`), so each eye sits as far behind the bill as in its photo. `test_bill_profile`
  holds the drawn profile to the traces; `tests/probe_beak_profile.gd` + `tools/beak_profiles.py` chart them
  (`docs/images/beak_profiles_after.jpg`).
- `scripts/bird/body_shape.gd`: `BodyShape`, the body's landmarks and lofted shell (`docs/design/body_rig_plan.html`). The neck
  meets the head and trunk flush, lit and coloured as one (`BirdRig._loft_neck`, `docs/design/wing_rig.md`; `test_neck_seam` measures
  the crease, the normals, the nape's notch, the perched throat and the colour hand-over; the rig gallery's `--view nape|throat` look at it).
- `scripts/tack/`: the war tack, visual only (`Tack.fit(rig, bird)`): `Saddle` (harness, seat, launcher, laid out on
  `BackSurface`), `Rider` (head, helmet and goggles fitted to `HeadShape`), `TackMesh` + the leather/metal/
  cloth/skin/eye shaders. Look at it with
  `.\run.ps1 --scene res://scenes/tack_gallery.tscn [--bird crow] [--sheet <png> [--macros | --heads | --mounts]]`.
  Weapons: a pod each side of the rider (`Saddle` loadout, left and right, each `rockets` x3, `seekers` x2 or `gun`,
  a belt-fed machine gun with `Launcher.GUN_POD` (40) rounds; tilted in a trunnion). `Launcher` carries each kind
  summed over the pods (`set_tack`, `carried` / `left`), fires each round from its own pod's muzzle (in flight, the very round the pod carries, `Saddle.flying_round`,
  drawn true size leaving the pod and at most `CombatWorld.ROUND_GROW` (2x) further out; `test_flying_round`)
  (`Tack.muzzle_world`; two gun pods take turns), and Q / RB (`next_weapon`) switches between the two kinds when they
  differ. `--loadout <left>,<right>` (one value: both; `--seekers` = seekers,seekers; `.\range.ps1 -Loadout gun,rockets`)
  arms your bird; the menu's Fight screen picks each pod. The target and circuit wingman carry yours with a gun
  swapped for rockets, the match's AI birds their species' round (the combat AI doesn't use the gun yet: with one
  selected its fire control holds). A seeker lock needs a clear line of sight (`Launcher.sees`: wood on the line
  stops it, past `LOS_GRACE` drains it).
  The gun (`Projectile.Kind.GUN`): 10 rounds/s held (`GUN_RATE`; a tap fires a 3-round burst, `GUN_BURST`), 95 m/s
  on the carrier's speed, 0.42 s life (about 40 m), 0.7 deg scatter; aimed at the lead mark like rockets
  (`lead_point` at bullet speed). A bullet hits only within the bird's own size (`Projectile.hit_radius`: crow
  0.27 m, sparrow 0.09) and hurts only that bird: no stun, a nudge, one feather -- inside the recovery window a third
  of one (`CombatWorld.GUN_CHIP`), so a stream chips about a feather a second. Drawn as tracer streaks with muzzle
  flashes, both from the gun's mouth as it's drawn this frame (`Projectile.gun_mouth` -> `Tack.muzzle_drawn`: physics
  interpolation draws the bird behind the latest tick; `test_gun_tracer`, `tests/probe_gun_close.gd` to look); sparks on wood and ground (`CombatFx`); `launched` / `burst` carry `kind` GUN (`burst` why `"hit"` on a bird,
  `"impact"`; none when it runs out). `GameAudio`: its own shot (crack and bolt clatter), strikes on wood and ground, and a zip for someone else's
  bullet passing within `ZIP_NEAR` of you.
- Tactics for players (the tutorial's source): `docs/tutorial/tactics.md` -- keep its numbers in step with the code.
- Damage: a hit knocks out the flight feathers nearest it (`Bird.lose_feathers`, 2.5 on average); the wing loses
  that area and drops (`FlightModel.wing_loss`); eight down the bird, which flutters down to the ground (`CombatWorld.down_flutter`, `Bird.start_tumble`: its wings flail
  and hold 0.3 of their lift, it rolls and drops, and sits where it comes down until it respawns; a respawn ends it); a hit within `CombatWorld.recover` (1 s) of the last
  takes one feather at most (a bullet a third of one), so a salvo can't down a bird in one pass (`tests/probe_salvo.gd` measures how birds go down); your base (`Launcher.rearm_perch`) rearms and mends. The HUD shows a health bar.
- Teams: `CombatWorld.add_bird(b, controller, team)` (unset: a team of its own), `friends()`, `friend_in_line()`;
  locks and the HUD's target take enemies only (`Launcher.is_enemy`), bursts hurt anyone (friendly fire on). The
  HUD: enemies warm (`CombatHud.ENEMY`), teammates a teal caret (`FRIEND`), a teal cross over the gunsight while a
  teammate is in the line of fire; trails in team colour. Bases per team (`CombatWorld.bases`, `respawn()`:
  a downed bird comes back on its base, mended and rearmed), `score` (enemies downed, shown top right). The
  range: you and a wingman v the target, your base by the clearing and theirs the farthest outpost. Warnings:
  `CombatWorld.warnings_for(bird)` (rounds coming at it, locks on it) -- what the HUD shows and all an AI may
  know of threats; `--return-fire` has the target shoot back.
- Landing: the highlighted perch (`Bird.candidate`) is the one the predicted flight path (`Bird.predicted_path`: its
  sink and turn, not the nose) passes closest, a perch in reach now winning, only within `Bird.CONE_DEG` (25) of the path's way in plan and
  scored worse the further off it (`OFF_PATH_COST`); the perch assist keeps the old pick, the
  nearest perch ahead (`Bird._ahead`: the AI's flying is tuned on it). `--flying novice|realistic` (default
  realistic; `FlightAssist.configure`, `fit` on the player's bird): novice blends the player's input toward
  `AIPilot.steer`'s approach while catch is held (`FlightAssist.strength`, 0 = off), adding at most `MAX_BANK_ADD` of bank and
  holding the perch it engaged on (`Bird.candidate_lock`, kept within `LOCK_CONE_DEG`, 35) so it can't swing onto the next tree, the perch assist works from
  further out on the candidate and brakes for height (`Bird.novice_landing`), and `EnergyModel` gives every bird 1.5x stamina, 2x
  recovery, 1.3x burst refill. `test_perch_highlight`, `test_landing_assist`, `test_energy`.
- HUD (`FlightHud`, `CombatHud`): `FlightHud.style` classic (default: status top left, a green / red landing bar on the perch while
  catch is held, instruments under F3), ring, or dev (`--hud`).
- `scripts/app/menu.gd`: run with no arguments, the menu (Flight: a screen to pick your bird and how it flies,
  Novice | Realistic (`--flying`), then the game without the tack, `Menu.flight_options()`; Fight: a screen to pick your
  bird, each pod's weapon (rockets | seekers | gun, `--loadout <left>,<right>`), Novice | Realistic, the 3 v 3 match (at
  recruit | pilot | ace) or target practice, with the mode's rules, `Menu.fight_options()`; Race: your bird, one of
  `Menu.COURSES`, rivals (none | recruits | pilots | aces), Novice | Realistic, your best there (`RaceRecord`), the
  rules, `Menu.race_options()`, the game's `--race` without the tack; Lab; Settings: which way the
  mouse and the stick climb (`Settings`, `user://settings.cfg`, loaded by `Boot` but not for tests; `PlayerController`
  takes it when made) and the controls, read from `InputSetup`'s bindings (`keys_for` / `pad_for`), the panel `SettingsPanel` (tabs Keyboard / Mouse / Gamepad, the bindings on disabled plates, ready for rebinding), its parts `MenuStyle`'s
  (`page`, `row`, `button`, ...); in the game and the range Esc or losing focus opens `PauseMenu` (`scripts/ui/`: the tree
  paused, Resume / Start over (the scene's: `Game.start_over`, the range's `restart`) / Settings / Leave; Esc or Start; resuming recaptures the mouse and `take_settings()`; `tests/probe_pause_shot.gd`); `--page flight|fight|settings`), in `MenuStyle`'s brass-on-leather look over `MenuBackdrop` (birds
  with riders idling on an outpost rail; `--no-backdrop`, `--shot <png>`, `--page fight`). The scenes read
  `Boot.args()` (the command line plus the menu's choice). The game and the range load behind `Loading` (the same
  look): the layout on a worker thread (headless: inline), `ArenaBuilder.steps()` a frame apart, the birds; they
  set `is_loaded` and emit `loaded` when ready (a test that opens them awaits it).
- `scripts/combat/`: the combat proof of concept (`.\range.ps1`). `CombatFx` (visual only): a burst's flash, light,
  smoke and embers; knocked-out feathers leave the wing as copies of the rig's own cards (`BirdRig.feather_copy`)
  and flutter to the ground; down; ruffled coverts; shedding.
- `scripts/combat/target_balloon.gd`: `TargetBalloon`, target practice's balloons (five round the clearing, `combat_range.gd`
  `_moor_balloons`, `TargetBalloon.moorings`; `--no-balloons`): a Caquot kite balloon at
  the riders' 1:20.6 (1.36 m), moored to a hand winch on a stump, nose into `breeze`. Stages (`stage()`): UP, HOLED
  (`bullet_hit`: a hole in and out, each leaking `LEAK` of its gas a second), SINKING (soft: the nose cups, the tail
  and fins droop, lower on its cable), DOWN (a limp heap on the ground), BURNING (`burst_near`: the fire runs over it
  from where it caught, `balloon.gdshader`), FALLING, WRECK. Holes and the burn are in rest space (CUSTOM0).
  `clear_spot` checks a mooring is clear of wood and crowns. In `CombatWorld.balloons`: a bullet through one holes it
  and flies on, a rocket's or seeker's fuse takes one, a burst within `BALLOON_IGNITE` sets it alight; down, the last
  to hit it is credited (`stats.balloons`, `balloon_downed`; the HUD counts yours), and `respawn_after` s on the ground
  a fresh one is winched up. Birds fly through them (no collision yet), and seekers don't lock on them. The HUD's
  target (`Launcher.target`) is an enemy or a balloon still up, whichever is nearest the sight within `PICK_CONE` (20 deg;
  held until another is nearer by `PICK_KEEP`), else the nearest enemy in front; the AI's is `target_bird` (birds only).
  The lead mark is drawn at `Launcher.lead_sight`: where the gunsight must be for the round to meet the target (drop
  allowed for, and the chase camera riding above the line of fire, so ring on mark hits at any range and zoom; the
  lead point itself is right only at the sight's 25 m). `test_aim_lead`; `tests/probe_gun_aim.gd` measures the miss.
  `tests/probe_balloon.gd` renders each stage in the clearing; `test_target_balloon`, `test_balloon_range`.
- `scripts/combat/ai/`: the combat AI (`docs/design/combat_ai.md`, section 11 for what's built): `CombatSense` (what a
  bird can see) -> `CombatBrain` (a Beehave tree, `CombatTree`, built in code; `addons/beehave`) -> an `Intent` that
  `CombatPilot` flies through `AIPilot.steer()` and `AICombat` fires by (`FireControl` flies the real `Projectile`).
  `Duel` (`scripts/test_support/`) runs headless matches; `test_combat_perches` checks the ambush and rest perch choices
  in a place of their own; `tests/probe_duels.gd` prints duel traces and cost
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
  `test_sounds` checks the stamp). A sound a 3D cue plays is baked with `SoundRecipes.LEAD_3D` of silence ahead (a 3D
  player is silent until the tick after it starts: short sounds went unheard); `gpu_test_audible` records the master bus
  to check they're heard, and `tests/probe_gun_audio.gd` records the range while firing. Plan and status: `docs/design/audio_plan.md`.
- `scripts/app/perf.gd` + `.\perf.ps1`: the frame profiler. Code marks sections (`Perf.t()` / `Perf.add()`); the
  game's `--perf <s>` writes per-frame CSV and a summary (sections per frame and per physics tick, frame pacing,
  ticks per frame, worst frames, the machine's load while it ran). Rules and numbers: `docs/design/performance.md`.
- Looks: `ForestLight.LOOKS` (golden by default, afternoon, misty_morning, overcast; `--look`, F6), graded as in
  `docs/design/color_grading.md` (`tests/probe_grade.gd` renders fixed views; `tools/grade_scopes.py` charts them
  beside the concept art).
- `tests/test_*.gd` run in `-TestAll`; `tests/probe_*.gd` are diagnostics, run by name: `.\probe.ps1 probe_x [args]`
  (`-Headless` where no renderer is needed). **Keep windowed runs off the user's screen**: many sessions run tests and
  renders at once, and each Godot window used to pop up over whatever the user was doing and take focus. The test
  runner, `mutation_check.ps1`, `probe.ps1`, `run.ps1 --shot/--sheet` (or `-Hidden`) and `perf.ps1 -Hidden` start
  Godot on a desktop of its own (`test_lib.ps1`, `FlapHidden`): it renders on the GPU as usual (the GPU tests' numbers
  are the same) but is never on screen, never in the taskbar, never focused, and dies with the script that started
  it. Don't launch a windowed Godot directly (`& $godot --path . -- ...`) for a render or check; use these.
  `FLAP_SHOW_WINDOWS=1` puts them on the user's desktop, to watch one. They are silent too: each starts with
  `FLAP_MUTE=1` in its own environment (`FlapHidden.ChildEnvironment`; the caller's shell is untouched) and
  `Boot.mute_if_asked` mutes the Master bus's output. The mix still runs, so an effect on the bus still records it
  (`gpu_test_audible`, `probe_gun_audio`); `gpu_test_audible` checks the mute and the Master's meter staying silent.
  `FLAP_SOUND=1` leaves the mute out, to hear one (`FLAP_SHOW_WINDOWS` doesn't change the sound). Headless runs use
  the dummy audio driver and were silent already. (A shell that already ran these scripts keeps the `FlapHidden` it
  compiled then: open a new one after changing `test_lib.ps1`.)
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
