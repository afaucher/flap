extends TestCase
## Catch and release with the split controls: holding CATCH catches the moment a perch is in reach and
## slow enough; a quick tap a touch early still counts (buffer); too fast never catches; the landing blend
## ends seated and still; FLAP takes off with a free wingbeat, CATCH just lets go; the stick turns a perched
## bird and it leaves the way it faces, through its own branch; perching rests the bird.

var arena: ArenaBuilder
var layout: ArenaLayout


func setup() -> void:
	layout = ArenaLayout.generate(7)
	arena = ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var p := BirdProfile.crow()
	var target: Perch = layout.start_perch()

	# 1. Hold catch from far out on a slow approach: caught on entering reach.
	var ctl := ScriptedInput.new()
	var b := _bird(p, ctl)
	b.perch_assist = 0.0
	var from := target.position + target.facing * 5.0 + Vector3.UP * 0.3
	b.fly_from(from, (target.position - from).normalized(), p.grab_speed_max * 0.8)
	ctl.catch_hold = true
	var caught_at := INF
	for i in 120:
		await frames(1)
		if b.state == Bird.State.LANDING and caught_at == INF:
			caught_at = target.distance_to(b._land_from)
		if b.state == Bird.State.PERCHED:
			break
	eq(b.state, Bird.State.PERCHED, "holding catch catches")
	check(caught_at <= p.grab_radius + 0.01 and caught_at > p.grab_radius - 0.5, "caught on entering reach (%.2f m)" % caught_at)
	check(b.global_position.distance_to(Perch.seat_at(b.perch_grip, p)) < 0.01, "seated on its grip point")
	check(target.distance_to(b.perch_grip) < 1e-4, "the grip point is on the perch")
	near(b.model.velocity.length(), 0.0, 1e-4, "at rest")
	# Still holding catch on the perch: it stays.
	await frames(10)
	eq(b.state, Bird.State.PERCHED, "holding catch through the landing doesn't let go")

	# 2. Look around: the stick turns the bird; it takes off (FLAP) the way it faces, with a free wingbeat.
	ctl.catch_hold = false
	var f0 := b.facing
	ctl.stick = Vector2(1.0, 0.0)
	await frames(30)
	ctl.stick = Vector2.ZERO
	var turned := AIPilot._signed_heading(f0, b.facing)
	near(rad_to_deg(turned), Bird.TURN_RATE * 0.5, 4.0, "stick right turns the bird right")
	var burst_before: float = b.model.energy.burst
	var flaps_before: int = b.model.flap_count
	ctl.flap = true
	await frames(1)
	eq(b.state, Bird.State.FLYING, "FLAP takes off")
	check(b.model.flight_dir().dot(b.facing) > 0.9, "leaves the way it faced")
	eq(b.model.flap_count, flaps_before + 1, "take-off starts a wingbeat")
	check(b.model.energy.burst >= burst_before - 0.01, "the push-off wingbeat is free")
	ctl.catch = true
	await frames(1)
	check(b.state == Bird.State.FLYING, "can't re-catch the perch just left")
	b.queue_free()

	# 3. CATCH on a perch lets go: drops off without a wingbeat.
	var ctl6 := ScriptedInput.new()
	var dropper := _bird(p, ctl6)
	dropper.perch_at(target)
	await frames(2)
	ctl6.catch = true
	await frames(1)
	eq(dropper.state, Bird.State.FLYING, "CATCH lets go")
	eq(dropper.model.flap_count, 0, "letting go doesn't flap")
	dropper.queue_free()

	# 4. Too fast: holding catch through the reach never catches; reported as TOO_FAST.
	var ctl2 := ScriptedInput.new()
	var fast := _bird(p, ctl2)
	fast.perch_assist = 0.0
	var from2 := target.position + target.facing * 5.0
	fast.fly_from(from2, (target.position - from2).normalized(), p.grab_speed_max * 1.6)
	ctl2.catch_hold = true
	var saw_too_fast := false
	for i in 40:
		await frames(1)
		saw_too_fast = saw_too_fast or fast.candidate_status == Perch.Catch.TOO_FAST
		check(fast.state != Bird.State.LANDING and fast.state != Bird.State.PERCHED, "too fast never catches")
	check(saw_too_fast, "too fast is reported")
	fast.queue_free()

	# 5. A quick tap just before reach still catches (buffer).
	var ctl3 := ScriptedInput.new()
	var early := _bird(p, ctl3)
	early.perch_assist = 0.0
	var spd := p.grab_speed_max * 0.7
	var from3 := target.position + target.facing * (p.grab_radius + spd * 0.08) + Vector3.UP * 0.2
	early.fly_from(from3, (target.position - from3).normalized(), spd)
	await frames(1)
	ctl3.catch = true    # ~4 ticks early, released at once
	var early_caught := false
	for i in 30:
		await frames(1)
		if early.state == Bird.State.LANDING or early.state == Bird.State.PERCHED:
			early_caught = true
			break
	check(early_caught, "a tap just before reach still catches")
	early.queue_free()

	# 6. Assist: a fast approach with the assist on is flared down to a catchable speed.
	var ctl4 := ScriptedInput.new()
	var assisted := _bird(p, ctl4)
	assisted.perch_assist = 1.0
	var from4 := target.position + target.facing * 7.0 + Vector3.UP * 0.2
	assisted.fly_from(from4, (target.position - from4).normalized(), p.grab_speed_max * 1.25)
	var assisted_ok := false
	for i in 90:
		await frames(1)
		if assisted.candidate_status == Perch.Catch.OK:
			assisted_ok = true
			break
	check(assisted_ok, "the flare assist bleeds a fast approach down to a catch")
	assisted.queue_free()

	# 7. Facing along the branch (over it) and leaving: passes through its own tree, no bonk, no standing on it.
	var bp: Perch = null
	var br: ArenaLayout.BranchData = null
	for t in layout.trees:
		for candidate_branch in t.branches:
			if candidate_branch.root.y > 4.0:
				br = candidate_branch
				bp = layout.perches[candidate_branch.perch_id]
				break
		if bp != null:
			break
	var ctl7 := ScriptedInput.new()
	var along := _bird(p, ctl7)
	along.perch_at(bp)
	var out: Vector3 = br.tip - br.root
	along.facing = Vector3(out.x, 0.0, out.z).normalized()
	await frames(1)
	ctl7.catch = true   # let go: drop straight down over the branch
	for i in 30:
		await frames(1)
	eq(along.bonks, 0, "no bonk leaving along the branch")
	eq(along.state, Bird.State.FLYING, "fell clear of its own branch")
	check(along.global_position.y < bp.position.y - 0.3, "below the branch")
	along.queue_free()

	# 8. Rest: perched birds recover stamina.
	var ctl5 := ScriptedInput.new()
	var tired := _bird(p, ctl5)
	tired.perch_at(target)
	tired.model.energy.stamina = 0.1
	await frames(120)
	check(tired.model.energy.stamina > 0.2, "two seconds perched restores stamina (%.2f)" % tired.model.energy.stamina)
	finish()


func _bird(p: BirdProfile, ctl: Object) -> Bird:
	var b := Bird.new()
	add_child(b)
	b.setup(p, layout, ctl)
	b.arena = arena
	return b
