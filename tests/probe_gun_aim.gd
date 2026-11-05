extends TestCase
## Diagnostic (headless): where the gun's bullets go against the gunsight as the chase camera sees it. A crow on two
## gun pods glides straight; for each range d, the point the sight ring covers at d (the camera's ray through the
## ring, 25 m out on the flight path) against where a bullet from each pod (no scatter) is when it's d out: the miss
## in the camera's up and right (m, and in a balloon's radius), and the share of scattered bullets that would hole a
## balloon put under the sight at d. At each chase zoom.
##   .\probe.ps1 probe_gun_aim -Headless


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var layout := ArenaLayout.lab()
	for zoom in [1.0, 0.45, 2.0]:
		for speed in [10.0, 16.0]:
			await _run(layout, zoom, speed)
	finish()


func _run(layout: ArenaLayout, zoom: float, speed: float) -> void:
	var world := CombatWorld.new()
	world.layout = layout
	add_child(world)
	var a := Bird.new()
	add_child(a)
	a.setup(BirdProfile.crow(), layout, ScriptedInput.new())
	a.fly_from(Vector3(0, 40, 0), Vector3(0, 0, -1), speed)
	var l := world.add_bird(a, null)
	var pods: Array[String] = ["gun", "gun"]
	var t := Tack.fit(a.rig, a, pods)
	l.set_tack(t)
	var cam := ChaseCamera.new()
	cam.bird = a
	cam.zoom = zoom
	cam._zoom = zoom
	add_child(cam)
	cam.snap()
	for i in 40:
		await get_tree().physics_frame
	var aim := l.aim()
	var sight := l.muzzle() + aim * 25.0
	var c := cam.global_position
	var up := cam.global_basis.y
	var right := cam.global_basis.x
	var ray := (sight - c).normalized()
	var o := l.muzzle()
	print("zoom %.2f  %.0f m/s  flight path %+.1f deg  camera %.2f m behind, %.2f m above the line of fire, sight %.2f deg below the view's middle" % [
		zoom, a.model.velocity.length(), rad_to_deg(asin(aim.y)), -(c - o).dot(aim),
		(c - o - aim * (c - o).dot(aim)).length(), rad_to_deg(ray.angle_to(-cam.global_basis.z))])
	var paths := []
	for pod in 2:
		paths.append(_path(t.muzzle_world("gun", pod), a.model.velocity, aim, layout))
	print("  pods at %s and %s from the sight's origin (camera right, up)" % [_ru(t.muzzle_world("gun", 0) - o, right, up), _ru(t.muzzle_world("gun", 1) - o, right, up)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for d: float in [5.0, 8.0, 12.0, 16.0, 20.0, 25.0, 30.0, 35.0]:
		# Under the sight at d: the camera's ray through the ring, where it's d down the line of fire.
		var under: Vector3 = c + ray * ((o + aim * d - c).dot(aim) / ray.dot(aim))
		var line := "  %4.0f m:" % d
		for pod in 2:
			var b = _at(paths[pod], o, aim, d)
			if b == null:
				line += "  pod %d out of range       " % pod
				continue
			var miss: Vector3 = b - under
			line += "  pod %d %+.2f up %+.2f right (%+.1f r)" % [pod, miss.dot(up), miss.dot(right), miss.dot(up) / TargetBalloon.RADIUS]
		# Scattered bullets at a balloon (side on: its girth up and down, its length across) put under the sight.
		var holed := 0
		var n := 200
		for k in n:
			var pod := k % 2
			var side := aim.cross(Vector3.UP).normalized()
			var uu := side.cross(aim).normalized()
			var sd := deg_to_rad(Launcher.GUN_SPREAD)
			var dir := (aim + side * tan(rng.randfn(0.0, sd)) + uu * tan(rng.randfn(0.0, sd))).normalized()
			var b = _at(_path(t.muzzle_world("gun", pod), a.model.velocity, dir, layout), o, aim, d)
			if b == null:
				continue
			var m: Vector3 = b - under
			var v := m.dot(uu) / TargetBalloon.RADIUS
			var h := m.dot(side) / (TargetBalloon.LENGTH * 0.5)
			if v * v + h * h < 1.0:
				holed += 1
		line += "   holed %3.0f%%" % (100.0 * holed / n)
		print(line)
	cam.queue_free()
	a.queue_free()
	world.queue_free()
	await get_tree().physics_frame


func _ru(v: Vector3, right: Vector3, up: Vector3) -> String:
	return "(%+.2f, %+.2f)" % [v.dot(right), v.dot(up)]


## A bullet's positions, a tick apart, fired from `from` along `dir`.
func _path(from: Vector3, carrier: Vector3, dir: Vector3, layout: ArenaLayout) -> PackedVector3Array:
	var p := Projectile.launch(Projectile.Kind.GUN, from, carrier, dir, null)
	var out := PackedVector3Array([p.pos])
	while p.alive:
		p.step(1.0 / 60.0, layout, [])
		out.append(p.pos)
	return out


## Where the path is when it's `d` down the line of fire from `o` (null: it never gets there).
func _at(path: PackedVector3Array, o: Vector3, aim: Vector3, d: float):
	for i in range(1, path.size()):
		var s0 := (path[i - 1] - o).dot(aim) - d
		var s1 := (path[i] - o).dot(aim) - d
		if s0 <= 0.0 and s1 > 0.0:
			return path[i - 1].lerp(path[i], -s0 / (s1 - s0))
	return null
