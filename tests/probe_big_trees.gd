extends TestCase
## The wood's big trees in a sheet of fixed views: the big oak in the clearing (whole, at limb height among its limbs,
## from under its canopy), a glade oak, and a veteran pine (whole, from under its crown). Windowed:
##   .\probe.ps1 probe_big_trees --out <png> [--seed 7]

const CELL := Vector2i(800, 450)


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var seed_arg := Boot.arg_value(args, "--seed")
	get_window().size = Vector2i(1600, 900)
	var layout := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	var big: ArenaLayout.TreeData = null
	var glade: ArenaLayout.TreeData = null
	var vet: ArenaLayout.TreeData = null
	for t in layout.trees:
		if t.kind == ArenaLayout.Kind.BROADLEAF:
			if big == null or Vector2(t.base).length() < Vector2(big.base).length():
				if big != null:
					glade = big
				big = t
			elif glade == null:
				glade = t
		if t.form == "veteran" and (vet == null or Vector2(t.base).length() < Vector2(vet.base).length()):
			vet = t
	var root := Node3D.new()
	add_child(root)
	ForestLight.setup(root)
	var arena := ArenaBuilder.new()
	root.add_child(arena)
	arena.build(layout)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 600.0
	root.add_child(cam)
	cam.current = true
	var gd := _open_side(layout, glade)[0] as Vector2
	var vd := _open_side(layout, vet)[0] as Vector2
	var vr := float(_open_side(layout, vet)[1])
	var bb: Vector2 = big.base
	var views := [
		["the big oak, from the clearing's edge", _v3(bb + Vector2(1, 0.3).normalized() * 19.5, 3.0), _v3(bb, big.height * 0.45), 84.0],
		["the big oak, among its limbs", _v3(bb + Vector2(0.4, 1).normalized() * 12.0, big.height * 0.45), _v3(bb, big.height * 0.45)],
		["under the big oak", _v3(bb + Vector2(-1, 0.2).normalized() * 4.0, 1.6), _v3(bb + Vector2(1, -0.2) * 2.0, big.height * 0.7)],
		["a glade oak", _v3(glade.base + gd * 24.0, 4.0), _v3(glade.base, glade.height * 0.45), 75.0],
		["a veteran pine, from the open", _v3(vet.base + vd * minf(vr - 1.0, 20.0), vet.height * 0.3), _v3(vet.base, vet.height * 0.55)],
		["the big oak from above, 30 m", _v3(bb + Vector2(1, 0.6).normalized() * 26.0, 30.0), _v3(bb, big.height * 0.4)],
	]
	var sheet := Image.create(CELL.x * 2, CELL.y * 3, false, Image.FORMAT_RGB8)
	for i in views.size():
		var v: Array = views[i]
		cam.fov = v[3] if v.size() > 3 else 62.0
		cam.look_at_from_position(v[1], v[2], Vector3.UP)
		await frames(40 if i == 0 else 12)
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 2) * CELL.x, (i / 2) * CELL.y))
	print("big oak h %.1f r %.2f; glade oak h %.1f r %.2f; veteran h %.1f r %.2f" % [big.height, big.radius, glade.height, glade.radius, vet.height, vet.radius])
	if out != "":
		sheet.save_png(out)
		print("sheet: ", out)
	finish()


## [direction, how far the look reaches] for the most open side of `t`.
func _open_side(a: ArenaLayout, t: ArenaLayout.TreeData) -> Array:
	var best := [Vector2.RIGHT, 0.0]
	for k in 24:
		var d := Vector2.from_angle(TAU * k / 24.0)
		var from := Vector3(t.base.x + d.x * (t.radius + 0.5), ArenaLayout.GROUND_Y + t.height * 0.33, t.base.y + d.y * (t.radius + 0.5))
		var reach := Pinewood.sight_distance(a, from, Vector3(d.x, 0.0, d.y), 40.0, true)
		if reach > float(best[1]):
			best = [d, reach]
	return best


func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, ArenaLayout.GROUND_Y + y, p.y)
