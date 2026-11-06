extends TestCase
## Target practice's balloons in the CombatWorld, hit by real rounds: a bullet through one holes it in and out and flies
## on, one over it leaves it whole; a rocket at one bursts on it (surface "balloon") and sets it alight, one passing
## wide doesn't; when one's down -- alight, or holed until it settles -- the shooter is credited (stats.balloons,
## balloon_downed); and a downed one is winched up fresh (respawn_after) and rises back up its cable.


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	var layout := ArenaLayout.new()
	var world := CombatWorld.new()
	world.layout = layout
	add_child(world)
	var me := Bird.new()
	add_child(me)
	me.setup(BirdProfile.crow(), layout, ScriptedInput.new())
	me.rig.visible = false
	me.fly_from(Vector3(0, 40, -60), Vector3.FORWARD, 10.0)
	world.player = world.add_bird(me, null)
	var downed := []
	world.balloon_downed.connect(func(b, by): downed.append([b, by]))
	var bursts := []
	world.burst.connect(func(at, why, kind, surface): bursts.append([at, why, kind, surface]))
	var a := _balloon(world, Vector3(0, 0, 0), 0)
	var b := _balloon(world, Vector3(12, 0, 0), 1)
	var c := _balloon(world, Vector3(-12, 0, 0), 2)
	await _ticks(90)
	# A bullet through A's flank holes it, in and out, and flies on; one over B leaves it whole.
	var side := a.body.global_basis.x
	var p := Projectile.launch(Projectile.Kind.GUN, a.centre() - side * 6.0, Vector3.ZERO, side, me)
	world.spawn(p)
	var miss := Projectile.launch(Projectile.Kind.GUN, b.centre() - side * 6.0 + Vector3.UP * 1.2, Vector3.ZERO, side, me)
	world.spawn(miss)
	await _ticks(8)
	check(a.holes.size() == 2 and a.stage() == TargetBalloon.Stage.HOLED, "a bullet through its flank holes it in and out (%d holes)" % a.holes.size())
	check(p.alive and p.pos.distance_to(a.centre()) > 1.0 and side.dot(p.pos - a.centre()) > 0.0, "and flies on through it")
	check(b.holes.is_empty(), "a bullet 1.2 m over it leaves it whole")
	check(int(world.stats.hits) == 1, "your hit counts (%d)" % int(world.stats.hits))
	# A rocket at A bursts on it and sets it alight; one passing 3 m wide of B doesn't touch it.
	bursts.clear()
	world.spawn(Projectile.launch(Projectile.Kind.ROCKET, a.centre() - side * 9.0, Vector3.ZERO, side, me))
	world.spawn(Projectile.launch(Projectile.Kind.ROCKET, b.centre() - side * 9.0 + b.body.global_basis.z * 3.0, Vector3.ZERO, side, me))
	await _ticks(40)
	var on_balloon := bursts.filter(func(e): return e[3] == "balloon")
	check(on_balloon.size() == 1 and (on_balloon[0][0] as Vector3).distance_to(a.centre()) < 1.0, "a rocket at it bursts on it (%d bursts on a balloon)" % on_balloon.size())
	check(a.burn_r >= 0.0 and a.is_down(), "and sets it alight (%s)" % TargetBalloon.Stage.keys()[a.stage()])
	check(b.burn_r < 0.0 and not b.is_down(), "a rocket 3 m wide passes it by (%s)" % TargetBalloon.Stage.keys()[b.stage()])
	check(downed.size() == 1 and downed[0][0] == a and downed[0][1] == me and int(world.stats.balloons) == 1, "alight, it's down, and yours (%d downed, %d to you)" % [downed.size(), int(world.stats.balloons)])
	# Holed enough, C sinks and settles: that's down too, and yours.
	var cs := c.body.global_basis.x
	for i in 12:
		var u := 0.2 + 0.5 * i / 11.0
		var at := c.body.global_transform * Vector3(0.0, 0.0, (u - 0.5) * TargetBalloon.LENGTH)
		world.spawn(Projectile.launch(Projectile.Kind.GUN, at - cs * 6.0, Vector3.ZERO, cs, me))
	var t := 0
	while not c.is_down() and t < 1200:
		await _ticks(10)
		t += 10
	check(c.stage() == TargetBalloon.Stage.DOWN and c.burn_r < 0.0, "holed by a dozen bullets, it sinks down (%s after %.1f s)" % [TargetBalloon.Stage.keys()[c.stage()], t / 60.0])
	await _ticks(2)
	check(int(world.stats.balloons) == 2 and downed.size() == 2 and downed[1][0] == c, "and that's down and yours too (%d)" % int(world.stats.balloons))
	# A, burnt out on the ground, is winched up fresh and rises back up its cable.
	t = 0
	while a.stage() != TargetBalloon.Stage.UP and t < 1800:
		await _ticks(10)
		t += 10
	check(a.stage() == TargetBalloon.Stage.UP and a.holes.is_empty() and not a.counted, "burnt out, a fresh one goes up (%s after %.0f s)" % [TargetBalloon.Stage.keys()[a.stage()], t / 60.0])
	var low := a.centre().y
	await _ticks(180)
	check(a.centre().y > low + 2.0, "and rises up its cable (%.1f m to %.1f m)" % [low, a.centre().y])
	finish()


func _balloon(world: CombatWorld, at: Vector3, i: int) -> TargetBalloon:
	var bl := TargetBalloon.new(i)
	bl.cable = 6.0
	bl.respawn_after = 3.0
	add_child(bl)
	bl.position = at
	world.balloons.append(bl)
	return bl


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
