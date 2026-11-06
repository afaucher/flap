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
| pine, veteran, pole, oak | one tree of that form (the middle of the wood's size range for it) |
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
| - | Don't hit things | the flock's touches of wood |

An attempt passes if the bird sits on the perch (or has taken every gate) within 45 s. A bird that sits on another
perch first is sent on again; one that gives the perch up is asked again. Each species is judged on its share of
attempts and its median time (`test_flight_exam.RATE`, `TIME`).

## Baseline and now

Landed / tried, 45 s each (master 25df35b before; this branch after):

| Scene | crow | owl | hawk | falcon | sparrow |
|---|---|---|---|---|---|
| pine | 39 -> **44** / 44 | 39 -> **44** | 36 -> **44** | 8 -> **44** | 39 -> **44** |
| veteran | 57 -> **60** / 60 | 58 -> **60** | 58 -> **60** | 16 -> **60** | 51 -> **58** |
| pole | 28 -> **28** / 28 | 28 -> **28** | 24 -> **27** | 16 -> **28** | 26 -> **28** |
| oak | 42 -> **44** / 44 | 41 -> **44** | 36 -> **43** | 25 -> **44** | 41 -> **44** |
| pine's rail | 16 -> **16** / 16 | 16 -> **16** | 15 -> **16** | 4 -> **16** | 16 -> **16** |
| big oak's rail | 16 -> **16** / 16 | 16 -> **16** | 16 -> **15** | 7 -> **16** | 16 -> **16** |
| gates | 30 -> **30** / 30 | 30 -> **30** | 30 -> **30** | 24 -> **30** | 30 -> **30** |
HEIGHTS_GROVE_HOP

Median time to land on a lone pine: crow 6.4 -> 4.1 s, owl 6.5 -> 4.0, hawk 8.4 -> 3.6, falcon 13.4 -> 9.0, sparrow
10.9 -> 4.2. In the generated wood (`test_ai_flight`, 90 s, the flock picking its own perches): greybox 35 -> 48
perches (0 bonks), pine wood 21 -> 32 perches, 9 -> 4 bonks.

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
turn-straight-turn path from where it is, heading in), those it can line up on clear of the wood first, and those whose
pre-approach leg is open before those whose isn't; a bird already in on a way's line flies straight in.

**Line up for the final on your own turning circle** (`AIPilot._line_up`, `Dubins`). The planned route doesn't know
which way the bird is flying; a wide turner reached its last waypoints still turning and passed the perch to the side.
Within three turning circles of the approach point, the route's last legs are replaced by a turn-straight-turn path on
the circle the bird holds (with a margin), arriving at the approach point heading in -- if that path is clear of the
wood (half a wingspan and a margin). On the turn it aims far enough ahead to bank as the circle needs; from the
approach point on, close again.

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

**What's left.** The falcon can't always make the oak's lowest limbs (5 m, under limbs at 10 m): there's no room under
the crown to turn on its 13 m circle, and the ground limits its bank. It lands on all of them from 30 m out at 3 m above,
but from far above or below, or hopping from another tree, it misses some (81 of 88, 18 of 22). The hawk misses a few
of the big oak's rail from high above, coming onto the approach too fast after its spiral.

## The test, and why its bounds hold

`test_flight_exam` runs one scene a shard (9 shards, 20-60 s each) and checks each species' share and median time, and
the flock's touches of wood:

- Shares are judged over 20-90 attempts a species, from every side; one attempt that goes differently moves a share by
  1-5%. The bounds (`RATE`) sit 5-15% under what the AI does now, so a subtle change to a tree's shape, a profile or
  the flight model passes, while losing a way of flying (one side to land from, the lift-held bank, the line-up, the
  energy on the final) costs 10-80% and fails.
- Every regression entry for these fixes (`tests/regressions/mutations.json`, `ai-*`, `race-turns-past-lift`,
  `rail-deck-open-from-behind`) is caught by it or by `test_race`.
- The runs are deterministic (fixed steps, seeded): the same code gives the same numbers.

## Our other AI tests

How robust each is against a change it isn't about:

| Test | Checks | Depends on | Robust? |
|---|---|---|---|
| `test_ai_avoidance` | the avoidance and the planner, in hand-built layouts | its own trunks and limbs | yes: controlled scenes, both sides |
| `test_ai_flight` | the flock chaining perches in two greybox arenas and the pine wood, 90 s | the generated arenas | fair: flock totals with wide bounds; the per-species ">= 4 in both arenas" is one run each |
| `test_race` (field, run-in, go-round) | every pilot and ace lands home; racers out on the run-in land | course 16 of arena 7: one run each | fragile: one landing each, on one rail in one clearing; it moved with every change here. The exam's rails objective is the robust version; the field check could become "at least 9 of 10 pilots and aces land home" |
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
.\probe.ps1 -Headless -Engine --fixed-fps -Engine 60 probe_flight_exam --tree oak --perches 0 --birds falcon --bearings 0 --trace 0
```

`--fixed-fps 60` steps the physics as fast as the machine allows and makes the run repeatable (without it, it runs in
real time). `--trace <n>` prints attempt n's flight every 0.1 s: where it is, its speed against its stall and catch,
its path angle and bank, the pilot's mode and waypoint, the avoidance, the catch candidate.
