class_name Game
extends Node3D
## The flight demo: one generated arena, the player's bird on the tallest treetop by the clearing, a chase
## camera and the HUD. Optional AI birds fly perch to perch around it. Command-line options (after `--`):
##   --bird <id>        crow | owl | hawk | falcon | sparrow (default crow)
##   --seed <n>         arena seed (default 7)
##   --sdr              no HDR display output (default: HDR where the display offers it; F4 toggles)
##   --forest greybox   the old grey test arena (default: the pine wood, Pinewood, in ForestLight)
##   --ai <n>           AI birds flying around (default 3)
##   --autopilot        the player's bird flies itself (P toggles in game)
##   --legs <kind>      detail (default) | capsules: the legs drawn
##   --max-steps <n>    physics ticks a frame may run to catch up (the project sets 3; Godot's default is 8)
##   --rig-tick         pose the rigs on the physics tick, not every rendered frame (Bird.rig_in_process; for comparison)
##   --cpu-feathers     place the feathers in GDScript, not the shader (BirdRig.gpu_feathers off; for comparison)
##   --cpu-body         build the neck, arm wings and trousers in GDScript, not the shader (BirdRig.gpu_body off)
##   --shot <png>       save a screenshot after --shot-after seconds (default 3) and quit
##   --shot-after <s>
##   --perf <s>         profile that many seconds of play (after a warm-up), write --perf-out <path>.csv/.txt, quit
##   --no-rider         no war tack on any bird (the menu's Flight)
##   --no-far-blur      no softening of the far wood (ForestLight.far_blur; F5 toggles in game)
##   --look <name>      the pine wood's look: afternoon (default) | golden | misty_morning | overcast (ForestLight.LOOKS;
##                      F6 steps through them in game)
##   --hud <style>      classic (default) | ring | dev: the HUD's layout (FlightHud.style)

var layout: ArenaLayout
var arena: ArenaBuilder
var bird: Bird
var camera: ChaseCamera
var hud: FlightHud
var audio: GameAudio
var player := PlayerController.new()
var autopilot: AIPilot
var ai_birds: Array[Bird] = []
var profile_id := "crow"
var use_autopilot := false
var rider := true            ## crows, falcons and hawks carry the war tack (--no-rider: none)


func _ready() -> void:
	var args := Boot.args()
	var bid := Boot.arg_value(args, "--bird")
	if BirdProfile.IDS.has(bid):
		profile_id = bid
	var seed_arg := Boot.arg_value(args, "--seed")
	var arena_seed := int(seed_arg) if seed_arg != "" else 7
	var ai_arg := Boot.arg_value(args, "--ai")
	var ai_count := int(ai_arg) if ai_arg != "" else 3
	use_autopilot = args.has("--autopilot")
	rider = not args.has("--no-rider")
	if args.has("--no-far-blur"):
		ForestLight.far_blur = false
	if FlightHud.STYLES.has(Boot.arg_value(args, "--hud")):
		FlightHud.style = Boot.arg_value(args, "--hud")
	if args.has("--cpu-feathers"):
		BirdRig.gpu_feathers = false
	if args.has("--cpu-body"):
		BirdRig.gpu_body = false
	if args.has("--rig-tick"):
		Bird.rig_in_process = false
	if Boot.arg_value(args, "--max-steps") != "":   # (catch-up physics ticks a frame may run; project.godot sets 3)
		Engine.max_physics_steps_per_frame = int(Boot.arg_value(args, "--max-steps"))
	if Boot.arg_value(args, "--legs") != "":
		LegRig.enabled = Boot.arg_value(args, "--legs") == "detail"

	var pinewood := Boot.arg_value(args, "--forest") != "greybox"   # (the pine wood in its own light; --forest greybox: the old test arena)
	if pinewood:
		ForestLight.setup(self)
	else:
		_environment()
	layout = Pinewood.generate(arena_seed) if pinewood else ArenaLayout.generate(arena_seed)
	HdrOutput.add(self)
	arena = ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	autopilot = AIPilot.new(layout, arena_seed + 100)

	camera = ChaseCamera.new()
	camera.current = true
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = FlightHud.new()
	layer.add_child(hud)
	audio = GameAudio.new()
	add_child(audio)
	_spawn_player(profile_id, layout.start_perch())

	for i in ai_count:
		var pid: String = BirdProfile.IDS[(i + 1) % BirdProfile.IDS.size()]
		var b := Bird.new()
		b.name = "AI%d" % i
		var pilot := AIPilot.new(layout, arena_seed * 31 + i)
		add_child(b)
		b.setup(BirdProfile.by_id(pid), layout, pilot)
		b.arena = arena
		if rider and Tack.RIDDEN.has(pid):
			Tack.fit(b.rig, b)
		b.perch_at(layout.perches[(i * 97 + 13) % layout.perches.size()])
		audio.watch(b)
		ai_birds.append(b)

	var perf := Boot.arg_value(args, "--perf")
	if perf != "":   # (profile `perf` seconds of play, write the report and quit: .\perf.ps1)
		var rec := Perf.new()
		rec.seconds = float(perf)
		if Boot.arg_value(args, "--perf-out") != "":
			rec.out = Boot.arg_value(args, "--perf-out")
		add_child(rec)

	var shot := Boot.arg_value(args, "--shot")
	if shot != "":
		var after_arg := Boot.arg_value(args, "--shot-after")
		_screenshot(shot, float(after_arg) if after_arg != "" else 3.0)


func _environment() -> void:
	add_environment(self)


## The sky, fog, ambient light and sun (also used by the bird lab).
static func add_environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.45, 0.6, 0.8)
	sky_mat.sky_horizon_color = Color(0.78, 0.82, 0.85)
	sky_mat.ground_horizon_color = Color(0.78, 0.82, 0.85)   # = the fog, so the ground's far edge melts away
	sky_mat.ground_bottom_color = Color(0.5, 0.53, 0.48)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Lighting.bird_occlusion(env, 1.0, 0.25)   # (the bird a few metres off: rows and the wing root)
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.82, 0.85)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	Lighting.bird_shadows(sun, 120.0, 5.0)   # (the first cascade holds the bird the chase camera follows)
	parent.add_child(sun)


func _spawn_player(pid: String, at: Perch) -> void:
	if bird != null:
		bird.queue_free()
	profile_id = pid
	bird = Bird.new()
	bird.name = "Player"
	add_child(bird)
	bird.setup(BirdProfile.by_id(pid), layout, autopilot if use_autopilot else player)
	bird.arena = arena
	if rider and Tack.RIDDEN.has(pid):
		Tack.fit(bird.rig, bird)   # (crows, falcons and hawks carry a rider and the war tack)
	bird.perch_at(at)
	audio.player = bird
	audio.watch(bird)
	camera.bird = bird
	camera.snap()
	hud.autopilot = use_autopilot


func _physics_process(_dt: float) -> void:
	if bird == null:
		return
	var p0 := Perf.t()
	var mark := bird.candidate if FlightHud.show_perch(bird.last_input.catch_held) else null
	arena.show_candidate(mark, bird.candidate_too_fast(), bird.profile.grab_radius, bird.candidate_grip)
	Perf.add("game.candidate", p0)


func _process(_dt: float) -> void:
	if bird != null:
		var p0 := Perf.t()
		var t := bird.telemetry()
		hud.gamepad = player.using_gamepad
		hud.set_state(t)
		audio.set_state(t)
		Perf.add("game.hud_audio", p0)
	camera.look_input = player.look


func _unhandled_input(e: InputEvent) -> void:
	player.handle_event(e)
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F6:
		print("look: ", ForestLight.next_look(self))
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F5:
		ForestLight.toggle_far_blur(self)
	if e.is_action_pressed("toggle_debug"):
		hud.debug = not hud.debug
	if e.is_action_pressed("toggle_autopilot"):
		use_autopilot = not use_autopilot
		bird.controller = autopilot if use_autopilot else player
		hud.autopilot = use_autopilot
	if e.is_action_pressed("respawn"):
		_spawn_player(profile_id, bird.perch if bird.perch != null else layout.start_perch())
	if e.is_action_pressed("cycle_bird"):
		var next: String = BirdProfile.IDS[(BirdProfile.IDS.find(profile_id) + 1) % BirdProfile.IDS.size()]
		_spawn_player(next, bird.perch if bird.perch != null else layout.start_perch())
	for i in BirdProfile.IDS.size():
		if e.is_action_pressed("bird_%d" % (i + 1)):
			_spawn_player(BirdProfile.IDS[i], bird.perch if bird.perch != null else layout.start_perch())


func _screenshot(path: String, after: float) -> void:
	await get_tree().create_timer(after).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("screenshot: ", path)
	get_tree().quit()
