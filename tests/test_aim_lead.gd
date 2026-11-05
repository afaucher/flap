extends TestCase
## The lead mark and what it's on, seen through the chase camera (which rides above the line of fire):
##  - fly the gunsight onto the lead mark (Launcher.lead_sight) and a bullet meets a balloon near (6 m) and far (35 m);
##    the old mark -- the gunsight over the lead point itself, as the camera sees it -- shoots under one near and over
##    one far, and the lead without the bullet's drop shoots under a far one;
##  - the HUD's target (Launcher.target) is whatever is nearest the sight: a balloon over a bird further off it, and a
##    bird over a balloon; held against one only a little nearer the sight, taken by one much nearer; never a balloon
##    that's down, nor a teammate; the AI's (target_bird) never a balloon;
##  - the HUD brackets the balloon and draws its lead mark at lead_sight.

const D_NEAR := 6.0
const D_FAR := 35.0


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	world.layout = layout
	add_child(world)
	var me := Bird.new()
	add_child(me)
	me.setup(BirdProfile.crow(), layout, ScriptedInput.new())
	me.fly_from(Vector3(0, 40, 0), Vector3.FORWARD, 12.0)
	var l := world.add_bird(me, null, 0)
	var pods: Array[String] = ["gun", "gun"]
	l.set_tack(Tack.fit(me.rig, me, pods))
	l.weapon = Launcher.Weapon.GUN
	var mate := _bird(world, layout, Vector3(-30, 40, 0), 0)
	var foe := _bird(world, layout, Vector3(30, 40, 0), 1)
	var bl := TargetBalloon.new(0)
	bl.auto = false
	add_child(bl)
	bl.position = Vector3(0, 0, -200)
	for i in 600:
		bl.step(1.0 / 60.0)   # (up to the top of its cable)
	world.balloons.append(bl)
	var cam := ChaseCamera.new()
	cam.bird = me
	add_child(cam)
	cam.current = true
	cam.snap()
	var hud := CombatHud.new()
	hud.launcher = l
	hud.world = world
	add_child(hud)
	await _ticks(30)
	# --- The lead mark: near and far, against the old mark and a lead without the drop.
	for d in [D_NEAR, D_FAR]:
		_put(bl, l, d, 0.0, 0.0)
		var m := l.muzzle()
		var c := cam.global_position
		var speed := me.model.velocity.length()
		var new_aim := _sight_over(c, m, l.lead_sight(bl))   # (the gunsight over the lead mark, as the camera sees them)
		var p := l.lead_point(bl)
		var old_aim := _sight_over(c, m, p)
		var flat := l.lead_point(bl) - Vector3.UP * (p.y - bl.centre().y)   # (the lead point less its drop)
		var flat_aim := (flat - m).normalized()
		var hit_new: float = _miss(m, new_aim, speed, bl.centre())
		var hit_old: float = _miss(m, old_aim, speed, bl.centre())
		var hit_flat: float = _miss(m, flat_aim, speed, bl.centre())
		check(absf(hit_new) < TargetBalloon.RADIUS * 0.3, "%.0f m: the sight on the lead mark, the bullet meets the balloon (%+.2f m)" % [d, hit_new])
		if d == D_NEAR:
			check(hit_old < -TargetBalloon.RADIUS, "%.0f m: the sight over the lead point as seen shoots under it (%+.2f m)" % [d, hit_old])
		else:
			check(hit_old > TargetBalloon.RADIUS * 0.5, "%.0f m: the sight over the lead point as seen shoots over it (%+.2f m)" % [d, hit_old])
			check(hit_flat < -TargetBalloon.RADIUS, "%.0f m: a lead without the drop shoots under it (%+.2f m)" % [d, hit_flat])
		# And the real bullet, in the world: holes it from the lead mark, not from the old one.
		bl.reset()
		for i in 600:
			bl.step(1.0 / 60.0)
		var holes := []
		for k in 2:
			_put(bl, l, d, 0.0, 0.0)
			var aim := _sight_over(cam.global_position, l.muzzle(), l.lead_point(bl)) if k == 0 else _sight_over(cam.global_position, l.muzzle(), l.lead_sight(bl))
			var before := bl.holes.size()
			world.spawn(Projectile.launch(Projectile.Kind.GUN, l.muzzle(), aim * me.model.velocity.length(), aim, me))
			await _ticks(30)
			holes.append(bl.holes.size() - before)
		check(holes[1] > 0 and (d == D_FAR or holes[0] == 0), "%.0f m: a real bullet from the lead mark holes it (%d holes; from the old mark %d)" % [d, holes[1], holes[0]])
	bl.reset()
	for i in 600:
		bl.step(1.0 / 60.0)
	# --- What the HUD's target is.
	_put(bl, l, 20.0, 3.0, 0.0)
	_put(foe, l, 20.0, 10.0, 90.0)
	check(l.target() == bl, "a balloon 3 deg off the sight is picked over a bird 10 deg off")
	l._pick = null
	_put(bl, l, 20.0, 10.0, 0.0)
	_put(foe, l, 20.0, 3.0, 90.0)
	check(l.target() == foe, "and a bird 3 deg off over a balloon 10 deg off")
	_put(bl, l, 20.0, 5.0, 0.0)
	_put(foe, l, 20.0, 12.0, 90.0)
	check(l.target() == bl, "(the balloon picked at 5 deg)")
	_put(foe, l, 20.0, 4.0, 90.0)
	check(l.target() == bl, "held against a bird only a little nearer the sight (4 deg)")
	_put(foe, l, 20.0, 2.0, 90.0)
	check(l.target() == foe, "taken by one much nearer (2 deg)")
	_put(foe, l, 20.0, 40.0, 90.0)
	_put(mate, l, 20.0, 1.0, 180.0)
	_put(bl, l, 20.0, 6.0, 0.0)
	check(l.target() == bl and l.target() != mate, "never a teammate, even on the sight")
	check(l.target_bird() != bl and l.target_bird() == foe, "the AI's target is never a balloon")
	# (the range's demo shooter fires at its target's lead: at a bird dead ahead, never at a balloon there)
	var ai := AICombat.new()
	ai.prefer = Launcher.Weapon.GUN
	_put(foe, l, 50.0, 60.0, 90.0)
	_put(bl, l, 15.0, 0.0, 0.0)
	_put(bl, l, 15.0, rad_to_deg(l.aim().angle_to(l.lead_point(bl) - l.muzzle())), 180.0)
	check(not ai.sample(l, 1.0 / 60.0).fire_pressed, "the AI's trigger finger doesn't fire at a balloon on its lead")
	_put(bl, l, 50.0, 60.0, 0.0)
	_put(foe, l, 15.0, 0.0, 0.0)
	check(ai.sample(l, 1.0 / 60.0).fire_pressed, "but does at a bird there")
	_put(foe, l, 50.0, 30.0, 90.0)
	_put(bl, l, 70.0, 2.0, 0.0)
	check(l.target() == foe, "a balloon past TARGET_RANGE isn't picked: the nearest enemy in front is")
	_put(bl, l, 20.0, 2.0, 0.0)
	bl.gas = 0.1
	bl.step(1.0 / 60.0)
	check(bl.is_down() and l.target() == foe, "nor one that's down")
	bl.reset()
	for i in 600:
		bl.step(1.0 / 60.0)
	# --- The HUD brackets it and draws its lead mark where the sight must be.
	_put(foe, l, 50.0, 60.0, 90.0)
	_put(mate, l, 50.0, 60.0, 180.0)
	var ok := false
	var lead_ok := false
	for i in 20:
		_put(bl, l, D_NEAR + 2.0, 2.0, 0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		ok = ok or hud.bracketed == bl
		lead_ok = lead_ok or (hud.drew_lead and hud.lead_world.distance_to(l.lead_sight(bl)) < 0.5)
	check(ok, "the HUD brackets the balloon on the sight")
	check(lead_ok, "and draws its lead mark at lead_sight, where the sight must be")
	finish()


func _bird(world: CombatWorld, layout: ArenaLayout, at: Vector3, team: int) -> Bird:
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.crow(), layout, ScriptedInput.new())
	b.rig.visible = false
	b.fly_from(at, Vector3.FORWARD, 10.0)
	world.add_bird(b, null, team)
	return b


## Put `o` (a bird's body, a balloon's envelope) `d` m from the muzzle, `off` deg off the aim, round it by `round` deg.
func _put(o: Node3D, l: Launcher, d: float, off: float, round: float) -> void:
	var a := l.aim()
	var side := a.cross(Vector3.UP).normalized()
	var dir := a.rotated(side.rotated(a, deg_to_rad(round)), deg_to_rad(off))
	o.global_position += l.muzzle() + dir * d - Launcher.aim_at(o)


## The aim that puts the gunsight (SIGHT_RANGE out on it) over `p` as the camera at `c` sees it.
func _sight_over(c: Vector3, m: Vector3, p: Vector3) -> Vector3:
	var u := (p - c).normalized()
	var b := u.dot(c - m)
	var t := -b + sqrt(b * b - ((c - m).length_squared() - Launcher.SIGHT_RANGE * Launcher.SIGHT_RANGE))
	return (c + u * t - m).normalized()


## A bullet's (no scatter) height over `at` as it passes it, fired from `m` along `aim` by a bird flying that way.
func _miss(m: Vector3, aim: Vector3, speed: float, at: Vector3) -> float:
	var p := Projectile.launch(Projectile.Kind.GUN, m, aim * speed, aim, null)
	var best := INF
	var miss := 0.0
	while p.alive:
		var a := p.pos
		p.step(1.0 / 60.0, null, [])
		var q := Geometry3D.get_closest_point_to_segment(at, a, p.pos)
		if q.distance_to(at) < best:
			best = q.distance_to(at)
			miss = (q - at).dot(Vector3.UP)
	return miss


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
