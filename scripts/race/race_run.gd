class_name RaceRun
extends RefCounted
## One bird's run round a RaceCourse: the rules. Fed the bird's move each physics tick (step: where it was, where
## it is, whether it's on a perch):
##   - the clock starts the tick the bird leaves the start perch, and runs until it passes the finish gate;
##   - a gate counts only when the bird goes through its window the way it faces, and only the next one: the gates
##     are taken in order, a later one flown through first doesn't count;
##   - crossing the next gate's plane outside its window (within MISS_NEAR) is a miss: the gate stays the next one,
##     to go back for (the time lost is the penalty);
##   - each gate's split is the moment the bird crossed it, found within the tick (so splits don't round to 1/60 s).

enum Phase { READY, RUNNING, FINISHED }

var course: RaceCourse
var phase := Phase.READY
var clock := 0.0          ## s since the start
var next := 0             ## the gate to fly through next
var splits: Array[float] = []   ## s at each gate passed
var misses := 0
var missed_at: Array[int] = []  ## the gate each miss was at
var time := INF           ## the finish time
var event := ""           ## this tick's: "start", "gate", "miss", "finish" or ""


func _init(c: RaceCourse) -> void:
	course = c


## One physics tick of the bird's flight: it moved from `a` to `b` over `dt`; `perched`: it's sitting on a perch.
func step(a: Vector3, b: Vector3, dt: float, perched: bool) -> void:
	event = ""
	if phase == Phase.FINISHED:
		return
	if phase == Phase.READY:
		if perched:
			return
		phase = Phase.RUNNING
		event = "start"
	var t0 := clock
	clock += dt
	var g: RaceCourse.Gate = course.gates[next]
	var f := g.crossing(a, b)
	if f >= 0.0:
		var t := t0 + dt * f
		splits.append(t)
		next += 1
		if next >= course.gates.size():
			phase = Phase.FINISHED
			time = t
			clock = t
			event = "finish"
		else:
			event = "gate"
	elif g.missed(a, b):
		misses += 1
		missed_at.append(next)
		event = "miss"


func finished() -> bool:
	return phase == Phase.FINISHED


## What the HUD shows: {phase, clock, next, count, splits, time, next_centre, next_normal, after_centre (or null),
## finish (the next gate is the finish)}.
func state() -> Dictionary:
	var s := {"phase": phase, "clock": clock, "next": next, "count": course.gates.size(), "splits": splits.duplicate(),
		"time": time, "misses": misses}
	if next < course.gates.size():
		var g: RaceCourse.Gate = course.gates[next]
		s["next_centre"] = g.centre
		s["next_normal"] = g.normal
		s["finish"] = g.finish
		s["after_centre"] = course.gates[next + 1].centre if next + 1 < course.gates.size() else null
	return s
