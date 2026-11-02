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

## Rules

- **Pose the rig once per rendered frame** (`Bird._physics_process`: on the frame's first tick, for the time since
  it was last posed). A frame catching up runs several ticks but draws once. Posing on every tick multiplied the
  rig's cost by the catch-up ticks, so one slow frame made the next slower. It stays in the physics tick, where the
  feathers' MultiMesh transforms are interpolated tick to tick (posing from `_process` breaks that: Godot warns).
  `test_rig_pacing`.
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
(~3 ms) every few ticks while they swing. Next: the distant-bird level of detail above; then, if needed, the
feather placement in compiled code or a vertex shader.
