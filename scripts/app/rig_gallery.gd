extends Node3D
## Dev scene: every species' rig side by side, for looking at the model.
##   .\run.ps1 --scene res://scenes/rig_gallery.tscn [--pose glide|flap|folded|flare|upstroke] [--view top|front|three|under|side]
##       [--only <bird id>] [--sun front|back] [--time <s>] [--feather-shader] [--shot <png> --shot-after <s>]
## --only frames one bird close up; --sun back lights it from behind (feather translucency); --time freezes the
## clock (feather flutter) for repeatable screenshots.
## glide (default) holds the wings spread; flap animates a wingbeat; folded is the perched pose with feet
## gripping; flare is the landing pose (wings forward, alula out, tail fanned down, feet reaching).

var rigs: Array[BirdRig] = []
var pose := "glide"
var t := 0.0
var frozen := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var p := Boot.arg_value(args, "--pose")
	if p != "":
		pose = p
	var view := Boot.arg_value(args, "--view")
	var only := Boot.arg_value(args, "--only")
	BirdRig.plain_feathers = not args.has("--feather-shader")
	BirdRig.flat_perch = args.has("--flat-perch")
	var sun_arg := Boot.arg_value(args, "--sun")
	var time_arg := Boot.arg_value(args, "--time")
	if time_arg != "":
		t = float(time_arg)
		frozen = true
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.85, 0.83)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.8)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	# Back: low sun behind the bird, shining toward the camera (feather translucency).
	sun.rotation_degrees = Vector3(-60, -30, 0) if sun_arg != "back" else Vector3(-25, 10, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var x := 0.0
	var profiles := BirdProfile.all()
	if only != "":
		profiles = [BirdProfile.by_id(only)]
	for i in profiles.size():
		var pr: BirdProfile = profiles[i]
		var r := BirdRig.new()
		add_child(r)
		r.build(pr)
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
	match view:
		"front":
			cam.look_at_from_position(mid + Vector3(0, 0.15, -3.2) * k, mid, Vector3.UP)
		"three":
			cam.look_at_from_position(mid + Vector3(0.6, 1.6, -2.4) * k, mid, Vector3.UP)
		"side":
			cam.look_at_from_position(mid + Vector3(2.6, 0.35, 0.0) * k, mid, Vector3.UP)
		"under":
			cam.look_at_from_position(mid + Vector3(0.3, -1.4, -1.6) * k, mid, Vector3.UP)
		_:
			cam.look_at_from_position(mid + Vector3(0, 3.0, 0.05) * k, mid, Vector3.FORWARD)
	cam.fov = 50.0
	cam.current = true
	_pose_all(0.0)
	var shot := Boot.arg_value(args, "--shot")
	if shot != "":
		var after := Boot.arg_value(args, "--shot-after")
		await get_tree().create_timer(float(after) if after != "" else 1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("screenshot: ", shot)
		get_tree().quit()


func _process(dt: float) -> void:
	if not frozen:
		t += dt
	_pose_all(t)
	for r in rigs:
		r.set_clock(t)


func _pose_all(time: float) -> void:
	for r in rigs:
		r.fold = 0.0
		r.sweep = 0.0
		r.twist = 0.0
		r.alula = 0.0
		r.slot = 0.3
		r.hand_lift = 0.0
		r.flap = deg_to_rad(5.0)
		r.tail_spread = 0.3
		r.tail_pitch = 0.0
		r.toe_grip = 0.0
		for i in 2:
			r.foot_targets[i] = r._tucked_foot(i)
		match pose:
			"flap", "upstroke":
				var ph := fmod(time * 2.0, 1.0) if pose == "flap" else 0.75
				r.flap = deg_to_rad(10.0 + 45.0 * cos(ph * TAU))
				r.hand_lift = 50.0 * sin((ph - 0.5) * TAU) if ph > 0.5 else 0.0
			"folded":
				# Perched: the species' posture, tail at its angle, feet gripping a branch under the body.
				var pose: Dictionary = BirdRig.POSE.get(r.profile.id, BirdRig.POSE["crow"])
				r.rotation_degrees.x = 0.0 if BirdRig.flat_perch else float(pose.perch_pitch)
				r.fold = 1.0
				r.flap = deg_to_rad(-10.0)
				r.slot = 0.0
				r.tail_spread = 0.0
				r.tail_pitch = deg_to_rad(float(pose.tail_down)) if not BirdRig.flat_perch else 0.15
				r.toe_grip = 1.0
				for i in 2:
					var grip_world := r.position + Vector3(BirdRig.SIDES[i] * r._L * 0.04, -r._L * 0.35, 0.0)
					r.foot_targets[i] = r.transform.affine_inverse() * grip_world
			"flare":
				r.flap = deg_to_rad(25.0)
				r.sweep = 12.0
				r.twist = deg_to_rad(30.0)
				r.alula = 1.0
				r.slot = 1.0
				r.tail_spread = 1.0
				r.tail_pitch = 0.6
				for i in 2:
					r.foot_targets[i] = r._hip[i] + Vector3(0.0, -r._L * 0.22, -r._L * 0.16)
		r.look_dir = Vector3(0, -0.2, -1).normalized()
		r.apply_pose()
