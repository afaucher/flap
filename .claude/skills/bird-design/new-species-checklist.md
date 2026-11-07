# A new species: every table it needs

Most tables fall back to the crow (`DATA.get(id, DATA["crow"])`): **a forgotten entry draws a crow, silently.** Go
through all of them; the ones marked **no fallback** error instead. Grep for an existing id (`"sparrow"`) across
`scripts/` and `tests/` to catch anything added since this list.

## Research first
- [ ] `docs/research/bird_aerodynamics_by_species.md`: the real bird's numbers (section 2) and the proposed profile
      (4a, 4b), each sourced / `[E]` / gameplay.
- [ ] A side-on reference photo for the head (Commons, licence), plumage references, measured leg bones.

## Flight
- [ ] `scripts/flight/bird_profile.gd`: a preset (ending `return p.derive()`), `IDS`, the `by_id` match. `IDS` drives the
      menus, the bird lab, `game.gd` (`--bird`, cycling, racers), the range, the tack gallery, the race envelope.
- [ ] `scripts/app/input_setup.gd`: `bird_1`..`bird_5` keys -- a sixth species has no key.

## Wing and body
- [ ] `scripts/bird/wing_shape.gd` `DATA` (a new `tail_shape` name also needs `BirdRig._tail_shape`).
- [ ] `scripts/bird/bird_rig.gd`: `POSE` (perch / ground pitch, tail_down, stance), `FEATHER_LOOK` (the parked shader
      only), `_tint()`.
- [ ] `scripts/bird/body_shape.gd` `DATA`.
- [ ] `scripts/bird/leg_rig.gd` `SPEC`.

## Head and bill
- [ ] `scripts/bird/face.gd` `DATA` (eye with `back`, iris, `beak`, bill colours, head yaw / pitch, saccades, blinks).
- [ ] `tools/beak_profiles.py`: `REFS`, `LIFE_R`, `ORDER`, `NAMES`; run `tools/bill_profiles_emit.py` ->
      `scripts/bird/bill_profiles.gd` (**no fallback**).
- [ ] `tests/test_bill_profile.gd` `REF` (**no fallback**), read off the new traces.

## Plumage
- [ ] `scripts/bird/plumage.gd`: `DATA`, `TEXTURE`, `GLOSS`.

## Tack
- [ ] `scripts/tack/tack.gd` `RIDDEN`; it must pass `test_tack` at the 8.5 cm rider (`tests/probe_rider_scale.gd`).

## Sound
- [ ] `scripts/audio/flight_audio.gd` `BEATS` (wingbeat pitch, length, level, noise).
- [ ] `scripts/audio/sound_recipes.gd`: `SOUNDS` call / alarm entries, the recording constant and `CALL_SOURCES`,
      `CALLS` (**no fallback**), `_call_<id>` / `_alarm_<id>`; re-bake with `tools/bake_sounds.gd` (`test_sounds`
      checks the stamp).
- [ ] `scripts/audio/sfx.gd`: `call_<id>`, `alarm_<id>` cue settings.

## Optional lists
- [ ] `scripts/ui/menu_backdrop.gd` `BIRDS` (the menu's rail), `scripts/race/race_course.gd` `STYLES` birds,
      `tests/test_combat_boom_zoom.gd` `HITS`.

## Derived, no table
`CombatStyle` (from roll rate and stall), the bullet hit radius, `CombatSkill`'s weapon via the style, the race
envelope. Re-check combat and race behaviour after adding a bird: the hawk's turning circle plans courses by default.

## Docs
- [ ] `README.md` (the species list), `docs/design/flight_model.md` section 8 and the climb-trim table,
      `docs/design/wing_rig.md` species table, `wing_rig_plan.html`, `docs/design/combat_ai.md` style table,
      `docs/tutorial/tactics.md`, the `AGENTS.md` bullets that list species.

## Then
Every test looping over `BirdProfile.all()` / `IDS` runs the new bird: flight (`test_bird_profiles`, `test_glide_trim`,
`test_stall`, `test_energy`, `test_flap_trim`, `test_ground_takeoff`, `test_flight_controls`), AI and race
(`test_ai_flight`, `test_race`), the rig (`test_bird_rig`, `test_wing_shape`, `test_face`, `test_bill_profile`,
`test_neck_seam`, `test_leg_rig`, `test_landing_legs`, `test_posture`, `test_takeoff_pose`, `test_wingbeat_onset`),
the tack, the menu and smoke tests, the `gpu_test_*`. All must pass.
