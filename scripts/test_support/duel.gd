class_name Duel
extends Node3D
## Headless match harness for the combat AI (docs/design/combat_ai.md, 8): an arena with collision, a
## CombatWorld, a base per team, and birds with any controllers; run it for so many physics ticks (no rendering)
## and read the outcome per bird and per team. Downed birds come back at their team's base after the down stun,
## as in the range. Add it to the scene tree, then setup(), add birds, await run().

var layout: ArenaLayout
var arena: ArenaBuilder
var world: CombatWorld
var entries: Array = []          ## {bird, launcher, brain (or null), team, downs, bonks0}
var boards := {}                 ## team -> TeamBoard, shared by its combat-AI birds
var _respawn := {}               ## Bird -> physics ticks left until it comes back


func setup(l: ArenaLayout, bases := {}) -> void:
	layout = l
	arena = ArenaBuilder.new()
	add_child(arena)
	arena.build(l)
	world = CombatWorld.new()
	world.layout = l
	add_child(world)
	world.bases = bases
	world.downed.connect(func(b: Bird): _respawn[b] = int(CombatWorld.DOWN_STUN * 60.0))


## A combat-AI bird of species `id` on `team`, flying from `at` along `dir` (or perched, if `perch` is given).
func add_ai(id: String, team: int, at: Vector3, dir: Vector3, skill: CombatSkill = null, seed := 1, perch: Perch = null) -> Dictionary:
	var b := _bird(id)
	var l := world.add_bird(b, null, team)
	var brain := CombatBrain.new(b, world, l, skill, seed)
	if not boards.has(team):
		boards[team] = TeamBoard.new(team)
	brain.board = boards[team]
	CombatBrain.arm(l, brain.style)
	var weapons := AICombat.new()
	weapons.brain = brain
	l.controller = weapons
	b.controller = CombatPilot.new(brain)
	var base := world.bases.get(team, null) as Perch
	l.rearm_perch = base.id if base != null else -1
	_place(b, at, dir, perch)
	var e := {"bird": b, "launcher": l, "brain": brain, "team": team, "downs": 0}
	entries.append(e)
	return e


## A bird with your own controllers (a scripted target, a CircuitPilot, ...).
func add_bird(id: String, team: int, flight: Object, weapons: Object, at: Vector3, dir: Vector3, perch: Perch = null) -> Dictionary:
	var b := _bird(id)
	b.controller = flight
	var l := world.add_bird(b, weapons, team)
	var base := world.bases.get(team, null) as Perch
	l.rearm_perch = base.id if base != null else -1
	_place(b, at, dir, perch)
	var e := {"bird": b, "launcher": l, "brain": null, "team": team, "downs": 0}
	entries.append(e)
	return e


func _bird(id: String) -> Bird:
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(id), layout, null)
	b.arena = arena
	b.rig.visible = false   # (nothing renders here)
	return b


func _place(b: Bird, at: Vector3, dir: Vector3, perch: Perch) -> void:
	if perch != null:
		b.perch_at(perch)
	else:
		b.fly_from(at, dir.normalized(), b.profile.v_best)


## Run for `seconds` of simulated time. Returns the outcome (outcome()).
func run(seconds: float) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var ticks := int(seconds * 60.0)
	for f in ticks:
		await step()
	var out := outcome()
	out["ms_per_tick"] = float(Time.get_ticks_usec() - t0) / 1000.0 / maxf(ticks, 1)
	return out


## One physics tick (and the respawns due in it).
func step() -> void:
	await get_tree().physics_frame
	for b in _respawn.keys():
		_respawn[b] = int(_respawn[b]) - 1
		if int(_respawn[b]) <= 0:
			_respawn.erase(b)
			if is_instance_valid(b):
				for e in entries:
					if e.bird == b:
						e.downs += 1
				world.respawn(b)


## Per bird: hits taken, shots fired, times downed, bonks, health, ammo, its brain's time in each mode; per team:
## enemies downed (the score).
func outcome() -> Dictionary:
	var birds := []
	for e in entries:
		var b: Bird = e.bird
		var l: Launcher = e.launcher
		birds.append({"id": b.profile.id, "team": e.team, "hits_taken": int(world.hits.get(b, 0)), "shots": l.shots,
			"downs": e.downs + (1 if b.is_down() else 0), "bonks": b.bonks, "health": b.health(),
			"ammo": int(l.ammo[l.weapon]), "modes": (e.brain as CombatBrain).stats.modes.duplicate() if e.brain != null else {}})
	return {"birds": birds, "score": world.score.duplicate()}


func cleanup() -> void:
	for e in entries:
		if is_instance_valid(e.bird):
			world.remove_bird(e.bird)
			e.bird.queue_free()
	entries.clear()
