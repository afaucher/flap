extends TestCase
## Novice flying's landing assist (FlightAssist): approaches a realistic bird misses -- too high, and off the line with
## the perch to its left and to its right -- holding catch with a neutral stick, a novice bird lands on. A branch alone
## in still air, so only the approach decides it:
##   realistic: the bird passes the perch out of its feet's reach (its closest pass measured) and never perches;
##   novice: it perches on that branch;
##   novice with the assist's strength at 0: it misses as the realistic bird does (the knob turns it off);
##   novice without catch held: no assist (the player's stick is passed through untouched, and no landing).

const PERCH_Y := 10.0
var _results := {}


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	var cases := [
		# [label, species, start offset from the seat (x right, y up, z back); it flies a best glide toward -z]
		["too high", "crow", Vector3(0.0, 5.0, 12.0)],
		["perch to the left", "crow", Vector3(2.6, 0.9, 12.0)],
		["perch to the right", "crow", Vector3(-2.6, 0.9, 12.0)],
		["too high, hawk", "hawk", Vector3(0.0, 4.5, 13.0)],
	]
	for c in cases:
		var label: String = c[0]
		var p := BirdProfile.by_id(c[1])
		var real := await _fly(p, c[2], false, 0.75, true)
		check(real.min_d > p.grab_radius, "%s, realistic: passes out of the feet's reach (closest %.2f m)" % [label, real.min_d])
		check(not real.perched, "%s, realistic: misses" % label)
		var nov := await _fly(p, c[2], true, 0.75, true)
		check(nov.perched, "%s, novice: lands on the perch (closest %.2f m, %s)" % [label, nov.min_d, nov.why])
		var off := await _fly(p, c[2], true, 0.0, true)
		check(not off.perched, "%s, novice at strength 0: misses" % label)
	# Without catch held the assist does nothing: the stick out is the stick in, every tick.
	var p := BirdProfile.crow()
	var free := await _fly(p, Vector3(0.0, 3.0, 12.0), true, 0.75, false)
	check(free.untouched, "novice, catch not held: the player's input passes through untouched")
	check(not free.perched, "novice, catch not held: no landing")
	FlightAssist.novice = false
	FlightAssist.strength = 0.75
	finish()


func _fly(p: BirdProfile, off: Vector3, novice: bool, strength: float, hold: bool) -> Dictionary:
	FlightAssist.novice = novice
	FlightAssist.strength = strength
	var layout := ArenaLayout.new()
	var grip := Vector3(0.0, PERCH_Y, 0.0)
	var target := Perch.branch(0, grip + Vector3(-0.6, 0, 0), grip + Vector3(0.6, 0, 0), Vector3.BACK, -1, 0.04)
	layout._add_perch(target)
	var ctl := ScriptedInput.new()
	ctl.catch_hold = hold
	var assist := FlightAssist.new(ctl)
	var b := Bird.new()
	add_child(b)
	b.setup(p, layout, assist)
	b.rig.visible = false
	FlightAssist.fit(b)
	var start := grip + Vector3.UP * Perch.seat_at(Vector3.ZERO, p).y + off
	var dir := Vector3(0.0, -sin(p.glide_angle), -cos(p.glide_angle))
	b.fly_from(start, dir, p.v_best)
	var out := {"perched": false, "min_d": INF, "untouched": true, "why": ""}
	for i in 240:
		await frames(1)
		out.min_d = minf(out.min_d, target.distance_to(b.global_position))
		if b.last_input.stick != ctl.stick or b.last_input.flap_held != ctl.hold:
			out.untouched = false
		if b.state == Bird.State.PERCHED or b.state == Bird.State.LANDING:
			out.perched = b.perch == target
			out.why = "caught at %.2f m/s of %.2f" % [b._land_vel.length(), p.grab_speed_max]
			break
		if b.state == Bird.State.GROUNDED or b.global_position.z < -6.0:
			break
	if not out.perched:
		out.why = "state %d, speed %.2f of %.2f" % [b.state, b.model.speed, p.grab_speed_max]
	b.queue_free()
	await frames(1)
	return out
