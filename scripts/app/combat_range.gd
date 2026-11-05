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
## enemy birds each side has downed. Round the clearing ride target balloons (TargetBalloon, --no-balloons: none): bullets
## hole them and they sink, a rocket's burst sets one alight, and each is winched up again BALLOON_RESPAWN s after it's
## down (the HUD counts yours).
##   .\range.ps1 [--bird <id>] [--target <id>] [--loadout <left>,<right>] [--seekers] [--no-evade] [--demo]
##       [--shot <png> --shot-after <s>]
## Every bird carries the war tack: a pod each side of the rider. Yours are --loadout <left>,<right>, each rockets
## (three), seekers (two) or gun (a machine gun, Launcher.GUN_POD rounds); one value arms both sides, and --seekers is
## seekers,seekers (unset: rockets,rockets). Each round leaves from its own pod; Q / RB switches between the two kinds
## when they differ, and you start on the left pod's. The target and the wingman carry the same, a gun swapped for
## rockets (the AI doesn't fly the gun yet: ai_pods); the match's AI birds, their species' round.
## --look <name> sets the pine wood's look (ForestLight.LOOKS; F6 steps through them).
## --demo flies your bird for you (chasing the target and firing), for screenshots and the test.
## --match: a team match instead of the target (docs/design/combat_ai.md, 4.8): you and two combat-AI wingmen
## (--team crow,hawk) against three combat-AI birds (--enemy falcon,owl,crow) out from the far base, at --skill
## recruit | pilot (default) | ace. Each AI bird carries its species' round (CombatStyle). The score is the match.
## Keys: mouse / left stick steer, Space / LT flap, left mouse / F / RT fire, Q / RB switch weapon,
## T target evasion on/off, Esc pauses (PauseMenu: Resume, Start over, Settings, Leave).

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
var pause: PauseMenu   ## Esc: Resume, Settings, Leave, the range paused
var bird: Bird
var target: Bird
var target_pilot: CircuitPilot
var demo := false
var bird_id := "crow"
var target_id := "crow"
var start_seekers := false
var evade := true            ## the target breaks when locked or shot at (T toggles)
var loadout: Array = []      ## your pods, left and right (--loadout; empty: Saddle.DEFAULT_LOADOUT)
var tacks := {}              ## Bird -> Tack
var home: Perch              ## your base's perch: where you rearm and mend
var their_base: Perch        ## the other side's
var wingman: Bird            ## your side's other bird (null: --no-wingman)
var wingman_pilot: CircuitPilot
var with_wingman := true
var return_fire := false     ## the target fires back at you (AICombat), for the HUD's warnings
var match_mode := false      ## --match: 3 v 3 against combat-AI birds instead of the target
var is_loaded := false       ## the arena built and the birds out (behind the loading screen until then: Loading)
signal loaded
var match_skill := "pilot"
var match_team: Array = ["crow", "hawk"]               ## your two AI wingmen
var match_enemy: Array = ["falcon", "owl", "crow"]     ## the other side
var match_birds: Array = []  ## the AI birds of a match (yours and theirs)
var with_balloons := true    ## target practice's balloons round the clearing (--no-balloons: none)
const BALLOON_CABLES := [6.0, 11.0, 8.0, 14.0, 9.5]   ## m: from just over the ferns to up among the crowns
const BALLOON_BREEZE := Vector3(1.0, 0.0, 0.35)       ## the way they lie (the range's air is calm: AirField)
const BALLOON_RESPAWN := 12.0                         ## s down before a fresh one goes up


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
	match_mode = args.has("--match")
	with_balloons = not args.has("--no-balloons")
	FlightAssist.configure(args)   # (--flying novice: the landing assist, more stamina)
	if Boot.arg_value(args, "--skill") in ["recruit", "pilot", "ace"]:
		match_skill = Boot.arg_value(args, "--skill")
	var team_ids := _ids(Boot.arg_value(args, "--team"), 2)
	if not team_ids.is_empty():
		match_team = team_ids
	var enemy_ids := _ids(Boot.arg_value(args, "--enemy"), 3)
	if not enemy_ids.is_empty():
		match_enemy = enemy_ids
	if args.has("--no-far-blur"):
		ForestLight.far_blur = false
	Antialias.apply(self, args)
	if FlightHud.STYLES.has(Boot.arg_value(args, "--hud")):
		FlightHud.style = Boot.arg_value(args, "--hud")
	loadout = parse_loadout(Boot.arg_value(args, "--loadout"))
	if start_seekers and loadout.is_empty():
		loadout = ["seekers", "seekers"]
	start_seekers = loadout.has("seekers")
	var pinewood := Boot.arg_value(args, "--forest") != "greybox"   # (the pine wood in its light; --forest greybox: the old test arena)
	var screen := Loading.new(("3 v 3 match, %s skill" % match_skill) if match_mode else "Target practice")
	add_child(screen)
	if pinewood:
		ForestLight.setup(self)
	else:
		Game.add_environment(self)
	Pinewood.cliff = args.has("--cliff")   # (the escarpment at the edge: on hold, off unless asked for)
	var make: Callable = (func() -> ArenaLayout: return Pinewood.generate(7)) if pinewood else (func() -> ArenaLayout: return ArenaLayout.generate(7))
	layout = await screen.generate(make, 0.25, 1.5 if pinewood else 0.2)
	if CombatWorld.calm_air:
		layout.air = AirField.new()
	HdrOutput.add(self)
	arena = ArenaBuilder.new()
	add_child(arena)
	await screen.run(arena.steps(layout), 0.85)
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
	await screen.run([["Saddling the birds", restart, 1.0]], 0.97)
	pause = PauseMenu.attach(self, [player_ctl], restart)
	is_loaded = true
	loaded.emit()
	screen.finish()
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
	for b in [bird, target, wingman] + match_birds:
		if b != null and is_instance_valid(b):
			world.remove_bird(b)
			trails.untrack(b)
			b.queue_free()
	world.stats = {"shots": 0, "hits": 0, "kills": 0, "balloons": 0}
	world.score = {YOUR_TEAM: 0, THEIR_TEAM: 0}
	home = _home()
	their_base = CombatWorld.far_base(layout, home.position)
	world.bases = {YOUR_TEAM: home, THEIR_TEAM: their_base}
	match_birds.clear()
	target = null
	target_pilot = null
	wingman = null
	if match_mode:
		_start_match()
	else:
		_start_target()
		_moor_balloons()
	# You: coming into the clearing from the south, a little above the target (in a match, out from your base).
	var flight: Object = player_ctl
	var weapons: Object = PlayerCombat.new()
	if demo and target != null:
		var chase := CircuitPilot.new()
		chase.mode = CircuitPilot.Mode.CHASE
		chase.quarry = target
		chase.cruise = 1.1
		flight = chase
		weapons = AICombat.new()
		(weapons as AICombat).prefer = Launcher.Weapon.SEEKERS if start_seekers else Launcher.weapon_of((loadout if not loadout.is_empty() else ["rockets"])[0])
	bird = _spawn(bird_id, flight, "Player")
	FlightAssist.fit(bird)   # (novice: perches highlighted from further out)
	audio.player = bird
	var mine := loadout if not loadout.is_empty() else Array(Saddle.DEFAULT_LOADOUT)
	if target_pilot != null:
		var w: Array = target_pilot.waypoints   # come in behind the target's first straight, a little high
		var along := ((w[1] as Vector3) - (w[0] as Vector3)).normalized()
		bird.fly_from((w[0] as Vector3) - along * 22.0 + Vector3.UP * 2.0, along, bird.profile.v_best)
	else:
		var out := Vector3(their_base.position.x - home.position.x, 0.0, their_base.position.z - home.position.z).normalized()
		bird.fly_from(home.position + out * 10.0 + Vector3.UP * 4.0, out, bird.profile.v_best)
	world.player = world.add_bird(bird, weapons, YOUR_TEAM)
	_arm(bird, world.player, mine)
	world.player.rearm_perch = home.id
	combat_hud.home = home.position
	world.player.weapon = Launcher.weapon_of(mine[0])   # (the left pod's)
	camera.bird = bird
	camera.snap()
	combat_hud.launcher = world.player
	combat_hud.world = world


## The racetrack target, and your circuit wingman above it.
func _start_target() -> void:
	# The target: a figure-eight through the clearing.
	target_pilot = CircuitPilot.new()
	target_pilot.waypoints = CircuitPilot.clear_racetrack(layout, CIRCUIT_CENTRE, CIRCUIT_LENGTH, CIRCUIT_R)
	target_pilot.threat = world.threat_to
	target_pilot.evade = evade
	target = _spawn(target_id, target_pilot, "Target")
	var tl := world.add_bird(target, AICombat.new() if return_fire else null, THEIR_TEAM)
	tl.rearm_perch = their_base.id
	_arm(target, tl, ai_pods())
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
		_arm(wingman, wl, ai_pods())
		trails.track(wingman, CombatHud.FRIEND)
		_launch_wingman()


## Target practice's balloons, moored round the clearing clear of its oak and the pines (TargetBalloon.moorings);
## on a restart, the ones there are winched up fresh.
func _moor_balloons() -> void:
	if not with_balloons:
		return
	if not world.balloons.is_empty():
		for bl: TargetBalloon in world.balloons:
			bl.reset()
		return
	var centre := Vector2.ZERO
	var open_r := 0.0
	for o in layout.openings:
		if o.kind == "clearing" and o.r > open_r:
			centre = o.centre
			open_r = o.r
	var spots := TargetBalloon.moorings(layout, centre, BALLOON_CABLES.size(), BALLOON_CABLES)
	for i in spots.size():
		var bl := TargetBalloon.new(i)
		bl.name = "Balloon %d" % (i + 1)
		bl.cable = BALLOON_CABLES[i]
		bl.breeze = BALLOON_BREEZE.normalized()
		bl.respawn_after = BALLOON_RESPAWN
		add_child(bl)
		bl.position = spots[i]
		world.balloons.append(bl)


## A team match: two combat-AI wingmen out from your base, three combat-AI birds out from theirs, each team sharing
## a TeamBoard.
func _start_match() -> void:
	var skill := CombatSkill.preset(match_skill)
	var n := 0
	for side in [[YOUR_TEAM, home, their_base, match_team], [THEIR_TEAM, their_base, home, match_enemy]]:
		var team: int = side[0]
		var base: Perch = side[1]
		var other: Perch = side[2]
		var ids: Array = side[3]
		var board := TeamBoard.new(team)
		# Your wingmen fly their species' rounds; the other side carries the mix its skill gives (CombatSkill.weapons).
		var kit: Array = skill.weapons(ids) if team == THEIR_TEAM else ids.map(func(s): return CombatStyle.of(BirdProfile.by_id(s)).weapon)
		var out := Vector3(other.position.x - base.position.x, 0.0, other.position.z - base.position.z).normalized()
		var across := Vector3(-out.z, 0.0, out.x)
		for i in ids.size():
			var id: String = ids[i]
			var b := _spawn(id, null, "%s %d (%s)" % ["Wingman" if team == YOUR_TEAM else "Enemy", i + 1, id])
			var l := world.add_bird(b, null, team)
			var brain := CombatBrain.new(b, world, l, skill, 100 + n)
			brain.board = board
			var weapon: int = kit[i]
			var kind: String = {Launcher.Weapon.SEEKERS: "seekers", Launcher.Weapon.GUN: "gun"}.get(weapon, "rockets")
			_arm(b, l, [kind, kind])
			if not tacks.has(b):
				CombatBrain.arm_with(l, weapon)
			l.weapon = weapon
			var weapons := AICombat.new()
			weapons.brain = brain
			l.controller = weapons
			b.controller = CombatPilot.new(brain)
			l.rearm_perch = base.id
			var off := (float(i) - (ids.size() - 1) * 0.5) * 6.0 + (4.0 if team == YOUR_TEAM else 0.0)   # (yours beside you)
			b.fly_from(base.position + out * 12.0 + across * off + Vector3.UP * (5.0 + i), out, b.profile.v_best)
			trails.track(b, CombatHud.FRIEND if team == YOUR_TEAM else CombatHud.ENEMY)
			match_birds.append(b)
			n += 1


## Up to `n` species ids from a comma list ("crow,hawk"), the last repeated to fill; [] if none given.
static func _ids(list: String, n: int) -> Array:
	var ids := Array(list.split(",", false)).filter(func(i): return BirdProfile.IDS.has(i))
	if ids.is_empty():
		return []
	while ids.size() < n:
		ids.append(ids[-1])
	return ids.slice(0, n)


## Saddle up a bird that can carry the tack, and arm its launcher from the mounts (`pods`, left and right; empty:
## Saddle.DEFAULT_LOADOUT): the rounds they hold, each fired from its own pod.
func _arm(b: Bird, l: Launcher, pods: Array = []) -> void:
	if not Tack.RIDDEN.has(b.profile.id):
		return
	var t := Tack.fit(b.rig, b, pods)
	tacks[b] = t
	l.set_tack(t)


## The target's and the circuit wingman's pods: yours, a gun pod swapped for rockets.
func ai_pods() -> Array:
	return loadout.map(func(p: String) -> String: return "rockets" if p == "gun" else p)


## --loadout's pods, [left, right]: "<left>,<right>", each rockets | seekers | gun, or one kind for both sides; []
## when unset or not understood.
static func parse_loadout(arg: String) -> Array:
	var parts := Array(arg.to_lower().split(",", false)).map(func(p: String) -> String: return p.strip_edges())
	if parts.size() == 1:
		parts.append(parts[0])
	if parts.size() != 2 or not Saddle.POD_KINDS.has(parts[0]) or not Saddle.POD_KINDS.has(parts[1]):
		if arg != "":
			push_warning("--loadout %s: expected <left>,<right>, each rockets | seekers | gun" % arg)
		return []
	return parts


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
		if target_pilot != null:
			target_pilot.rejoin(b.global_position, base.facing)
	elif b == wingman:
		wingman_pilot.rejoin(b.global_position, base.facing)
	elif b == bird:
		camera.snap()


## The landing bar on the perch ahead while catch is held, as in the game.
func _physics_process(_dt: float) -> void:
	if not is_loaded or bird == null or not is_instance_valid(bird):
		return
	var mark := bird.candidate if FlightHud.show_perch(bird.last_input.catch_held) else null
	arena.show_candidate(mark, bird.candidate_too_fast(), bird.profile.grab_radius, bird.candidate_grip)


func _process(_dt: float) -> void:
	if not is_loaded:
		return
	if bird != null and is_instance_valid(bird):
		flight_hud.gamepad = player_ctl.using_gamepad
		var t := bird.telemetry()
		flight_hud.set_state(t)
		audio.set_state(t)
	camera.look_input = player_ctl.look
	combat_hud.note = ("match, %s skill" % match_skill) if match_mode else ("target evades (T)" if evade else "target flies straight (T)")
	# The pods show the rounds left.
	for l in world.launchers:
		if tacks.has(l.bird) and is_instance_valid(l.bird):
			(tacks[l.bird] as Tack).set_ammo(l.left(Launcher.Weapon.ROCKETS), l.left(Launcher.Weapon.SEEKERS), l.left(Launcher.Weapon.GUN))


func _unhandled_input(e: InputEvent) -> void:
	if not is_loaded:
		return
	player_ctl.handle_event(e)
	PlayerCombat.handle_event(e, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)   # (before capturing: that click doesn't fire)
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F7:
		print("TAA ", "on" if Antialias.toggle(self) else "off")
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F6:
		print("look: ", ForestLight.next_look(self))
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_F5:
		ForestLight.toggle_far_blur(self)
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_T:
		evade = not evade
		if target_pilot != null:
			target_pilot.evade = evade
