# Race mode (prototype)

A course of gates through the pine wood, flown against the clock. This first version validates how racing works:
how a course is laid out in the wood, what turns and climbs it asks of each bird, and how the AI racers fly it. The
gates are placeholders (frames, bars and rings); their designs and the menu entry come later.

Play it: `.\run.ps1 --race [--bird hawk] [--flying novice] [--race-ai recruit|pilot|ace] [--course <n>]`
(`--autopilot` or P: an ace racer flies your bird). Measure it: `.\probe.ps1 -Headless probe_race [--seed n]`.

## The course (`scripts/race/race_course.gd`)

Ten gates, the last the finish, from the rail of the outpost nearest the middle of the wood (if no full course leaves
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
- **Climbs and dives.** A climb at most 15 deg over the leg less 4 m (the zoom out of the gate before); a dive at
  most 35 deg over the leg less the 8 m level run-in.
- **Seeing the way.** The next gate is in sight (its centre and 3 of 4 points round its rim, past trunks, branches
  and needles) from the gate you're passing and from 10 m before it. So is the gate after it, within 60 m, unless the
  turn at the next gate is over 60 deg: that gate is `marked`, for course markers round the turn (to come).
- The course never comes back within 10 m of a gate.

`problems()` lists any rule a course breaks; `test_race` checks generated courses keep them all, and hand-built
courses that break the turn and the way-in rules are caught.

## The rules of a run (`race_run.gd`)

- The clock starts the tick the bird leaves the start rail and stops at the finish gate.
- A gate counts only through its window the way it faces, and only the next one: a later gate flown first doesn't
  count. Crossing the next gate's plane beside its window (within 10 m) is a miss; the gate stays next, to go back for.
- Splits and the finish are timed to the moment the bird crossed, within the tick.
- Best times (with their splits) are kept per course, bird and way of flying (`RaceRecord`, `user://race_best.cfg`).

The HUD (`race_hud.gd`): the clock and the gate count top centre, the last split against your best's, your best top
right, a bracket and distance on the next gate (fainter on the one after), an arrow at the edge when it's off screen.

## What the probe measured (2026-11-05, planned for all five)

Courses on seeds 3, 5, 7, 9 and 11: 10 gates each, 240-280 m, every rule kept; windows from 2.3 to 14 m up; three or
four kinds each, about half of them post gates (they fit anywhere in the open); both turn directions on every course,
but each winds round 200-300 deg in all, like a circuit. Every leg's flown line turns wider than the hawk's 6.9 m
circle (7-50 m).

Fifteen AI racers (every bird at every skill) on seeds 7 and 11: one finish (the ace hawk on seed 7, 74.7 s, five
misses on the way). Where they missed says as much about the course as the AI:
- the gates right after a turn over 60 deg (the `marked` ones: hidden until the turn, and the line into them is the
  tightest): on seed 7 nearly every racer stalled at gate 2, after a 69 deg turn, and again at gate 4, after 61 deg;
- low post gates (window 0.8 m off the ground), worst as the first gate off the start rail: on seed 11 most racers
  never took gate 1, a low post gate 6 m below the rail.

Candidate rules from this, not yet in: no turns over 60 deg until course markers exist (or a longer leg after one);
no low gate first off the start.

## Open questions

- Gate designs (the prop sheet: banded trunks with bunting, willow hoops, balloon gates over the open ground) and
  soft rope contact.
- Course markers for `marked` turns (chevron boards, marker balloons).
- The AI racer's gate-hitting (separate work): it lines up on a carrot along the gate's axis and gets down to the
  window early, but low windows after a hard turn still beat it, and its go-arounds are slow.
- Courses per class (agile birds vs the hawk and falcon), ghosts, the menu entry.
