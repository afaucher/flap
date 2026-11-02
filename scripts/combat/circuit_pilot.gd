class_name CircuitPilot
extends RefCounted
## A simple pilot for the combat range (FlightInput only, like every controller):
##   CIRCUIT  fly a loop of waypoints at a set height (the range's figure-eight target).
##   CHASE    follow `quarry`, aiming `offset` m behind it -- a stand-in for a player, for tests and demos.
## Banks toward the next point, holds height with the stick, flaps to hold speed.

enum Mode { CIRCUIT, CHASE }

var mode := Mode.CIRCUIT
var waypoints: Array = []      ## Vector3, looped
var quarry: Bird = null
var offset := 12.0             ## CHASE: metres behind the quarry to aim at
var cruise := 1.0              ## x best-glide speed to hold
var wp := 0
var via: Array = []           ## points to fly through before the circuit (a respawn: out from the base and up)
## Evading: a Callable(bird) -> threat position or null (CombatWorld.threat_to). When something threatens,
## break hard -- full bank across the threat's line and a pull -- for BREAK_TIME, then rejoin the circuit.
var threat: Callable = Callable()
var evade := true
const BREAK_TIME := 1.1
var _break := 0.0
var _break_side := 1.0
var breaks := 0
var _stick := Vector2.ZERO


## A figure-eight of `n` points: two loops of radius `r` either side of `centre`, at `centre.y`.
## A racetrack: two straights of `length` joined by half-circles of radius `r`, turned `angle` rad about the
## vertical, at `centre.y`. Straights give a chaser time to lock; the turns break it.
static func racetrack(centre: Vector3, length: float, r: float, angle: float, n_turn := 7) -> Array:
	var pts := []
	var half := length * 0.5
	for side in 2:
		var s := 1.0 if side == 0 else -1.0
		pts.append(Vector3(-half * s, 0.0, r * s))
		pts.append(Vector3(0.0, 0.0, r * s))
		for k in n_turn:
			var a := PI * (k + 1) / (n_turn + 1)
			pts.append(Vector3(half * s + sin(a) * r * s, 0.0, cos(a) * r * s))
	var out := []
	for p in pts:
		out.append(centre + (p as Vector3).rotated(Vector3.UP, angle))
	return out


## The first racetrack orientation (in 15 deg steps) whose legs are all clear of trunks by `clearance`.
static func clear_racetrack(layout: ArenaLayout, centre: Vector3, length: float, r: float, clearance := 2.0) -> Array:
	for i in 24:
		var w := racetrack(centre, length, r, deg_to_rad(15.0 * i))
		var ok := true
		for k in w.size():
			if not layout.segment_clear(w[k], w[(k + 1) % w.size()], clearance):
				ok = false
				break
		if ok:
			return w
	return racetrack(centre, length, r, 0.0)


static func figure_eight(centre: Vector3, r: float, n := 16) -> Array:
	var out := []
	for i in n:
		var t := TAU * i / n
		out.append(centre + Vector3(r * 2.0 * sin(t), 0.0, r * sin(t) * cos(t) * 2.0))
	return out


func sample(bird: Bird, dt: float) -> FlightInput:
	if bird.state == Bird.State.PERCHED or bird.state == Bird.State.GROUNDED:
		return FlightInput.new(Vector2.ZERO, true, true)   # take off again
	if bird.state != Bird.State.FLYING:
		return FlightInput.new()
	var p := bird.profile
	var m := bird.model
	var pos := bird.global_position
	var aim := pos + m.flight_dir() * 10.0
	if not via.is_empty() and pos.distance_to(via[0]) < 4.0:
		via.pop_front()
	if not via.is_empty():   # (on the way back to the circuit: out from the base first)
		aim = via[0]
	elif mode == Mode.CIRCUIT and not waypoints.is_empty():
		var w: Vector3 = waypoints[wp % waypoints.size()]
		if Vector2(w.x - pos.x, w.z - pos.z).length() < 4.0:
			wp += 1
			w = waypoints[wp % waypoints.size()]
		aim = w
	elif mode == Mode.CHASE and quarry != null and is_instance_valid(quarry):
		# Lead pursuit once in range (cut the corner, as a pilot would), close from behind when far out.
		var qp := quarry.global_position
		var qv := quarry.model.velocity
		var d := pos.distance_to(qp)
		aim = qp + qv * clampf(d / 25.0, 0.2, 0.8) if d < offset * 2.5 else qp - quarry.model.flight_dir() * offset
	var max_bank := deg_to_rad(p.max_bank_deg)
	# Break turn: across the threat's line of approach, toward whichever side it's already coming from less.
	_break = maxf(0.0, _break - dt)
	if evade and threat.is_valid() and _break <= 0.0:
		var th: Variant = threat.call(bird)
		if th != null:
			var from: Vector3 = pos - (th as Vector3)
			_break_side = -signf(AIPilot._signed_heading(m.flight_dir(), from)) if from.length() > 0.1 else 1.0
			if _break_side == 0.0:
				_break_side = 1.0
			_break = BREAK_TIME
			breaks += 1
	if _break > 0.0:
		var pull := 0.55 if m.speed > p.v_stall * 1.25 else 0.0
		_stick = _stick.lerp(Vector2(_break_side * 0.95, pull), 1.0 - exp(-14.0 * dt))
		return FlightInput.new(_stick, false, m.energy.burst >= 1.0)
	var desired := (aim - pos).normalized()
	var sx := clampf(AIPilot._signed_heading(m.flight_dir(), desired) * 2.0, -max_bank * 0.8, max_bank * 0.8) / max_bank
	var horiz := Vector2(aim.x - pos.x, aim.z - pos.z).length()
	var gamma_cmd := clampf(atan2(aim.y - pos.y, maxf(horiz, 1.0)), deg_to_rad(-25.0), deg_to_rad(20.0))
	var sy := clampf((gamma_cmd - m.path_angle) * 3.0, -0.6, 0.6)
	if m.stalled:
		sy = minf(sy, -0.3)
	_stick = _stick.lerp(Vector2(sx, sy), 1.0 - exp(-10.0 * dt))
	var flap := m.speed < p.v_best * cruise or pos.y < 4.0
	return FlightInput.new(_stick, false, flap and m.energy.burst >= 1.0)


## Rejoin the circuit from wherever the bird is (a respawn at its base): out along `out` and up first, then the
## nearest waypoint.
func rejoin(from: Vector3, out: Vector3) -> void:
	var exit := from + Vector3(out.x, 0.0, out.z).normalized() * 10.0 + Vector3.UP * 3.0
	via = [exit]
	var best := 0
	for i in waypoints.size():
		if (waypoints[i] as Vector3).distance_to(exit) < (waypoints[best] as Vector3).distance_to(exit):
			best = i
	wp = best
