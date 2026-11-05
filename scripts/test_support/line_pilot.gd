class_name LinePilot
extends RefCounted
## Flyability's yardstick: a pilot that knows the course's planned line exactly and follows it, as well as the
## bird can (RaceCourse.flown_line, gate to gate). No avoidance, no noise, no reaction time, the full bank limit: if a
## bird flown by this can't stay on a leg's line, the leg asks more than the bird has; if it can and the AI misses,
## that's the AI's. Produces a FlightInput only (the player's authority).
##   lateral       a pursuit of the point LOOK ahead along the line (an L1 guidance law: the bank that curves the
##                 path onto it, up to the bird's bank limit)
##   longitudinal  the path angle to that point, with the extra pull a bank needs (1/cos - 1)
##   energy        flaps when slow or when the line climbs past its glide, every wingbeat it has (weak ones too)
## Each leg is flown from where the last one left the bird; a leg it fails (its gate not taken within FAIL_OFF of the
## line, or by the time it's past it) is marked, and the bird is put back on the line at that gate, along its way
## through, at the speed it had: so one bad leg doesn't spoil the next (`legs`).

const LOOK := 0.55        ## s of flight ahead the pursuit point lies (at least LOOK_MIN m)
const LOOK_MIN := 3.5
const PULL_GAIN := 3.0
const BANK_PULL := 0.8    ## stick per unit of extra load a bank needs
const FAIL_OFF := 4.0     ## m off the line: that leg is failed

var course: RaceCourse
var run: RaceRun
var line := PackedVector3Array()   ## the whole course's flown line, about a metre a chord
var leg_of := PackedInt32Array()   ## each point's leg (the gate it leads to)
var legs: Array = []               ## per gate: {off (m, the most it strayed), low (m, the lowest above the ground),
                                   ##   speed (m/s, through the gate), bank (deg, the most it used), touches (of wood), ok}
var _i := 0                        ## the nearest line point so far
var _touch0 := 0                   ## the bird's touches of wood when this leg began


func _init(c: RaceCourse, r: RaceRun) -> void:
	course = c
	run = r
	for k in c.gates.size():
		var pts := c.flown_line(c.gates, k)
		for j in pts.size() - 1:
			var n := maxi(1, ceili(pts[j].distance_to(pts[j + 1])))
			for s in n:
				line.append(pts[j].lerp(pts[j + 1], float(s) / n))
				leg_of.append(k)
		legs.append({"off": 0.0, "low": INF, "speed": 0.0, "bank": 0.0, "ok": true, "done": false, "touches": 0})
	var last := c.gates[-1]
	for s in 12:   # (on past the finish)
		line.append(last.centre + last.normal * s)
		leg_of.append(c.gates.size() - 1)


## Where to start: just out from the start perch along the first leg's line, at cruise.
func start_at() -> Array:
	return [line[2], (line[4] - line[2]).normalized()]


func sample(bird: Bird, _dt: float) -> FlightInput:
	if run.finished() or bird.state != Bird.State.FLYING:
		return FlightInput.new()
	var m := bird.model
	var p := bird.profile
	var pos := bird.global_position
	# The nearest point on the line, searching on from the last.
	var best := INF
	var hi := mini(_i + 40, line.size() - 1)
	for j in range(_i, hi + 1):
		var d := pos.distance_squared_to(line[j])
		if d < best:
			best = d
			_i = j
	var k: int = leg_of[_i]
	if k == run.next and k < legs.size():
		var lg: Dictionary = legs[k]
		lg.off = maxf(lg.off, sqrt(best))
		lg.low = minf(lg.low, pos.y - bird.layout.ground(pos.x, pos.z))
		lg.bank = maxf(lg.bank, absf(rad_to_deg(m.bank)))
	var v := maxf(m.speed, 1.0)
	var ahead := maxf(LOOK_MIN, v * LOOK)
	var j2 := _i
	var walked := 0.0
	while j2 < line.size() - 1 and walked < ahead:
		walked += line[j2].distance_to(line[j2 + 1])
		j2 += 1
	var aim := line[j2]
	# Lateral: L1 guidance -- the lateral acceleration that curves the path onto the aim point.
	var fd := m.flight_dir()
	var fh := Vector3(fd.x, 0.0, fd.z).normalized()
	var to := Vector3(aim.x - pos.x, 0.0, aim.z - pos.z)
	var eta := AIPilot._signed_heading(fh, to)   # (+: aim to the right)
	var l1 := maxf(to.length(), 1.0)
	var a_lat := 2.0 * v * v * sin(eta) / l1
	var max_bank := deg_to_rad(p.max_bank_deg)
	var bank_cmd := clampf(atan(a_lat / BirdProfile.G), -max_bank, max_bank)
	# Longitudinal: the path angle to the aim point, and the pull the bank needs.
	var gamma := atan2(aim.y - pos.y, maxf(to.length(), 1.0))
	var sy := (gamma - m.path_angle) * PULL_GAIN + (1.0 / maxf(cos(m.bank), 0.25) - 1.0) * BANK_PULL
	var flap := m.speed < p.v_best or gamma > -p.glide_angle * 0.5
	return FlightInput.new(Vector2(bank_cmd / max_bank, clampf(sy, -0.8, 1.0)), false, flap)


## After the run has stepped: the leg just finished (the gate taken), or failed (strayed past FAIL_OFF, or past the
## gate's plane): marked, and the bird put back at the gate. Call once a tick, after RaceRun.step.
func check(bird: Bird) -> void:
	var k := run.next
	var touches := bird.bonks + bird.glances + bird.wing_strikes
	if run.event in ["gate", "finish"]:
		var done: Dictionary = legs[k - 1]
		done.speed = bird.model.speed
		done.done = true
		done.touches = touches - _touch0
		done.ok = done.ok and done.touches == 0
		_touch0 = touches
		return
	if k >= legs.size() or run.finished():
		return
	var g := course.gates[k]
	var lg: Dictionary = legs[k]
	var past := (bird.global_position - g.centre).dot(g.normal) > 1.0
	if lg.off > FAIL_OFF or past or bird.state != Bird.State.FLYING:
		lg.ok = false
		lg.done = true
		lg.speed = bird.model.speed
		lg.touches = touches - _touch0
		_touch0 = touches
		# Back on the line at the gate, along its way through, at the speed it had (or cruise, if it stopped).
		var v := maxf(bird.model.speed, bird.profile.v_best)
		bird.fly_from(g.centre + g.normal * 0.6, g.normal, v)
		run.next += 1
		run.splits.append(run.clock)
		if run.next >= course.gates.size():
			run.phase = RaceRun.Phase.FINISHED
			run.time = run.clock
		_i = _nearest_from(_i, bird.global_position)


func _nearest_from(i: int, pos: Vector3) -> int:
	var best := INF
	var at := i
	for j in range(i, line.size()):
		var d := pos.distance_squared_to(line[j])
		if d < best:
			best = d
			at = j
	return at


## Fly `birds` round `course` with LinePilot (all at once: they don't collide); per bird, its legs (LinePilot.legs).
static func fly_course(layout: ArenaLayout, course: RaceCourse, birds: Array, parent: Node) -> Dictionary:
	var trial := RaceTrial.new()
	parent.add_child(trial)
	trial.setup(layout, course)
	var pilots := []
	for id in birds:
		var run := RaceRun.new(course)
		var lp := LinePilot.new(course, run)
		var e := trial.add_bird(id, lp, run)
		var at: Array = lp.start_at()
		e.bird.fly_from(at[0], at[1], e.bird.profile.v_best)
		e.prev = at[0]
		pilots.append([e, lp])
	for f in 60 * 120:
		await trial.step()
		var all_done := true
		for pe in pilots:
			pe[1].check(pe[0].bird)
			all_done = all_done and pe[0].run.finished()
		if all_done:
			break
	var out := {}
	for pe in pilots:
		out[pe[0].bird.profile.id] = pe[1].legs
	trial.queue_free()
	return out
