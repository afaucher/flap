# Flap: combat AI design (draft, 2026-11-02)

A plan for an AI that fights: picks a target, flies for a shot, fires when the shot is good, defends against
rockets and seekers, and breaks off to rest on a perch or fly home to its base to rearm. It builds on the combat range
(`scripts/combat/`, `.\range.ps1`) and on the flight AI (`scripts/ai/`). Stages 1-3 of the build order are built
(section 11 says what, and what the flight model taught us on the way); section 1 describes the range before them.

Read first: `docs/design/flight_model.md` (sections 2, 6 and 8), `docs/design/combat_concepts.html`
("Ranged") and `docs/design/concept_briefs.html` (Hedgerow Aces).

**Decided with the user (2026-11-02):**
- **Two teams, 3 v 3** for now (player + two AI wingmen against three AI; or 3 AI v 3 AI in tests).
- A downed bird **respawns at its team's base** (an outpost, section 7).
- **Ammo restocks only at your own base**, and lost feathers grow back only there; stamina recovers on any
  perch (section 4.7).
- **One kind of round per bird**: six rockets or four seekers (no switching). **Damage is feathers**: a hit
  knocks out 2-3 flight feathers, eight down the bird (section 1).
- Default difficulty is **medium** (the `pilot` preset, section 6).
- **Ambushing from a perch is a valid tactic** (section 4.7), not only resting.
- The decision layer is a **Beehave behaviour tree** if a headless spike passes Flap's strict test runner
  (section 3.2); otherwise a plain GDScript selector behind the same leaf interface.

## 1. What exists today

There is no combat AI. There are three pieces that each do one narrow job:

| Piece | What it actually does |
|---|---|
| `AICombat` (`scripts/combat/ai_combat.gd`, 22 lines) | A trigger finger only. Seekers: presses fire the tick the launcher reports a lock. Rockets: presses fire when the HUD's lead point is under 28 m away and within 5° of the aim. Switches to its preferred weapon while that has ammo. It never steers, never rations ammo, never thinks about rearming. |
| `CircuitPilot` (`scripts/combat/circuit_pilot.gd`) | **CIRCUIT**: flies a looped racetrack at a fixed height. **CHASE**: aims 12 m behind its quarry, or at the quarry plus a fraction of its velocity once within 30 m. **Break**: when `CombatWorld.threat_to()` reports something, it banks 95% toward one side and pulls for 1.1 s, then goes back to what it was doing. It has **no tree avoidance**; the range only works because the racetrack is checked clear of trunks once at setup and the chase stays up at 20 m. |
| `AIPilot` + `FlightPlanner` (`scripts/ai/`) | Perch-to-perch flight: picks a reachable perch, A*-plans through free air, flies the route, avoids trees, lands, rests. Knows nothing about other birds or weapons. |

How the range uses them (`scripts/app/combat_range.gd`):
- The target flies `CircuitPilot` CIRCUIT and breaks when threatened. Its launcher has **no controller**: it
  never shoots back.
- `--demo` flies your bird with `CircuitPilot` CHASE and fires with `AICombat`. `test_combat._range` checks
  that this lands at least one hit in 18 s and that the target breaks at least once.

What the combat systems give an AI to work with:
- **Launcher** (`launcher.gd`): fixed forward along the flight path (aim by flying). Rockets: 0.25 s cadence
  while held. Seekers: lock after 1.0 s inside a 15° cone (kept to 25°), 6-40 m. Rearm (and mend) by
  sitting 2 s on the base perch (`Launcher.rearm_perch`; unset, any perch). `lead_point()` is the HUD's lead
  marker. Each pod holds rockets x3 or seekers x2 and a bird carries one kind: **six rockets or four seekers**
  (`Saddle.DEFAULT_LOADOUT` is rockets; the range's `--seekers`); weapon switching is a no-op with one kind.
- **Projectiles** (`projectile.gd`, pure and headless): rocket ~47 m/s peak, 1.0 s life (~40 m), unguided,
  drops under gravity. Seeker ~35 m/s, 2.2 s life, lead pursuit capped at 150°/s, loses the target outside a
  60° gimbal. Both arm after 3 m, proximity fuse 1.0 m, and **burst on trunks, branches and the ground**.
- **Damage** (`combat_world.gd`, `Bird.lose_feathers`): a burst within 1.3 m stuns 0.5 s, shoves, and knocks
  out the flight feathers nearest it: 2 or 3 inside the fuse's reach (2.5 on average), 1 in the blast's outer
  ring. The damaged wing loses that area (`FlightModel.wing_loss`): less lift, and it drops, so the bird rolls
  toward it unless the stick holds it off (the AI's bank law has to trim for it; `telemetry().wing_loss`).
  **Eight feathers down a bird** (2.5 s stun, `downed`); `Bird.health()` is 1 - lost / 8, shown as a bar on
  the HUD (yours, and a small one under the target's bracket).
- **Threat cue**: `CombatWorld.threat_to(bird)` returns the nearest round within 25 m heading at the bird, or
  a launcher with a lock above 50%. The player's HUD shows **neither** (no lock warning, no missile warning):
  today the target "knows" more than a player would.

## 2. Rules the combat AI keeps

These extend the project rules in `AGENTS.md`:
1. **The player's authority.** Two controllers per AI bird, nothing else: a flight controller producing
   `FlightInput` and a weapons controller producing `CombatInput`. No reaching into `FlightModel`,
   `Launcher` or `Projectile` state to change it.
2. **The player's information.** The AI reads what a player could see or the HUD shows: birds in its view
   (with a rear blind spot and line of sight through the trunks), smoke trails of rounds in flight, its own
   launcher's lock and lead, and warnings the HUD also gives the player. Section 7 lists what has to be added
   so the player gets the same warnings.
3. **Geometry, not physics.** Line of sight, firing lanes and escape routes use `ArenaLayout` queries
   (`segment_clear`, `segment_clear_among`, `trees_near_segment`); no `intersect_ray` per tick.
4. **One tree-avoidance.** Combat flight goes through `AIPilot`'s avoidance (`_avoid` / `_predict`, being
   reworked on `claude/ai-tree-avoidance-0f8387`), not a second copy.
5. **Every assist and cheat is switchable to 0**, and difficulty only ever *removes* skill (reaction time, aim
   error, awareness); no difficulty level gives the AI extra speed, ammo or information.

## 3. Architecture

```
            sense (what it can see)          decide                       act
Bird ─────► CombatSense ─► Picture ─► CombatBrain ─► Intent ─┬─► CombatPilot ─► AIPilot.steer() ─► FlightInput
CombatWorld                                (tactics,          └─► AICombat (fire control) ─────────► CombatInput
Launcher                                    per-species
ArenaLayout                                 CombatStyle,
                                            CombatSkill)
```

New files, all under `scripts/combat/ai/` (pure `RefCounted`, headless-testable like `FlightModel`):

| Class | File | Job |
|---|---|---|
| `CombatSense` | `combat_sense.gd` | Builds a `Picture` each tick (throttled by `CombatSkill.reaction`): other birds it can see (view cone, range, line of sight through trees) with remembered tracks for ones it lost; rounds in flight it can see (by their smoke) with time-to-go and miss distance; warnings (being locked); its own state (height, speed, energy height, stamina, burst, ammo, hits taken). |
| `Engagement` | `engagement.gd` | Static geometry, no state: range, closure, antenna-train angle (ATA, target off my nose), aspect angle (AA, me off the target's tail), the target's turn circle, pursuit points (lead / pure / lag), "can I point at it in t seconds" from roll rate and turn rate, and the energy-height difference. |
| `CombatStyle` | `combat_style.gd` | Per-species numbers **derived from `BirdProfile`** (section 5), not hand-typed: sustained and corner turn rates, turn radius, roll time to 90°, stoop speed, climb budget, how it compares with each projectile. |
| `CombatSkill` | `combat_skill.gd` | Difficulty knobs (section 6) and three presets. |
| `CombatBrain` | `combat_brain.gd` | Owns the bird's behaviour tree and blackboard (3.2): target selection and the modes (section 4) as tree branches. Outputs an `Intent`: where to fly (a point, or a point plus a heading), how hard (bank fraction, flap policy), and what the weapons should do (weapon, fire / hold / hold-for-lock). Shared by `CombatPilot` and `AICombat` (both hold the same brain, which is ticked once per physics tick). |
| `CombatPilot` | `combat_pilot.gd` | The flight controller (`sample(bird, dt) -> FlightInput`). Turns the `Intent` into an aim point and hands it to `AIPilot.steer()`. In REARM it lets `AIPilot` fly its perch logic unchanged. |
| `AICombat` | `scripts/combat/ai_combat.gd` (rewritten) | The weapons controller (`sample(launcher, dt) -> CombatInput`): weapon choice and fire control (section 4.5). |
| `Duel` | `scripts/test_support/duel.gd` | Headless duel harness (section 8). |

### 3.1 Reusing the flight AI

`AIPilot._fly` today mixes three things: following its own route, the guidance law (bank-to-turn, path
angle, flap policy, ground guard, stall recovery), and avoidance. Once the avoidance rework has landed on
master, one refactor in `ai_pilot.gd` gives combat what it needs:

- **`AIPilot.steer(bird, aim: Vector3, dt, opts := {}) -> FlightInput`**, public: the guidance law plus
  `_avoid` / `_predict`, ground guard and low-speed recovery, toward an aim point supplied by the caller,
  with no perch or catch logic. `_fly` becomes route-following that calls `steer()`. Options:
  - `bank_frac` (combat wants up to ~0.95 of the bank limit; cruise keeps 0.85),
  - `gamma` (path angle to hold, for zooms and stoops instead of the one that reaches `aim`),
  - `flap`: `AUTO` (today's policy), `HOLD_SPEED(v)`, `SPRINT` (any wingbeat, for defending), `NONE`,
  - `ignore_tree` (a perch being left).
- `_predict` currently follows `route[wp..]` when steering at a point. For `steer()` with no route it
  predicts straight at `aim` (the same law as `is_point` with a one-point route). The target moves, but the
  prediction horizon is ~1 s and is re-run every tick, so a fixed aim per tick is enough.
- **Avoidance wins.** If `_avoid` says the wanted path is blocked, `steer()` flies the escape and reports
  `avoiding > 0`; `CombatBrain` reads that and holds fire (the gunsight isn't on anything it chose).
- **Routes for repositioning.** When the target is behind trees (no line of sight) or far away,
  `CombatBrain` asks `FlightPlanner.plan(from, to)` for a route to a point behind or above it and
  `CombatPilot` follows the waypoints the way `_fly` does. Re-plan at most every 1.5 s (planning is the
  expensive call; `Perf` section `ai.plan`).
- **Rearm and rest** reuse `AIPilot` whole: `CombatBrain` picks the perch (section 4.6), sets it as
  `AIPilot.target` (a small public `go_to_perch(bird, perch)`), and `CombatPilot` returns `AIPilot.sample()`
  until the bird is perched, rested and rearmed.

`ai_pilot.gd`, `flight_planner.gd` and `arena_layout.gd` are not edited until the avoidance branch lands.
Everything in sections 4-8 can be built against today's `AIPilot` API through `steer()`; until it exists,
`CombatPilot` can call a thin local wrapper so the brain and the tests don't wait on it.

### 3.2 The decision layer: a Beehave behaviour tree

`CombatBrain`'s mode machine (4.3) is a priority list with multi-second actions (a stoop, a yo-yo, a landing
to rearm), and 3 v 3 adds roles and per-species variants (owl ambush, falcon boom-and-zoom). That is what a
behaviour tree composes well, and the sibling projects already use one: `project_deep_space` and
`team-dark` vendor **Beehave 2.9.2** (`addons/beehave`), with trees built in code by a factory
(`project_deep_space/scripts/ai/ai_tree_factory.gd`) and ticked headless in tests
(`test_ai_beehave_spike.gd`). Flap copies that pattern.

**Split of work.** The tree decides; it never flies.
- **Leaves are thin.** Conditions read the blackboard (`Picture`, `Engagement` numbers, team state);
  actions write an `Intent` to it (aim point, `steer()` options, weapon, fire policy) and return RUNNING
  while a manoeuvre is in progress. All the maths stays in the pure classes (`Engagement`, fire control,
  `CombatStyle`), so it is unit-tested without the tree.
- **`CombatPilot.sample()` ticks the tree once per physics tick** (Beehave `process_thread = MANUAL`, as
  deep space's spike does), then turns the `Intent` into `FlightInput`; `AICombat.sample()` reads the same
  `Intent` for `CombatInput`. Order within a tick stays deterministic, and the AI still has only the two
  input surfaces.
- **The tree is a child of the `Bird`** (Beehave trees are Nodes), its `actor` the bird, one `Blackboard`
  per bird. A team-shared blackboard (`TeamBoard`, section 4.8) holds who is targeting whom.
- **Built in code** by `scripts/combat/ai/combat_tree.gd` (`CombatTree.build(style, skill)`), not
  `.tscn`, so species variants are data plus small subtree swaps:

```
Selector (root)
├── Sequence  Defend          [ThreatImminent?] → DefendAgainst(threat)        (rocket sidestep, seeker break, drags)
├── Sequence  Recover         [Stunned?] → HoldLevel
├── Sequence  Rearm           [OutOfAmmo?] → Extend → FlyHome → LandAndRest
├── Sequence  Rest            [Tired? or Hurt?] → Extend → PickSafePerch → LandAndRest
├── Sequence  Ambush          [StyleAmbushes? and SafePerchWithView?] → PerchAndWatch → DropOnTarget
├── Sequence  Support         [TeammateUnderAttack?] → TargetTheAttacker
├── Sequence  Fight           [HasTarget?]
│   └── Selector
│       ├── Sequence  Extend      [Outmatched?] → Extend
│       ├── Sequence  Attack      [InEnvelope?] → Pursue(lead|pure) + FireControl
│       └── Reposition            (lag, yo-yos, stoop / zoom by style, route around trees)
└── Patrol                        (perch-hop or loiter near the team, scanning)
```

**Risks, checked by a spike first** (`tests/test_combat_tree_spike.gd`, step 1 of section 9):
- **Flap's runner fails on any engine `ERROR:`/`WARNING:` line.** Deep space notes Beehave's debugger
  prints `Capture not registered: 'beehave'` on shutdown, even on passing tests. The spike must run clean
  under `.\test_runner.ps1`; the likely fix is leaving Beehave's debugger autoload out (or disabling it
  headless), not loosening the runner.
- **Godot 4.7**: Beehave 2.9.2 was used on an earlier 4.x; the spike confirms it loads and ticks.
- **Class cache**: deep space found the global class cache needs warming (`--import`); `build.ps1` already
  imports first, and the spike checks a cold run.
- **Cost**: a tree tick for 6 birds at 60 Hz must stay inside the AI budget (section 8, `Perf` section
  `ai.combat.tree`).

If the spike fails and can't be fixed cheaply, the same tree shape runs on a ~100-line GDScript
`Selector` / `Sequence` with the same leaf interface (deep space's documented fallback); the leaves and
tests don't change.

## 4. Behaviour layers

`CombatBrain.tick(picture)` runs these in order, every physics tick (cheap parts) or every
`CombatSkill.decide_every` (0.1-0.25 s: target choice, mode, re-plans).

### 4.1 Situation

From the `Picture`:
- **Energy height** `E = y + v²/2g` for each bird, and `ΔE` against the target. Height is stored speed; the
  falcon and hawk fight on it.
- **Geometry** of each seen bird: range, closure, ATA, AA.
- **Threats**: rounds with predicted miss distance < 3 m and time-to-go < 1.2 s; any bird with me inside its
  nose cone (ATA < 25°) within 40 m; a lock warning.
- **Own reserves**: stamina, burst, ammo, health (`Bird.health()`, on the player's HUD too) and which wing
  the damage is on.

### 4.2 Target selection

Score each visible (or recently seen) enemy, highest wins, re-chosen every `decide_every`:
- closer is better (`-range / 20`), on my nose is better (`-ATA / 45°`), its tail toward me is better
  (`-AA / 90°`: a tail chase is the easy shot),
- `+ΔE / 5 m` (I have the height on it), `+2 x (1 - health)` (finish it: its feathers show), `+2` if it is attacking me,
- `+2` if it is attacking a teammate (the Support branch), `-1.5` per teammate already on it unless it is
  attacking me (spread the targets, don't all chase one bird),
- `-3` if there's no line of sight and no route shorter than 40 m,
- **hysteresis**: the current target gets `+1.5` so the AI doesn't flick between two similar ones.

Only enemies (the other team) are scored. No target: PATROL (fly a loose circuit near the team at the
style's preferred height, scanning).

### 4.3 Modes

| Mode | Enter when | What it flies |
|---|---|---|
| **PATROL** | no target | `AIPilot` perch-hopping at a preferred height, or a loiter circle; looking for targets |
| **ENGAGE** | target chosen, not yet in a shooting position | positioning: pursuit geometry (4.4), energy use, routes around trees |
| **ATTACK** | target inside the current weapon's envelope or about to be | the weapon's pursuit (lead for rockets, pure for a seeker lock), fire control on |
| **DEFEND** | a threat (4.1) | the defence for that threat (4.6); overrides everything for its duration |
| **EXTEND** | outmatched (enemy behind me and `ΔE < 0`), or after a missed stoop | unload and run along the clearest line away, flapping, to rebuild speed and height, then re-engage |
| **REARM** | out of ammo | disengage, fly home to the team's base (the only place ammo restocks), land, rearm, take off (4.7) |
| **REST** | stamina < `skill.rest_at`, or health ≤ 0.5 | tired: a safe perch in reach (the base if it is); hurt: the base, the only place feathers grow back (4.7) |

These are the branches of the tree in 3.2 (ENGAGE is its Reposition leaf), plus Ambush and Support.
Each mode has a minimum dwell (0.6 s) and exit hysteresis so the AI doesn't twitch between them. DEFEND has
no dwell: it ends when its threat is gone.

### 4.4 Engagement geometry

The launcher is fixed forward, so aiming is flying. `CombatPilot` picks the aim point fed to `steer()`:
- **Lead pursuit**: aim at the rocket lead point (`Launcher.lead_point`), cutting inside the target's turn.
  Used in ATTACK with rockets.
- **Pure pursuit**: aim at the target itself, to keep it inside the 15° lock cone for a full second. Used in
  ATTACK with seekers while locking.
- **Lag pursuit**: aim behind the target, on its flight path. Used when closing too fast (closure > 6 m/s
  inside 15 m) or when I'm inside its turn circle and would overshoot: stay behind its wing line, bleed
  closure, then pull to lead.
- **High yo-yo**: overshooting a hard turner, climb out of its plane (`gamma` +20-30°), then roll and drop
  back onto its tail. Converts excess speed to height instead of flying past it.
- **Low yo-yo**: it out-turns me and I'm falling behind, so dip inside and below its circle to gain closure
  (spends height). Only with height to spare above the understory floor.
- **Range control**: rockets want 10-25 m behind (time of flight under ~0.6 s), seekers 12-30 m (inside the
  lock range, outside the 6 m minimum). Speed is held with `flap = HOLD_SPEED` and by trading height.
- **Use of the vertical**: the forest's open vertical space is the main lever. Birds turn tighter when slower,
  so a pull up into a climbing turn (a wingover) reverses direction in less room than a level turn.

Choices come from `Engagement` numbers (ATA, AA, range, closure, turn circles), with the style deciding which
are allowed: a hawk never low-yo-yos into the understory, a sparrow rarely high-yo-yos (it has little speed
to trade).

### 4.5 Weapons: choice and fire control

**Weapon choice** is made before the fight: a bird carries six rockets or four seekers, never both (decided
2026-11-02). The loadout is a style choice (5): seekers for birds that can hold a target in the cone for a
second (ahead, AA < 60°, 12-30 m, not much more agile than the seeker), rockets for close, nimble fights.
REARM when empty.

**Fire control** asks "would this round hit?" by flying the real projectile code forward, not a hand-tuned
cone. `AICombat._solution(launcher, target)` launches a scratch `Projectile` (`Projectile.launch` + `step`,
both pure) against a dummy that moves with the target's seen velocity and turn rate, for the round's life
(60 steps at 60 Hz; only run when the target is inside a coarse envelope, so it costs a handful of
simulations a second). It returns the predicted miss distance.
- **Rockets**: fire when the predicted miss < `fuse` (1.0 m, times the skill's `min_quality`; **not** `fuse + blast`:
  a rocket that passes outside the proximity fuse never goes off near the bird, so the blast's reach doesn't help it)
  and the lane is clear
  (`segment_clear(muzzle, lead point, 0.2)`, no trunk in the way). Ripple: hold fire for 2 rounds when the
  target is steady (a 0.25 s pair covers its jink), single rounds when it is jinking. Skill adds aim error
  and a minimum quality before firing.
- **Seekers**: lock first (pure pursuit). Once locked, fire when the solution hits against the target
  flying straight *and* against its best break both ways (the dummy turning at the target's corner turn rate
  from `CombatStyle`, left and right). A target that can beat the seeker by breaking (a sparrow at
  high aspect) is not shot until the geometry is better: tail-on, close, or while it is slow or stunned.
- **Ammo discipline**: `skill.min_quality` scales with the rounds left (the last seeker waits for a
  near-certain shot). Never fire while `steer()` is avoiding, or while stunned.
- **Information**: the solution uses only the target's seen position and velocity (`CombatSense` tracks),
  never its `FlightInput`.

### 4.6 Defence

Each threat has its own answer; all are flown through `steer()`, so the trees are still avoided.

**Built and measured (2026-11-02): defend before the round is in the air.** In this flight model no level break,
at any timing, beats a locked seeker (`tests/probe_seeker_break.gd`: the worst miss of a sparrow, crow or hawk breaking
either way, from launch or at its break time, 12-36 m, any aspect, is under 0.15 m against a 1.0 m fuse), and a rocket
fired from inside ~15 m arrives before a crow can roll to 90 deg (0.28 s). So the late breaks below matter little;
what works is earlier:
- **Deny the lock / break into a bird in firing position** (its nose within 25 deg of me inside 30 m, or, carrying
  seekers, from behind me out to lock range; one seen there is remembered 1 s between looks into the blind cone):
  hard breaks *toward its side*, re-picked every 0.35-0.7 s with a random climb or dive. Its nose has to come across
  mine, so it neither holds the 15 deg cone for the 1 s a lock needs nor a rocket lead. Jinking back and forth across
  its line was tried and is worse: the attacker locks as the bird swings back across its nose. A rocket bird further
  than 30 m back is left alone (turning into it only closes the range).
- **Tree drag** (`skill.tree_drag`, ace): a seeker coming and a trunk it can pass before the seeker catches it: close
  past its edge on the side it's already heading for, hook in behind it, then on along the seeker's line; the seeker's
  lead pursuit cuts the corner into the wood. A sparrow does it from a 25 m warning; a crow's ~4 m turn can't hook in
  behind in that second (it would need the trunk picked while still only locked, before launch: not built).
- `test_combat_defense`: a pilot combat-AI attacker hunting from five starts; defending takes 2/15 and 4/15 hits
  against seekers, 0/15 and 1/12 against rockets, where flying straight takes all of them, both sides. Hits that remain
  come from a seeker attacker starting at ~32 m dead astern: the lock completes before any turn can take the defender
  out of the 25 deg keep cone at that range.

The original plan, for reference:
- **Incoming rocket** (unguided, seen by its smoke): it only has to miss by `fuse + blast`. At time-to-go
  under ~0.5 s, sidestep across its line: full roll and pull perpendicular to the rocket's velocity. Earlier
  is wasted (a shooter can re-aim); later doesn't move the bird far enough.
- **Incoming seeker** (150°/s, 60° gimbal, ~35 m/s; its turning circle is ~13 m, a bird's 3-10 m): break
  hard across its line at time-to-go ≈ `CombatStyle.seeker_break_tgo` (about the time the bird needs to roll
  to 90° and move 2.3 m sideways; ~0.5 s for a sparrow, longer for a hawk). Also try, in order of what the
  style allows:
  - **tree drag**: if a trunk is within reach, fly close past it (`segment_clear` with a small clearance) so
    the seeker's lead pursuit cuts through the trunk and bursts on it (rounds do burst on trunks),
  - **gimbal drag**: turn perpendicular so the seeker's off-boresight angle passes 60° and it loses the lock,
  - **the understory**: small birds dive into the 4-9 m layer, where trunk density helps both of the above.
- **Being locked** (warning, section 7): deny the 15° cone. Turn hard so the attacker's nose can't follow
  (its ATA rising), or reverse into a scissors if it is closing fast.
- **Gun on my tail** (enemy behind, ATA < 25°, within 30 m, no round yet): break turn toward the attacker's
  side to raise its ATA and force an overshoot; out-of-plane if it is a better turner; EXTEND into the trees
  if it's a better turner *and* I have no energy.
- **Recover after a hit**: no input during the stun (the bird has no control anyway); then roll level, rebuild
  speed, re-pick the mode.

Defence cost: hard breaks bleed speed and burn burst. The brain counts that: a bird that has just defended
low and slow goes to EXTEND, not straight back to ATTACK.

### 4.7 Disengage, rest and rearm

Ammo is restocked **only at your own team's base** (decided 2026-11-02); stamina recovers on any perch. So
there are two reasons to leave the fight, with different destinations:
- **REARM** (ammo): both weapons empty, or one empty and the other down to its last round with no good shot
  coming. Destination: the team's base rail perch.
- **REST** (stamina): stamina < `skill.rest_at` (default 0.3), with ammo left. Destination: the safest
  perch in reach, or the base if it is in reach anyway (rest and top up in one stop).
- **MEND** (feathers): health ≤ 0.5 (four or more feathers gone; the next two or three hits down it).
  Destination: the base, the only place feathers grow back; a hurt bird also flies worse (less lift, a wing
  that drops), so it extends early and plans a gentler route.

Both run the same way:
- **Leave**: EXTEND first, away from every enemy's nose, until no enemy has ATA < 45° on it within 30 m.
- **Route**: to the base, `FlightPlanner` plans the whole trip (it may be across the wood), and the energy
  check is the same glide + climb budget `AIPilot` uses; a bird that can't reach the base on its energy
  rests on a safe perch on the way first.
- **Pick a rest perch** with `AIPilot`'s reach rule, scored also by safety: far from enemies, not on their
  side, and screened by trunks (no line of sight from them).
- **Sit** for `Launcher.RESTOCK_TIME` (2 s, at the base) and until stamina is back above 0.5 (`AIPilot`
  already waits for that).
- **Ammo is the fight's clock**: with base-only rearming, the brain rations harder the further it is from
  base (`min_quality` rises with the trip length), and a team keeps track of who is heading home
  (`TeamBoard`), so the base is a place enemies will look for birds coming in slow to land.
- **Perched is vulnerable**: if an enemy within 35 m turns its nose on the perch, drop off early
  (diving off gives speed at once) and fight or EXTEND.

**Ambush** (the tree's Ambush branch; mainly the owl's style, open to any bird the style allows):
- Pick a perch high above where enemies are flying, screened from them by trunks, with a clear dive lane
  below (`segment_clear` from the perch to a point under it).
- Sit and watch. A perched bird recovers stamina, so ambushing is never wasted time (it rearms only if the
  perch is its own base, which makes the base itself a good ambush spot against raiders).
- Drop when an enemy passes inside the dive envelope: below, within ~25 m, crossing or going away (AA <
  90°), and not looking at the perch. The drop is a stoop onto its tail: ATTACK with rockets, or a seeker
  lock built on the way down.
- Give it up if spotted (an enemy turns its nose on the perch) or after a patience time from the skill.

### 4.8 Team play (3 v 3)

A `TeamBoard` per team (a shared blackboard, read and written by the team's trees) holds each member's
target, mode and position. It holds only what teammates could tell each other by sight and call; it never
carries enemy positions a member hasn't seen itself, beyond a short "called" track (a teammate's sighting,
delayed and blurred like the AI's own memory).
- **Target spread**: the target score's teammate penalty (4.2).
- **Support**: a member being attacked (enemy on its tail within 30 m) is the top target for any teammate
  within 50 m that isn't defending.
- **Pairs**: by default two members fly as a pair (leader and wingman: the wingman holds a slot 10-15 m
  behind and above, takes the leader's attacker) and one free; each team's style mix decides who leads.
- **Rearm in turns**: two members don't go home or to rest at once unless both must; a member flying home
  low on ammo is escorted by its pair if the other is free.
- **Base watch**: enemies landing at the base are slow and predictable; a member resting or rearming there
  defends it (drops off onto an attacker), and an attacking team's style may send one bird to catch birds
  flying home.
- With the player on a team, the AI teammates treat the player's bird like any member (reading its target
  from the launcher's bracket); they don't take orders yet.

## 5. Per-species styles

`CombatStyle.from(profile)` derives the numbers that decide tactics. Rough values from the section 8
profile table (lift-limited, ignoring drag; `tests/probe_combat_envelopes.gd` will measure the real ones in
the flight model and the style uses the measured formula):

| | Sustained turn at v* | Radius | Roll to 90° | Burst / stamina | Style |
|---|---|---|---|---|---|
| Sparrow | ~110°/s | ~4 m | 0.2 s | 40 / 800 | **Turn fighter.** Out-rolls everything, flaps cheaply. Fights in and under the understory; beats seekers by breaking late; rockets at close range. Weak glide, so it can't run. |
| Crow | ~135°/s | ~4 m | 0.3 s | 16 / 260 | **All-rounder.** Turns with most birds, uses seekers on straights and rockets in turns. |
| Owl | ~140°/s | ~3.5 m | 0.5 s | 12 / 200 | **Ambusher.** Slow, gentle, tight. Waits on a perch and drops on birds passing below; seekers. |
| Hawk | ~120°/s | ~5 m | 0.75 s | 8 / 130 | **Energy fighter.** Slow roll, flapping is costly: stays high, glides, makes diving passes and climbs out. Never turns with a sparrow; avoids the understory. |
| Falcon | ~70°/s | ~10 m | 0.4 s | 14 / 240 | **Boom and zoom.** Fastest stoop, worst turn, high stall: dives through from height, one rocket pass, zooms back up. Can't out-turn a seeker; defends by tree drag and gimbal drag. Never low and slow. |

The style sets: preferred height band, which manoeuvres are allowed (yo-yos, understory, scissors), the
seeker break time, which weapon it prefers, and how much energy advantage it wants before committing.
Matchups follow from the numbers rather than being scripted: e.g. a hawk only engages a sparrow from above
with ΔE > 8 m, and extends rather than turning with it.

## 6. Difficulty: `CombatSkill`

Every knob degrades a perfect pilot; 0 / the "off" value is the honest maximum. Presets `recruit` (easy),
`pilot` (medium, **the default**), `ace` (hard).

| Knob | Meaning | Recruit / Pilot / Ace |
|---|---|---|
| `reaction` | s of delay between the world and the `Picture` | 0.45 / 0.25 / 0.12 |
| `view_deg` | field of view (rear blind cone is the rest) | 220 / 280 / 320 |
| `scan_every` | s between checks of the rear hemisphere | 1.5 / 0.8 / 0.3 |
| `aim_error_deg` | noise on the lead it aims at | 4 / 2 / 0.5 |
| `min_quality` | fire-control miss allowed (x `fuse + blast`) | 1.6 / 1.1 / 0.9 |
| `break_error` | s of error in defensive timing | 0.35 / 0.15 / 0.05 |
| `bank_frac` | fraction of the bank limit it will use | 0.7 / 0.85 / 0.95 |
| `tactics` | which manoeuvres it knows (yo-yos, tree drag, scissors) | pursuit only / + yo-yos, gimbal drag / all |
| `aggression` | risk taken (energy deficit it accepts, hits before REARM) | low / mid / high |
| `rest_at` | stamina at which it goes to rest | 0.4 / 0.3 / 0.2 |
| `ambush_patience` | s an ambusher waits on its perch | 12 / 25 / 40 |
| `watch_range` | m out to which it reads a bird lining up on it and breaks before any warning (built) | 20 / 42 / 42 |

## 7. Prerequisites outside the AI

1. **Avoidance branch on master** (`claude/ai-tree-avoidance-0f8387`), then the `AIPilot.steer()` refactor
   (3.1). `_fly` must still pass `test_ai_flight` unchanged.
2. **Player-visible warnings** (**done 2026-11-02**: `CombatWorld.warnings_for(bird)` -> {rounds (tgo, kind),
   locks}; `threat_to()` wraps it; the HUD's red chevron / arrowhead round the aim ring and LOCK / INCOMING;
   the range's `--return-fire` makes the target shoot back): a lock warning (an attacker's lock on you above 50%) and an incoming-round
   cue on `CombatHud`, from a new `CombatWorld.warnings_for(bird)`. `CombatSense` reads the same call, and
   `threat_to()` (which `CircuitPilot` uses) becomes a thin wrapper over it. Without this the AI knows about
   locks the player can't see.
3. **Teams and bases** in `CombatWorld` (**teams done 2026-11-02**: `add_bird(b, controller, team)`,
   `friends()`, `friend_in_line()` for the lane check, `Launcher.is_enemy` -- locks and the HUD's target take
   enemies only -- and the HUD's friend / foe marks; **bases, respawn and score done too**: `bases` (team ->
   perch), `base_of()`, `respawn()`, `far_base()` for the other side's, `score` (team -> enemies downed; a
   teamkill scores nothing), the range respawning downed birds on their base and `CircuitPilot.rejoin()`):
   `team` per bird (`add_bird(b, controller, team)`), bursts still hurt
   anyone but the shooter (friendly fire stays on, so the AI must check its lane for teammates), and a base
   per team: an outpost (`ArenaLayout.outposts`, which the pine wood places on pines and oaks) chosen at the
   start as far apart as the layout allows. `downed` → the scene respawns the bird on its base's rail perch
   after the down stun. The HUD's tally becomes a team score.
   **Base-only rearming: done (2026-11-02).** `Launcher` restocks and mends only while perched on
   `rearm_perch` (unset keeps the any-perch rule, which the unit tests use). The range gives the player the
   rail of the outpost nearest the clearing, and `CombatHud.home` shows the way home when out of rounds or
   hurt. Teams still to do: the range's single base becomes one per team.
4. **A team match in the range**: `--match` mode in `combat_range.gd`
   (`.\range.ps1 -Match -Skill pilot [-Team crow,hawk,sparrow -Enemy falcon,owl,crow]`): you and two AI
   wingmen against three AI, in place of the racetrack target. `--duel` (1 v 1) stays for tuning.
5. **Seen-track input**: `CombatSense` needs other birds' velocity; `Projectile.velocity_of` already reads
   `model.velocity`. That's state the player sees on screen (the bird's motion), so it's allowed, but it goes
   through `CombatSense`'s delay and noise, not straight to the brain.

## 8. Testing headlessly

**The match harness** (`scripts/test_support/duel.gd`, `Duel`): builds a layout (`Pinewood.generate(seed)`,
with `--forest greybox` as an option), a `CombatWorld`, the two bases, and 1 v 1 up to 3 v 3 birds with any
controllers, runs it for N physics ticks with no rendering, and returns outcomes per bird and per team:
`{kills, deaths, hits, shots, accuracy, friendly_hits, first_hit_s, time_offensive, time_defensive, bonks,
ground_hits, rearms, ambushes, min_stamina, perf_ms_per_tick}`. 1 v 1 start geometries are named
(head-on pass, one behind the other, beam crossing, one perched below, one high); 3 v 3 starts from the
bases. Every one is also run **mirrored left/right**, and team matches with the sides swapped.

**Tests in `-TestAll`** (each a few seconds of sim unless noted):
- `test_combat_geometry.gd`: `Engagement` angles and pursuit points for targets left and right, ahead and
  behind; lead points lie inside the target's turn, lag points outside, both sides.
- `test_fire_control.gd`: the rocket solution says hit for a target the round really hits (run the shot and
  check) and miss for ones it misses, crossing left and right; it holds fire through a trunk; seekers are held
  against a sparrow at high aspect and fired on a crow tail-on.
- `test_combat_defense.gd`: a scripted shooter fires rockets and seekers at an AI bird from fixed geometries
  (both sides, front and rear quarters). Defending must beat flying straight (survival rate higher, both
  sides) and the species order against seekers holds: sparrow survives more than crow, crow more than hawk.
  Tree drag: with a trunk alongside, the seeker bursts on the trunk.
- `test_combat_ai.gd` (~60 s of sim): a pilot-skill AI downs a non-evading racetrack target within 40 s; it
  lands more hits on the evading target than today's `--demo` chase does; when empty it flies home, lands on
  its base, rearms and re-engages, and a perch that isn't its base doesn't rearm it; bonks per minute in combat stay within `test_ai_flight`'s per-perch budget.
- `test_combat_team.gd` (~90 s of sim, 3 v 3 pilot v pilot): both teams score kills; downed birds respawn
  on their base and rejoin; no two members chase the same target for more than a few seconds unless it's
  attacking one of them; friendly hits stay rare (under 1 in 20 hits).
- `test_combat_tree_spike.gd`: the Beehave tree builds in code, ticks headless, drives a bird, and the run
  prints no engine `ERROR:`/`WARNING:` (section 3.2).
- `test_combat._range` keeps running (the demo shooter), switched over to the combat AI once it is better.

**Probes (run by name, not in `-TestAll`)**:
- `probe_combat_envelopes.gd`: measures each species' sustained and corner turn rate, roll time, and
  survival against a seeker by break time; this calibrates `CombatStyle`.
- `probe_duels.gd` + `.\duel.ps1`: the matrix, species x species x skill x start geometry x mirror, several
  seeds, printing win rates and the outcome table. Acceptance targets to tune toward:
  - mirror matches (same species, same skill) 40-60% either way,
  - ace beats recruit at least 70% in every species pairing,
  - every species wins some matchups: no species loses everything,
  - 3 v 3 with the same team mix on both sides: 40-60%; a pilot team beats a recruit team clearly.

**Regressions**: each combat-AI bug fixed gets a `tests/regressions/mutations.json` entry and a
`.\mutation_check.ps1 -Only <id>` KILLED, as the rules require.

**Perf**: `Perf` sections `ai.combat.sense`, `ai.combat.brain`, `ai.combat.fire` (the solution sims), and
`ai.combat.tree` and the existing `ai.plan`. Budget: under 0.1 ms per AI bird per tick on average with 6
birds in a 3 v 3 (`docs/design/performance.md`).

## 9. Build order

1. **Groundwork** (after avoidance lands): the Beehave spike (go / no-go, 3.2); `AIPilot.steer()`;
   `CombatWorld.warnings_for` and the HUD warnings; teams and bases in `CombatWorld`; `Duel` harness;
   `probe_combat_envelopes`; `CombatStyle` from measured numbers.
2. **Attack (1 v 1)**: `CombatSense`, `Engagement`, the tree's Patrol / Fight branches, `CombatPilot`
   pursuit (lead, pure, lag), new `AICombat` fire control; range `--duel`. Tests: geometry, fire control.
3. **Defence**: the Defend branch against rockets, seekers, locks and tails, tree and gimbal drag. Test:
   defence.
4. **Energy, rest and ambush**: yo-yos, stoops and zooms by style, Extend, Rest on a safe perch, Rearm at
   the base, Ambush.
   Test: combat AI.
5. **Teams (3 v 3)**: `TeamBoard`, target spread, support, pairs; respawn at base; range `--match`. Test:
   team.
6. **Difficulty and tuning**: `CombatSkill` presets (default `pilot`), the duel and match matrix, tuning to
   the acceptance targets.
7. **In the game**: a 3 v 3 in `game.gd`.

## 10. Open questions

- **Bases**: just a respawn and rearm point, or something to attack (a win condition), or a team score from
  kills only?
- **Your AI wingmen**: should they take simple orders (attack my target, cover me) later, or always fly on
  their own?

## 11. Status (2026-11-02)

**Built** (stages 1-3; `scripts/combat/ai/`, all headless-tested):
- Groundwork: Beehave 2.9.2 vendored (`addons/beehave`, `FLAP_PATCHES.md`: three headless guards; the spike passes
  the strict runner); `AIPilot.steer(bird, aim, dt, opts)` and `go_to_perch()` (`_fly` calls `steer`;
  `test_ai_flight` unchanged); the `Duel` harness; `tests/probe_duels.gd` (`DUEL=crow,hawk`, `DUEL_TARGET=circuit`,
  `DUEL_SECONDS`, `DUEL_SKILL`: traces and per-section cost).
- `Engagement`, `CombatStyle` (`of()` / `from()`: turn rates, roll time, lift-limited bank, break time, the style
  flags from roll time and stall speed), `CombatSkill` presets, `CombatSense` (reaction delay with dead-reckoning to
  now, view cone with checks of six, line of sight through the trunks, memory, the HUD's `warnings_for`, which pods a
  bird carries), `FireControl` (`miss()` flies the real `Projectile` against a dummy; `lead()` corrects the quick lead
  by where a real rocket passes; seekers judged against a break at the target's break time), `CombatBrain` (target
  score, `Intent`, the launcher held by `WeakRef`: the launcher holds `AICombat`, which holds the brain), `CombatTree`
  (Defend / Recover / Rearm / Rest / Fight {Extend, Attack, Reposition} / Patrol; every action returns SUCCESS and
  manoeuvres that last are the brain's timers; the blackboard is seeded through its exported dictionary, because
  `Blackboard._ready` wipes anything `set_value()` put there before the tree entered the scene), `CombatPilot`,
  `AICombat` with a brain (fire control) or without (the range's `--demo` trigger finger).
- Defence before the round flies (4.6): breaks into a bird in firing position, tree drag.
- Tests: `test_combat_geometry`, `test_combat_sense`, `test_fire_control`, `test_combat_ai` (downs the racetrack
  target, beats the old demo shooter on the evading one, rearms at its base, a 40 s turning fight without a stall or a
  spiral), `test_combat_defense`, `test_combat_tree_spike`. Nine `combat-*` entries in
  `tests/regressions/mutations.json`, each KILLED.

**Built since** (stages 4-5):
- **Seen turn rate.** `CombatSense` reads how hard each bird is turning from its velocity over 0.2 s and carries it on
  through the reaction delay *along that turn*; the rocket lead (`FireControl.lead`) and fire control use it. Against
  a bird in a hard break this is the difference between a hit and a miss (`test_fire_control`); in a 3 v 3 it took
  the hits from 4 to 16 in 90 s.
- **Boom and zoom** (hawk, falcon: `CombatStyle.prefers_height`): the Fight branch's `BoomZoom` -- climb (run out to
  30 m from the target, climbing at 16 deg while above v*, then back at a point 9 m above it), stoop (with 5+ m of
  height, the target ahead within 45 deg and 8-32 m: dive on the rocket lead, unflapped, weapons free, aiming past the
  lead by 1.4x how far the gunsight trails it -- without that, in the clumped wood, they never fired), zoom (pull up
  30 deg along the heading while faster than v*). `test_combat_boom_zoom`: against the racetrack target, 40 s in each
  of three woods, the hawk stoops 7 times and lands 4 hits, the falcon 9 and 3 (before: no hits). Their hit rate is
  the weakest of the five (avoidance cuts many stoops short among the clumps): stage 6 material.
- **Range control** in Attack: seekers hold 12-28 m behind the target, rockets 8-22 m, by speed. The seeker crow had
  been closing to 5-10 m, inside the lock's 6 m minimum and too close to keep a jinking bird in the cone; with it the
  combat AI beats the old demo shooter on the evading target in the clumped wood, 13 hits to 11 over four woods
  (`test_combat_vs_demo`, which replaces test_combat_ai's one-seed comparison).
- **Ambush** (owl: `CombatStyle.ambusher`): a perch 4-15 m above where it has seen the enemies fly
  (`CombatBrain.fight_area`, a slow average), 15-45 m out from there; sit (resting) until one passes below within
  30 m not flying straight at it, then drop off and fight; give up after `skill.ambush_patience` or when spotted.
- **Rest on a safe perch**: a tired bird picks, of the perches it can reach with height in hand, one far from the
  enemies and out of their sight (from where each is, where it's heading, and where they've been flying); with none in
  reach it glides down and rests on the ground. **Known weakness:** a tired crow in the test fails two perch approaches
  in a row (a bonk on an outpost, then short of a low perch) and rests on the ground; AIPilot's approach with almost
  no stamina needs a look.
- **Lift for the pull-out**: the bank cap also leaves lift for pulling out of a dive, and a defensive break never
  commands more than 12 deg above the bird's path (the hawk stalled pulling out of a stoop into a break).
- Perched birds don't break from an enemy whose nose swings past (the ambusher drops off when spotted); a bird making
  a head-on pass on its own target doesn't break from it; a perched bird's line of sight leaves out its own branch.
- **Teams**: `TeamBoard` (each member's target and mode, as called out; no enemy positions): a target already taken by
  teammates scores 2.5 less each, unless it's after me (the plan's 1.5 left two on one target 37% of the time).
  `Duel` gives each team a board; `CombatWorld.friendly_hits` counts teamkill hits. `test_combat_team`: 3 v 3 (crow,
  sparrow, hawk a side), 90 s: both teams land hits and birds are downed, downed birds respawn and fly again, two on
  one target ~12% of fighting time, no friendly hits.
- **Range `--match`** (`.\range.ps1 -Match [-Skill pilot] [-Team crow,hawk] [-Enemy falcon,owl,crow]`): you and two
  combat-AI wingmen against three, from the two bases; each AI bird carries its species' round.
- Not built yet: pairs (leader / wingman slots), rearming in turns, base watch, yo-yos beyond the high yo-yo in
  Attack, the duel matrix and skill tuning (stage 6), the game (stage 7).

**Stage 6, first duel matrix (2026-11-03, `tests/probe_duel_matrix.gd`, pilot v pilot, 45 s, two starts each way
round, the clumped wood):** far from section 8's targets.
- Most mirror duels end 0-0 (crow, hawk, falcon, sparrow): two pilots that break into each other deny every shot.
- **Seekers beat the energy fighters outright**: crow and owl took every duel against hawk and falcon (owl v hawk 16
  hits to 0). A hawk or falcon can't break a lock it's already in, can't out-turn the seeker, and its stoops start
  from inside the seeker bird's lock range.
- The falcon won nothing; the sparrow beat hawk and falcon and drew the seeker birds.
Closing this is partly tactics (energy fighters keeping out of lock range until they stoop, a seeker bird's lock
denied by the stoop's speed) and partly balance (seeker turn rate, gimbal, lock time), which is the user's call.

**Findings:**
- **Seekers can't be out-turned.** No level break at any timing beats a locked seeker (4.6); only denying the lock and
  trunks do. Balance is the user's call (seeker turn rate, gimbal, fuse); nothing was changed.
- **Rockets need a pass inside the fuse** (1.0 m), not `fuse + blast`: the blast only reaches a bird when the fuse has
  gone off near it.
- **The bank has to be lift-limited** in a sustained combat turn (`CombatStyle.lift_bank`, 15% margin): turning at
  the skill's share of the bank limit at any speed bled a hawk into stalls and a sparrow into a spiral.
- **Falcon and hawk** got no hits turning (the falcon's 10 m turn at 14 m/s); boom-and-zoom gives them theirs.
- **Defence outweighed attack** between AI birds until the attackers read the turn: a 3 v 3 of pilots landed 4 hits
  in 90 s, most of each bird's time spent breaking. Stage 6 (the duel matrix) is where that balance gets tuned.

**Cost** (`tests/probe_team_cost.gd`: a 3 v 3, six AI birds, 60 s; it prints a fingerprint of every bird's flight so a
change meant to leave behaviour alone can be shown to, to the bit). 2026-11-03: 7.35 ms per physics tick, of it 5.5 ms AI
(~0.9 ms per bird), worst ticks 80-150 ms. Now ~3 ms per tick, ~2 ms of it AI (~0.35 ms per bird), worst ~40-100 ms:
- Exact (the fingerprint unchanged): a tree's branches filed by height band (`TreeData.bands()`), so a clearance check
  visits only those at the segment's height -- it walked all ~47 of every nearby tree's, 6,500 a tick; the avoidance
  fan doesn't check a heading against the wood once it couldn't beat the best clear one; a predicted path checked in
  one call (`ArenaLayout.path_blocked_at`), against the outposts near it only; `obstacle_distance` pruned (trees in
  order, none that can't come nearer), and the planner's nodes asked yes/no (`clear_by`). Avoidance 2.9 -> 1.2 ms.
- Bugs that cost time: a combat bird sent to a perch it had no route to (team 1's base: an outpost facing a tree 6 m
  off its rail) planned a route to some random perch every tick. Outposts now face only where every species can swoop
  onto the rail (`Pinewood.APPROACH*`); the pilot heads for a perch it can't plan to; the hangar is in the layout's
  geometry; a combat bird turns to face out before it pushes off. Planning 1.3 -> 0.1 ms.
- Lower rates: the brain looks and decides every other tick (`CombatBrain.THINK_EVERY`, 30 Hz, well inside the best
  reaction time), the picture coasted on between looks; history is still recorded every tick (sparser history made the
  turning shot and the seeker drag miss). Brain + sense 1.0 -> 0.6 ms.
Still over section 8's 0.1 ms per bird: avoidance (~0.2 ms per bird) and the occasional long plan home (a bird 70-160 m
from its base: a few hundred expansions, every new node and edge checked against the wood -- not a failed search).

**Seeker locks need sight** (2026-11-03): `Launcher.sees` -- wood on the line from muzzle to target stops a lock
building, and past `LOS_GRACE` (0.25 s) drains it (`LOS_DRAIN` 1.5/s); a new lock starts only on a bird in sight
(`test_lock_sight`). In 3 v 3s over six woods it changed little (38 locks against 41, hits level): between birds
10-30 m apart the line rarely crosses a trunk. It makes cover a player's tool (`docs/tutorial/tactics.md`).
An AI cover tactic was tried and dropped: running for a trunk to put between itself and a locking shooter made a
pursued sparrow *worse* (10 hits against 6 in the wood) -- the run is a straight line, the easiest lock -- and
limited to trunks already near the line it never fired. Breaking into the attacker stays the better lock denial.
Seen in passing (not chased): with one trunk ahead 1-3 m to the left, a pursued sparrow takes 4 hits whatever it
does; to the right, none -- an asymmetry in the break or the attacker's line, for a later look.

**Weapon proficiency and the enemy mix by difficulty** (2026-11-04, `tests/probe_weapon_skill.gd`): an attacker (a
crow, then a sparrow) armed with one weapon hunts a defending pilot crow through the pine wood, 60 s from 25 m astern,
woods 1-4, with respawns:

| skill | weapon | rounds | hits | hits per round | hits per match |
|---|---|---|---|---|---|
| recruit | rockets | 23 | 2 | 0.09 | 0.25 |
| recruit | seekers | 17 | 14 | 0.82 | 1.75 |
| pilot | rockets | 12 | 1 | 0.08 | 0.12 |
| pilot | seekers | 11 | 10 | 0.91 | 1.25 |
| ace | rockets | 25 | 10 | 0.40 | 1.25 |
| ace | seekers | 14 | 12 | 0.86 | 1.50 |

The AI is far better with seekers at every skill; only an ace makes rockets work (a defending bird denies the slow
rocket pass; a lock, once made, mostly hits). Downs per minute are near nil at every skill (eight feathers down a bird).
So the enemy's mix follows the skill (`CombatSkill.seeker_share`, `weapons()`): a recruit side carries seekers on a
third of its birds, pilot two thirds (the range's mix as before), ace all -- seekers first to the birds built for them
(crow, owl), then the sparrow; the energy fighters (hawk, falcon) always rockets. The range match arms the enemy so
(`combat_range.gd`); your wingmen fly their species' rounds. Per-pod loadouts and the machine gun will let the mix go
per pod; the AI flies one weapon per bird until it learns to switch.

**The machine gun** (2026-11-04). The AI flies the bullet's lead pursuit (`CombatBrain.lead_for`: FireControl.lead with
the round's kind) in `GUN_BAND` (6-18 m), and fires a burst when one has a fair chance: the aimed bullet's miss within
the target's hit radius, plus two of the scatter's spreads at that range, plus `AICombat.GUN_TRACK` (0.5 m) of the
sight's wander, all scaled by the skill's `min_quality`. Bullets in the air aren't a reason to break (too fast to
dodge: the bird lined up on it is). Measured (`probe_gun_straight`, a crow, 40 s, woods 1-4): against the racetrack
target flying straight on the gun lands 48-60 hits from 286-341 rounds (0.16-0.21 a round) and downs as many birds as
rockets or seekers; against a defending crow that breaks (`probe_weapon_skill`) 0-1 hits from 36-57 rounds -- the
nose never tracks a breaking bird to within its hit radius (aimed misses: median ~4 m, best tenth ~1.5 m). So in the AI's
hands the gun is the weakest weapon against a bird that defends, and the mix gives it only to an easy side
(`CombatSkill.gun_share`: recruit a third, pilot and ace none; the rocket birds first, never the energy fighters).
Not yet: switching between two kinds on mixed pods (the AI flies the one it's armed with), gun passes in boom and zoom.
