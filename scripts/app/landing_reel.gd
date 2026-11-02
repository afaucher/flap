extends Node3D
## Dev scene: a bird flies into a branch perch (catch held) on a fixed setup, filmed side-on, saving a frame
## every few ticks: for looking at, and A/B-ing, the landing.
##   Godot --fixed-fps 60 --path . -- --scene res://scenes/landing_reel.tscn --out <dir> [--prefix before]
##       [--bird crow] [--frames 12] [--every 5] [--speed 0.95] [--from front|below|above]
## --speed is the arrival speed as a share of the bird's catch speed; --from picks the approach.

var bird: Bird
var ctl := ScriptedInput.new()
var perch: Perch
var out_dir := ""
var prefix := "frame"
var frames := 12
var every := 5
var tick := 0
var saved := 0
var started := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = Boot.arg_value(args, "--out")
	if Boot.arg_value(args, "--prefix") != "":
		prefix = Boot.arg_value(args, "--prefix")
	if Boot.arg_value(args, "--frames") != "":
		frames = int(Boot.arg_value(args, "--frames"))
	if Boot.arg_value(args, "--every") != "":
		every = int(Boot.arg_value(args, "--every"))
	var bid := Boot.arg_value(args, "--bird")
	var speed_k := float(Boot.arg_value(args, "--speed")) if Boot.arg_value(args, "--speed") != "" else 0.95
	var from := Boot.arg_value(args, "--from")

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
	sun.rotation_degrees = Vector3(-55, -30, 0)
	add_child(sun)

	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	# A canopy branch with room around it.
	for p in layout.perches:
		if p.kind == Perch.Kind.BRANCH and p.position.y > 8.0 and p.position.y < 14.0 and p.a.distance_to(p.b) > 1.2:
			perch = p
			break
	var p := BirdProfile.by_id(bid if bid != "" else "crow")
	bird = Bird.new()
	add_child(bird)
	bird.setup(p, layout, ctl)
	bird.arena = arena
	bird.perch_assist = 0.6
	var target := perch.a.lerp(perch.b, 0.6)
	var back := perch.facing * 3.2
	var start := target + back + Vector3.UP * (0.0 if from == "" or from == "front" else (-0.8 if from == "below" else 0.8))
	bird.fly_from(start, (target - start).normalized(), p.grab_speed_max * speed_k)
	ctl.catch_hold = true
	# Side-on camera, perpendicular to the approach, framing the last few metres.
	# (Out past the branch tip, so the tree is behind the bird rather than in front of the camera.)
	var side := Vector3(perch.b.x - perch.a.x, 0.0, perch.b.z - perch.a.z).normalized()
	var cam := Camera3D.new()
	add_child(cam)
	var mid := target + perch.facing * 1.4
	# The first roughly side-on viewpoint with a clear line of sight (other trees may stand in the way).
	var eye := mid + side * 3.4 + Vector3.UP * 0.4
	for yaw in [0.0, 180.0, 30.0, -30.0, 150.0, -150.0, 60.0, -60.0]:
		var cand: Vector3 = mid + side.rotated(Vector3.UP, deg_to_rad(yaw)) * 3.4 + Vector3.UP * 0.4
		if layout.segment_clear(cand, mid, 0.3, perch.tree_id) and layout.segment_clear(cand, target, 0.3, perch.tree_id):
			eye = cand
			break
	cam.look_at_from_position(eye, mid, Vector3.UP)
	cam.fov = 45.0
	cam.current = true
	started = true


func _physics_process(_dt: float) -> void:
	if not started:
		return
	tick += 1
	if tick % every == 0 and saved < frames:
		saved += 1
		_save(saved)
	if saved >= frames and tick % every == 0:
		await RenderingServer.frame_post_draw
		get_tree().quit()


func _save(n: int) -> void:
	await RenderingServer.frame_post_draw
	if out_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [out_dir, prefix, n])
	print("frame %d state %d speed %.2f" % [n, bird.state, bird.model.velocity.length()])
