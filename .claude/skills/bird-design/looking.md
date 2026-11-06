# Looking at a bird

Never launch a windowed Godot directly: these scripts run it on a hidden desktop, muted (`AGENTS.md`).
`FLAP_SHOW_WINDOWS=1` to watch one.

## The rig gallery (`scripts/app/rig_gallery.gd`)

```
.\run.ps1 --scene res://scenes/rig_gallery.tscn --only <id> --view <view> --pose <pose> --shot <png>
```

| Flag | What |
|---|---|
| `--only <id>` | one bird, framed close |
| `--pose glide\|flap\|upstroke\|folded\|flare` | a static pose (`RigPoses`); folded is perched, feet gripping |
| `--view top\|front\|three\|under\|side\|wing\|lead\|head\|profile\|nape\|throat\|feet\|toes` | the camera: `wing` / `lead` the arm wing, `nape` / `throat` the neck's joins, `feet` / `toes` the grip |
| `--zoom <x>`, `--ortho` | closer; orthographic (true silhouette; use it for close-ups, perspective clips on the near plane) |
| `--sun front\|back`, `--light studio\|flat` | back light shows translucency |
| `--time <s>` | freeze the clock: repeatable shots for A/B |
| `--plumage 0..6`, `--chart`, `--relief <x>`, `--variety <x>` | plumage level, the feather chart, texture relief and variation (0 off) |
| `--no-cards`, `--no-down`, `--feather-shader` | silhouette cards off, outline fray off, the parked shader |
| `--cpu-feathers`, `--cpu-body` | the GDScript builds (A/B against the GPU) |
| `--legs detail\|capsules`, `--branch` | the leg model; draw the branch the folded pose grips |
| `--shot <png> --shot-after <s>`, `--measure <n>` | save and quit; mean GPU and pose ms over n frames |

A before/after set for every species: loop over `crow sparrow hawk falcon owl` and the views you're changing, the
same flags each time, and tile them into one sheet (Python + PIL) for comparison. Keep the ones worth keeping in
`docs/images/<part>_before.jpg` / `_after.jpg` (JPEG; stage by path).

## Other views

- Tack gallery: `.\run.ps1 --scene res://scenes/tack_gallery.tscn [--bird <id>] [--sheet <png> [--macros | --heads | --mounts]]`.
- Bird lab (motion, ghosts, bone view, scenarios): `.\lab.ps1 <bird> <scenario>`; the menu's Lab.
- The game itself, for colours in game light from the chase camera: `.\run.ps1 --bird <id> --shot <png>`.

## Charts and probes (`.\probe.ps1 [-Headless] <name> [args]`)

- `probe_beak_profile` + `tools/beak_profiles.py`: bills in profile against their photos (`bills.md`).
- `probe_coplanar [pose]` (z-fighting feather pairs), `probe_fold_top` (folded pieces above the back),
  `probe_feather_chart` (the chart's u/v at the neck's ends).
- `probe_pose_jerks` (one-tick snaps of the head, bill, feet), `probe_foot_frame`, `probe_legs` (leg cost),
  `probe_landing_legs`, `probe_takeoff_neck`.
- `probe_tack_fit`, `probe_rider_scale` (the largest rider every bird carries).
- `tools/light_match.py <ref.jpg> <sheet.png>`: a render's light against a concept.
- Timing: the gallery's `--measure`, and `.\perf.ps1` in the game (`docs/design/performance.md`).
