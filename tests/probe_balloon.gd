extends TestCase
## Target balloons (TargetBalloon) in the pine wood's clearing, in the game's light, one in each stage -- up, holed,
## sinking, down, alight, falling, wreck -- each looked at close, and all of them from across the clearing.
## The close views clip what stands nearer the camera than the balloon (the understory in the way). Windowed:
##   .\probe.ps1 probe_balloon --out <prefix>
## writes <prefix>_<stage>.png (1376 x 768) for each, <prefix>_wide.png, and <prefix>_sheet.png (the eight, 4 x 2).

const STAGES := ["up", "holed", "sinking", "down", "alight", "falling", "wreck"]
const DT := 1.0 / 60.0


func _init() -> void:
	timeout_sec = 180.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var vp := SubViewport.new()
	vp.size = Vector2i(1376, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var layout := Pinewood.generate(7)
	var ab := ArenaBuilder.new()
	vp.add_child(ab)
	ab.build(layout)
	var sun := ForestLight.setup(vp)
	var to_sun := Vector3(sun.global_basis.z.x, 0.0, sun.global_basis.z.z).normalized()
	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	cam.current = true
	var breeze := Vector3(-to_sun.z, 0.0, to_sun.x)   # (across the sun: the row's flanks face it, front-lit from its side)
	var side := Vector3(-breeze.z, 0.0, breeze.x)
	# The widest clearing: the row runs down the breeze through it.
	var open := Vector2.ZERO
	var open_r := 0.0
	for o in layout.openings:
		if o.r > open_r:
			open = o.centre
			open_r = o.r
	print("clearing r %.1f at %s" % [open_r, open])
	# Spots round it, clear of the oak's crown in its middle and the pines at its edge, a few metres apart.
	var spots := []
	for k in 72:
		var ang := TAU * k / 72.0
		for rr in [12.0, 14.0, 10.0, 16.0]:
			var p := Vector3(open.x + rr * cos(ang), 0.0, open.y + rr * sin(ang))
			p.y = ArenaLayout.GROUND_Y + layout.ground(p.x, p.z)
			var far := true
			for q in spots:
				far = far and (q as Vector3).distance_to(p) > 4.5
			if far and TargetBalloon.clear_spot(layout, p, 10.0):
				spots.append(p)
				break
		if spots.size() == STAGES.size():
			break
	print("spots: %d" % spots.size())
	var balloons := {}
	for i in STAGES.size():
		var b := TargetBalloon.new(i)
		b.auto = false
		b.leak = 0.0
		b.breeze = breeze
		b.cable = [9.0, 7.5, 8.0, 8.0, 8.5, 10.0, 8.0][i]
		var at: Vector3 = spots[i]
		vp.add_child(b)
		b.position = at
		balloons[STAGES[i]] = b
	await frames(2)
	var eye := func(b: TargetBalloon) -> Vector3:
		return b.centre() + b.body.global_basis.x * 3.0
	# Each into its stage, stepped by hand.
	for k in balloons:
		var b: TargetBalloon = balloons[k]
		_run(b, 3.0)
		var from: Vector3 = eye.call(b)
		match k:
			"holed":
				_shoot(b, from, 7, 1)
				b.gas = 0.93
			"sinking":
				_shoot(b, from, 14, 2)
				b.gas = 0.5
			"down":
				_shoot(b, from, 18, 3)
				b.gas = 0.12
			"alight", "falling", "wreck":
				b.burst_near(b.centre() + b.body.global_basis.x * 0.6 + b.body.global_basis.z * 0.2)
		_run(b, {"alight": 0.4, "falling": 1.9, "wreck": 7.0, "sinking": 5.0, "down": 8.0}.get(k, 0.5))
		print("%s: %s gas %.2f burnt %.2f at %.1f m" % [k, TargetBalloon.Stage.keys()[b.stage()], b.gas, b.burnt(), b.centre().y - b.global_position.y])
	var shots := []
	for k in STAGES:
		var b: TargetBalloon = balloons[k]
		var c := b.centre()
		var bx := b.body.global_basis.x
		var nose := -b.body.global_basis.z
		if bx.dot(to_sun) < 0.0:
			bx = -bx   # (from the sun's side: front-lit)
		var p: Vector3 = c + bx * 2.3 + nose * 1.0 + Vector3.UP * 0.25
		var at := c
		if k in ["down", "wreck"]:
			p = c + bx * 2.0 + nose * 1.0 + Vector3.UP * 2.6
			at = c + Vector3(0.0, -0.1, 0.0)
		elif k == "falling":
			p = c + bx * 4.5 + nose * 1.5 + Vector3.UP * 0.8
			at = c + Vector3.UP * 0.7
		cam.position = _clear(layout, at, p)
		cam.look_at(at)
		cam.near = 0.05 if k in ["down", "wreck"] else maxf(0.05, cam.position.distance_to(at) - 0.9)   # (nothing nearer than the balloon's own reach in the way)
		shots.append(await _shot(vp, out, k))
	# Across the clearing: all of them, from treetop height at its edge.
	var mid := Vector3.ZERO
	for k in balloons:
		mid += (balloons[k] as TargetBalloon).global_position
	mid /= balloons.size()
	cam.fov = 60.0
	cam.position = _clear(layout, mid + Vector3.UP * 4.0, mid + to_sun * 17.0 + Vector3(0.0, 7.0, 0.0))
	cam.look_at(mid + Vector3.UP * 4.0)
	cam.near = 6.0
	shots.append(await _shot(vp, out, "wide"))
	if out != "":
		var tile := Vector2i(688, 384)
		var sheet := Image.create(tile.x * 4, tile.y * 2, false, Image.FORMAT_RGB8)
		for i in shots.size():
			var im: Image = shots[i]
			im.resize(tile.x, tile.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, tile), Vector2i((i % 4) * tile.x, (i / 4) * tile.y))
		sheet.save_png(out + "_sheet.png")
		print("sheet: ", out + "_sheet.png")
	finish()


## `want` swung round `at` (keeping its distance and height) to the first place with nothing in the way: no trunk
## or branch (ArenaLayout.wood_near), no small tree's crown.
func _clear(layout: ArenaLayout, at: Vector3, want: Vector3) -> Vector3:
	var off := want - at
	var best := want
	var best_n := 1 << 30
	for k in 15:
		var p := at + off.rotated(Vector3.UP, (k / 2 + 1) * 0.2 * (1.0 if k % 2 == 0 else -1.0) if k > 0 else 0.0)
		var n := layout.wood_near(p, at, 0.4).size() * 10
		for t: ArenaLayout.TreeData in layout.trees:
			if Geometry2D.get_closest_point_to_segment(t.base, Vector2(p.x, p.z), Vector2(at.x, at.z)).distance_to(t.base) < t.reach() * 0.7:
				n += 1
		if n < best_n:
			best_n = n
			best = p
	return best


func _run(b: TargetBalloon, secs: float) -> void:
	for i in int(secs / DT):
		b.step(DT)


## `n` bullets into `b` from `from`, spread over the side facing it.
func _shoot(b: TargetBalloon, from: Vector3, n: int, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	for i in n:
		var u := rng.randf_range(0.12, 0.75)
		var a := rng.randf_range(-0.8, 0.8)
		var r := TargetBalloon._r(u)
		var p := b.body.global_transform * Vector3(r * cos(a), r * sin(a), (u - 0.5) * TargetBalloon.LENGTH)
		b.bullet_hit(p, (p - from).normalized())


func _shot(vp: SubViewport, out: String, name: String) -> Image:
	await frames(24)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if out != "":
		img.save_png("%s_%s.png" % [out, name])
		print("shot: ", name)
	return img
