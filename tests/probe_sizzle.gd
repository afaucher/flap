extends TestCase
## Sizzle stills (the README's pictures): the combat range in its own look, running live, with a free camera that
## cuts in on the action -- a round leaving its pod, a burst on a trunk or a bird, a bird flying past among the pines,
## the chase camera with the HUD while a seeker lock builds, and your bird on its base's rail at the start. At each
## cut the game is slowed almost to a stop (Engine.time_scale) for a few frames so TAA settles, then saved.
##   .\probe.ps1 probe_sizzle --out <dir> [--match [--skill ace]] [--demo] [--loadout <left>,<right>] [--secs 60]
##       [--max 40] [--warmup <s>] [--look <name>]
## --warmup: only fly-bys for the first <s> seconds (a match takes a while to close).
## --match: the 3 v 3 (your bird flown by the combat AI too, so the HUD shows its locks); otherwise target
## practice, with --demo flying your bird onto the target (a gun pod: it holds fire while the target is in the cone).
## Every flag also reaches the range (Boot.args()): --bird, --loadout, --look, --skill ...

const SIZE := Vector2i(1920, 1080)
const COOLDOWN := {"launch": 2.5, "gun": 3.0, "burst": 2.0, "flyby": 5.0, "chase": 6.0, "lock": 4.0}
const SETTLE := 14            ## frames held at the cut for TAA

var r: Node
var cam: Camera3D
var out_dir := ""
var queue: Array = []         ## [due (s), kind, data]
var last := {}                ## kind -> time of its last shot (s)
var shots := 0
var max_shots := 40
var hud: CanvasLayer
var loaded_at := 0.0
var warm_until := 0.0         ## only fly-bys until then (--warmup)


class _GunHold:   ## holds the trigger while the target is in the gun's cone and in reach
	var target: Bird
	func sample(l: Launcher, _dt: float) -> CombatInput:
		var b := l.bearing(target) if target != null else Vector2(180, 999)
		return CombatInput.new(false, b.x < 8.0 and b.y < 30.0, false)


func _init() -> void:
	timeout_sec = 400.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = Boot.arg_value(args, "--out")
	if out_dir == "":
		out_dir = OS.get_user_data_dir() + "/sizzle"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var secs := float(Boot.arg_value(args, "--secs")) if Boot.arg_value(args, "--secs") != "" else 60.0
	if Boot.arg_value(args, "--max") != "":
		max_shots = int(Boot.arg_value(args, "--max"))
	get_window().size = SIZE
	r = load("res://scenes/combat_range.tscn").instantiate()
	add_child(r)
	if not r.is_loaded:
		await r.loaded
	await frames(2)
	hud = r.flight_hud.get_parent()
	if r.has_node("HdrOutput"):
		(r.get_node("HdrOutput") as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.fov = 55.0
	cam.far = 900.0
	add_child(cam)
	var world: CombatWorld = r.world
	world.launched.connect(_on_launched)
	world.burst.connect(_on_burst)
	var l: Launcher = world.player
	if r.match_mode:
		# Your bird on its rail first (the base by the hangar), then flown by the combat AI like the others.
		world.respawn(r.bird)
		await frames(30)
		await _rail_shots()
		var brain := CombatBrain.new(r.bird, world, l, CombatSkill.preset(r.match_skill), 99)
		brain.board = (r.match_birds[0].controller as CombatPilot).brain.board
		var w := AICombat.new()
		w.brain = brain
		l.controller = w
		r.bird.controller = CombatPilot.new(brain)
	elif r.demo and l.weapon == Launcher.Weapon.GUN:
		var g := _GunHold.new()
		g.target = r.target
		l.controller = g
	var start := _now()
	loaded_at = start + 3.0   # (the loading screen fading)
	warm_until = loaded_at + (float(Boot.arg_value(args, "--warmup")) if Boot.arg_value(args, "--warmup") != "" else 0.0)
	var next_flyby := start + 3.0
	var next_chase := start + 5.0
	while _now() - start < secs and shots < max_shots:
		await get_tree().process_frame
		var t := _now()
		if t > next_flyby:
			next_flyby = t + 4.0
			_want(t, "flyby", _pick_bird())
		if t > next_chase:
			next_chase = t + 7.0
			_want(t, "chase", r.bird)
		if r.match_mode and l.weapon == Launcher.Weapon.SEEKERS and l.lock > 0.55 and l.lock < 1.0:
			_want(t, "lock", r.bird)
		for q in queue.duplicate():
			if t >= q[0]:
				queue.erase(q)
				await _shoot(q[1], q[2])
				break
	print("probe_sizzle: %d shots in %s  stats %s" % [shots, out_dir, world.stats])
	finish()


func _want(due: float, kind: String, data: Variant) -> void:
	var t := _now()
	if t < loaded_at or (t < warm_until and kind != "flyby"):
		return
	if t - float(last.get(kind, -99.0)) < COOLDOWN.get(kind, 3.0):
		return
	for q in queue:
		if q[1] == kind:
			return
	last[kind] = t
	queue.append([due, kind, data])


func _on_launched(p: Projectile) -> void:
	if not (p.shooter is Bird):
		return
	if p.kind == Projectile.Kind.GUN:
		_want(_now() + 0.45, "gun", p.shooter)   # (a few rounds out)
	else:
		_want(_now() + 0.16, "launch", p.shooter)


func _on_burst(at: Vector3, _why: String, _kind: int, surface: String) -> void:
	if surface in ["trunk", "bird", "ground"]:
		_want(_now() + 0.04, "burst", at)


func _pick_bird() -> Bird:
	var flying := (r.world.birds as Array).filter(func(b: Bird) -> bool: return b.state == Bird.State.FLYING)
	return flying.pick_random() if not flying.is_empty() else null


## Is the line from `a` to `b` clear of the wood and the ground?
func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	return get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty()


## The first of `poses` ([camera, look at]) whose camera `at` can see.
func _first_clear(at: Vector3, poses: Array) -> Array:
	for p in poses:
		if _clear(at, p[0]) and _clear(p[0], p[1]):
			return p
	return []


## The bird ahead of `b` it is most likely shooting at (within 40 m and 35 deg of its flight), or null.
func _quarry(b: Bird) -> Bird:
	var f: Vector3 = b.model.flight_dir()
	var best: Bird = null
	var best_d := 40.0
	for o in r.world.birds:
		if o == b or o.state != Bird.State.FLYING:
			continue
		var to: Vector3 = o.global_position - b.global_position
		if to.length() < best_d and rad_to_deg(f.angle_to(to)) < 35.0:
			best = o
			best_d = to.length()
	return best


func _bird_frame(b: Bird) -> Array:   ## [forward, side, up] of a bird's flight
	var f: Vector3 = b.model.flight_dir()
	var s := f.cross(Vector3.UP).normalized()
	return [f, s, s.cross(f).normalized()]


func _shoot(kind: String, data: Variant) -> void:
	var pose := []
	var use_hud := false
	var label := kind
	match kind:
		"launch", "gun", "flyby":
			var b := data as Bird
			if b == null or not is_instance_valid(b) or b.state != Bird.State.FLYING:
				return
			label += "_" + b.profile.id
			var p := b.global_position
			var fr := _bird_frame(b)
			var f: Vector3 = fr[0]
			var s: Vector3 = fr[1]
			var u: Vector3 = fr[2]
			var side := 1.0 if randf() < 0.5 else -1.0
			var poses := []
			var q := _quarry(b)
			if kind == "flyby":   # ahead and beside, the bird coming at the camera among the trunks
				poses = [[p + f * 3.2 + s * side * 1.3 + u * 0.35, p - f * 0.3],
					[p + s * side * 2.0 + u * 0.25 + f * 0.4, p + f * 0.8],
					[p - f * 2.2 + s * side * 1.4 + u * 0.6, p + f * 3.0]]
			elif kind == "gun":   # close behind the shoulder: the tracers going out
				poses = [[p - f * 1.1 + s * side * 0.8 + u * 0.35, p + f * 8.0],
					[p - f * 1.1 - s * side * 0.8 + u * 0.35, p + f * 8.0]]
			elif q != null and randf() < 0.5:   # behind and above: the shooter, its rounds and its mark in one
				label += "_pursuit"
				var mid := p.lerp(q.global_position, 0.45)
				poses = [[p - f * 2.6 + s * side * 0.9 + u * 0.9, mid],
					[p - f * 2.6 - s * side * 0.9 + u * 0.9, mid]]
			else:                 # behind the shoulder, the round going away toward its mark
				poses = [[p - f * 1.4 + s * side * 1.1 + u * 0.45, p + f * 6.0],
					[p - f * 1.4 - s * side * 1.1 + u * 0.45, p + f * 6.0],
					[p + s * side * 1.8 + u * 0.25 + f * 0.5, p + f * 3.0]]
			pose = _first_clear(p, poses)
		"burst":
			var at := data as Vector3
			var poses := []
			for a in 6:
				var d := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
				poses.append([at + d * 6.5 + Vector3.UP * randf_range(0.5, 2.5), at])
			pose = _first_clear(at, poses)
		"chase", "lock":
			if r.bird.state != Bird.State.FLYING:
				return
			use_hud = true
	if not use_hud and pose.is_empty():
		return
	Engine.time_scale = 0.02
	hud.visible = use_hud
	if use_hud:
		r.camera.current = true
	else:
		cam.global_position = pose[0]
		cam.look_at(pose[1], Vector3.UP)
		cam.current = true
	await frames(SETTLE)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path := "%s/%02d_%s.png" % [out_dir, shots, label]
	img.save_png(path)
	print("shot ", path, "  ", img.get_size())
	shots += 1
	r.camera.current = true
	hud.visible = true
	Engine.time_scale = 1.0


## Your bird on the rail of its base, the hangar beside it, from a few sides.
func _rail_shots() -> void:
	var b: Bird = r.bird
	var p := b.global_position
	var face: Vector3 = (b.telemetry().facing as Vector3)
	face.y = 0.0
	face = face.normalized()
	var s := face.cross(Vector3.UP)
	var poses := [[p + face * 2.2 + s * 1.2 + Vector3.UP * 0.5, p + Vector3.UP * 0.1],
		[p + face * 1.6 - s * 1.8 + Vector3.UP * 1.1, p - face * 0.6],
		[p + face * 4.5 + s * 2.5 + Vector3.UP * 2.0, p - face * 1.0]]
	hud.visible = false
	for i in poses.size():
		cam.global_position = poses[i][0]
		cam.look_at(poses[i][1], Vector3.UP)
		cam.current = true
		await frames(SETTLE)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var path := "%s/%02d_rail_%d.png" % [out_dir, shots, i]
		img.save_png(path)
		print("shot ", path)
		shots += 1
	hud.visible = true
	r.camera.current = true
