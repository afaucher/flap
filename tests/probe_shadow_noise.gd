extends TestCase
## The menu's outpost close up (a bird on the rail, the deck in and out of shadow) under switches, to find where
## speckle comes from: the soft sun (--ang 0: hard), the shadow filter, TAA, SSAO, volumetric fog. (2026-11-03: none
## of the shadow / SSAO / fog switches changed it; TAA halved it; the wood's relief made the deck's.) Windowed:
##   Godot --path . -- --run-test probe_shadow_noise --out <png> [--ang <deg>] [--filter <0-5>] [--taa] [--blur <x>] [--no-ssao] [--no-vfog] [--ssao-q <0-3>]


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	if Boot.arg_value(args, "--filter") != "":
		RenderingServer.directional_soft_shadow_filter_set_quality(int(Boot.arg_value(args, "--filter")))
		RenderingServer.positional_soft_shadow_filter_set_quality(int(Boot.arg_value(args, "--filter")))
	if args.has("--taa"):
		get_viewport().use_taa = true
	var bd := MenuBackdrop.new()
	add_child(bd)
	await frames(2)
	if Boot.arg_value(args, "--ang") != "":
		bd.sun.light_angular_distance = float(Boot.arg_value(args, "--ang"))
	for c in bd.get_children():
		if c is WorldEnvironment:
			var env: Environment = c.environment
			if args.has("--no-ssao"):
				env.ssao_enabled = false
			if args.has("--no-vfog"):
				env.volumetric_fog_enabled = false
			if args.has("--no-ssil"):
				env.ssil_enabled = false
			if Boot.arg_value(args, "--ssao-q") != "":
				RenderingServer.environment_set_ssao_quality(int(Boot.arg_value(args, "--ssao-q")), false, 0.5, 2, 50.0, 300.0)
	if Boot.arg_value(args, "--blur") != "":
		bd.sun.shadow_blur = float(Boot.arg_value(args, "--blur"))
	bd.cam.position = bd.rigs[2].global_position + Vector3(-0.35, 0.12, 0.55)
	bd.cam.look_at(bd.rigs[2].global_position + Vector3(0.1, -0.05, 0.0))
	await frames(30)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Boot.arg_value(args, "--out"))
	finish()
