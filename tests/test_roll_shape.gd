extends TestCase
## A bird rolls by making its wings differ (BirdRig._roll_shape; docs/research/turning_kinematics.md): rolling, the
## outer wing (the one rising) twisted up and the inner down, the inner flexed, shorter; flapping, the outer beating
## wider early in the downstroke; the tail twisted against the roll (rolling in, more level than the body; rolling out,
## overbanked) and, held, a little toward level; the head counter-rolled toward level; in a held turn the wings alike
## again. Each bird flies the moves through its own flight model -- level, roll right, the turn held, roll out, roll
## left -- and the drawn feathers are measured against the research's numbers at the roll rate it flew: each wing's
## incidence (the secondaries' chord against the body) against the twist strip theory says rolls the wing at that rate
## (section 9.1, drawn ROLL_READ times), the inner wing's reach (its farthest primary tip from the body's midline)
## against the peregrine's cut (section 9.2), the tail's roll (its outer feathers' tips), the head's roll from level.
## Both ways round; switched off (BirdRig.roll_shape) the wings are drawn alike and the tail as before.

const SHARDS := 5
const TWIST_K := 0.29     ## deg per (deg/s x m / (m/s)): each wing's twist to roll it (section 9.1) [E]
const READ := 1.5         ## drawn this many times the real twist [G]
const SPAN_CUT := 0.14    ## the inner wing's reach cut at the full roll rate and 0.7 of CL max (the peregrine) [S]
const OUT := 0.7          ## rolling back toward level, the shape this much of the roll in's [E]
const HELD_TOL_DEG := 0.5
const HELD_TOL_REACH := 0.005


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	var birds := BirdProfile.all()
	for k in birds.size():
		if in_shard(k):
			await _fly(birds[k])
	finish()


## [time, stick x], and the moments measured, from the start; T is the bird's roll from level to its full bank.
static func moves_for(p: BirdProfile) -> Dictionary:
	var T := p.max_bank_deg / p.roll_rate_deg
	var a := 0.5
	var b := a + T + 0.7
	var c := b + T + 0.5
	return {
		"moves": [[0.0, 0.0], [a, 1.0], [b, 0.0], [c, -1.0]],
		"at": {"level": 0.45, "right": a + 0.6 * T, "held": b - 0.05, "out": b + 0.6 * T, "left": c + 0.6 * T},
		"end": c + T + 0.3,
	}


func _fly(p: BirdProfile) -> void:
	var runs := []   # what was measured, the roll shape on, then off
	for on in [true, false]:
		BirdRig.roll_shape = on
		var input := ScriptedInput.new()
		var b := Bird.new()
		add_child(b)
		b.setup(p, ArenaLayout.lab(), input)
		b.fly_from(Vector3(-40, 60, 0), Vector3.RIGHT, p.v_best)
		var sc := moves_for(p)
		var t0 := b._sim_t
		var got := {}
		var mi := 0
		var last_bank := b.model.bank
		var dt := 1.0 / Engine.physics_ticks_per_second
		while b._sim_t - t0 < float(sc.end):
			var t := b._sim_t - t0
			while mi < sc.moves.size() and t >= float(sc.moves[mi][0]):
				input.stick = Vector2(float(sc.moves[mi][1]), 0.0)
				mi += 1
			for key in sc.at:
				if not got.has(key) and t >= float(sc.at[key]):
					got[key] = _measure(b)
					got[key]["rate"] = rad_to_deg(b.model.bank - last_bank) / dt
			last_bank = b.model.bank
			await get_tree().physics_frame
		runs.append(got)
		var id := p.id + (" (roll shape off)" if not on else "")
		for key in got:
			var m: Dictionary = got[key]
			print("  %-26s %-6s bank %+5.1f rate %+5.0f deg/s  incidence L %+5.1f R %+5.1f deg  reach L %.3f R %.3f m  tail %+5.1f deg  head %+5.1f deg" % [
				id, key, m.bank, m.rate, m.inc[0], m.inc[1], m.reach[0], m.reach[1], m.tail, m.head])
		if on:
			_check_on(p, got)
		else:
			for key in got:
				var m: Dictionary = got[key]
				check(absf(m.inc[0] - m.inc[1]) < 1e-3 and absf(m.reach[0] - m.reach[1]) < 1e-5, "%s %s: switched off, the wings are drawn alike (incidence %.3f / %.3f deg, reach %.4f / %.4f m)" % [
					id, key, m.inc[0], m.inc[1], m.reach[0], m.reach[1]])
			var h: Dictionary = got["held"]
			check(h.tail < -0.15 * h.bank, "%s: switched off, the tail twists with the bank, as before (%.1f deg at bank %.0f)" % [id, h.tail, h.bank])
			# The same flight both ways (the roll's shape is drawn only): where nothing is rolling the wings are the same.
			for key in ["level", "held"]:
				var a: Dictionary = runs[0][key]
				check(absf(a.inc[0] - m_inc(got, key)) < 0.3 and absf(a.reach[0] - float(got[key].reach[0])) < 0.002, "%s %s: not rolling, the wings are drawn the same on and off (incidence %.2f / %.2f deg)" % [
					p.id, key, a.inc[0], m_inc(got, key)])
		b.queue_free()
		await get_tree().physics_frame
	BirdRig.roll_shape = true
	await _flapping(p)


static func m_inc(got: Dictionary, key: String) -> float:
	return float(got[key].inc[0])


func _check_on(p: BirdProfile, got: Dictionary) -> void:
	# Rolling right the left wing is the outer one; rolling left (and rolling out of the right turn), the right.
	for key in ["right", "out", "left"]:
		var m: Dictionary = got[key]
		var outer := 0 if key == "right" else 1
		var inner := 1 - outer
		var gentle := OUT if key == "out" else 1.0
		var want := minf(TWIST_K * absf(float(m.rate)) * p.span / maxf(float(m.speed), p.v_stall) * READ * gentle, 15.0)
		var drawn: float = 0.5 * (m.inc[outer] - m.inc[inner])
		check(drawn > 0.65 * want and drawn < 1.35 * want, "%s rolling %s at %.0f deg/s: each wing twisted %.1f deg (outer %.1f, inner %.1f), as strip theory needs to roll it (%.1f deg)" % [
			p.id, key, absf(float(m.rate)), drawn, m.inc[outer], m.inc[inner], want])
		var cut_want := SPAN_CUT * (0.3 + clampf(float(m.cl) / p.cl_max, 0.0, 1.0)) * minf(absf(float(m.rate)) / p.roll_rate_deg, 1.5) * gentle
		var cut: float = 1.0 - m.reach[inner] / m.reach[outer]
		check(cut > 0.6 * cut_want and cut < 1.5 * cut_want and cut > 0.04, "%s rolling %s: the inner wing flexed, its reach %.0f%% short of the outer's (the peregrine's cut at this rate and lift: %.0f%%)" % [
			p.id, key, 100.0 * cut, 100.0 * cut_want])
	for key in ["level", "held"]:
		var m: Dictionary = got[key]
		check(absf(m.inc[0] - m.inc[1]) < HELD_TOL_DEG and absf(m.reach[0] - m.reach[1]) < HELD_TOL_REACH * m.reach[0], "%s %s: the wings alike (incidence %.2f / %.2f deg, reach %.3f / %.3f m)" % [
			p.id, key, m.inc[0], m.inc[1], m.reach[0], m.reach[1]])
	# The tail (+ its right side up against the body): rolling in, twisted against the roll -- more level than the body;
	# rolling out, overbanked past where the held turn has it; held, a little toward level.
	var r: Dictionary = got["right"]
	var l: Dictionary = got["left"]
	var h: Dictionary = got["held"]
	var o: Dictionary = got["out"]
	check(r.tail > 6.0 and l.tail < -6.0, "%s: rolling in, the tail twisted against the roll (rolling right %+.1f deg, left %+.1f; at least 6)" % [p.id, r.tail, l.tail])
	check(h.tail > 0.0 and h.tail < 0.2 * h.bank, "%s: the turn held, the tail a little toward level (%+.1f deg at bank %.0f)" % [p.id, h.tail, h.bank])
	check(o.tail < h.tail - 5.0, "%s: rolling out, the tail overbanked (%+.1f deg, held %+.1f)" % [p.id, o.tail, h.tail])
	# The head nearly level, to the neck's reach (60 deg from the body's; the pigeon's gain 0.91).
	var allow := maxf(absf(float(h.bank)) - 60.0, 0.1 * absf(float(h.bank))) + 3.0
	check(absf(float(h.head)) < allow, "%s: the turn held at %.0f deg, the head %.1f deg from level (at most %.1f)" % [p.id, h.bank, h.head, allow])


## Flapping while rolling, the outer wing beats wider and further forward in the first half of the downstroke and
## nearly alike on the upstroke -- measured on the drawn humerus and forearm (shoulder to wrist), rolling one way then
## the other.
func _flapping(p: BirdProfile) -> void:
	var input := ScriptedInput.new()
	var b := Bird.new()
	add_child(b)
	b.setup(p, ArenaLayout.lab(), input)
	b.fly_from(Vector3(-40, 60, 0), Vector3.RIGHT, p.v_best)
	input.hold = true
	input.flap = true
	await get_tree().physics_frame
	input.flap = false
	await frames(20)
	var early := 0
	var early_wrong := 0
	var wide := 0.0
	var up_most := 0.0
	var up_n := 0
	var t0 := b._sim_t
	var dir := 1.0
	while b._sim_t - t0 < 3.0:
		# (back and forth across level, so the bird is always rolling)
		if absf(b.model.bank) > deg_to_rad(p.max_bank_deg) * 0.6 and signf(b.model.bank) == dir:
			dir = -dir
		input.stick = Vector2(dir, 0.0)
		await get_tree().physics_frame
		var r := b.rig
		if absf(r.roll_cmd) < 0.6 or r._beat < 0.99:
			continue
		var outer := 0 if r.roll_cmd > 0.0 else 1
		var d := _elevation(b, outer) - _elevation(b, 1 - outer)
		var ph := r.roll_phase
		if ph > 0.03 and ph < 0.18:   # (early downstroke: the wing above its middle, the outer higher)
			wide = maxf(wide, d)
			if d > 0.5:
				early += 1
			else:
				early_wrong += 1
		elif ph > 0.6 and ph < 0.88:
			up_most = maxf(up_most, absf(d))
			up_n += 1
	check(early >= 2 and early_wrong == 0, "%s flapping while rolling: early in the downstroke the outer wing beats wider than the inner (%d moments, %d not; up to %.1f deg)" % [p.id, early, early_wrong, wide])
	check(up_n >= 2 and up_most < 0.5 * wide, "%s flapping while rolling: on the upstroke the wings nearly alike (%d moments, at most %.2f deg apart -- the twist alone tilts the arm --, under half the downstroke's %.1f)" % [p.id, up_n, up_most, wide])
	b.queue_free()
	await get_tree().physics_frame


## The drawn arm's elevation above the body's level, shoulder to wrist (deg, + up), side i.
static func _elevation(b: Bird, i: int) -> float:
	var j: Array = b.rig.wing_joints[i]
	var v: Vector3 = (j[2] as Vector3) - (j[0] as Vector3)
	return rad_to_deg(atan2(v.y, absf(v.x)))


## Each wing as drawn (rig space): its incidence (the secondaries' chord: + leading edge up), its reach (the farthest
## primary tip from the body's midline); the tail's roll against the body (its two outer feathers' tips, + right side
## up); the head's roll from level (world); and the flight's bank, speed and CL.
static func _measure(b: Bird) -> Dictionary:
	var r := b.rig
	var inc := [0.0, 0.0]
	var n := [0, 0]
	var reach := [0.0, 0.0]
	var tail := []
	for k in r.feather_xforms.size():
		var xf: Transform3D = r.feather_xforms[k]
		var kind: int = r.feather_kinds[k]
		if kind == 6:
			tail.append(xf.origin + xf.basis.z)
			continue
		var side := 0 if kind >= 100 else 1
		var kk := kind % 100
		var tip := xf.origin + xf.basis.z
		if kk == WingShape.Kind.PRIMARY:
			reach[side] = maxf(reach[side], absf(tip.x))
		elif kk == WingShape.Kind.SECONDARY:
			var d := xf.basis.z.normalized()
			inc[side] += rad_to_deg(asin(clampf(-d.y, -1.0, 1.0)))
			n[side] += 1
	for i in 2:
		inc[i] /= maxf(float(n[i]), 1.0)
	tail.sort_custom(func(a: Vector3, c: Vector3) -> bool: return a.x < c.x)
	var tl: Vector3 = tail[0]
	var tr: Vector3 = tail[-1]
	# The head's roll from level: its up against the world's up, both across its line of sight.
	var hb := (r.global_basis * r.head_basis).orthonormalized()
	var f := -hb.z
	var wu := (Vector3.UP - f * f.dot(Vector3.UP)).normalized()
	var hu := (hb.y - f * f.dot(hb.y)).normalized()
	var head := rad_to_deg(wu.signed_angle_to(hu, f))
	return {"inc": inc, "reach": reach, "tail": rad_to_deg(atan2(tr.y - tl.y, tr.x - tl.x)), "head": head,
		"bank": rad_to_deg(b.model.bank), "speed": b.model.speed, "cl": b.model.cl}
