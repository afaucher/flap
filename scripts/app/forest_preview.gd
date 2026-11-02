extends Node3D
## Dev scene: the pine wood (Pinewood) in greybox, seen from a set of fixed views, for judging its structure.
##   .\run.ps1 --scene res://scenes/forest_preview.tscn [--seed <n>] [--sheet <png>]
## --sheet renders the views into one image and quits. Keys: Space next view. To fly it:
##   .\run.ps1 -- --forest pinewood

var layout: ArenaLayout
var cam: Camera3D
var views := []
var view_i := 0
var _label: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_arg := Boot.arg_value(args, "--seed")
	if Boot.arg_value(args, "--crowns") != "":
		Pinewood.crown_density = float(Boot.arg_value(args, "--crowns"))
	layout = Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	if Boot.arg_value(args, "--light") == "grey":
		Game.add_environment(self)
	else:
		ForestLight.setup(self, Boot.arg_value(args, "--gi") == "on")
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	add_child(_label)
	views = _views()
	_show(0)
	var sheet := Boot.arg_value(args, "--sheet")
	if sheet != "":
		await _sheet(sheet)
		get_tree().quit()


## [label, camera position, look-at point]
func _views() -> Array:
	var v := []
	var oak: ArenaLayout.TreeData = layout.trees[0]
	v.append(["The clearing's oak, from its edge at 9 m", Vector3(4.0, 9.0, 30.0), oak.top() * Vector3(1, 0, 1) + Vector3.UP * 8.0])
	v.append(["Overview", Vector3(0.0, 75.0, 120.0), Vector3(0.0, 0.0, 10.0)])
	var on_pine: ArenaLayout.OutpostData = null
	for o in layout.outposts:
		if layout.trees[o.tree_id].kind == ArenaLayout.Kind.PINE:
			on_pine = o
			break
	# The concept's angle: above and behind a bird coming in to the outpost, looking across it into the light.
	var toward_sun := -(Basis.from_euler(Vector3(0.0, deg_to_rad(ForestLight.SUN_AZIMUTH), 0.0)) * Vector3.BACK).normalized()
	v.append(["The concept's angle: coming in to an outpost", on_pine.centre - toward_sun * 4.0 + on_pine.out * 1.2 + Vector3.UP * 2.4, on_pine.centre + toward_sun * 3.0])
	v.append(["A pine's outpost, on approach", on_pine.centre + on_pine.out * 3.2 + Vector3.UP * 0.6 + on_pine.out.cross(Vector3.UP) * 1.2, on_pine.centre])
	v.append(["A pine's outpost, the deck from 1 m", on_pine.centre + on_pine.out * 1.1 + on_pine.out.cross(Vector3.UP) * 0.5 + Vector3.UP * 0.9, on_pine.centre - on_pine.out * 0.1])
	var o2: ArenaLayout.OutpostData = layout.outposts[0]
	v.append(["The clearing oak's outpost, from 8 m", o2.centre + o2.out * 8.0 + Vector3.UP * 1.5, o2.centre + Vector3.UP * 0.5])
	v.append(["Between the pines at 8 m", Vector3(-70.0, 8.0, -30.0), Vector3(-20.0, 9.0, -10.0)])
	v.append(["Crown layer at 22 m", Vector3(60.0, 22.0, -55.0), Vector3(10.0, 21.0, -10.0)])
	v.append(["Low over the floor at 1.5 m", Vector3(30.0, 1.5, 70.0), Vector3(0.0, 2.5, 30.0)])
	v.append(["Looking up a pine", Vector3(-40.0, 1.0, 40.0) + Vector3(2.5, 0.0, 0.0), Vector3(-40.0, 30.0, 40.0)])
	# Bark, close: the pine nearest the clearing's edge, sunlit side.
	var pine: ArenaLayout.TreeData = null
	for t in layout.trees:
		if t.kind == ArenaLayout.Kind.PINE and (pine == null or Vector2(t.base).length() < Vector2(pine.base).length()):
			pine = t
	var c := Vector3(pine.base.x, 0.0, pine.base.y)
	var sun_side := (Basis.from_euler(Vector3(0.0, deg_to_rad(ForestLight.SUN_AZIMUTH), 0.0)) * Vector3.BACK).normalized()
	var side := sun_side.cross(Vector3.UP).normalized()
	v.append(["Pine bark from 2 m", c + sun_side * 2.0 + side * 0.6 + Vector3.UP * 6.0, c + Vector3.UP * 6.5])
	v.append(["Pine bark at 40 cm (a skimming pass)", c + sun_side * (pine.radius + 0.4) + side * 0.25 + Vector3.UP * 9.0, c + sun_side * pine.radius + Vector3.UP * 9.0])
	v.append(["Upper trunk and crown limbs", c + sun_side * 4.0 + side * 1.5 + Vector3.UP * (pine.crown_base - 1.5), c + Vector3.UP * (pine.crown_base + 1.0)])
	var oc := Vector3(oak.base.x, 0.0, oak.base.y)
	v.append(["Oak bark from 2.5 m", oc + sun_side * (oak.radius + 2.5) + Vector3.UP * 3.0, oc + Vector3.UP * 3.2])
	return v


func _show(i: int) -> void:
	view_i = i
	var s: Array = views[i]
	var up := Vector3.UP if absf(((s[2] as Vector3) - (s[1] as Vector3)).normalized().y) < 0.97 else Vector3.FORWARD
	cam.look_at_from_position(s[1], s[2], up)
	_label.text = s[0]


func _sheet(path: String) -> void:
	var cell := Vector2i(800, 450)
	get_window().size = Vector2i(1600, 900)
	var rows := (views.size() + 1) / 2
	var img := Image.create(cell.x * 2, cell.y * rows, false, Image.FORMAT_RGB8)
	for i in views.size():
		_show(i)
		for f in (12 if i > 0 else 40):   # (the first view lets SDFGI and the volumetric fog settle)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(shot, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 2) * cell.x, (i / 2) * cell.y))
	img.save_png(path)
	print("sheet: ", path)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_SPACE:
		_show((view_i + 1) % views.size())
