extends TestCase
## Diagnostic (windowed: `.\run.ps1 --run-test probe_gun_view [--out <png>]`): a crow with two gun pods fires a held
## burst past a target crow; three views a moment in -- beside the shooter, the chase camera's, and the target's
## side -- to look at the tracers, the muzzle flashes and the strikes.


class _Hold:
	func sample(_l: Launcher, _dt: float) -> CombatInput:
		return CombatInput.new(false, true, false)


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var out := Boot.arg_value(OS.get_cmdline_user_args(), "--out")
	if out == "":
		out = OS.get_user_data_dir() + "/probe_gun_view.png"
	Game.add_environment(self)
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	world.layout = layout
	add_child(world)
	var a := Bird.new()
	add_child(a)
	a.setup(BirdProfile.crow(), layout, null)
	a.fly_from(Vector3(0, 30, 0), Vector3(0, 0, -1), 9.0)
	var l := world.add_bird(a, null)
	var pods: Array[String] = ["gun", "gun"]
	l.set_tack(Tack.fit(a.rig, a, pods))
	var t := Bird.new()
	add_child(t)
	t.setup(BirdProfile.crow(), layout, null)
	world.add_bird(t, null)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 60.0
	get_window().size = Vector2i(1280, 720)
	var views := [Vector3(2.5, 0.6, 1.0), Vector3(0.0, 0.7, 3.2), Vector3(3.0, 0.5, -12.0)]
	var shots := []
	for v in views:
		a.fly_from(Vector3(0, 30, 0), Vector3(0, 0, -1), 9.0)
		l.ammo = l.capacity.duplicate()
		l.controller = _Hold.new()
		for f in 24:
			t.fly_from(a.global_position + a.model.flight_dir() * 18.0 + Vector3(0.15, 0, 0), a.model.flight_dir(), 9.0)
			cam.look_at_from_position(a.global_position + v, a.global_position + Vector3(0, 0, -9.0))
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		shots.append(get_viewport().get_texture().get_image())
		l.controller = null
	var img := Image.create(1280, 720 * shots.size(), false, Image.FORMAT_RGB8)
	for i in shots.size():
		var s: Image = shots[i]
		s.convert(Image.FORMAT_RGB8)
		s.resize(1280, 720)
		img.blit_rect(s, Rect2i(0, 0, 1280, 720), Vector2i(0, 720 * i))
	img.save_png(out)
	print("probe_gun_view: ", out, "  shots ", l.shots, "  hits ", world.hits.get(t, 0))
	finish()
