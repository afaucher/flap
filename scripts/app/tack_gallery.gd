extends Node3D
## Dev scene: one bird with its war tack (scripts/tack), posed in flight or perched, for looking at the saddle,
## harness, launcher and rider up close.
##   .\run.ps1 --scene res://scenes/tack_gallery.tscn [--bird falcon] [--pose glide|flap|upstroke|folded|flare]
##       [--shot <png> [--shot-after <s>]] [--sheet <png> [--label <text>]] [--ammo <rockets>,<seekers>[,<gun>]]
## --sheet renders the standard set of views (flight, perched, close-ups of the rider, launcher, harness and
## leather) into one image, for before/after comparisons; with --macros, close-ups of the seat, face, boots and
## breast ring instead; with --heads, the face and helmet; with --mounts, the weapon mounts; with --placement,
## the lines of fire. --loadout rockets,gun (left, right: rockets | seekers | gun) and --tilt <deg> set the mounts. Keys: Space next view, P pose.

const MACROS := [
	["Seat from behind", "glide", "seat", Vector3(0.2, 0.6, 1.0), 0.05],
	["Face", "glide", "head", Vector3(-0.2, -0.1, -1.0), 0.035],
	["Boots and heels", "glide", "seat", Vector3(1.0, 0.4, 0.6), 0.05],
	["Breast ring", "glide", "ring", Vector3(0.1, -1.0, -0.5), 0.06],
]
const HEADS := [
	# (anchor "face": the direction is in the rider's head frame, -Z the way the face looks; pose "rest": wings
	# spread but the rider at rest, kneeling up with goggles raised)
	["Face, goggles down", "glide", "face", Vector3(0.3, 0.12, -1.0), 0.032],
	["Face, goggles up", "rest", "face", Vector3(0.3, 0.12, -1.0), 0.032],
	["Profile", "rest", "face", Vector3(1.0, 0.05, -0.15), 0.034],
	["Helmet from behind", "rest", "face", Vector3(-0.6, 0.55, 0.85), 0.036],
]
const MOUNTS := [
	# (anchor "mount0" / "mount1": the left / right mount's trunnion)
	["Left mount, outside", "glide", "mount0", Vector3(-1.0, 0.35, -0.25), 0.05],
	["Right mount, outside", "glide", "mount1", Vector3(1.0, 0.35, -0.25), 0.05],
	["Mounts from ahead", "glide", "seat", Vector3(0.1, 0.35, -1.0), 0.09],
	["Mounts from behind, above", "glide", "seat", Vector3(0.25, 0.8, 1.0), 0.09],
	["Perched, boots on the bar", "folded", "footrest", Vector3(1.0, 0.1, 0.35), 0.05],
	["Perched, the scarf", "folded", "head", Vector3(0.8, -0.1, 0.9), 0.09],
	["Riding, hands on the grips (from ahead)", "glide", "launcher", Vector3(0.35, 0.3, -1.0), 0.028],
	["Riding, the boots", "glide", "heel", Vector3(1.0, 0.25, 0.3), 0.03],
	["Left mount close, outside above", "glide", "mount0", Vector3(-1.0, 0.7, 0.2), 0.026],
	["Left mount close, from behind", "glide", "mount0", Vector3(-0.45, 0.35, 1.0), 0.026],
]
const PLACEMENT := [
	# (with --placement: the line of fire from the drawn muzzle in red, where the combat code fires from in yellow)
	["Side", "glide", "bird", Vector3(1.0, 0.08, -0.05), 1.15],
	["Ahead and above", "glide", "bird", Vector3(0.45, 0.55, -1.0), 1.15],
]
const SHOTS := [
	# [label, pose, anchor, direction to the camera (world), distance (x L for whole-bird anchors)]
	["Flight, from behind", "glide", "bird", Vector3(0.25, 0.5, 1.0), 1.9],
	["Flight, the rider", "glide", "head", Vector3(0.75, 0.45, 0.85), 0.11],
	["Flight, the pilot's face", "glide", "head", Vector3(-0.45, 0.15, -1.0), 0.07],
	["The launcher", "glide", "launcher", Vector3(0.55, 0.55, -1.0), 0.1],
	["Harness from below", "glide", "ring", Vector3(0.35, -1.0, -0.7), 0.22],
	["Perched", "folded", "bird", Vector3(1.0, 0.15, 0.55), 1.6],
	["Perched, the rider", "folded", "head", Vector3(0.65, 0.2, 0.85), 0.12],
	["Flight, the legs", "glide", "seat", Vector3(1.0, 0.35, 0.25), 0.075],
]

var bird_id := "falcon"
var pose := "glide"
var rig: BirdRig
var tack: Tack
var cam: Camera3D
var branch: MeshInstance3D
var shot_i := 0
var _label: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if BirdProfile.IDS.has(Boot.arg_value(args, "--bird")):
		bird_id = Boot.arg_value(args, "--bird")
	if Boot.arg_value(args, "--pose") != "":
		pose = Boot.arg_value(args, "--pose")
	Game.add_environment(self)
	for c in get_children():
		if c is DirectionalLight3D:
			(c as DirectionalLight3D).directional_shadow_max_distance = 3.0
	rig = BirdRig.new()
	add_child(rig)
	rig.build(BirdProfile.by_id(bird_id))
	var pods: Array[String] = []
	for p in Boot.arg_value(args, "--loadout").split(",", false):
		pods.append(p)
	var tilt_arg := Boot.arg_value(args, "--tilt")
	tack = Tack.fit(rig, null, pods, float(tilt_arg) if tilt_arg != "" else Saddle.DEFAULT_TILT)
	var ammo := Boot.arg_value(args, "--ammo")
	if ammo != "":
		var p := ammo.split(",")
		tack.set_ammo(int(p[0]), int(p[1]), int(p[2]) if p.size() > 2 else -1)
	branch = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = 1.2
	branch.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.35, 0.28, 0.2)
	bm.roughness = 0.9
	branch.material_override = bm
	branch.rotation_degrees = Vector3(0, 0, 90)
	add_child(branch)
	cam = Camera3D.new()
	cam.near = 0.003
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	add_child(_label)
	_apply_pose()
	if args.has("--placement"):
		_placement_markers()
	_frame(["", pose, "bird", Vector3(0.6, 0.45, 0.9), 1.9])
	var sheet := Boot.arg_value(args, "--sheet")
	if sheet != "":
		await _sheet(sheet, Boot.arg_value(args, "--label"), MACROS if args.has("--macros") else (HEADS if args.has("--heads") else (PLACEMENT if args.has("--placement") else (MOUNTS if args.has("--mounts") else SHOTS))))
		get_tree().quit()
		return
	var shot := Boot.arg_value(args, "--shot")
	if shot != "":
		var after := Boot.arg_value(args, "--shot-after")
		await get_tree().create_timer(float(after) if after != "" else 1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("screenshot: ", shot)
		get_tree().quit()


func _apply_pose() -> void:
	RigPoses.apply(rig, "glide" if pose == "rest" else pose, 0.0)
	tack.sitting = pose == "folded" or pose == "rest"
	tack.wind = Vector3(0, 0, 12.0) if pose == "glide" or pose == "flap" or pose == "upstroke" else Vector3.ZERO
	tack.update(0.0)
	branch.visible = pose == "folded"
	var L := rig.body.L
	branch.position = Vector3(0, -L * 0.35 - 0.018 + rig.position.y, 0)


## The line of fire from the drawn launcher's muzzle (red, along the rig's nose) and the point the combat
## code fires from (Launcher.muzzle: 0.6 L ahead of the bird's middle, 0.1 L up; yellow), in rig space.
func _placement_markers() -> void:
	var L := BirdProfile.by_id(bird_id).body_length
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for kind in Saddle.POD_KINDS:
		for i in (tack.saddle.round_order[kind] as Array).size():
			var m := tack.saddle.round_muzzle(kind, i) * tack.saddle.scale.x
			im.surface_set_color(Color(0.9, 0.1, 0.1))
			im.surface_add_vertex(m)
			im.surface_set_color(Color(0.9, 0.1, 0.1))
			im.surface_add_vertex(m + Vector3.FORWARD * L)
	var c := Vector3(0.0, 0.1 * L, -0.6 * L)
	for ax in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		im.surface_set_color(Color(1.0, 0.85, 0.0))
		im.surface_add_vertex(c - ax * 0.02)
		im.surface_set_color(Color(1.0, 0.85, 0.0))
		im.surface_add_vertex(c + ax * 0.02)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	rig.add_child(mi)


## Point the camera: [label, pose, anchor, direction, distance].
func _frame(s: Array) -> void:
	var anchor := Vector3.ZERO
	var L := rig.body.L
	var dist: float = s[4]
	match String(s[2]):
		"bird":
			anchor = rig.global_position
			dist *= L
		"head":
			anchor = tack.rider.to_global(tack.rider.joints.head)
		"face":
			var hd := tack.rider.get_node("head") as Node3D
			anchor = hd.global_position
			var dir := (hd.global_basis * (s[3] as Vector3)).normalized()
			cam.look_at_from_position(anchor + dir * dist, anchor, hd.global_basis.y.normalized())
			_label.text = s[0]
			return
		"seat":
			anchor = tack.saddle.to_global(tack.saddle.seat_point)
		"launcher":
			anchor = tack.saddle.to_global(tack.saddle.launcher_xf.origin.lerp(tack.saddle.muzzle, 0.45))
		"grip":
			anchor = tack.saddle.to_global(tack.saddle.grips[1])
		"heel":
			anchor = tack.rider.to_global(tack.rider.joints.ankle1)
		"footrest":
			anchor = tack.saddle.to_global((tack.saddle.pegs[0] + tack.saddle.pegs[1]) * 0.5)
		"mount0", "mount1":
			anchor = tack.saddle.to_global((tack.saddle.mounts[int(String(s[2]).right(1))].pivot as Transform3D) * (Vector3(0.0, 0.0, -25.0) / tack.saddle.cm))
		"ring":
			var z := -0.11 * L
			anchor = tack.saddle.to_global(tack.saddle.surf.point(z, tack.saddle.surf.half_girth(z)))
	var d: Vector3 = (s[3] as Vector3).normalized()
	cam.look_at_from_position(anchor + d * dist, anchor, Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD)
	_label.text = s[0]


func _sheet(path: String, title: String, shots: Array) -> void:
	var cell := Vector2i(800, 450)
	get_window().size = Vector2i(1600, 900)
	var img := Image.create(cell.x * 2, cell.y * (shots.size() / 2) + (40 if title != "" else 0), false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.95, 0.93))
	var top := 40 if title != "" else 0
	for i in shots.size():
		var s: Array = shots[i]
		pose = s[1]
		_apply_pose()
		_frame(s)
		for f in 6:
			tack.update(1.0 / 60.0)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(shot, Rect2i(Vector2i.ZERO, cell), Vector2i((i % 2) * cell.x, top + (i / 2) * cell.y))
	if title != "":
		_label.text = title
		_label.position = Vector2(16, 6)
		# (the title row: a strip of the last frame's label, rendered on a plain background)
		var strip := Image.create(cell.x * 2, top, false, Image.FORMAT_RGB8)
		strip.fill(Color(0.95, 0.95, 0.93))
		img.blit_rect(strip, Rect2i(0, 0, cell.x * 2, top), Vector2i.ZERO)
	img.save_png(path)
	print("sheet: ", path)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		if (e as InputEventKey).keycode == KEY_SPACE:
			shot_i = (shot_i + 1) % SHOTS.size()
			pose = SHOTS[shot_i][1]
			_apply_pose()
			_frame(SHOTS[shot_i])
		elif (e as InputEventKey).keycode == KEY_P:
			pose = "folded" if pose != "folded" else "glide"
			_apply_pose()


func _process(dt: float) -> void:
	tack.update(dt)
