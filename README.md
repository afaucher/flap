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
.\run.ps1 --scene res://scenes/rig_gallery.tscn --pose folded --view feet --branch --legs detail   # the detailed legs and feet (LegRig, off by default)
.\run.ps1 --scene res://scenes/bird_lab.tscn   # the bird lab: species, poses, take-offs and landings from several approaches; slow-mo, pause/step, onion-skin ghosts, orbit camera
.\run.ps1 --scene res://scenes/bird_lab.tscn --bird hawk --scenario land_above --speed 0.25 --onion   # start straight into one
.\run.ps1 --scene res://scenes/bird_lab.tscn --bird owl --scenario pose_folded --bones   # the skeleton drawn over the bird (B cycles: off / over / bones only)
.\test_runner.ps1 -TestAll     # headless tests
.\build.ps1                    # tests, then export build\windows\Flap.exe + zip
```

Godot 4.7 is found via `$env:FLAP_GODOT`, `..\Hero-Reader\third_party\godot`, or `..\cast\build\deps`.
Export templates are copied from `..\cast\build\deps\godot-data` on the first build.

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
| | F3 | debug panel: angle of attack, CL, L/D, wing areas |

**HUD.**
- Speed tape with stall, catch and best-glide marks, and the current speed band (STALL, CATCH, SLOW, GLIDE, FAST, DIVE).
- Pitch ladder: nose, flight path and the green ideal-glide line.
- Roll arc with red bank-limit ticks.
- Burst and stamina bars.
- Stick position.

**Audio.** The wind rises with speed. Each speed band boundary plays its own whoosh: rising when you speed up, falling when you slow down. When you drop under catch speed you hear it, and best glide has its own whoosh too. Wingbeats thump.

**Perching.** Approach the perch slower than the cyan "catch" speed: dive under it and swoop up. Hold catch on the way in.

**Low and slow.** Ground effect (within about 1.5 spans of the ground) cuts drag and strengthens wingbeats, so a downed bird can flap back up.

Design: `docs/design/flight_model.md`. Research: `docs/research/`.
