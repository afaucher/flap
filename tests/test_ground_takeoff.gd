extends TestCase
## Getting off the ground: every species standing on open ground climbs out with FLAP held; a bird
## skimming the ground below stall speed can flap its way up and away; ground effect is there near the
## ground and gone above it; the stick turns a grounded bird.

var layout: ArenaLayout


func setup() -> void:
	layout = ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	for p in BirdProfile.all():
		# Standing in the clearing, facing out along an avenue.
		var ctl := ScriptedInput.new()
		var b := Bird.new()
		add_child(b)
		b.setup(p, layout, ctl)
		b.arena = arena
		b.fly_from(Vector3(0, 0.3, 0), Vector3(1, -1, 0).normalized(), 1.0)
		for i in 30:
			await frames(1)
			if b.state == Bird.State.GROUNDED:
				break
		eq(b.state, Bird.State.GROUNDED, p.id + " stands on the ground")
		var f0 := b.facing
		ctl.stick = Vector2(-1.0, 0.0)
		await frames(20)
		ctl.stick = Vector2.ZERO
		check(AIPilot._signed_heading(f0, b.facing) < -0.3, p.id + " stick turns a grounded bird")
		ctl.flap = true
		ctl.hold = true
		var top := 0.0
		var landed_again := false
		for i in 60 * 4:
			await frames(1)
			top = maxf(top, b.global_position.y)
			landed_again = landed_again or b.state == Bird.State.GROUNDED
		print("%s: ground takeoff reaches %.1f m in 4 s, stamina %.2f" % [p.id, top, b.model.energy.stamina])
		check(not landed_again, p.id + " doesn't fall back to the ground")
		check(top > 4.0, "%s climbs out from the ground (%.1f m)" % [p.id, top])
		b.queue_free()

		# Skimming the ground slow, flapping and easing back: climbs away.
		var ctl2 := ScriptedInput.new()
		var s := Bird.new()
		add_child(s)
		s.setup(p, layout, ctl2)
		s.fly_from(Vector3(0, 0.6, 0), Vector3(1, 0, 0), p.v_stall * 0.8)
		check(s.model.ground_effect == 0.0, "launch resets ground effect")
		ctl2.hold = true
		ctl2.stick = Vector2(0.0, 0.2)
		var saw_effect := false
		var high := 0.0
		for i in 60 * 5:
			await frames(1)
			saw_effect = saw_effect or s.model.ground_effect > 0.5
			high = maxf(high, s.global_position.y)
		check(saw_effect, p.id + " feels ground effect skimming the ground")
		check(high > 4.0, "%s flaps up out of a slow skim (%.1f m)" % [p.id, high])
		check(s.global_position.y > p.ground_effect_height and s.model.ground_effect == 0.0, p.id + " no ground effect up high")
		s.queue_free()
		await frames(1)
	finish()
