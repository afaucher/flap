class_name RaceRun
extends RefCounted
## One bird's run round a RaceCourse: the rules. Fed the bird's move each physics tick (step: where it was, where
## it is, the perch it's on):
##   - the race starts and ends on the course's start perch (an outpost's rail): the clock starts the tick the bird
##     leaves it, and stops the tick it lands back on it with every gate taken;
##   - a gate counts only when the bird goes through its window the way it faces, and only the next one: the gates
##     are taken in order, a later one flown through first doesn't count;
##   - crossing the next gate's plane outside its window (within MISS_NEAR) is a miss: the gate stays the next one,
##     to go back for (the time lost is the penalty);
##   - each gate's split is the moment the bird crossed it, found within the tick (so splits don't round to 1/60 s);
##   - landing on the rail with a gate still to take resets the run (ready to start again, the clock at 0); landing
##     anywhere else doesn't stop the clock.

enum Phase { READY, RUNNING, FINISHED }

var course: RaceCourse
var phase := Phase.READY
var clock := 0.0          ## s since the start
var next := 0             ## the gate to fly through next (= the gates' count: all taken, home to the rail)
var splits: Array[float] = []   ## s at each gate passed
var misses := 0
var missed_at: Array[int] = []  ## the gate each miss was at
var time := INF           ## the finish time
var event := ""           ## this tick's: "start", "gate", "miss", "finish" (landed home), "reset" (landed on the rail
                          ## with gates to go) or ""


func _init(c: RaceCourse) -> void:
	course = c


## The perch `bird` is sitting on (null while it isn't): what step() is fed.
static func perch_of(bird: Bird) -> Perch:
	return bird.perch if bird.state == Bird.State.PERCHED else null


## One physics tick of the bird's flight: it moved from `a` to `b` over `dt`; `perch`: the perch it's sitting on
## (null if it isn't: perch_of).
func step(a: Vector3, b: Vector3, dt: float, perch: Perch) -> void:
	event = ""
	if phase == Phase.FINISHED:
		return
	if phase == Phase.READY:
		if perch != null:
			return
		phase = Phase.RUNNING
		event = "start"
	var t0 := clock
	clock += dt
	if home():
		if perch == course.start:
			phase = Phase.FINISHED
			time = clock
			event = "finish"
		return
	if perch == course.start:   # (back on the rail before the course is done: the run starts over)
		_reset()
		event = "reset"
		return
	var g: RaceCourse.Gate = course.gates[next]
	var f := g.crossing(a, b)
	if f >= 0.0:
		splits.append(t0 + dt * f)
		next += 1
		event = "gate"
	elif g.missed(a, b):
		misses += 1
		missed_at.append(next)
		event = "miss"


func _reset() -> void:
	phase = Phase.READY
	clock = 0.0
	next = 0
	splits.clear()
	misses = 0
	missed_at.clear()


func finished() -> bool:
	return phase == Phase.FINISHED


## Every gate taken, not yet landed: on the way home to the rail.
func home() -> bool:
	return phase == Phase.RUNNING and next >= course.gates.size()


## What the HUD shows: {phase, clock, next, count, splits, time, misses, home (every gate taken: land on the rail),
## next_centre (the next gate's, or the rail's home), after_centre (the gate after it, the rail after the last, or
## null)}.
func state() -> Dictionary:
	var s := {"phase": phase, "clock": clock, "next": next, "count": course.gates.size(), "splits": splits.duplicate(),
		"time": time, "misses": misses, "home": next >= course.gates.size()}
	if next < course.gates.size():
		s["next_centre"] = course.gates[next].centre
		s["after_centre"] = course.gates[next + 1].centre if next + 1 < course.gates.size() else course.start.position
	elif phase != Phase.FINISHED:
		s["next_centre"] = course.start.position
		s["after_centre"] = null
	return s
