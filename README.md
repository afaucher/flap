# Flap

A bird flight combat demo in Godot 4.7. Fly a bird around a greybox arena of trees, flap and glide, and catch
perches to rest. This is the flight-model prototype; combat comes next.

## Run

```powershell
.\run.ps1                      # play (crow)
.\run.ps1 --bird falcon        # crow | owl | hawk | falcon | sparrow
.\run.ps1 --seed 3 --ai 5      # another arena, more AI birds
.\run.ps1 --autopilot          # watch your bird fly itself (P toggles)
.\test_runner.ps1 -TestAll     # headless tests
.\build.ps1                    # tests, then export build\windows\Flap.exe + zip
```

Godot 4.7 is found via `$env:FLAP_GODOT`, `..\Hero-Reader\third_party\godot`, or `..\cast\build\deps`.
Export templates are copied from `..\cast\build\deps\godot-data` on the first build.

## Controls

| Input | Effect |
|---|---|
| Click | capture the mouse (Esc releases it) |
| Mouse left / right | bank (bank-and-yank: bank, then pull to turn tighter) |
| Mouse toward you / away | pull back (climb, lose speed, flare) / push forward (dive, gain speed, tuck past half) |
| Let go | the stick drifts back to centre: wings level, best glide |
| Space | flap (hold to keep flapping); catch a perch when the ring is green; drop off a perch |
| C or middle mouse | centre the stick |
| 1-5 | switch bird (crow, owl, hawk, falcon, sparrow) |
| R | respawn  ·  P autopilot  ·  F3 debug (angle of attack, CL, L/D, wing areas) |

**HUD.**
- Speed tape: stall, catch and best-glide marks.
- Pitch ladder: nose, flight path and the green ideal-glide line.
- Roll arc: red bank-limit ticks.
- Burst and stamina bars.
- Stick position.

**Perching.** Approach the perch slower than the cyan "catch" speed: dive under it and swoop up. Press Space
inside the ring.

Design: `docs/design/flight_model.md`. Research: `docs/research/`.
