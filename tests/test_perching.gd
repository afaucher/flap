extends TestCase
## The catch and release: SPACE catches a perch only within the catch sphere and under the catch speed;
## a press a touch early still counts (buffer); too fast never catches; the landing blend ends seated and
## still; release drops off along the facing with a free wingbeat and can't instantly re-catch; perching
## rests the bird.

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

	# 1. Slow approach straight at the perch, press inside the catch sphere -> caught.
	var ctl := ScriptedInput.new()
	var b := _bird(p, ctl)
	var from := target.position + target.facing * 4.0 + Vector3.UP * 0.3
	b.fly_from(from, (target.position - from).normalized(), p.grab_speed_max * 0.8)
	b.perch_assist = 0.0
	var caught := false
	for i in 120:
		await frames(1)
		if b.candidate == target and b.candidate_status == Perch.Catch.OK and not caught:
			ctl.press = true
			caught = true
		if b.state == Bird.State.PERCHED:
			break
	eq(b.state, Bird.State.PERCHED, "slow approach + SPACE catches")
	check(b.global_position.distance_to(target.seat(p)) < 0.01, "seated on the perch")
	near(b.model.velocity.length(), 0.0, 1e-4, "at rest")

	# 2. Release: drops off along the facing, a free wingbeat, can't re-catch at once.
	var stamina_before: float = b.model.energy.stamina
	var burst_before: float = b.model.energy.burst
	ctl.press = true
	await frames(1)
	eq(b.state, Bird.State.FLYING, "SPACE releases")
	check(b.model.flight_dir().dot(target.facing) > 0.7, "drops off along the facing")
	check(b.model.flap_count >= 1, "release starts a wingbeat")
	check(b.model.energy.burst >= burst_before - 0.01, "the push-off wingbeat is free")
	ctl.press = true
	await frames(1)
	check(b.state == Bird.State.FLYING, "can't re-catch the perch just left")
	b.queue_free()

	# 3. Too fast: in the sphere, pressing, never catches; the HUD says TOO_FAST.
	var ctl2 := ScriptedInput.new()
	var fast := _bird(p, ctl2)
	fast.perch_assist = 0.0
	var from2 := target.position + target.facing * 5.0
	fast.fly_from(from2, (target.position - from2).normalized(), p.grab_speed_max * 1.6)
	var saw_too_fast := false
	for i in 40:
		ctl2.press = true
		await frames(1)
		saw_too_fast = saw_too_fast or fast.candidate_status == Perch.Catch.TOO_FAST
		check(fast.state != Bird.State.LANDING and fast.state != Bird.State.PERCHED, "too fast never catches")
	check(saw_too_fast, "too fast is reported")
	fast.queue_free()

	# 4. Buffered press: SPACE a few ticks before entering the sphere still catches.
	var ctl3 := ScriptedInput.new()
	var early := _bird(p, ctl3)
	early.perch_assist = 0.0
	var spd := p.grab_speed_max * 0.7
	var from3 := target.position + target.facing * (p.grab_radius + spd * 0.08) + Vector3.UP * 0.2
	early.fly_from(from3, (target.position - from3).normalized(), spd)
	await frames(1)
	eq(early.candidate, target, "the perch ahead is the candidate")
	ctl3.press = true    # ~4 ticks early: OUT_OF_RANGE now
	var early_caught := false
	for i in 30:
		await frames(1)
		if early.state == Bird.State.LANDING or early.state == Bird.State.PERCHED:
			early_caught = true
			break
	check(early_caught, "a press just before reach still catches")
	early.queue_free()

	# 5. Assist: a fast approach with the assist on is flared down to a catchable speed.
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

	# 6. Rest: perched birds recover stamina far faster than flying ones.
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
	return b
