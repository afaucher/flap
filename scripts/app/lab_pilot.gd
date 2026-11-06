class_name LabPilot
extends RefCounted
## The bird lab's controller: flies one scripted manoeuvre with the player's controls (a FlightInput and
## nothing else, like AIPilot), so the lab shows exactly what the game does.
##   APPROACH  steer at `target` (+ `aim_up`), bleed speed for the catch (unless `bleed` is off: the too-fast
##             case) and hold CATCH from 8 m out, as the AI's final approach does. Coming in high it dives to a
##             gate below the branch and swoops up; if it flies past, it goes around.
##   TAKEOFF   sit for `wait` s, press FLAP, beat for 2.4 s (wings level until up to speed, then pulling gently),
##             then glide.
##   DROP      sit for `wait` s, press CATCH (let go), then glide.
##   GLIDE     hands off: wings level, best glide (into the trunk: the glances and bonks).
##   AI        the AI flies it (AIPilot `ai`, as in the game): sent to land on `goal` (sent again every second it's
##             flying without that target, as a race sends its racers home), or, with no goal, picking its own perches.

enum Kind { APPROACH, TAKEOFF, DROP, GLIDE, AI }

var kind := Kind.APPROACH
var target := Vector3.ZERO
var aim_up := 0.45
var bleed := true
var swoop := -1.0         ## m: coming in more than this above the branch, dive to a gate below it first, then swoop up (< 0: never)
var room := 1.0         ## stretch for the gate distance (faster birds need longer to swoop off their speed)
var wait := 0.6
var clock := 0.0
var _pressed := false
var _stick := Vector2.ZERO
var _closest := INF
var missed := false   ## flew past the perch: going around
var ai: AIPilot = null
var goal: Perch = null
var _resend := 0.0


func sample(bird: Bird, dt: float) -> FlightInput:
	clock += dt
	match kind:
		Kind.TAKEOFF:
			if clock < wait:
				return FlightInput.new()
			var press := not _pressed
			_pressed = true
			# Beat hard with the wings level to build speed off the push, then climb out gently.
			var beating := clock < wait + 2.4
			var pull := 0.2 if clock > wait + 0.8 and bird.model.speed > bird.profile.v_stall * 1.2 else 0.0
			return FlightInput.new(Vector2(0.0, pull if beating else 0.0), press, beating)
		Kind.DROP:
			if clock < wait:
				return FlightInput.new()
			var press := not _pressed
			_pressed = true
			return FlightInput.new(Vector2.ZERO, false, false, press)
		Kind.GLIDE:
			return FlightInput.new()
		Kind.AI:
			if goal != null and bird.state == Bird.State.FLYING and ai.target != goal and clock >= _resend:
				_resend = clock + 1.0
				ai.go_to_perch(bird, goal)
			return ai.sample(bird, dt)
	return _approach(bird, dt)


func _approach(bird: Bird, dt: float) -> FlightInput:
	if bird.state != Bird.State.FLYING:
		return FlightInput.new()
	var p := bird.profile
	var m := bird.model
	var pos := bird.global_position
	var aim := target + Vector3.UP * aim_up
	# Coming in high: a bird can't brake while it's still descending, so it loses the height first -- down
	# to a gate below and short of the branch -- and swoops up to the perch, trading the speed for height.
	var back := Vector3(pos.x - target.x, 0.0, pos.z - target.z)
	var gating := swoop >= 0.0 and pos.y > target.y + swoop and back.length() > 7.5 * room
	if gating:
		aim = target + back.normalized() * 7.0 * room + Vector3.DOWN * 1.5
	var desired := (aim - pos).normalized()
	var fd := m.flight_dir()
	var max_bank := deg_to_rad(p.max_bank_deg)
	var sx := clampf(AIPilot._signed_heading(fd, desired) * 2.2, -max_bank * 0.85, max_bank * 0.85) / max_bank
	var horiz := Vector2(aim.x - pos.x, aim.z - pos.z).length()
	var gamma_cmd := clampf(atan2(aim.y - pos.y, maxf(horiz, 1.0)), deg_to_rad(-35.0), deg_to_rad(25.0))
	var sy := clampf((gamma_cmd - m.path_angle) * 3.0, -0.8, 0.75)
	var want_flap := gamma_cmd > -p.glide_angle + deg_to_rad(1.5) or m.speed < p.v_best * 0.9
	var dist := pos.distance_to(target)
	_closest = minf(_closest, dist)
	if not missed and _closest < 2.0 and dist > _closest + 1.5:
		missed = true
	if missed:   # go around: wings level, beat and climb away
		_stick = _stick.lerp(Vector2(0.0, 0.25 if m.speed > p.v_stall * 1.2 else 0.0), 1.0 - exp(-10.0 * dt))
		return FlightInput.new(_stick, false, m.energy.burst >= 1.0 or pos.y < 3.0)
	if bleed and not gating and dist < maxf(10.0, m.speed * 1.5):
		var catch_v := p.grab_speed_max * 0.8
		if pos.y > target.y:   # above the branch: keep braking (the feet reach well below the flight path)
			sy = maxf(sy, 0.0)
		sy = clampf(sy + (m.speed - catch_v) * 0.12, -0.6, 0.9)
		want_flap = pos.y < target.y - 0.3 and m.speed < catch_v
	elif not bleed:
		want_flap = m.speed < p.v_best * 1.3
	# Too slow short of the perch: stop braking and beat to hold speed (as the AI does), or it stalls and drops.
	if m.speed < p.v_stall * 1.1 and dist > 2.5:
		sy = minf(sy, 0.0)
		want_flap = true
	# Ground guard (as the AI's): low down and away from the perch, climb and beat.
	if pos.y < 1.2 and dist > 3.0:
		want_flap = true
		sy = maxf(sy, 0.3 if m.speed > p.v_stall * 1.2 else 0.0)
		sx = clampf(sx, -0.3, 0.3)
	if m.stalled:
		sy = minf(sy, -0.3)
	_stick = _stick.lerp(Vector2(sx, sy), 1.0 - exp(-10.0 * dt))
	return FlightInput.new(_stick, false, want_flap and m.energy.burst >= 1.0, false, dist < 8.0)
