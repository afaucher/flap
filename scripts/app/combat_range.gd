extends Node3D
## The combat range (proof of concept for ranged combat, docs/design/combat_concepts.html): the forest arena,
## your bird with a saddle launcher, and a target bird flying a figure-eight through the clearing. Fly onto
## it and fire: rockets (lead it) or seekers (hold it in the cone for a second to lock). Three hits down it;
## it comes back a moment later. The target flies a racetrack above the clearing: straights long enough to lock,
## turns that break it. Sit on any perch for two seconds to rearm.
##   .\range.ps1 [--bird <id>] [--target <id>] [--seekers] [--no-evade] [--demo] [--shot <png> --shot-after <s>]
##       [--loadout rockets,seekers]
## Crows, falcons and hawks carry the war tack: a pod each side of the rider (--loadout: left,right, each
## "rockets" -- three -- or "seekers" -- two), and each round leaves from its own tube. Other birds fire from
## ahead of the beak with the full AMMO.
## --demo flies your bird for you (chasing the target and firing), for screenshots and the test.
## Keys: mouse / left stick steer, Space / LT flap, left mouse / F / RT fire, Q / RB switch weapon,
## T target evasion on/off, R restart, Esc release the mouse.

const CIRCUIT_CENTRE := Vector3(0.0, 20.0, 0.0)   ## over the clearing, up among the emergent trees
const CIRCUIT_LENGTH := 40.0   ## m of straight: time to lock
const CIRCUIT_R := 12.0        ## m, the turns that break it

var layout: ArenaLayout
var arena: ArenaBuilder
var world: CombatWorld
var trails: WingTrails
var camera: ChaseCamera
var flight_hud: FlightHud
var combat_hud: CombatHud
var player_ctl := PlayerController.new()
var bird: Bird
var target: Bird
var target_pilot: CircuitPilot
var demo := false
var bird_id := "crow"
var target_id := "crow"
var start_seekers := false
var evade := true            ## the target breaks when locked or shot at (T toggles)
var loadout: Array = []      ## the pods, left and right (empty: Saddle.DEFAULT_LOADOUT)
var tacks := {}              ## Bird -> Tack


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if BirdProfile.IDS.has(Boot.arg_value(args, "--bird")):
		bird_id = Boot.arg_value(args, "--bird")
	if BirdProfile.IDS.has(Boot.arg_value(args, "--target")):
		target_id = Boot.arg_value(args, "--target")
	demo = args.has("--demo")
	start_seekers = args.has("--seekers")
	evade = not args.has("--no-evade")
	var lo := Boot.arg_value(args, "--loadout").split(",", false)
	if lo.size() == 2 and Saddle.POD_KINDS.has(lo[0]) and Saddle.POD_KINDS.has(lo[1]):
		loadout = [lo[0], lo[1]]
	var pinewood := Boot.arg_value(args, "--forest") != "greybox"   # (the pine wood in its light; --forest greybox: the old test arena)
	if pinewood:
		ForestLight.setup(self)
	else:
		Game.add_environment(self)
	layout = Pinewood.generate(7) if pinewood else ArenaLayout.generate(7)
	arena = ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	world = CombatWorld.new()
	world.layout = layout
	add_child(world)
	world.downed.connect(_on_downed)
	trails = WingTrails.new()
	add_child(trails)
	camera = ChaseCamera.new()
	camera.current = true
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	flight_hud = FlightHud.new()
	layer.add_child(flight_hud)
	combat_hud = CombatHud.new()
	layer.add_child(combat_hud)
	restart()
	var shot := Boot.arg_value(args, "--shot")
	if shot != "":
		var after := Boot.arg_value(args, "--shot-after")
		await get_tree().create_timer(float(after) if after != "" else 4.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("screenshot: ", shot, "  stats: ", world.stats)
		get_tree().quit()


func restart() -> void:
	tacks.clear()
	for b in [bird, target]:
		if b != null and is_instance_valid(b):
			world.remove_bird(b)
			trails.untrack(b)
			b.queue_free()
	world.stats = {"shots": 0, "hits": 0, "kills": 0}
	# The target: a figure-eight through the clearing.
	target_pilot = CircuitPilot.new()
	target_pilot.waypoints = CircuitPilot.clear_racetrack(layout, CIRCUIT_CENTRE, CIRCUIT_LENGTH, CIRCUIT_R)
	target_pilot.threat = world.threat_to
	target_pilot.evade = evade
	target = _spawn(target_id, target_pilot, "Target")
	_arm(target, world.add_bird(target, null))
	trails.track(target)
	_launch_target()
	# You: coming into the clearing from the south, a little above the target.
	var flight: Object = player_ctl
	var weapons: Object = PlayerCombat.new()
	if demo:
		var chase := CircuitPilot.new()
		chase.mode = CircuitPilot.Mode.CHASE
		chase.quarry = target
		chase.cruise = 1.1
		flight = chase
		weapons = AICombat.new()
		(weapons as AICombat).prefer = Launcher.Weapon.SEEKERS if start_seekers else Launcher.Weapon.ROCKETS
	bird = _spawn(bird_id, flight, "Player")
	var w: Array = target_pilot.waypoints   # come in behind the target's first straight, a little high
	var along := ((w[1] as Vector3) - (w[0] as Vector3)).normalized()
	bird.fly_from((w[0] as Vector3) - along * 22.0 + Vector3.UP * 2.0, along, bird.profile.v_best)
	world.player = world.add_bird(bird, weapons)
	_arm(bird, world.player)
	if start_seekers:
		world.player.weapon = Launcher.Weapon.SEEKERS
	camera.bird = bird
	camera.snap()
	combat_hud.launcher = world.player
	combat_hud.world = world


## Saddle up a bird that can carry the tack, and arm its launcher from the mounts: the rounds they hold, each
## fired from its own tube.
func _arm(b: Bird, l: Launcher) -> void:
	if not Tack.RIDDEN.has(b.profile.id):
		return
	var t := Tack.fit(b.rig, b, loadout)
	tacks[b] = t
	var kinds := {Launcher.Weapon.ROCKETS: "rockets", Launcher.Weapon.SEEKERS: "seekers"}
	l.set_mounts(t.capacity("rockets"), t.capacity("seekers"), func(w: int, i: int) -> Vector3: return t.muzzle_world(kinds[w], i))


func _spawn(id: String, ctl: Object, n: String) -> Bird:
	var b := Bird.new()
	b.name = n
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, ctl)
	b.arena = arena
	return b


func _launch_target() -> void:
	var w: Array = target_pilot.waypoints
	target_pilot.wp = 1
	target.fly_from(w[0], ((w[1] as Vector3) - (w[0] as Vector3)).normalized(), target.profile.v_best)


func _on_downed(b: Bird) -> void:
	if b != target:
		return
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(target):
		_launch_target()


func _process(_dt: float) -> void:
	if bird != null and is_instance_valid(bird):
		flight_hud.gamepad = player_ctl.using_gamepad
		flight_hud.set_state(bird.telemetry())
	camera.look_input = player_ctl.look
	combat_hud.note = "target evades (T)" if evade else "target flies straight (T)"
	# The pods show the rounds left.
	for l in world.launchers:
		if tacks.has(l.bird) and is_instance_valid(l.bird):
			(tacks[l.bird] as Tack).set_ammo(int(l.ammo[Launcher.Weapon.ROCKETS]), int(l.ammo[Launcher.Weapon.SEEKERS]))


func _unhandled_input(e: InputEvent) -> void:
	player_ctl.handle_event(e)
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if e.is_action_pressed("respawn"):
		restart()
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_T:
		evade = not evade
		target_pilot.evade = evade
