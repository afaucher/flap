# Race mode (prototype)

A course of gates through the pine wood, flown against the clock. This first version validates how racing works:
how a course is laid out in the wood, what turns and climbs it asks of each bird, and how the AI racers fly it. The
gates are placeholders (frames, bars and rings); their designs come later.

Play it from the menu's Race screen (your bird, the course: Technical or Long, Level or High and low -- four courses on the game's arena, seed 7, `Menu.COURSES`; rivals: none,
recruits, pilots or aces, one of each other bird; Novice | Realistic; your best on that course shown), or
`.\run.ps1 --race [--bird hawk] [--flying novice] [--race-ai recruit|pilot|ace] [--course <n>]` (`--autopilot` or P: an
ace racer flies your bird). The menu's race has no rider or tack (`--no-rider`); the pause menu's Start over puts
everyone back on the rail, the clocks reset. Measure it: `.\probe.ps1 -Headless probe_race [--seed n]`.

## The course (`scripts/race/race_course.gd`)

Ten gates, from the rail of the outpost nearest the middle of the wood and back to it (the race ends landing on the
rail) (if no full course leaves
it, the next one out). Each window is 3 m across.

| Kind | Where | Heights |
|---|---|---|
| post | two posts standing on open ground, a banner between their tops; turned to the course | low (window 0.8-3.8 m) or tall (5.5-8.5 m) |
| trunk | between two pines whose trunks are 3.6-6 m apart, a banner from trunk to trunk | any, under the crowns |
| hoop (limb) | a ring hung on ropes from an oak's or pine's long, nearly level limb | under the limb |
| hoop (span) | a ring hung from a rope strung between two pines 8-16 m apart | any, under the crowns |

The posts are solid wood in the layout (`apply()`), so they collide, the AI avoids them and the reflexes see them.
Ropes, frames and rings are drawn only for now (contact with ropes: soft, to come with the gate designs).

A beam search strings candidate gates together under the rules below, scored for variety: legs about 25 m, height
changes, a change of kind, turns of 20-70 deg, turning back against the way the course has wound so far, and the kinds
that fit in fewer places (trunk gates and limb hoops). About 3-5 s per course on this machine (on the loading screen's
worker thread).

## Planning rules from performance

The rules about flying a course come from the birds racing it (`RaceCourse.Envelope`): the widest cruise turning
circle (`AIPilot.cruise_turn_radius`: v* at 85% of the bank limit) and the widest wings among them. By default all
five race, so the hawk sets both (turning circle 6.9 m, span 1.3 m). `--plan-for crow,owl,sparrow` plans for the
agile birds (3.4 m, 1.1 m): tighter courses.

- **A clear way in and out.** 1.5 turning circles of straight clear run in front of each window (10.4 m for the hawk)
  and 0.8 past it (5.6 m), clear by half a wingspan and 0.4 m; the lanes along the window's four edges clear 3 m
  either side. The bird is rolled out and lined up before the window, and through it before it must turn.
- **The flown line, not the straight one.** Each leg is checked along the line a bird flies (`flown_line`): out of
  one gate along its way through, into the next along its, a smooth curve between, down to the window's height 8 m
  before it on a dive. That line is clear of wood by half a wingspan and 0.4 m, of gate posts by 1 m, and of every
  rope by 1.5 m (1 m from the ropes over the window it goes through).
- **Turns the birds can make.** The flown line's tightest radius is at least the widest turning circle. Each leg
  leaves and meets its gates within 45 deg of their way through, so a turn at a gate is at most 90 deg.
- **Climbs and dives.** A climb at most 15 deg, a dive at most 35 deg, over the leg less the metres it spends
  turning (`turn_arc`: the leg's heading change on the widest turning circle; a bird can't dive or climb steeply
  banked hard), less 4 m out of the gate before on a climb, and less a level run-in before the gate on a dive (0.9 s
  at the fastest racer's cruise, at least 8 m: 11.3 m with the falcon racing). The planned line turns first, then
  changes height.
- **Seeing the way.** The next gate is in sight (its centre and 3 of 4 points round its rim, past trunks, branches
  and needles) from the gate you're passing and from 10 m before it. So is the gate after it, within 60 m, unless the
  turn at the next gate is over 60 deg: that gate is `marked`, for course markers round the turn (to come).
- The course never comes back within 10 m of a gate.
- **The way home** (`home_problem`): the race ends landing on the rail it started from, so the last gate is within 45 m
  of it with it in sight, and home is straight: from the last gate (turning at most 90 deg out of it) to a run-in out in
  front of the rail (`home_in`: 1.5 turning circles out, a little below), clear of the wood and of every gate's posts
  and ropes, turning at most 120 deg onto the run-in, which is clear too. No loop round the outpost's tree to land
  facing the rail. The rail faces out, so a course comes home from the side it left by: it turns about half round in
  all (out and back), and the search keeps every gate within reach of home (25 m a leg left) and pulls the last five
  legs toward a point out in front of the run-in; winding on past 200 deg one way is scored down (a full circuit comes
  home from behind). The price: on arena 7, 10 of 24 course seeds make a full course (`tests/probe_courses.gd`), the
  others nine gates; and they lean to post gates in the open. Courses 16, 23 and 17 leave the centre outpost with two or
  three kinds and windows up to 8-14 m.

`problems()` lists any rule a course breaks; `test_race` checks generated courses keep them all, and hand-built
courses that break the turn and the way-in rules are caught.

## Flyability (`LinePilot`, `tests/probe_flyable.gd`)

Whether a course asks more than a bird has is measured apart from the AI: `LinePilot` flies the planned line
itself, known exactly, through the bird's own flight model (an L1 pursuit of a point 0.55 s ahead along the line,
the full bank limit, the pull a bank needs, flapping when slow), with no avoidance, noise or reaction time. Each leg
is flown from where the last left the bird; a leg it can't fly (more than 4 m off the line, or past the gate) is
marked and the bird put back at that gate. `.\probe.ps1 -Headless probe_flyable --seed 7` prints each leg for each
bird. A leg no bird can fly is the course's to fix; one they can and the AI misses is the AI's.

What it found (2026-11-05): with the first rules, seed 7 had two legs three of the five birds couldn't fly, both
steep dives straight out of a 61-69 deg turn. Leaving the turn out of the dive (`turn_arc`) fixed those; seeds 11, 3
and 5 then showed six legs only the falcon couldn't fly, low windows it couldn't settle into from its speed, fixed by
scaling the level run-in to the fastest bird. Now every bird flies every leg on seeds 3 and 9; four bird-legs are
left on the other three: three of the falcon's (descents to a window out of a turn) and one of the sparrow's (a
climb out of a 64 deg turn). `test_race` requires every leg flown by at least four of the five birds,
and every bird to fly at least nine of the ten legs, on seeds 7 and 11.

The price: these courses are mostly post gates (6-8 of 10: they face any way, so fit the rules most easily), with
trunk gates and a hoop or two; they still wind round one way (200-290 deg). Planned for the agile birds only
(`--plan-for crow,owl,sparrow`) crow, owl and sparrow fly every leg, with no more variety: the rules about the way in
and seeing the next gate, not the hawk, are what keep the gates in the open.

## The rules of a run (`race_run.gd`)

- The race starts and ends on the outpost's rail: the clock starts the tick the bird leaves it and stops the tick it
  lands back on it with every gate taken. Landing on it with a gate still to go resets the run (ready to start again,
  the clock at 0); landing anywhere else doesn't stop the clock. The way home
  from the last gate is free: no line, no rules but the landing.
- A gate counts only through its window the way it faces, and only the next one: a later gate flown first doesn't
  count. Crossing the next gate's plane beside its window (within 10 m) is a miss; the gate stays next, to go back for.
- Splits are timed to the moment the bird crossed, within the tick; the finish to the tick it lands.
- Best times (with their splits) and the last ten finishes are kept per course, bird and way of flying (`RaceRecord`,
  `user://race_best.cfg`).

The HUD (`race_hud.gd`): the clock and the gate count top centre ("Land on the rail" once every gate is taken), the
last split against your best's under it for 3 s, top right your best and the average of your last three finishes, a
bracket and distance on the next gate (fainter on the one after; the rail's mark after the last), an arrow at the edge
when it's off screen. The rail's mark (`RaceView`) lights up when it's next.

## What the probe measured (2026-11-05, planned for all five)

Courses on seeds 3, 5, 7, 9 and 11: 10 gates each, 240-280 m, every rule kept; windows from 2.3 to 14 m up; three or
four kinds each, about half of them post gates (they fit anywhere in the open); both turn directions on every course,
but each winds round 200-300 deg in all, like a circuit. Every leg's flown line turns wider than the hawk's 6.9 m
circle (7-50 m).

With the first AI racer (it aimed at a point on each gate's axis), fifteen racers (every bird at every skill) on seeds
7 and 11 made one finish (the ace hawk on seed 7, 74.7 s, five misses on the way). Where they missed says as much about the course as the AI:
- the gates right after a turn over 60 deg (the `marked` ones: hidden until the turn, and the line into them is the
  tightest): on seed 7 nearly every racer stalled at gate 2, after a 69 deg turn, and again at gate 4, after 61 deg;
- low post gates (window 0.8 m off the ground), worst as the first gate off the start rail: on seed 11 most racers
  never took gate 1, a low post gate 6 m below the rail.

These were AI-trial results on the first rules; probe_flyable since showed most of those legs were the course's
(dives out of hard turns), and the rules now leave them out. The AI's own misses are separate work.

## The AI racer (`race_pilot.gd`)

It flies the course's planned line (the one probe_flyable proved), by the same kind of L1 pursuit as LinePilot, through
a FlightInput only. Its skill takes away from a perfect pilot:

| | look-ahead | bank (of the limit) | input lag | aim drift (sd) | pace (x v*) |
|---|---|---|---|---|---|
| recruit | 0.8 s | 0.7 | 0.18 s | 0.6 m | 1.0 |
| pilot | 0.65 s | 0.85 | 0.1 s | 0.3 m | 1.05 |
| ace | 0.55 s | 0.95 | 0.05 s | 0.1 m | 1.12 |

Height comes from a point 0.6 s ahead (nearer made the fast birds porpoise into the gates); under its line by more than
a metre it banks no more than 45 deg and flaps until it's back up. A wood guard hands the tick to AIPilot.steer's
avoidance when 0.4 s straight on meets wood, and below 1.25x its stall speed (after a bonk) AIPilot.steer's low-speed
recovery flies it. Lost (past the gate's plane outside its window, or 5 m off its line), it plans a go-around: the
shortest turn-straight-turn (Dubins) path clear of wood, from where it is and the way it's flying, on the circle it
can turn at its speed at no more than 60 deg of bank (x1.15), to a point out in front of the gate facing through it;
the loop climbs 3 m, the run-in comes down to the gate. It follows that as it follows the course. Every gate taken,
AIPilot flies it home and lands it on the rail (`go_to_perch`: a planned route, the approach and the catch, as a combat
bird goes to its base); not landed in 40 s, it gives up.

What it does (2026-11-05, `probe_race`, every bird at every skill on seeds 3, 5, 7, 9 and 11, 25 runs a skill):

| | finished | mean time | bonks (all runs) |
|---|---|---|---|
| pilot | 23 of 25 | 23.6 s | 2 |
| ace | 23 of 25 | 23.6 s | 3 |
| recruit | 11 of 25 | 39.9 s | 36 |

(Those times stopped at the last gate, before the race ended back on the rail; the first AI racer made one finish in
30.)

With the finish on the rail (2026-11-05, seeds 7, 11 and 3, 15 runs a skill): pilots finish 12 of 15 (mean 42.1 s),
aces 12 of 15 (41.7 s), recruits 6 of 15 (59.1 s). Every pilot and ace takes all ten gates; the three of each that
don't finish are the falcon, which AIPilot can't land on an outpost's rail at all (`tests/probe_race_home.gd`: each
bird flown by AIPilot from the last gate to the rail, with the course's posts in or out: the falcon 0 of 15, the others
14 or 15 of 15; it's the falcon's known weakness, `flight_model.md`: a final approach planned by speed would fix it).
The landing home adds 10-30 s and most of the spread between racers: a missed catch costs a loop round the outpost.
Racers going home drop AIPilot's departure clearance round the rail's tree (they took off from it), which had pushed
the sparrow off every final approach.

The falcon's rail landings (2026-11-05): its look-ahead (13-15 m at its speed) reached the rail from beyond the 8 m
in which AIPilot counts the perch's own tree and outpost as the perch it's landing on, so the deck it was landing on
blocked its approach and it flew escapes all the way in. Running the landing wherever the look-ahead reaches the
perch landed it from the last gate on courses 1 and 2 (3 of 3 each, from 0), but not on course 3 (it reaches that
rail from the side, low among the outpost pine's lower limbs, too tightly turned to line up), and it broke combat:
in test_combat_team's 3 v 3 the birds spent most of the match resting or failing to rearm on their bases, and no one
was downed. Lowering rail approaches less (0.4-0.7 m under the rail, not 1.2) landed the falcon on course 3 but lost
others elsewhere. Both were taken out: the final approach is fragile (arriving from the side, the bird's catch
candidate not the perch it aims for, the falcon's bleed target under its stall speed, the outpost counted as wood)
and wants planning by speed and turn, checked against free flight, combat and races together. The four pilot and ace runs that didn't finish are all the falcon's (seeds
5, 9, 11): a miss, then go-arounds it can't hold its height through. Recruits are slower and miss far more: their
wider look-ahead, input lag and aim drift take them off the line, and the go-arounds cost them 10-40 s. The ace is no
faster than the pilot yet: its edge (bank, lag, drift) doesn't buy time on these courses, where every bird flies the
same line; a racing line of its own (cutting corners, carrying speed) would.

With the way home planned (2026-11-05, arena 7, courses 16, 23 and 17): on course 16 every pilot and every ace
finishes, the falcon too (24-62 s; the hawk's landing loops cost it most); on 23 and 17 every pilot and ace but the
falcon, which fails out on the course, not landing. Recruits finish about half the time.

## Course styles (`RaceCourse.STYLES`, `--course-style`)

A style is a shape and heights, `<shape>-<heights>`; each sets the search's scoring and a few rules (`SHAPES`, `HEIGHTS`):

| | gates | legs | turns scored | other |
|---|---|---|---|---|
| technical | 12 | 12-24 m (aim 16) | 40-90 deg, S-bends favoured | planned for the agile birds (crow, owl, sparrow: a 3.4 m circle): the hawk and falcon can't make its turns, by design |
| long | 7 | 26-55 m (aim 40) | 5-40 deg | a leg the smooth curve can't fly clear is routed through the wood (`route_line`) |
| (all-round) | 10 | 14-40 m | 20-70 deg | as before |

Heights: level scores climbs and dives down and a narrow spread; high and low scores them up. **Routed legs**: the ways
out of the gate before and into the next are kept clear straight lanes, as on every leg; between them the AI's own
route planner (`FlightPlanner`, at the course's clearance) finds the way through the wood, its route no steeper than a
leg may climb or dive. A routed leg isn't held to the smooth curve's turning circle, and the next gate needn't be in
sight from the one before (the HUD's arrow shows the way); the AI racer and LinePilot follow the route.

The menu's four (arena 7, the map baked 2026-11-06 with the new oaks and pines): technical level, course 8 (12 gates,
windows 7-8.4 m); technical high and low, 19 (2.3-11 m); long level, 13 (7 gates, 7-8 m); long high and low, 12
(2.3-11 m). On that wood most seeds' courses turn one way only (probe_courses: 7L 0R and the like); test_race's
`_course_rules` takes seed 28, which turns both ways. Raced on the wood before that bake (probe_race; not yet re-raced): every pilot and ace crow, owl and sparrow finishes all four; the hawk finishes technical level but not
technical high and low (its turns aren't planned for it), and most of the long; the falcon fails the long ones, on
their routed legs (it can't hold a route's corners). `tests/probe_courses.gd --style <s>` sums up many seeds.

Not done: technical courses that cross themselves (the user's ask: the lit gates show the way). Scoring a crossing,
letting the course wind further and pulling the middle legs back at an early leg made one crossing in 32 courses: the
beam search picks each gate from those 12-24 m on, and a crossing needs the course planned as a figure of eight from
the start.

## Open questions

- Gate designs (the prop sheet: banded trunks with bunting, willow hoops, balloon gates over the open ground) and
  soft rope contact.
- Course markers for `marked` turns (chevron boards, marker balloons).
- The falcon turning back: even flapping it loses ~6 m in a 180 deg turn at 45-65 deg of bank, so a go-around beside a
  low gate can put it on the ground. The course rules' turning circle (85% of the bank limit, level) is optimistic for
  it: a course rule from its sustained level turn would be truer.
- Courses per class (agile birds vs the hawk and falcon), ghosts, riders and tack in a race.
