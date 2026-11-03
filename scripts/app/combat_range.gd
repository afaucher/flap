extends Node3D
## The combat range (proof of concept for ranged combat, docs/design/combat_concepts.html): the forest arena,
## your bird with a saddle launcher, and a target bird flying a figure-eight through the clearing. Fly onto
## it and fire: rockets (lead it) or seekers (hold it in the cone for a second to lock). Each hit knocks out
## flight feathers (2.5 on average); eight lost down it, and it comes back a moment later, mended. The target
## flies a racetrack above the clearing: straights long enough to lock, turns that break it. Your base is the
## outpost nearest the clearing (with no outposts, the start perch): sit on its rail for two seconds to rearm
## and grow lost feathers back; the HUD points home when you need it. Two sides: you and a wingman (a crow on
## its own racetrack above the target's; --no-wingman leaves it out) against the target. The HUD marks friend
## and foe; locks only take enemies, but a burst still hurts a teammate. --return-fire: the target shoots back
## (the HUD warns of its locks and rounds). Each side has a base: yours as above,
## theirs the outpost farthest from it. A downed bird comes back at its side's base once its down stun is over
## (mended, rearmed), and the circuit birds fly out from there and back to their racetracks. The score: the
## enemy birds each side has downed.
##   .\range.ps1 [--bird <id>] [--target <id>] [--seekers] [--no-evade] [--demo] [--shot <png> --shot-after <s>]
## Every bird carries the war tack: a pod each side of the rider, both of one kind -- rockets (six) or, with
## --seekers (or --loadout seekers), seekers (four) -- and each round leaves from its own tube.
## --demo flies your bird for you (chasing the target and firing), for screenshots and the test.
## Keys: mouse / left stick steer, Space / LT flap, left mouse / F / RT fire, Q / RB switch weapon,
## T target evasion on/off, R restart, Esc release the mouse.

const CIRCUIT_CENTRE := Vector3(0.0, 20.0, 0.0)   ## over the clearing, up among the emergent trees
const CIRCUIT_LENGTH := 40.0   ## m of straight: time to lock
const CIRCUIT_R := 12.0        ## m, the turns that break it
const WINGMAN_ABOVE := 9.0     ## m: the wingman's racetrack, over the target's
const YOUR_TEAM := 0
const THEIR_TEAM := 1

var layout: ArenaLayout
var arena: ArenaBuilder
var world: CombatWorld
var trails: WingTrails
var camera: ChaseCamera
var audio: GameAudio
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
var loadout: Array = []      ## the pods, left and right: both of one kind (empty: Saddle.DEFAULT_LOADOUT)
var tacks := {}              ## Bird -> Tack
var home: Perch              ## your base's perch: where you rearm and mend
var their_base: Perch        ## the other side's
var wingman: Bird            ## your side's other bird (null: --no-wingman)
var wingman_pilot: CircuitPilot
var with_wingman := true
var return_fire := false     ## the target fires back at you (AICombat), for the HUD's warnings


func _ready() -> void:
	var args := Boot.args()
	if BirdProfile.IDS.has(Boot.arg_value(args, "--bird")):
		bird_id = Boot.arg_value(args, "--bird")
	if BirdProfile.IDS.has(Boot.arg_value(args, "--target")):
		target_id = Boot.arg_value(args, "--target")
	demo = args.has("--demo")
	start_seekers = args.has("--seekers")
	evade = not args.has("--no-evade")
	with_wingman = not args.has("--no-wingman")
	return_fire = args.has("--return-fire")
	if args.has("--no-far-blur"):
		ForestLight.far_blur = false
	if FlightHud.STYLES.has(Boot.arg_value(args, "--hud")):
		FlightHud.style = Boot.arg_value(args, "--hud")
	if Boot.arg_value(args, "--loadout") == "seekers":
		start_seekers = true
	if start_seekers:
		loadout = ["seekers", "seekers"]
	var pinewood := Boot.arg_value(args, "--forest") != "greybox"   # (the pine wood in its light; --forest greybox: the old test arena)
	if pinewood:
		ForestLight.setup(self)
	else:
		Game.add_environment(self)
	layout = Pinewood.generate(7) if pinewood else ArenaLayout.generate(7)
	HdrOutput.add(self)
	arena = ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	world = CombatWorld.new()
	world.layout = layout
	add_child(world)
	world.downed.connect(_on_downed)
	audio = GameAudio.new()
	add_child(audio)
	audio.watch_world(world)
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
	for b in [bird, target, wingman]:
		if b != null and is_instance_valid(b):
			world.remove_bird(b)
			trails.untrack(b)
			b.queue_free()
	world.stats = {"shots": 0, "hits": 0, "kills": 0}
	world.score = {YOUR_TEAM: 0, THEIR_TEAM: 0}
	home = _home()
	their_base = CombatWorld.far_base(layout, home.position)
	world.bases = {YOUR_TEAM: home, THEIR_TEAM: their_base}
	# The target: a figure-eight through the clearing.
	target_pilot = CircuitPilot.new()
	target_pilot.waypoints = CircuitPilot.clear_racetrack(layout, CIRCUIT_CENTRE, CIRCUIT_LENGTH, CIRCUIT_R)
	target_pilot.threat = world.threat_to
	target_pilot.evade = evade
	target = _spawn(target_id, target_pilot, "Target")
	var tl := world.add_bird(target, AICombat.new() if return_fire else null, THEIR_TEAM)
	tl.rearm_perch = their_base.id
	_arm(target, tl)
	trails.track(target, CombatHud.ENEMY)
	_launch_target()
	# Your wingman: a racetrack of its own, above the target's, half a lap round.
	wingman = null
	if with_wingman:
		wingman_pilot = CircuitPilot.new()
		wingman_pilot.waypoints = CircuitPilot.clear_racetrack(layout, CIRCUIT_CENTRE + Vector3.UP * WINGMAN_ABOVE, CIRCUIT_LENGTH, CIRCUIT_R)
		wingman_pilot.threat = world.threat_to
		wingman = _spawn(target_id, wingman_pilot, "Wingman")
		var wl := world.add_bird(wingman, null, YOUR_TEAM)
		wl.rearm_perch = home.id
		_arm(wingman, wl)
		trails.track(wingman, CombatHud.FRIEND)
		_launch_wingman()
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
	audio.player = bird
	var w: Array = target_pilot.waypoints   # come in behind the target's first straight, a little high
	var along := ((w[1] as Vector3) - (w[0] as Vector3)).normalized()
	bird.fly_from((w[0] as Vector3) - along * 22.0 + Vector3.UP * 2.0, along, bird.profile.v_best)
	world.player = world.add_bird(bird, weapons, YOUR_TEAM)
	_arm(bird, world.player)
	world.player.rearm_perch = home.id
	combat_hud.home = home.position
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


## Your base: the rail of the outpost nearest the clearing (the start perch where the layout has none).
func _home() -> Perch:
	var best: Perch = layout.start_perch()
	var best_d := INF
	for o in layout.outposts:
		var od := o as ArenaLayout.OutpostData
		var d := Vector2(od.centre.x - CIRCUIT_CENTRE.x, od.centre.z - CIRCUIT_CENTRE.z).length()
		if od.rail_perch_id >= 0 and d < best_d:
			best_d = d
			best = layout.perches[od.rail_perch_id]
	return best


func _spawn(id: String, ctl: Object, n: String) -> Bird:
	var b := Bird.new()
	b.name = n
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, ctl)
	b.arena = arena
	audio.watch(b)
	return b


func _launch_target() -> void:
	target.mend()
	var w: Array = target_pilot.waypoints
	target_pilot.wp = 1
	target.fly_from(w[0], ((w[1] as Vector3) - (w[0] as Vector3)).normalized(), target.profile.v_best)


func _launch_wingman() -> void:
	wingman.mend()
	var w: Array = wingman_pilot.waypoints
	var h: int = floori(w.size() * 0.5)
	wingman_pilot.wp = (h + 1) % w.size()
	wingman.fly_from(w[h], ((w[(h + 1) % w.size()] as Vector3) - (w[h] as Vector3)).normalized(), wingman.profile.v_best)


## Downed: once the down stun is over, back at its side's base; the circuit birds then fly out and rejoin.
func _on_downed(b: Bird) -> void:
	await get_tree().create_timer(CombatWorld.DOWN_STUN).timeout
	if not is_instance_valid(b) or not world.birds.has(b):
		return
	world.respawn(b)
	var base := world.base_of(b)
	if base == null:
		return
	if b == target:
		target_pilot.rejoin(b.global_position, base.facing)
	elif b == wingman:
		wingman_pilot.rejoin(b.global_position, base.facing)
	elif b == bird:
		camera.snap()


func _process(_dt: float) -> void:
	if bird != null and is_instance_valid(bird):
		flight_hud.gamepad = player_ctl.using_gamepad
		var t := bird.telemetry()
		flight_hud.set_state(t)
		audio.set_state(t)
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
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F5:
		ForestLight.toggle_far_blur(self)
	if e.is_action_pressed("respawn"):
		restart()
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_T:
		evade = not evade
		target_pilot.evade = evade
