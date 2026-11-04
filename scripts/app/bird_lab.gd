extends Node3D
## The bird lab: one tree, one branch, one bird, for looking at how the bird moves. Pick a species and a
## scenario -- a static pose, a take-off, or a landing from one of several approaches (LabScenarios) -- slow
## it down, pause and step it, orbit the camera, and leave onion-skin ghosts along the way to compare how
## the body, wings, tail and legs adjust. Live scenarios are the real game: Bird, FlightModel, perch logic and
## rig, flown by a LabPilot through the player's controls.
##   .\run.ps1 --scene res://scenes/bird_lab.tscn [--bird <id>] [--scenario <id>] [--speed <0.05..1>] [--onion]
##       [--view side|front|three|top|chase] [--dist <m>] [--pause-at <sim s>] [--bones | --bones-only]
##       [--shot <png> --shot-after <real s>] [--no-rider]
## Keys: 1-5 bird, Up/Down scenario, Space pause, . step, R restart, -/= speed, O onion skin, F follow,
##       V next view, T trail, B bones (off / over the bird / bones only), K rider; drag to orbit, wheel to zoom.
## Crows, falcons and hawks carry their war tack and rider (Tack), as in the game.
## Bones (BoneView): every bone and joint of the rig as it was solved, drawn on top -- the shoulder, elbow,
## wrist, hip, knee, ankle, the neck's joints, head and tail, coloured by chain.

const VIEWS := {
	"side": Vector3(1.0, 0.15, -0.35),
	"front": Vector3(0.0, 0.12, 1.0),
	"three": Vector3(0.75, 0.45, 0.7),
	"top": Vector3(0.02, 1.0, 0.02),
	"chase": Vector3(0.15, 0.3, -1.0),
}
const GHOST_EVERY := 0.08   ## sim s between onion-skin snapshots
const GHOSTS := 14
const STATE_COLORS := [Color(0.25, 0.5, 0.95), Color(0.95, 0.55, 0.15), Color(0.2, 0.75, 0.35), Color(0.55, 0.55, 0.55)]
const STATE_NAMES := ["FLYING", "LANDING", "PERCHED", "GROUNDED"]
const CATCH_NAMES := ["out of reach", "IN REACH", "too fast"]

var layout: ArenaLayout
var arena: ArenaBuilder
var world: Node3D             ## everything that pauses
var cam: Camera3D
var bird: Bird
var pose_rig: BirdRig
var pilot: LabPilot
var bird_id := "crow"
var scenario: Dictionary = LabScenarios.LIST[0]
var speed := 0.5
var onion := false
var rider := true             ## the war tack and rider on species that carry them
var _tack: Tack
var follow := true
var trail_on := true
var loop := true
var override_body := false
var neck := 0.5
var fluff := 1.0
var view := "three"
var sim_t := 0.0              ## scenario time (sim seconds)
var pause_at := -1.0
var _dist_arg := -1.0
var bones := 0                ## 0 off, 1 the skeleton over the bird, 2 the skeleton only
var _bone_view: BoneView

var _yaw := 0.0
var _pitch := 0.0
var _dist := 3.0
var _focus := Vector3.ZERO
var _dragging := false
var _ghosts: Array[BirdRig] = []
var _ghost_i := 0
var _ghost_clock := 0.0
var _trail: Array = []        ## [position, state]
var _trail_mesh: ImmediateMesh
var _ended_at := -1.0
# UI
var _bird_opt: OptionButton
var _list: ItemList
var _pause_btn: Button
var _speed_slider: HSlider
var _speed_label: Label
var _readout: Label
var _onion_box: CheckBox
var _rider_box: CheckBox
var _neck_slider: HSlider
var _fluff_slider: HSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := Boot.args()
	if BirdProfile.IDS.has(Boot.arg_value(args, "--bird")):
		bird_id = Boot.arg_value(args, "--bird")
	if Boot.arg_value(args, "--scenario") != "":
		scenario = LabScenarios.by_id(Boot.arg_value(args, "--scenario"))
	if Boot.arg_value(args, "--speed") != "":
		speed = clampf(float(Boot.arg_value(args, "--speed")), 0.05, 1.0)
	if VIEWS.has(Boot.arg_value(args, "--view")):
		view = Boot.arg_value(args, "--view")
	if Boot.arg_value(args, "--pause-at") != "":
		pause_at = float(Boot.arg_value(args, "--pause-at"))
	onion = args.has("--onion")
	FlightAssist.configure(args)   # (--flying novice: the landing assist, more stamina)
	rider = not args.has("--no-rider")
	if Boot.arg_value(args, "--dist") != "":
		_dist_arg = float(Boot.arg_value(args, "--dist"))
	bones = 2 if args.has("--bones-only") else (1 if args.has("--bones") else 0)

	Game.add_environment(self)
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	layout = ArenaLayout.lab()
	arena = ArenaBuilder.new()
	world.add_child(arena)
	arena.build(layout)
	var trail := MeshInstance3D.new()
	_trail_mesh = ImmediateMesh.new()
	trail.mesh = _trail_mesh
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.vertex_color_use_as_albedo = true
	trail.material_override = tm
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	_bone_view = BoneView.new()
	add_child(_bone_view)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.current = true
	add_child(cam)
	_build_ui()
	_set_view(view)
	restart()

	var shot := Boot.arg_value(args, "--shot")
	if shot != "":
		var after := Boot.arg_value(args, "--shot-after")
		await get_tree().create_timer(float(after) if after != "" else 2.0, true, false, true).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("screenshot: ", shot)
		Engine.time_scale = 1.0
		get_tree().quit()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- Scenario ---------------------------------------------------------------------------------------

func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = speed
	sim_t = 0.0
	_ended_at = -1.0
	_trail.clear()
	_clear_ghosts()
	_tack = null
	if bird != null:
		bird.queue_free()
		bird = null
	if pose_rig != null:
		pose_rig.queue_free()
		pose_rig = null
	var p := BirdProfile.by_id(bird_id)
	if LabScenarios.is_pose(scenario):
		pose_rig = BirdRig.new()
		world.add_child(pose_rig)
		pose_rig.build(p)
		var aim := LabScenarios.aim_point(layout.perches[0])
		pose_rig.position = Perch.seat_at(aim, p) if scenario.pose == "folded" else aim + Vector3(0.0, 0.5, -1.2)
		_pose_tick()
		if Tack.RIDDEN.has(p.id):
			_tack = Tack.fit(pose_rig)
			_tack.sitting = scenario.pose == "folded"
	else:
		bird = Bird.new()
		bird.name = "LabBird"
		world.add_child(bird)
		bird.setup(p, layout, null)
		bird.arena = arena
		pilot = LabScenarios.start(scenario, bird, layout)
		if Tack.RIDDEN.has(p.id):
			_tack = Tack.fit(bird.rig, bird)
	if _tack != null and is_instance_valid(_tack):
		_tack.visible = rider
	_dist = _dist_arg if _dist_arg > 0.0 else maxf(1.2, p.span * 2.6)
	_focus = _target_point()
	_sync_ui()


func _target_point() -> Vector3:
	if pose_rig != null:
		return pose_rig.global_position
	if bird != null and follow:
		return bird.global_position
	return LabScenarios.aim_point(layout.perches[0])


func _physics_process(dt: float) -> void:
	if get_tree().paused:
		return
	sim_t += dt
	if pause_at >= 0.0 and sim_t >= pause_at:
		pause_at = -1.0
		get_tree().paused = true
	if pose_rig != null:
		_pose_tick()
		return
	if bird == null:
		return
	arena.show_candidate(bird.candidate, bird.candidate_too_fast(), bird.profile.grab_radius, bird.candidate_grip)
	if trail_on:
		_trail.append([bird.global_position, bird.state])
		if _trail.size() > 2400:
			_trail.pop_front()
	# Onion skin: a ghost of the rig every GHOST_EVERY s while something is happening.
	_ghost_clock += dt
	var active := bird.state == Bird.State.FLYING or bird.state == Bird.State.LANDING or sim_t < 1.0 or (_ended_at < 0.0 and bird.state != Bird.State.PERCHED)
	if onion and active and _ghost_clock >= GHOST_EVERY:
		_ghost_clock = 0.0
		_snapshot()
	# Loop: start over a moment after the bird has settled or flown off.
	var kind: String = scenario.get("kind", "")
	var done := (kind == "land" and bird.state == Bird.State.PERCHED) or (kind != "land" and sim_t > 4.0) or sim_t > 14.0
	if done and _ended_at < 0.0:
		_ended_at = sim_t
	if loop and _ended_at >= 0.0 and sim_t - _ended_at > 1.5 and pause_at < 0.0:
		restart()


func _pose_tick() -> void:
	RigPoses.apply(pose_rig, scenario.pose, sim_t, neck if override_body else -1.0, fluff if override_body else -1.0)


func _snapshot() -> void:
	var g: BirdRig
	if _ghosts.size() < GHOSTS:
		g = BirdRig.new()
		world.add_child(g)
		g.build(bird.profile)
		g.set_ghost(0.6)
		_ghosts.append(g)
	else:
		g = _ghosts[_ghost_i % GHOSTS]
		_ghost_i += 1
	g.global_transform = bird.rig.global_transform
	g.copy_pose_from(bird.rig)


func _clear_ghosts() -> void:
	for g in _ghosts:
		g.queue_free()
	_ghosts.clear()
	_ghost_i = 0
	_ghost_clock = GHOST_EVERY


func step() -> void:
	get_tree().paused = false
	await get_tree().physics_frame
	get_tree().paused = true
	_sync_ui()


# --- Camera, trail, readout (run while paused) --------------------------------------------------------

func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.01)
	_focus = _focus.lerp(_target_point(), 1.0 - exp(-8.0 * real_dt))
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	cam.look_at_from_position(_focus + dir * _dist, _focus, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	_draw_trail()
	_show_bones()
	_readout.text = _status()


## The bone view on whichever rig is live (the posed one, or the flying bird's), and the rig hidden for
## bones only.
func _show_bones() -> void:
	var rig: BirdRig = pose_rig if pose_rig != null else (bird.rig if bird != null else null)
	_bone_view.rig = rig
	_bone_view.visible = bones > 0
	if rig != null:
		rig.visible = bones < 2


func _draw_trail() -> void:
	_trail_mesh.clear_surfaces()
	if not trail_on or _trail.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for pt in _trail:
		_trail_mesh.surface_set_color(STATE_COLORS[int(pt[1])])
		_trail_mesh.surface_add_vertex(pt[0])
	_trail_mesh.surface_end()


func _status() -> String:
	var lines := ["%s  -  %s" % [BirdProfile.by_id(bird_id).display_name, scenario.label], "t %.2f s   speed x%.2f%s" % [sim_t, speed, "   PAUSED" if get_tree().paused else ""]]
	if bird != null:
		var t := bird.telemetry()
		lines.append("%s   %.1f m/s   catch %s at %.0f m/s" % [STATE_NAMES[bird.state], t.speed, CATCH_NAMES[int(t.candidate_status)] if bird.candidate != null else "-", t.grab_speed])
		lines.append("flare %.2f   landing %.0f%%   neck %.2f   fold %.2f" % [t.flare, 100.0 * float(t.landing_t), bird.rig.neck_ext, bird.rig.fold])
	elif pose_rig != null:
		lines.append("neck %.2f   fluff %.2f   fold %.2f" % [pose_rig.neck_ext, pose_rig.fluff, pose_rig.fold])
	if bones > 0:
		lines.append("bones (B): spine white  neck yellow  L wing orange  R wing cyan  legs green")
	return "\n".join(lines)


func _set_view(v: String) -> void:
	view = v
	var d: Vector3 = (VIEWS[v] as Vector3).normalized()
	_pitch = asin(d.y)
	_yaw = atan2(d.x, d.z)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(0.3, _dist * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(60.0, _dist * 1.1)
	elif e is InputEventMouseMotion and _dragging:
		var mm := e as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.006
		_pitch = clampf(_pitch + mm.relative.y * 0.006, -1.45, 1.45)
	elif e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).keycode:
			KEY_SPACE: _toggle_pause()
			KEY_PERIOD: step()
			KEY_R: restart()
			KEY_O: _set_onion(not onion)
			KEY_K: _set_rider(not rider)
			KEY_F: follow = not follow
			KEY_T: trail_on = not trail_on
			KEY_B: bones = (bones + 1) % 3
			KEY_V: _set_view(VIEWS.keys()[(VIEWS.keys().find(view) + 1) % VIEWS.size()])
			KEY_MINUS: _set_speed(speed * 0.5)
			KEY_EQUAL: _set_speed(speed * 2.0)
			KEY_UP: _pick_scenario(LabScenarios.LIST.find(scenario) - 1)
			KEY_DOWN: _pick_scenario(LabScenarios.LIST.find(scenario) + 1)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				_pick_bird((e as InputEventKey).keycode - KEY_1)


# --- Controls ------------------------------------------------------------------------------------------

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_sync_ui()


func _set_speed(v: float) -> void:
	speed = clampf(v, 0.05, 1.0)
	Engine.time_scale = speed
	_sync_ui()


func _set_rider(on: bool) -> void:
	rider = on
	if _tack != null and is_instance_valid(_tack):
		_tack.visible = on
	_sync_ui()


func _set_onion(on: bool) -> void:
	onion = on
	if not on:
		_clear_ghosts()
	_sync_ui()


func _pick_bird(i: int) -> void:
	if i < 0 or i >= BirdProfile.IDS.size():
		return
	bird_id = BirdProfile.IDS[i]
	restart()


func _pick_scenario(i: int) -> void:
	scenario = LabScenarios.LIST[posmod(i, LabScenarios.LIST.size())]
	restart()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(BuildVersion.make_label())
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(300, 0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Bird lab"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_bird_opt = OptionButton.new()
	for id in BirdProfile.IDS:
		_bird_opt.add_item(BirdProfile.by_id(id).display_name)
	_bird_opt.item_selected.connect(_pick_bird)
	box.add_child(_bird_opt)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 250)
	for s in LabScenarios.LIST:
		_list.add_item(s.label)
	_list.item_selected.connect(_pick_scenario)
	box.add_child(_list)
	var row := HBoxContainer.new()
	box.add_child(row)
	_pause_btn = Button.new()
	_pause_btn.pressed.connect(_toggle_pause)
	row.add_child(_pause_btn)
	var step_btn := Button.new()
	step_btn.text = "Step"
	step_btn.pressed.connect(step)
	row.add_child(step_btn)
	var again := Button.new()
	again.text = "Restart"
	again.pressed.connect(restart)
	row.add_child(again)
	_speed_label = Label.new()
	box.add_child(_speed_label)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.05
	_speed_slider.max_value = 1.0
	_speed_slider.step = 0.05
	_speed_slider.value_changed.connect(_set_speed)
	box.add_child(_speed_slider)
	_onion_box = _check(box, "Onion skin (ghosts)", onion, _set_onion)
	_rider_box = _check(box, "Rider and tack (crow, falcon, hawk)", rider, _set_rider)
	_check(box, "Camera follows the bird", follow, func(on: bool) -> void: follow = on)
	_check(box, "Flight path trail", trail_on, func(on: bool) -> void: trail_on = on)
	_check(box, "Loop", loop, func(on: bool) -> void: loop = on)
	_check(box, "Poses: set neck and fluff", override_body, func(on: bool) -> void: override_body = on)
	_neck_slider = _slider(box, "Neck: retracted .. reaching", 0.0, 1.0, neck, func(v: float) -> void: neck = v)
	_fluff_slider = _slider(box, "Fluff: sleek .. fluffed", 0.9, 1.2, fluff, func(v: float) -> void: fluff = v)
	var views := HBoxContainer.new()
	box.add_child(views)
	for v in VIEWS:
		var b := Button.new()
		b.text = v.capitalize()
		b.pressed.connect(_set_view.bind(v))
		views.add_child(b)
	var info := PanelContainer.new()
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.offset_left = -430
	info.offset_right = -12
	info.offset_top = 12
	layer.add_child(info)
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 14)
	info.add_child(_readout)
	var help := Label.new()
	help.text = "1-5 bird  Up/Down scenario  Space pause  . step\nR restart  -/= speed  O ghosts  F follow  V view\nB bones  Drag to orbit, wheel to zoom"
	help.add_theme_font_size_override("font_size", 11)
	help.modulate = Color(1, 1, 1, 0.7)
	box.add_child(help)


func _check(box: Container, text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(cb)
	box.add_child(c)
	return c


func _slider(box: Container, text: String, lo: float, hi: float, v: float, cb: Callable) -> HSlider:
	var l := Label.new()
	l.text = text
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = v
	s.value_changed.connect(cb)
	box.add_child(s)
	return s


func _sync_ui() -> void:
	if _bird_opt == null:
		return
	_bird_opt.select(BirdProfile.IDS.find(bird_id))
	var i := LabScenarios.LIST.find(scenario)
	if i >= 0:
		_list.select(i)
	_pause_btn.text = "Play" if get_tree().paused else "Pause"
	_speed_slider.set_value_no_signal(speed)
	_speed_label.text = "Speed x%.2f" % speed
	_onion_box.set_pressed_no_signal(onion)
	_rider_box.set_pressed_no_signal(rider)
