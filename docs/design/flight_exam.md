# The AI's flight exam

What an AI bird must be able to do, measured where nothing but the objective is in the way, so a change to how the
wood is laid out doesn't move the numbers and a change to the AI that loses a way of flying does.

Code: `scripts/test_support/flight_exam.gd` (`FlightExam`: the places, the attempts, the scoring),
`tests/test_flight_exam.gd` (the bounds), `tests/probe_flight_exam.gd` (every attempt, a trace of one).

## Why

The AI's tests flew it in a generated wood (`Pinewood.generate(7)`) and checked one run: this perch, this base, this
course. A change elsewhere -- a tree's shape, the outposts' placement, a profile -- moved which perch was picked or which
way the bird turned, and a test that had passed by luck failed (or the reverse). Two sessions ran into it: changing the
pines' limbs broke landings, and the race's falcon couldn't land home on the rail. The landings themselves were
fragile; the tests couldn't tell fragile from broken.

## The places

Each is grown with the pine wood's own code (`Pinewood._grow_pine`, `_grow_oak`, `_outpost`) so the exam lands on the
trees the game has, but alone, on flat ground, in still air:

| Scene | What's there |
|---|---|
| pine, veteran, pole, oak | one tree of that form (the middle of the wood's size range for it); the oak judged as its crown (limbs from 6 m) and its low tier (the big limbs ~4.5 m up, under the crown: `oak_low`) |
| close | the pine, each perch from 12 m out in front at its height, heading at it: in on its line already |
| oak_low_heights | the oak's low tier from 10 m above and 6 m below (the hawk and falcon) |
| rails | an outpost on a mature pine; an outpost on the clearing's big oak |
| heights | the pine, from 10 m above and 8 m below its perches |
| grove | the pine with five more trees round it at a stand's spacing (8-11 m) |
| hop | two pines 28 m apart: from a perch on one to a perch on the other |
| gates | post gates on open ground: straight, a climb, a dive, 90 deg turns wide and tight, a U-turn, a gate behind, a slalom, an S-bend, up and down (`FlightExam.COURSES`) |

## The objectives

| | Objective | Attempt |
|---|---|---|
| 1 | Land on every perch of a tree | each perch, from in front, both sides and behind, 30 m out, 3 m above |
| 2 | Land on an outpost's rail | from 8 sides, 3 and 10 m above |
| 3 | Lose height, gain height | from 10 m above and 8 m below |
| 4 | Thread a stand | every perch of the middle tree of a grove |
| 5 | Go perch to perch | take off, fly across, land |
| 6 | Fly a course | every gate, in order, at recruit, pilot and ace |
| 7 | Already lined up, fly straight in | every pine perch from 12 m out on its line |
| - | Don't hit things | the flock's touches of wood |
| - | Turn only as hard as the lift holds | each species' share of its flying time banked past `AIPilot.held_bank` (+5 deg) |
| - | Begin each final at its speed | nine finals in ten begin under 1.35 x its cruise (`FINAL_FAST`) |

An attempt passes if the bird sits on the perch (or has taken every gate) within 45 s. A bird that sits on another
perch first is sent on again; one that gives the perch up is asked again. Each species is judged on its share of
attempts and its median time (`test_flight_exam.RATE`, `TIME`).

## Baseline and now

Landed / tried, 45 s each (master before -- 25df35b, and 63f2557 for the rows below the gates; this branch after, before
big-trees changed the oak -- its new numbers are below the table):

| Scene | crow | owl | hawk | falcon | sparrow |
|---|---|---|---|---|---|
| pine | 39 -> **44** / 44 | 39 -> **44** | 36 -> **44** | 8 -> **44** | 39 -> **44** |
| veteran | 57 -> **60** / 60 | 58 -> **60** | 58 -> **60** | 16 -> **60** | 51 -> **58** |
| pole | 28 -> **28** / 28 | 28 -> **28** | 24 -> **27** | 16 -> **28** | 26 -> **28** |
| oak | 42 -> **44** / 44 | 41 -> **44** | 36 -> **43** | 25 -> **44** | 41 -> **44** |
| pine's rail | 16 -> **16** / 16 | 16 -> **16** | 15 -> **16** | 4 -> **16** | 16 -> **16** |
| big oak's rail | 16 -> **16** / 16 | 16 -> **16** | 16 -> **15** | 7 -> **16** | 16 -> **16** |
| gates | 30 -> **30** / 30 | 30 -> **30** | 30 -> **30** | 24 -> **30** | 30 -> **30** |
| pine, 10 m above / 8 m below | 80 -> **88** / 88 | 77 -> **88** | 74 -> **88** | 25 -> **88** | 78 -> **88** |
| oak, 10 m above / 6 m below | 86 -> **88** / 88 | 85 -> **88** | 74 -> **88** | 40 -> **81** | 77 -> **88** |
| pine in a grove | 33 -> **44** / 44 | 36 -> **44** | 26 -> **44** | 5 -> **43** | 27 -> **44** |
| veteran in a grove | 51 -> **60** / 60 | 55 -> **60** | 45 -> **60** | 13 -> **59** | 33 -> **59** |
| hop, pine to pine | 20 -> **22** / 22 | 20 -> **22** | 20 -> **22** | 4 -> **22** | 19 -> **22** |
| hop, veteran to oak | 22 -> **22** / 22 | 22 -> **22** | 19 -> **22** | 10 -> **18** | 17 -> **22** |

Big-trees' oak (a short trunk to the fork, big low limbs, a crown above: 24 perches where there were 11), now: its
crown 60 / 60 for the crow, owl, hawk and sparrow, 58 / 60 for the falcon; its low tier 36 / 36 for the crow, owl and
sparrow, the hawk 35 / 36 (about 21 before the route floor, 28 before the line hold, below) and the falcon 30 / 36 (about 5 before it, 14 before
the high line-up, 26 before lining up at cruise, below). Close in on the line:
every species 11 / 11, in 1.3-2.0 s.

Median time to land on a lone pine: crow 6.4 -> 4.1 s, owl 6.5 -> 4.0, hawk 8.4 -> 3.6, falcon 13.4 -> 9.0, sparrow
10.9 -> 4.2. In the generated woods (`test_ai_flight`, 90 s, the flock picking its own perches): greybox arenas 33 -> 48
and 34 -> 52 perches (0 and 2 -> 0 and 1 bonks); the pine wood 30 -> 32 perches and 6 -> 4 bonks, the falcon 0 -> 4.

## How the birds differ, and what each needs

The species differ in three numbers that decide how they can land:

| | stall | catch up to | cruise | turning circle at cruise* |
|---|---|---|---|---|
| crow | 5.7 m/s | 6.8 m/s | 8.6 m/s | 4.5 m |
| owl | 5.5 | 7.2 | 8.3 | 4.4 |
| hawk | 6.5 | 7.9 | 9.9 | 7.0 |
| falcon | 9.2 | 10.6 | 12.6 | 13 m |
| sparrow | 6.0 | 7.2 | 8.2 | 2.6 |

\* at the bank its lift holds there (below). The planner had assumed 85% of each bird's bank limit: 5.2 m for the falcon.

**Turn only as hard as the lift holds** (`AIPilot.held_bank`, `_bank_room`). A sustained turn needs a load factor of
1/cos(bank); the wing gives at most (v / v_stall)^2, kept with a 15% margin. At cruise the falcon can hold about 51 deg,
not the 72 deg the guidance asked for: past that it sank into a stall spiral in every turn and go-around. Perch flights
and gliding are capped; a race's escapes and a combat break (which the combat brain caps itself) pull harder for their
moment. The racer's own turns and go-arounds are capped the same way (`RacePilot`).

**Come in by the open side nearest your turn** (`FlightPlanner.ways_in`, `plan_to_perch`). A branch can be landed on
from either side across it, square on or 35 deg off; a treetop from anywhere. Each perch had one way in (its facing),
so a bird behind the tree flew all the way round it, and a branch whose swoop was blocked on that side had no way in at
all. Now the planner tries them in order: for a flying bird, the one it can turn onto soonest (the shortest
turn-straight-turn path from where it is, heading in), those it can line up on clear of the wood first; a bird already in on a way's
line flies straight in (no turn-straight-turn path fits a small offset in a few metres: the falcon looped round the
tree).

**Line up for the final on your own turning circle** (`AIPilot._line_up`, `Dubins`). The planned route doesn't know
which way the bird is flying; a wide turner reached its last waypoints still turning and passed the perch to the side.
Within three turning circles of the approach point, the route's last legs are replaced by a turn-straight-turn path on
the circle the bird holds (with a margin), arriving at the approach point heading in -- if that path is clear of the
wood (half a wingspan and a margin). It aims far enough ahead to bank as the circle needs.

**Arrive with the energy the catch needs** (`FlightPlanner.approach_drop`, `catch_speed`; `AIPilot._spiral`). The
catch wants the bird inside its window between stall and fastest catch, for the falcon 9.2-10.6 m/s. The final swoops
up from below the perch, trading speed for height, so the approach point sits as far below the perch as the bird
zooms slowing from cruise to the middle of its window (less the drag): 1.9 m for the falcon, 0.7 for the sparrow (it
was 1.2 m for every bird: too deep for the sparrow to climb, too shallow for the falcon to bleed in). The final bleeds
toward the middle of the window (it bled toward 0.8 of the fastest catch, under the stall for four species). A perch
flight doesn't beat its wings above 1.1 x its cruise speed, on the approach leg above its cruise, and pulls gently to
come down to cruise by the approach point. And a bird with more energy than the way left can lose -- height over the
approach point and speed over cruise, less what a braking glide loses on the way -- circles down where it is first
(a turn its lift holds, 16 deg down, no wingbeats), then plans on from there.

*Should a falcon come in high?* No: a bird can't brake while it's still coming down, and diving the height away arrives
far over the catch speed. High, it spirals down first; then, like every bird, it comes in from below and zooms up into
the perch -- the falcon from deeper below and from further out, because it has more speed to lose.

**Go round out and up** (`AIPilot._go_around`). A missed catch was planned again on the spot -- often behind the
perch's tree, flying away, so the new route's first leg turned back through its limbs. Now it flies out, away from the
tree and climbing, for about a turning circle and a half, then plans afresh.

**Hold the perch you're landing on** (`Bird.candidate_lock`, as the novice landing assist holds the player's). On the
final another limb the path passed near could take the catch candidate, and the AI held catch only for its own perch.

**Rails** (`ArenaLayout.tree_clear`). On the final, the perch's own tree and outpost are passed at the landing's closer
clearance from wherever the look-ahead reaches (the final leg was planned clear) -- not only inside 8 m, where a fast
bird's look-ahead found the deck it was landing on and swerved off the line. The deck's outer strip along the rail
doesn't count for a rail landing (the feet reach over its edge); the rest of the deck and the hangar do, so the way in
is still from in front.

**Let the route down low** (`AIPilot.ROUTE_FLOOR`). The ground guard held every perch flight 4 m up (flapping, if it
had to) until the final. A low limb's approach point is under that: the hawk came at the oak's 4.5 m limbs high and
fast, overshot and looped 50 m out. The floor now sits a metre under the route's lowest point still ahead (4 m at most,
0.8 at least).

**Line up for a low perch from where you may bank** (`AIPilot.TURN_HIGH`, `LINEUP_DESCENT`). Near the ground the
guidance banks less (`_bank_room`: 25 deg at 1.5 m, its full share from 7.5 m), so a line-up turned down by a low
perch's approach point was a ~17 m circle for the falcon: it overshot and looped round under the crown. With the height
in hand, it now turns at up to 7.5 m onto a point out along the way in and runs in down to the approach point on an
8 deg slope; where that run isn't clear, or it's already low, it lines up down there as before. The falcon's share of
the oak's low limbs went from 14 to 27 of 36.

**Don't ride above a descending leg** (`AIPilot.LINE_OVER`, `LINE_HOLD`). Aiming at a leg's end, a bird coming down
lags above the leg's line; under a crown that's where the wood is (the planned clearance is the line's), so the
avoidance climbed the hawk over a neighbouring low limb and it reached the approach point 2.7 m high and fast. More than
0.3 m above the line, it now flies the leg's slope steepened by 0.15 rad a metre over. The hawk's share of the oak's low
limbs went from 28 to 33 of 36. (Holding the line both ways got the hawk to 35, but the falcon, gaining speed down
it, fell from 27 to 19.)

**Not too deep under a low perch** (`FlightPlanner.APPROACH_FLOOR`). The approach point sat its full drop under the
perch: under the oak's 4.5 m limbs the falcon's 1.9 m left it 2.6 m up, where the ground limits the bank and the
understory is in the way. It now stays 3.3 m up where the perch allows. From all 8 sides the falcon's share of the low
limbs went from 50 to 67 of 72, the hawk's from 69 to 72. (With this the drop's own speed rule -- deeper for a faster
bird -- no longer shows in the exam beside a fixed 1.2 m; it stays, as the physics, without a regression entry.)

**Line up at cruise** (`AIPilot._fly`). A line-up's turns were flown as fast as the cruise cap let the bird (1.1 x
cruise, no wingbeats above it): the falcon at ~14 m/s under the oak's crown, a 17 m circle, swung wide and looped away.
Now the whole line-up, not only the approach leg, beats no wings above cruise and pulls gently down to it. The falcon's
share of the oak's low limbs went from 26 to 30 of 36 (from above and below 31 to 34), the hawk's from 33 to 35.

**What's left.** The oak's low tier is still the hardest place, judged from all 8 sides for the hawk and falcon: the
hawk makes 72 of 72, the falcon 67 (from above and below 32 of 36); the rest of the oak, 60 of 60. The hawk misses one of the big oak's rail from high above.

**Cost.** In the big-trees wood one clearance check is ~60 us (three-quarters of it walking a big tree's branches), and
a route search asks thousands: a bird's first search somewhere took 100-200 ms in a tick, most of the game's hitched
frames. Now:
- The lattice's clearance is worked out ahead (`FlightPlanner.prepare`: every node's and edge's widest clearance it
  clears, for each species' clearance and the default; the check only gets harder as the clearance grows, so one number
  answers it for each). The game and the range do it on the loading screen, over up to 6 threads (more contend: on 32
  cores 16 took 32 s): ~3 s for the arena's 69,000 edges. It gives the same answers as the checks (`test_plan_table`:
  every node and a spread of edges, every clearance; the routes; a 3 v 3's flight fingerprint unchanged), so headless
  runs -- the tests -- leave it out and fly the same. A 3 v 3's slowest search went from ~136 ms to ~16 ms.
- A bird's route request (`plan_to_perch`, every way in it tries) ends after `REQUEST_EXPANSIONS` (600) search steps,
  route or not (~20 ms with the table; the longest a 3 v 3 needs is ~490). Steps, not time, so a run is the same on any
  machine.
- The A*'s open set is a binary heap (the same node first, so the same routes).

In the game (`perf.ps1`, a crow and 3 AI, 30 s): hitched frames 13 -> 9 (0.5%), planning's worst tick 30 -> 19 ms; what's
left of them is planning and the avoidance together in a tick, ~25 ms frames.

Found on the way: the combat AI's birds planned with the planner's default clearance (0.9 m), never their species' --
`CombatBrain` made its `AIPilot` and never fitted it (`_fit` runs in the pilot's own `sample()`, which `CombatPilot`
doesn't call). Fitted now: over six 3 v 3s (`probe_combat_rest --ai-seed 20..120`) base landings 19 -> 22, downs 4 -> 6,
touches of wood 46 -> 41, time on the ground 751 -> 701 bird-s (`test_combat_perches` checks the fit).

## The test, and why its bounds hold

`test_flight_exam` runs a scene a shard (17 shards, 10-70 s each; the runner stops a process at 120 s, so the veteran is
split by sides, the oak by tier and species, the grove by species, the rails by tree) and checks each species' share, its median time, its
share of time over-banked, and the shard's touches of wood:

- Shares are judged over 20-90 attempts a species, from every side; one attempt that goes differently moves a share by
  1-5%. The bounds (`RATE`) sit 5-15% under what the AI does now, so a subtle change to a tree's shape, a profile or
  the flight model passes, while losing a way of flying (one side to land from, the lift-held bank, the line-up, the
  energy on the final) costs 10-80% and fails.
- Each regression entry for these fixes (`tests/regressions/mutations.json`: the `ai-*` and `race-*` entries of
  2026-11-06) is caught by it, `test_race` or `test_combat_vs_demo`. Putting each back one at a time and flying the whole
  exam showed which ways of flying still earn their place: with the others in, several cost the falcon only 1-3% of its
  landings, which no bound robust to a subtle change can see. Those are caught by what they change in the flight
  instead -- the over-banked time (the lift cap: the falcon's 0.5% becomes 8-17%), the median time close in on the line
  (the straight-in: the falcon's 1.3 s becomes 14 s), the speed finals begin at (the spiral: nine in ten under 1.1-1.28 x
  cruise, without it 1.4-1.6), the oak's low tier from above and below (the route floor: the falcon's 31 of 36 becomes
  17). Two that changed nothing measurable were taken out: an aim-ahead special case for the last legs, and ranking ways
  in by their pre-approach leg. A third, the gentle pull to slow to cruise on the approach leg, changes nothing the exam
  measures (fresh or tired, stamina 0.2), but without it test_combat_team's 3 v 3 ran a different match in which three
  birds spent most of 400 s trying to rest: it stays, without a regression entry, until a controlled check shows it
  either way.
- The runs are deterministic (fixed steps, seeded): the same code gives the same numbers.

## Our other AI tests

How robust each is against a change it isn't about:

| Test | Checks | Depends on | Robust? |
|---|---|---|---|
| `test_ai_avoidance` | the avoidance and the planner, in hand-built layouts | its own trunks and limbs | yes: controlled scenes, both sides |
| `test_ai_flight` | the flock chaining perches in two greybox arenas and the pine wood, 90 s | the generated arenas | fair: flock totals with wide bounds; the per-species ">= 4 in both arenas" is one run each |
| `test_race` (field, run-in, go-round) | pilots and aces take every gate and land home; racers out on the run-in land; a racer put beside a gate goes round | course 16 of arena 7: one run each | fragile where it judged one landing each, on one rail in one clearing: it moved with every change here. The field's landing home is now per species (the pilot or the ace lands, at most one of the ten misses, named); the exam's rails objective judges rail landings over many tries. The go-round now has a place of its own (a 3 m post gate 7 m up with pines off one side, as course 16's gate 3 was before big-trees moved its trees) |
| `test_combat_team` | 3 v 3s: hits both ways, targets spread, little friendly fire; a downed bird comes back and flies | two 90 s matches in the wood; a bird shot down on purpose | was fragile: one match, run on until a downed bird was back -- deterministic but chaotic, so a change anywhere in the flying ran a different match, and one with nobody downed ran to 400 s, past the runner's 120 s. Now two fixed matches judged on what every match shows, and the downing done by real hits in a third shard, so it always happens. Over six matches (`probe_combat_rest --ai-seed 20..120`) birds landed on their bases 21 times (4 on master with the big-trees wood), and spent 10-25% of the match resting on the ground |
| `test_combat_vs_demo` | the combat AI out-hits the old demo shooter on an evading racetrack target, four woods | the racetrack's place in the wood | fair: after big-trees no loop at 20 m is clear of the crowns. The combat AI held every shot while avoiding wood, so it fired once in 40 s; seekers (gated by lock and line of sight) now fire while it dodges: 18 v 13, and 20 v 13 with the start nudged |
| `test_combat_ai` | rearming, leaving the base, resting, the boxed-in base | `Pinewood.generate(7)` perches and bases | mixed: the scenes are picked from the wood, so a change to the wood changes which perch is tested (the no-way-in base now builds its own) |
| `test_combat_team`, `test_combat_boom_zoom`, `test_combat` | 3 v 3 and duels | the wood; many seeds averaged | fair: totals over several woods with bounds about three standard deviations short |

Recommendations: when an AI check is about an objective (land, rearm, take off), give it a place of its own
(`FlightExam`) and judge a share over several attempts; keep the generated wood for checks that are about the wood (that
it can be flown at all), with totals and wide bounds.

## Running it

```
.\probe.ps1 -Headless -Engine --fixed-fps -Engine 60 probe_flight_exam --tree pine            # every perch, 4 sides
.\probe.ps1 -Headless -Engine --fixed-fps -Engine 60 probe_flight_exam --tree big_oak --rail --bearings 0,45,90,135,180,225,270,315 --ups 3,10
.\probe.ps1 -Headless -Engine --fixed-fps -Engine 60 probe_flight_exam --tree pine --grove     # among others
.\probe.ps1 -Headless -Engine --fixed-fps -Engine 60 probe_flight_exam --tree oak --hop veteran
.\probe.ps1 -Headless -Engine --fixed-fps -Engine 60 probe_flight_exam --gates --skills recruit,pilot,ace
.\probe.ps1 -Headless -Engine --fixed-fps -Engine 60 probe_flight_exam --tree pine --bearings 0 --out 12 --ups 0   # close in
.\probe.ps1 -Headless -Engine --fixed-fps -Engine 60 probe_flight_exam --tree oak --perches 0 --birds falcon --bearings 0 --trace 0
```

`--fixed-fps 60` steps the physics as fast as the machine allows and makes the run repeatable (without it, it runs in
real time). `--trace <n>` prints attempt n's flight every 0.1 s: where it is, its speed against its stall and catch,
its path angle and bank, the pilot's mode and waypoint, the avoidance, the catch candidate. Each species' `FLOWN` line
gives its time over-banked and how far the attempts from in front turned.
