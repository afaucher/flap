extends TestCase
## The pine wood's ages (Pinewood: mature pines, pole-stage pines, veterans) in a sheet of fixed views: a veteran
## from out in front and from under its crown, a group of poles, and long looks through the stand at two heights.
## The views are picked on the wood with its ages; `--no-ages` builds the same seed without them (the A/B). Windowed:
##   Godot --path . -- --run-test probe_pine_ages --out <png> [--seed 7] [--no-ages]

const CELL := Vector2i(800, 450)


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var seed_arg := Boot.arg_value(args, "--seed")
	var s := int(seed_arg) if seed_arg != "" else 7
	get_window().size = Vector2i(1600, 900)
	var layout := Pinewood.generate(s)
	# The veteran nearest the middle, and the pole with most poles round it.
	var vet: ArenaLayout.TreeData = null
	var pole: ArenaLayout.TreeData = null
	var most := -1
	for t in layout.trees:
		if t.form == "veteran" and (vet == null or Vector2(t.base).length() < Vector2(vet.base).length()):
			vet = t
		if t.form == "pole":
			var n := 0
			for u in layout.trees:
				n += int(u.form == "pole" and Vector2(u.base).distance_to(t.base) < 12.0)
			if n > most:
				most = n
				pole = t
	# Each looked at from its most open side: the level look out from it (at a third of its height) reaching
	# farthest past wood and leaves.
	var vet_view := _open_side(layout, vet)
	var pole_view := _open_side(layout, pole)
	var out_dir: Vector2 = vet_view[0]
	var pole_dir: Vector2 = pole_view[0]
	if args.has("--no-ages"):
		Pinewood.ages = false
		layout = Pinewood.generate(s)
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
	var vb: Vector2 = vet.base
	var side := Vector2(-out_dir.y, out_dir.x)
	var views := [
		["a veteran, from out in the open", _v3(vb + out_dir * minf(float(vet_view[1]) - 1.0, 20.0), vet.height * 0.3), _v3(vb, vet.height * 0.55)],
		["under a veteran's crown", _v3(vb + out_dir * 7.0 + side * 2.0, 2.0), _v3(vb - out_dir * 2.0, vet.height * 0.6)],
		["poles in the half-light", _v3(pole.base + pole_dir * minf(float(pole_view[1]) - 1.0, 20.0), 3.0), _v3(pole.base, pole.height * 0.5)],
		["a pole, from 7 m", _v3(pole.base + pole_dir * minf(float(pole_view[1]) - 1.0, 8.0), 2.0), _v3(pole.base, pole.height * 0.45)],
		["through the stand, 3 m", _v3(vb + out_dir * 45.0, 3.0), _v3(vb, 6.0)],
		["through the stand, 12 m", _v3(vb + out_dir * 45.0, 12.0), _v3(vb, 12.0)],
	]
	var sheet := Image.create(CELL.x * 2, CELL.y * 3, false, Image.FORMAT_RGB8)
	for i in views.size():
		var v: Array = views[i]
		cam.look_at_from_position(v[1], v[2], Vector3.UP)
		await frames(40 if i == 0 else 12)
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 2) * CELL.x, (i / 2) * CELL.y))
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
