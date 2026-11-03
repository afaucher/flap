# Flap

A bird flight combat demo in Godot 4.7. Fly a bird around a greybox arena of trees, flap and glide, and catch
perches to rest. This is the flight-model prototype; combat comes next.

## Run

```powershell
.\run.ps1                      # play (crow)
.\run.ps1 --bird falcon        # crow | owl | hawk | falcon | sparrow
.\run.ps1 --seed 3 --ai 5      # another arena, more AI birds
.\run.ps1 --autopilot          # watch your bird fly itself (P toggles)
.\run.ps1 --scene res://scenes/rig_gallery.tscn --pose flap --view three   # the bird models side by side
.\run.ps1 --scene res://scenes/rig_gallery.tscn --only hawk --view under --sun back   # one bird, backlit (add --feather-shader for the parked feather shader)
.\run.ps1 --scene res://scenes/rig_gallery.tscn --pose folded --view feet --branch             # the detailed legs and feet (--legs capsules: the old ones)
.\run.ps1 --scene res://scenes/bird_lab.tscn   # the bird lab: species, poses, take-offs and landings from several approaches; slow-mo, pause/step, onion-skin ghosts, orbit camera
.\run.ps1 --scene res://scenes/bird_lab.tscn --bird hawk --scenario land_above --speed 0.25 --onion   # start straight into one
.\run.ps1 --scene res://scenes/bird_lab.tscn --bird owl --scenario pose_folded --bones   # the skeleton drawn over the bird (B cycles: off / over / bones only)
.\test_runner.ps1 -TestAll     # headless tests
.\build.ps1                    # tests, then export build\windows\Flap.exe + zip
```

Godot 4.7 is found via `$env:FLAP_GODOT`, Flap's own `build\deps` (gitignored), `..\cast\build\deps`, or
`..\Hero-Reader\third_party\godot`. Export templates are copied from `..\cast\build\deps\godot-data` on the first
build. Every build is stamped `yyyy-MM-dd.HHmmss` (`build.ps1`), shown in a corner of the game's HUD and the bird
lab (`scripts/ui/build_version.gd`; a source run says `dev (...)`).

## Controls

A gamepad is the recommended way to fly: the left stick has a real centre (wings level, best glide).

| Gamepad | Keyboard + mouse | Effect |
|---|---|---|
| Left stick | mouse (click to capture, Esc releases) | bank left/right; pull back = climb, lose speed, flare; push = dive, gain speed, tuck past half |
| (let go) | (let go: drifts back; C / middle mouse snaps) | centre = wings level, best glide |
| Left trigger | Space | flap (hold to keep flapping); from a perch or the ground: take off |
| A (hold) | Ctrl (hold) | catch: hold it through the approach and the bird catches the perch the moment it's in reach and slow enough. On a perch, a fresh press lets go and drops. |
| Right stick | | tilt / orbit the camera (springs back) |
| Left stick while perched | mouse while perched | turn on the perch to look around; you leave the way you face |
| Back / Start / Y | 1-5 / R / P | change bird / respawn / autopilot |
| | F1 | show the key hints again |
| | F3 | instruments and debug panel: speed tape, pitch ladder, bank arc, stick; angle of attack, CL, L/D, wing areas |

**HUD.**
- Top left: your bird, burst and stamina (in a fight, health and rounds under them).
- Speed shows where it matters, on the perch: hold catch and the perch you're heading for is marked, with a
  gauge of your speed against the catch speed (green: it will hold; red: slow down).
- Prompts at the bottom (stall, too fast, perched); key hints fade after a few seconds.
- `--hud dev` puts every instrument on screen (speed tape, pitch ladder, bank arc, stick); `--hud ring` wraps the
  status round the aim circle.

**Audio.** The wind rises with speed. Each speed band boundary plays its own whoosh: rising when you speed up, falling when you slow down. When you drop under catch speed you hear it, and best glide has its own whoosh too. Wingbeats thump, each species its own (an owl's next to silent).

Everything else (`GameAudio`, `docs/design/audio_plan.md`):
- **Combat:** launches with motors that ride each round, bursts by what they hit, feather puffs, the downed flutter.
- **Lock tones:** beeps that quicken and rise as a lock builds, a steady tone once locked, a low pulse when someone is
  locking you, and a warble that speeds up as a seeker closes.
- **The base:** a clink for each round restocked, then a chime.
- **Perches and trees:** talons on the perch, take-off pushes, bonks.
- **Calls:** each species' contact call and alarm.
- **The forest:** canopy wind louder with height, insects near the ground, pinewood birdsong.

The sounds are baked by `tools/bake_sounds.gd` from `SoundRecipes`; re-run it after changing a recipe.

**Perching.** Approach the perch slower than the catch speed (the perch's gauge turns green): dive under it and swoop up. Hold catch on the way in.

**Low and slow.** Ground effect (within about 1.5 spans of the ground) cuts drag and strengthens wingbeats, so a downed bird can flap back up.

Design: `docs/design/flight_model.md`. Research: `docs/research/`.
