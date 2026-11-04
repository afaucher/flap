extends TestCase
## Novice flying's landing assist (FlightAssist): approaches a realistic bird misses -- too high, and off the line with
## the perch to its left and to its right, gliding in or flapping in (flap held: the climb trim carries it up over the
## perch) -- holding catch with a neutral stick, a novice bird lands on. A branch alone
## in still air, so only the approach decides it:
##   realistic: the bird passes the perch out of its feet's reach (its closest pass measured) and never perches;
##   novice: it perches on that branch;
##   novice with the assist's strength at 0: it misses as the realistic bird does (the knob turns it off);
##   novice without catch held: no assist (the player's stick is passed through untouched, and no landing).
## And it stays on the player's line (left and right): a perch on the next tree over, 55 deg off, doesn't swing the
## bird round (its heading over 1.5 s); toward one 22 deg off the assist adds at most MAX_BANK_ADD of bank to the
## player's; it holds the perch it engaged on (Bird.candidate_lock) and lets go on release; and when the player turns
## away so the perch falls out of the held perch's cone (Bird.LOCK_CONE_DEG), it lets go and hands the stick back.

const PERCH_Y := 10.0
var _results := {}


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	var cases := [
		# [label, species, start offset from the seat (x right, y up, z back), flap held all the way in]; it starts on a
		# best glide toward -z
		["too high", "crow", Vector3(0.0, 5.0, 12.0), false],
		["perch to the left", "crow", Vector3(2.6, 0.9, 12.0), false],
		["perch to the right", "crow", Vector3(-2.6, 0.9, 12.0), false],
		["too high, hawk", "hawk", Vector3(0.0, 4.5, 13.0), false],
		["flapping in, perch to the left", "crow", Vector3(2.6, 0.9, 12.0), true],
		["flapping in, perch to the right", "crow", Vector3(-2.6, 0.9, 12.0), true],
		["flapping in, too high", "crow", Vector3(0.0, 3.0, 12.0), true],
		["flapping in, too high, hawk", "hawk", Vector3(0.0, 3.0, 13.0), true],
	]
	for c in cases:
		var label: String = c[0]
		var p := BirdProfile.by_id(c[1])
		var real := await _fly(p, c[2], false, 0.75, true, c[3])
		check(real.min_d > p.grab_radius, "%s, realistic: passes out of the feet's reach (closest %.2f m)" % [label, real.min_d])
		check(not real.perched, "%s, realistic: misses" % label)
		var nov := await _fly(p, c[2], true, 0.75, true, c[3])
		check(nov.perched, "%s, novice: lands on the perch (closest %.2f m, %s)" % [label, nov.min_d, nov.why])
		var off := await _fly(p, c[2], true, 0.0, true, c[3])
		check(not off.perched, "%s, novice at strength 0: misses" % label)
	# Without catch held the assist does nothing: the stick out is the stick in, every tick.
	var p := BirdProfile.crow()
	var free := await _fly(p, Vector3(0.0, 3.0, 12.0), true, 0.75, false)
	check(free.untouched, "novice, catch not held: the player's input passes through untouched")
	check(not free.perched, "novice, catch not held: no landing")
	for side in [-1.0, 1.0]:
		await _stays_on_line(p, side)
	FlightAssist.novice = false
	FlightAssist.strength = 0.75
	finish()


## A novice crow gliding, catch held, with one branch `deg` off its way (+: left), `dist` m out at its path's height;
## `turn`, the player's stick x (0: neutral). Flown 1.5 s: {yaw: deg its heading turned, bank_add: the most stick x the
## assist added, lock: the held perch while engaged, released: the lock once catch is let go, back: the input equals the
## player's at the end, target}.
func _off_line(deg: float, dist: float, turn: float) -> Dictionary:
	FlightAssist.novice = true
	FlightAssist.strength = 0.75
	var p := BirdProfile.crow()
	var layout := ArenaLayout.new()
	var ctl := ScriptedInput.new()
	ctl.catch_hold = true
	var assist := FlightAssist.new(ctl)
	var b := Bird.new()
	add_child(b)
	b.setup(p, layout, assist)
	b.rig.visible = false
	FlightAssist.fit(b)
	var start := Vector3(0.0, 30.0, 0.0)
	var dir := Vector3(0.0, -sin(p.glide_angle), -cos(p.glide_angle))
	b.fly_from(start, dir, p.v_best)
	var way := Vector3(dir.x, 0.0, dir.z).normalized()
	var to := way.rotated(Vector3.UP, deg_to_rad(deg)) * dist + Vector3.DOWN * dist * tan(p.glide_angle)
	var seat_h := Perch.seat_at(Vector3.ZERO, p).y
	var mid := start + to - Vector3.UP * seat_h
	var half := Vector3.UP.cross(Vector3(to.x, 0.0, to.z)).normalized() * 0.5
	var target := Perch.branch(0, mid - half, mid + half, Vector3.FORWARD, -1, 0.04)
	layout._add_perch(target)
	var out := {"yaw": 0.0, "bank_add": 0.0, "lock": null, "released": null, "back": false, "target": target}
	for i in 90:
		if i == 10:
			ctl.stick = Vector2(turn, 0.0)
		await frames(1)
		var h := b.model.flight_dir()
		out.yaw = maxf(out.yaw, rad_to_deg(absf(Vector2(h.x, h.z).angle_to(Vector2(way.x, way.z)))))
		out.bank_add = maxf(out.bank_add, absf(b.last_input.stick.x - ctl.stick.x))
		if assist.engage >= 1.0 and out.lock == null:
			out.lock = b.candidate_lock
		if b.state != Bird.State.FLYING:
			break
	out.back = b.last_input.stick == ctl.stick
	ctl.catch_hold = false
	await frames(2)
	out.released = b.candidate_lock
	b.queue_free()
	await frames(1)
	return out


func _stays_on_line(p: BirdProfile, side: float) -> void:
	var what := "left" if side > 0.0 else "right"
	var far := await _off_line(55.0 * side, 7.0, 0.0)
	check(far.yaw < 8.0, "the next tree over, 55 deg to the %s: the bird isn't swung round (turned %.1f deg)" % [what, far.yaw])
	var near := await _off_line(22.0 * side, 9.0, 0.0)
	check(near.bank_add > 0.1 and near.bank_add <= FlightAssist.MAX_BANK_ADD + 1e-3, "a perch 22 deg to the %s: the assist turns for it, adding at most %.2f of bank (%.2f)" % [what, FlightAssist.MAX_BANK_ADD, near.bank_add])
	check(near.lock == near.target and near.released == null, "it holds the perch it engaged on (%s), and lets go on release" % ("it" if near.lock == near.target else "another"))
	var away := await _off_line(15.0 * side, 10.0, -0.9 * side)
	check(away.yaw > Bird.LOCK_CONE_DEG and away.back, "the player turning away from it (%.0f deg round): the assist lets go, the stick the player's" % away.yaw)


func _fly(p: BirdProfile, off: Vector3, novice: bool, strength: float, hold: bool, flapping := false) -> Dictionary:
	FlightAssist.novice = novice
	FlightAssist.strength = strength
	var layout := ArenaLayout.new()
	var grip := Vector3(0.0, PERCH_Y, 0.0)
	var target := Perch.branch(0, grip + Vector3(-0.6, 0, 0), grip + Vector3(0.6, 0, 0), Vector3.BACK, -1, 0.04)
	layout._add_perch(target)
	var ctl := ScriptedInput.new()
	ctl.catch_hold = hold
	ctl.hold = flapping   # (a held wingbeat trims the bird into a climb: FlightModel.trim_alpha)
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
