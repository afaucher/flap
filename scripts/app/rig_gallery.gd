extends Node3D
## Dev scene: every species' rig side by side, for looking at the model.
##   .\run.ps1 --scene res://scenes/rig_gallery.tscn [--pose glide|flap|folded|flare|upstroke] [--view top|front|three|under|side|wing|lead|head|profile]
##       [--only <bird id>] [--sun front|back] [--time <s>] [--feather-shader] [--plumage 0..6] [--chart] [--relief <x>] [--variety <x>]
##       [--zoom <x>] [--ortho] [--light studio|flat] [--no-cards] [--no-down] [--legs detail|capsules] [--branch]
##       [--shot <png> --shot-after <s>] [--measure <frames>]
## --only frames one bird close up; --sun back lights it from behind (feather translucency); --time freezes the
## clock (feather flutter) for repeatable screenshots. --measure prints the mean GPU render time and pose time over that many
## frames (after a warm-up) and quits: the plumage levels' cost (docs/research/feather_texture_study.md).
## glide (default) holds the wings spread; flap animates a wingbeat; folded is the perched pose with feet
## gripping; flare is the landing pose (wings forward, alula out, tail fanned down, feet reaching).
## --legs detail draws the detailed legs and feet (LegRig; docs/design/legs_and_feet.md); --view feet frames them
## close up from the front quarter; --branch draws the branch the folded pose grips; --ortho an orthographic camera.

var rigs: Array[BirdRig] = []
var pose := "glide"
var t := 0.0
var frozen := false
var measure := 0
var _frames := 0
var _gpu_ms := 0.0
var _pose_us := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var p := Boot.arg_value(args, "--pose")
	if p != "":
		pose = p
	var view := Boot.arg_value(args, "--view")
	var only := Boot.arg_value(args, "--only")
	BirdRig.plain_feathers = not args.has("--feather-shader")
	BirdRig.flat_perch = args.has("--flat-perch")
	BirdRig.silhouette_cards = not args.has("--no-cards")
	BirdRig.outline_down = not args.has("--no-down")
	if Boot.arg_value(args, "--legs") != "":
		LegRig.enabled = Boot.arg_value(args, "--legs") == "detail"
	if Boot.arg_value(args, "--plumage") != "":
		Plumage.level = int(Boot.arg_value(args, "--plumage"))
	var sun_arg := Boot.arg_value(args, "--sun")
	var time_arg := Boot.arg_value(args, "--time")
	if time_arg != "":
		t = float(time_arg)
		frozen = true
	# (--light flat: the old look, one ambient colour and no shadows)
	Lighting.studio(self, Boot.arg_value(args, "--light") if Boot.arg_value(args, "--light") != "" else "studio", sun_arg == "back")
	var x := 0.0
	var profiles := BirdProfile.all()
	if only != "":
		profiles = [BirdProfile.by_id(only)]
	for i in profiles.size():
		var pr: BirdProfile = profiles[i]
		var r := BirdRig.new()
		add_child(r)
		r.build(pr)
		if args.has("--chart") and r.body_texture_material != null:   # (level 6: the body's feather chart as a grid)
			r.body_texture_material.set_shader_parameter("show_chart", true)
		for knob in ["relief", "variety"]:   # (level 6 tuning: the texture's relief and variation, body and feathers)
			if Boot.arg_value(args, "--" + knob) != "" and r.body_texture_material != null:
				r.body_texture_material.set_shader_parameter(knob, float(Boot.arg_value(args, "--" + knob)))
				r.marks_material.set_shader_parameter(knob, float(Boot.arg_value(args, "--" + knob)))
		x += pr.span * 0.5 + (0.15 if i > 0 else 0.0)
		r.position = Vector3(x, 0, 0)
		x += pr.span * 0.5
		rigs.append(r)
		var label := Label3D.new()
		label.text = pr.display_name
		label.font_size = 48
		label.pixel_size = 0.002
		label.position = Vector3(x - pr.span * 0.5, -0.05, 0.45)
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.modulate = Color(0.15, 0.17, 0.17)
		label.visible = only == ""
		add_child(label)
	var cam := Camera3D.new()
	add_child(cam)
	var mid := Vector3(x * 0.5, 0, 0)
	var k := 1.0 if only == "" else profiles[0].span * 0.36   # close-up: frame one bird
	if Boot.arg_value(args, "--zoom") != "":   # (closer: the camera at 1 / zoom the distance)
		k /= float(Boot.arg_value(args, "--zoom"))
	match view:
		"front":
			cam.look_at_from_position(mid + Vector3(0, 0.15, -3.2) * k, mid, Vector3.UP)
		"three":
			cam.look_at_from_position(mid + Vector3(0.6, 1.6, -2.4) * k, mid, Vector3.UP)
		"side":
			cam.look_at_from_position(mid + Vector3(2.6, 0.35, 0.0) * k, mid, Vector3.UP)
		"under":
			cam.look_at_from_position(mid + Vector3(0.3, -1.4, -1.6) * k, mid, Vector3.UP)
		"wing":   # close on the right arm wing from ahead and a little above: leading edge, thickness
			var w := mid + Vector3(profiles[0].span * 0.17, 0, 0)
			cam.look_at_from_position(w + Vector3(0.12, 0.35, -0.9) * profiles[0].span * 0.3, w, Vector3.UP)
		"lead":   # low and straight ahead of the right arm wing: the leading edge's thickness and taper
			var w := mid + Vector3(profiles[0].span * 0.17, 0, 0)
			cam.look_at_from_position(w + Vector3(0.0, 0.04, -1.0) * profiles[0].span * 0.35, w, Vector3.UP)
		_:
			cam.look_at_from_position(mid + Vector3(0, 3.0, 0.05) * k, mid, Vector3.FORWARD)
	cam.fov = 50.0
	cam.current = true
	_pose_all(0.0)
	if args.has("--branch") and pose == "folded":   # (the branch under the folded pose's grip point, across the bird)
		for r in rigs:
			var branch := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = r._L * 0.045
			cyl.bottom_radius = r._L * 0.045
			cyl.height = r._L * 0.6
			branch.mesh = cyl
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color(0.36, 0.3, 0.24)
			bm.roughness = 0.95
			branch.material_override = bm
			branch.rotation_degrees = Vector3(0, 0, 90)
			branch.position = r.position + Vector3(0.0, -r._L * 0.35 - r._L * 0.045, 0.0)
			add_child(branch)
	var focus := mid
	if view == "feet":   # close on the feet, from the front quarter and a little below the belly
		var f := rigs[0].to_global((rigs[0].leg_joints[1][3] as Vector3).lerp(rigs[0].leg_joints[0][3], 0.5))
		var at := f + Vector3(0.0, profiles[0].body_length * 0.08, 0.0)
		focus = at
		cam.near = 0.002
		cam.look_at_from_position(at + Vector3(0.9, 0.35, -0.75).normalized() * profiles[0].body_length * 0.75 / (float(Boot.arg_value(args, "--zoom")) if Boot.arg_value(args, "--zoom") != "" else 1.0), at, Vector3.UP)
	if view == "head" or view == "profile":   # close on the face: three-quarter front, or side on
		var h := rigs[0].to_global(rigs[0]._head_pos)
		var off := Vector3(0.45, 0.15, -1.0) if view == "head" else Vector3(1.0, 0.05, -0.05)
		cam.look_at_from_position(h + off.normalized() * profiles[0].body_length * 0.75, h, Vector3.UP)
	if args.has("--ortho"):   # (no perspective: the true silhouette, for checking outlines; same framing, so A/B sheets line up)
		var dist := cam.global_position.distance_to(focus)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 2.0 * dist * tan(deg_to_rad(cam.fov * 0.5))
		cam.global_position = focus + (cam.global_position - focus) * 4.0   # (further back: close-ups clear the near plane)
		cam.near = dist * 2.0   # (an orthographic depth buffer is linear: keep its range tight, or layers a fraction of a mm
		cam.far = dist * 6.0    # apart fight)
	var shot := Boot.arg_value(args, "--shot")
	if shot != "":
		var after := Boot.arg_value(args, "--shot-after")
		await get_tree().create_timer(float(after) if after != "" else 1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("screenshot: ", shot)
		get_tree().quit()
	measure = int(Boot.arg_value(args, "--measure")) if Boot.arg_value(args, "--measure") != "" else 0
	if measure > 0:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(dt: float) -> void:
	if not frozen:
		t += dt
	var t0 := Time.get_ticks_usec()
	_pose_all(t)
	for r in rigs:
		r.set_clock(t)
	if measure > 0:
		_frames += 1
		if _frames > 60:   # (warm-up: shader compiles, first uploads)
			_pose_us += Time.get_ticks_usec() - t0
			_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		if _frames == 60 + measure:
			print("measure: plumage %d, %d rigs, %d frames: GPU %.3f ms/frame, pose %.3f ms/frame" % [Plumage.level, rigs.size(), measure, _gpu_ms / measure, _pose_us / 1000.0 / measure])
			get_tree().quit()


func _pose_all(time: float) -> void:
	for r in rigs:
		RigPoses.apply(r, pose, time)
