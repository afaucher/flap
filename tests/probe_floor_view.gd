extends TestCase
## The pine wood's floor up close, for judging the ground cover (the litter, the moss and dirt patches, the mounds,
## the plants): a sheet of fixed views -- low under a clump of pines, low in a gap, looking down from 4 m, across the
## glade, over the clearing's edge. Windowed:
##   Godot --path . -- --run-test probe_floor_view --out <png> [--seed 7] [--look <name>]

const CELL := Vector2i(800, 450)


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var seed_arg := Boot.arg_value(args, "--seed")
	get_window().size = Vector2i(1600, 900)
	var root := Node3D.new()
	add_child(root)
	var layout := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	ForestLight.setup(root)
	var arena := ArenaBuilder.new()
	root.add_child(arena)
	arena.build(layout)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 600.0
	root.add_child(cam)
	cam.current = true
	# Spots: the darkest floor (deep in a clump) and the lightest (a gap), from Pinewood.light over a grid.
	var shade := Vector2.ZERO
	var lit := Vector2.ZERO
	var lo := INF
	var hi := -INF
	for gx in range(-60, 61, 6):
		for gz in range(-60, 61, 6):
			var p := Vector2(gx, gz)
			if p.length() < layout.clearing_radius + 8.0 or Pinewood.in_opening(layout, p):
				continue
			var l := Pinewood.light(layout, p)
			if l < lo:
				lo = l
				shade = p
			if l > hi:
				hi = l
				lit = p
	# A moss patch (the floor field's moss signal well over its edge) near the lit spot, for a close look.
	var moss_at := lit
	var ff := layout.floor_field
	var best := INF
	for j in range(0, ff.n, 3):
		for i in range(0, ff.n, 3):
			var k := (j * ff.n + i) * 4
			var p := ff.origin + Vector2(i, j) * FloorField.RES
			if ff.data[k + 1] > 0.8 and ff.data[k + 3] == 0.0 and p.length() < layout.boundary - 10.0 and p.distance_to(lit) < best:
				best = p.distance_to(lit)
				moss_at = p
	var glade: Dictionary = layout.openings[1]
	var gc: Vector2 = glade.centre
	var views := [
		["under a clump, 1.2 m", _v3(shade, 1.2) + Vector3(4, 0, 4), _v3(shade, 0.2) - Vector3(4, 0, 4)],
		["in a gap, 1.2 m", _v3(lit, 1.2) + Vector3(-4, 0, 3), _v3(lit, 0.2) + Vector3(4, 0, -3)],
		["looking down from 4 m", _v3(lit, 4.0) + Vector3(2, 0, 2), _v3(lit, 0.0) - Vector3(2, 0, 2)],
		["looking down from 12 m", _v3(shade, 12.0) + Vector3(6, 0, 6), _v3(shade, 0.0) - Vector3(4, 0, 4)],
		["across the glade, 2 m", _v3(gc - gc.normalized() * float(glade.r) * 1.1, 2.0), _v3(gc, 0.5)],
		["the clearing's edge, 3 m", _v3(Vector2(0, layout.clearing_radius + 6.0), 3.0), _v3(Vector2(0, 0), 0.0)],
		["moss, from 0.8 m", _v3(moss_at, 0.8) + Vector3(1.2, 0, 1.2), _v3(moss_at, 0.0) - Vector3(0.3, 0, 0.3)],
		["moss, from 3 m", _v3(moss_at, 3.0) + Vector3(3, 0, 3), _v3(moss_at, 0.0)],
	]
	var sheet := Image.create(CELL.x * 2, CELL.y * 4, false, Image.FORMAT_RGB8)
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


func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, ArenaLayout.GROUND_Y + y, p.y)
