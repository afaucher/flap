# Performance

Where a frame's time goes, what was done about it, and the rules that keep it there (2026-11-02). Measure with the
frame profiler: `.\perf.ps1 [-Bird hawk] [-Ai 3] [-Seconds 15] [-Extra --max-steps,3]` runs the game windowed and
writes a per-frame CSV and a summary (each `Perf` section per frame and per physics tick, frame pacing, ticks per
frame, the worst frames, the machine's CPU load while it ran). Code marks sections with `Perf.t()` / `Perf.add()`.

## What costs

Almost all of it is GDScript posing the birds' rigs. Rendering (about 1-3 ms GPU for 4 birds, 6-9 ms for 20) and
the physics engine itself (moving the birds: under 1 ms a tick for 20) are small; Jolt measured the same as the
default engine.

| 20 birds, per rendered frame | Mean | p95 |
|---|---|---|
| Start (legs rebuilt every tick, rig posed every tick) | 684 ms | 834 ms |
| Legs GPU-skinned | 427 ms | 562 ms |
| Arm and neck lofts moved in place, feathers' instance data written once | 290 ms | 380 ms |
| Rig posed once per rendered frame | 57 ms | 100 ms |
| ... and at most 3 catch-up ticks a frame | 50 ms | 92 ms |

Four birds: 94 ms -> 16.7 ms mean (60 fps), p95 206 -> 30 ms.

Posing the rig every frame for the drawn moment instead of on the tick (below) costs the same: 8.5 vs 8.3 ms of rig a
frame for 4 birds, 37.8 vs 37.3 ms for 20 (`-Extra --rig-tick` for the comparison). What it changes is what moves
when: at 4 birds about 1 frame in 85 runs no tick or two, and at 20 birds 4 frames in 5 run two or three; posed on the
tick, the lofts and legs stepped with those while the body and feathers moved smoothly.

## Rules

- **Pose the rig once per rendered frame, for the moment the frame draws** (`Bird._process`). With physics
  interpolation on, a frame draws each body between its last two ticks, `Bird.drawn_lag()` behind the latest. The rig
  is posed for that moment (for the simulated time since its last pose) with physics interpolation off on the rig, so
  the engine doesn't interpolate it again: feathers, lofted wing and neck, skinned legs and the tack all move every
  frame with the body. A frame catching up runs several ticks but draws once, and the rig with it (posing on every
  tick multiplied its cost by the catch-up ticks, so one slow frame made the next slower). Posed on the tick instead
  (the game's `--rig-tick`, kept for comparison), the feathers were interpolated but the lofts and the legs' bones
  aren't, so they stepped with the ticks: on a frame with no tick, or two, the wing surface held still or jumped
  against its own feathers. `test_rig_pacing`.
- **Simulation on the tick, drawing for the drawn moment** (Godot's physics interpolation docs). The birds, the AI,
  the flight model, rounds in flight and trail sampling run in `_physics_process`. What `_process` places by hand is
  placed for `drawn_lag()` behind the tick, with interpolation off on those nodes: rounds between their last two
  positions, smoke and wing trails running to where the round or wingtip is drawn. The chase camera follows
  `get_global_transform_interpolated()` with its own interpolation off, the docs' camera pattern. The tack is posed
  by the rig (`BirdRig.posed`), never apart from it. `test_drawn_moment`.
- **At most 3 catch-up ticks a frame** (`project.godot` `physics/common/max_physics_steps_per_frame=3`; the game's
  `--max-steps` overrides it). Overloaded, the game runs a little slow for a moment instead of skipping ahead in
  ever longer frames.
- **Don't rebuild meshes in GDScript every pose.**
  - The legs are skinned on the GPU (`docs/design/legs_and_feet.md` §7); their trousers are re-rested only when the
    leg's exit from the body drifts `TROUSER_DRIFT`.
  - The arm wing and the neck are `LoftMesh`es: built in full (colours, coordinates, SurfaceTool-smoothed normals)
    only when what those carry would change, otherwise only positions and normals are written into the vertex
    buffer. `test_loft_mesh` holds the fast path to the full build.
  - The feathers write only their transforms each pose; their instance data (strip row, share of the flex, atlas
    cell, seed) is written when the feather set or paint changes, and the wing's flex reaches the shader as one
    uniform.
- **Never read a mesh back from the GPU in a frame** (`RenderingServer.mesh_get_surface` stalls: a 30 ms frame).
  Keep CPU copies of what was written (`LoftMesh.positions`); tests read those (`BirdRig.drawn_arrays`,
  `LegRig.drawn_arrays`), since the headless renderer can't read updated meshes back either.
- **Fidelity first.** Performance work keeps the look; any level of detail, update throttling or simplification is
  proposed with its visual cost and agreed before it goes in. Approved for distant AI birds: keep the silhouette and
  the key colours; tolerances (the legs' drift) may grow with distance.

## What's left

A rendered frame at 60 fps allows about 0.5 ms of rig a bird for 20 birds; it is about 1.9 ms. Per bird per pose:
feather placement and writes ~0.8 ms, the arm loft ~0.7 ms, the neck ~0.5 ms, legs ~0.1 ms plus a trousers rebuild
(~3 ms) every few ticks while they swing. The 4-bird hitches (p95 30 ms) are mostly trousers rebuilds coming
together: 10-18 ms frames when several birds' legs swing at once (landings, take-offs). Next: the distant-bird level of
detail above, and spreading or cheapening those rebuilds; then, if needed, the feather placement in compiled code or a
vertex shader.

## Proof of concept: feathers placed on the GPU (branch `gpu-poc`, 2026-11-02)

The game's `--gpu-feathers` (`BirdRig.gpu_feathers`) moves the flight and tail feathers' placement from GDScript into
the feather shader (`feather_place.gdshaderinc`). Each pose writes about 150 numbers (each wing's joints and normals,
the fold, the tail's frame) into a small float texture. Each feather's own definition goes into another texture
once: the only part of it that changes with the fold and slot, its angle, is linear in both, so it is stored as
three terms and worked out in the shader. The instances' transforms stay identity, so their bounds are set by hand
(`custom_aabb`). The silhouette cards share the material and keep their own transforms (`def_offset` -1).

Measured A/B (game on autopilot, quiet machine, 15 s runs):

| | Feathers placed in GDScript | Placed in the shader |
|---|---|---|
| 4 birds: rig per frame | 11.3 ms | 8.4 ms |
| 4 birds: wings and feathers | 5.4 ms | 2.5 ms (mostly the arm loft) |
| 20 birds: rig per frame | 58 ms | 45-50 ms |
| GPU time, 4 birds | 7.35 ms | 7.29 ms |

The pictures match: in the rig gallery (glide, flare, folded, flap from below and the side) at most 15 of 1.44
million pixels differ, along feather edges.

Tests read back what the GPU computed. `tests/gpu_test_feathers.gd` evaluates the same include in a canvas pass into
a half-float target (each value split hi + lo, about float precision) and compares every feather with the rig's own
placement: within 0.2 um, every species, spread to folded, alula, slots, lost feathers. GPU tests are named
`gpu_test_*` and run windowed (`test_runner.ps1` leaves out `--headless` for them), since the headless renderer runs
no shaders.

What stays on the CPU: the rig's own placement, for what reads feathers in the game. A perched bird's lean reads
every feather's tip each pose (`_posture`), so perched birds still place them in GDScript; a hit works out the
flight feathers for that pose (`flight_feathers`). The CPU copy is also what the GPU test compares against. Moving
those readers off the feathers (the lean from the wing joints, the hit from the defs) would leave one copy.

![Feathers placed in GDScript and in the shader, and their difference](../images/gpu_feathers_ab.jpg)
