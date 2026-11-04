class_name GameAudio
extends Node
## What the game sounds like (docs/design/audio_plan.md "As built"): decides which cue plays when, from what the HUD
## already reads -- your bird's telemetry, the Bird signals (perched, released, bonked), the CombatWorld signals
## (launched, burst, struck, downed) and the launchers' public state -- and hands it to Sfx. Never reads FlightModel.
##   - FlightAudio: your bird's wind, band whooshes and wingbeats (live synthesis).
##   - Every watched bird: perch catch, take-off push, ground landing, bonk; its species' alarm call when hurt or bonked
##     hard, now and then its contact call.
##   - Combat: each round's launch and its motor (a loop riding the round, Doppler from the camera), its burst (on a
##     bird, a trunk, the ground, or a fizzle), feather puffs, the downed flutter. The gun (Projectile GUN) has no cues
##     of its own yet: each shot is a quiet, high rocket_launch (GUN_SHOT), no motor; a bullet striking wood or the ground
##     a quiet, high burst_wood / burst_ground (GUN_STRIKE); one hitting a bird only its feather puff (struck).
##   - Your launcher: the lock building (beeps faster and higher with the lock), the locked tone, the dry click, the
##     weapon switch, "hold fire" when you shoot with a teammate in the line, the rack refilling on the base (a clink a
##     round, then a chime); what the HUD warns you of (CombatWorld.warnings_for): a lock on you (a low pulse) and a
##     round coming at you (a warble, faster as it closes); the score.
##   - The forest: the canopy wind (louder with height), insects near the ground, the pinewood's birds singing around you.
## `events` records every cue asked for, even headless where nothing plays, so tests check what would be heard.

const CANOPY := 30.0          ## m: the height the wind is fullest and the birdsong busiest at
const INSECT_TOP := 10.0      ## m: the insects fade out by here
const CALL_GAP := 0.8         ## s: the least time between one bird's calls
const CHATTER := Vector2(8.0, 20.0)   ## s between a watched AI bird's contact calls
const RACK_FILL := 0.9        ## of Launcher.RESTOCK_TIME: the clinks are spread over this much of it
const GUN_SHOT := [-12.0, 1.9]    ## dB, pitch: a gun's shot, on rocket_launch until it has its own cue
const GUN_STRIKE := [-16.0, 2.2]  ## dB, pitch: a bullet on wood or the ground, on the burst cues likewise
const BELT_CLINK := 10        ## gun rounds a rearm clink stands for

var sfx: Sfx
var flight: FlightAudio
var world: CombatWorld = null
var player: Bird = null       ## your bird (its launcher is world.player)
var forest := true            ## the forest beds and birdsong
var events: Array = []        ## {cue, pos, t, db, pitch} for every cue asked for (tests, debug); the last MAX_EVENTS
const MAX_EVENTS := 400

var _birds := {}              ## watched Bird -> {state, speed, next_call, last_call}
var _motors := {}             ## Projectile -> [player node, cue]
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _height := 0.0            ## your bird's height (telemetry)
var _lock_next := 0.0
var _lock_voice: Node = null
var _lock_on := false
var _warn_next := 0.0
var _incoming_next := 0.0
var _weapon := -1
var _shots := 0
var _dry := 0
var _score := {}
var _rack := {}               ## the rack refill in progress: {missing, ticked, t}
var _beds := {}               ## cue -> its looping voice
var _song_next := 2.0


func _ready() -> void:
	_rng.seed = 2026
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	flight = FlightAudio.new()
	flight.name = "FlightAudio"
	add_child(flight)


## Ask for `cue` (at `pos`, or flat); recorded in `events` whether or not it plays.
func cue(name: String, pos := Vector3.INF, volume_db := 0.0, pitch := 1.0) -> Node:
	events.append({"cue": name, "pos": pos, "t": _t, "db": volume_db, "pitch": pitch})
	if events.size() > MAX_EVENTS:
		events.pop_front()
	return sfx.play_at(name, pos, volume_db, pitch) if pos != Vector3.INF else sfx.play(name, volume_db, pitch)


## How many times `name` was asked for (tests).
func count(name: String) -> int:
	var n := 0
	for e: Dictionary in events:
		if e.cue == name:
			n += 1
	return n


## Hear `b`: its perch catches, take-offs, landings, bonks and calls.
func watch(b: Bird) -> void:
	if _birds.has(b):
		return
	_birds[b] = {"state": b.state, "speed": 0.0, "next_call": _t + _rng.randf_range(CHATTER.x, CHATTER.y), "last_call": -100.0}
	b.perched.connect(_on_perched.bind(b))
	b.released.connect(_on_released.bind(b))
	b.bonked.connect(_on_bonked.bind(b))
	b.tree_exiting.connect(func() -> void: _birds.erase(b))


## Hear a fight: its rounds, bursts and hits, and (world.player) your launcher.
func watch_world(w: CombatWorld) -> void:
	world = w
	w.launched.connect(_on_launched)
	w.burst.connect(_on_burst)
	w.struck.connect(_on_struck)
	w.downed.connect(_on_downed)


## Feed your bird's telemetry snapshot, once a frame (as FlightHud.set_state).
func set_state(t: Dictionary) -> void:
	flight.set_state(t)
	_height = (t.position as Vector3).y


func _process(dt: float) -> void:
	_t += dt
	for b: Bird in _birds.keys():
		if is_instance_valid(b):
			_bird_tick(b)
	_motors_tick()
	if world != null and world.player != null and is_instance_valid(world.player.bird):
		_launcher_tick(world.player)
		_threats_tick(world.player.bird)
		_score_tick()
	if forest:
		_forest_tick()


# --- birds ----------------------------------------------------------------------------------------

func _bird_tick(b: Bird) -> void:
	var w: Dictionary = _birds[b]
	if b.state == Bird.State.FLYING:
		w.speed = b.model.velocity.length()
	if b.state == Bird.State.GROUNDED and w.state != Bird.State.GROUNDED:
		cue("ground_land", b.global_position, _by_speed(w.speed, b.profile.grab_speed_max * 1.6))
	w.state = b.state
	if b != player and _t >= float(w.next_call) and not b.is_down():
		w.next_call = _t + _rng.randf_range(CHATTER.x, CHATTER.y)
		_call(b, "call")


func _on_perched(_p: Perch, b: Bird) -> void:
	var w: Dictionary = _birds.get(b, {})
	cue("perch_catch", b.global_position, _by_speed(float(w.get("speed", 0.0)), b.profile.grab_speed_max))


func _on_released(_p: Perch, b: Bird) -> void:
	cue("takeoff_push", b.global_position)


func _on_bonked(_n: Vector3, speed: float, b: Bird) -> void:
	cue("bonk", b.global_position, _by_speed(speed, 10.0))
	if speed > 6.0:
		_call(b, "alarm")


## A level for something `speed` fast out of `full`: -14 dB at a crawl up to 0 dB.
static func _by_speed(speed: float, full: float) -> float:
	return lerpf(-14.0, 0.0, clampf(speed / maxf(full, 0.01), 0.0, 1.0))


## `b`'s species' call ("call" or "alarm"), at most one per CALL_GAP.
func _call(b: Bird, kind: String) -> void:
	var w: Dictionary = _birds.get(b, {})
	if _t - float(w.get("last_call", -100.0)) < CALL_GAP:
		return
	if not w.is_empty():
		w.last_call = _t
	cue("%s_%s" % [kind, b.profile.id], b.global_position)


# --- combat ---------------------------------------------------------------------------------------

func _on_launched(p: Projectile) -> void:
	if p.kind == Projectile.Kind.GUN:
		cue("rocket_launch", p.pos, GUN_SHOT[0], GUN_SHOT[1])
		return
	var seeker := p.kind == Projectile.Kind.SEEKER
	cue("seeker_launch" if seeker else "rocket_launch", p.pos)
	var m := "seeker_motor" if seeker else "rocket_motor"
	_motors[p] = [cue(m, p.pos), m]


## The motors ride their rounds; a round gone (burst) takes its motor with it.
func _motors_tick() -> void:
	for p: Projectile in _motors.keys():
		var v: Array = _motors[p]
		if not p.alive or not sfx.owns(v[0], v[1]):
			sfx.stop(v[0], v[1])
			_motors.erase(p)
		elif v[0] != null:
			(v[0] as Node3D).global_position = p.pos


func _on_burst(at: Vector3, why: String, kind: int, surface: String) -> void:
	if kind == Projectile.Kind.GUN:
		if why == "impact":
			cue("burst_ground" if surface == "ground" else "burst_wood", at, GUN_STRIKE[0], GUN_STRIKE[1])
		return
	if why == "expired":
		cue("fizzle", at)
		return
	match surface:
		"ground":
			cue("burst_ground", at)
		"trunk":
			cue("burst_wood", at)
		_:
			cue("burst", at)


func _on_struck(b: Bird, _at: Vector3, _keys: Array) -> void:
	cue("feather_puff", b.global_position)
	_call(b, "alarm")


func _on_downed(b: Bird) -> void:
	cue("downed_flutter", b.global_position)
	if _birds.has(b):
		_birds[b].last_call = -100.0   # (the downed cry always sounds)
	_call(b, "alarm")


func _launcher_tick(l: Launcher) -> void:
	if _weapon >= 0 and l.weapon != _weapon:
		cue("weapon_switch")
	_weapon = l.weapon
	if l.shots > _shots and world.friend_in_line(l) != null:
		cue("friend_buzz")
	_shots = l.shots
	if l.dry_fires > _dry:
		cue("empty_click")
	_dry = l.dry_fires
	# The lock: beeps while it builds, faster and higher; a steady tone once locked.
	if l.locked():
		if not _lock_on or (sfx.enabled and not sfx.owns(_lock_voice, "lock_tone")):
			_lock_on = true
			_lock_voice = cue("lock_tone")
	else:
		if _lock_on:
			sfx.stop(_lock_voice, "lock_tone")
			_lock_on = false
		if l.lock_target != null and l.lock > 0.0 and _t >= _lock_next:
			cue("lock_beep", Vector3.INF, 0.0, 1.0 + 0.5 * l.lock)
			_lock_next = _t + lerpf(0.4, 0.09, l.lock)
	# The rack refilling on the base: a clink a missing round over the restock, then a chime.
	var missing := 0
	for w: int in l.capacity:
		var gone := l.carried(w) - l.left(w)
		missing += ceili(float(gone) / BELT_CLINK) if w == Launcher.Weapon.GUN else gone
	if l.on_base() and not l.full():
		if _rack.is_empty():
			_rack = {"missing": maxi(missing, 1), "ticked": 0, "t": 0.0}
		_rack.t = float(_rack.t) + get_process_delta_time()
		var due := int(float(_rack.t) / (Launcher.RESTOCK_TIME * RACK_FILL) * int(_rack.missing)) + 1
		while int(_rack.ticked) < mini(due, int(_rack.missing)):
			_rack.ticked = int(_rack.ticked) + 1
			cue("rearm_tick", l.bird.global_position)
	elif not _rack.is_empty():
		if l.on_base() and l.full():
			cue("rearmed")
		_rack = {}


## Someone locking you (a low pulse, quicker once locked) and a round coming at you (a warble, quicker and higher as
## it closes): what the HUD's LOCK and INCOMING marks show (CombatWorld.warnings_for), heard.
func _threats_tick(me: Bird) -> void:
	var w := world.warnings_for(me)
	var locks: Array = w.locks
	if not locks.is_empty() and _t >= _warn_next:
		cue("locked_warning")
		_warn_next = _t + (0.35 if bool(locks[0].locked) else 0.7)
	var rounds: Array = w.rounds
	if not rounds.is_empty() and _t >= _incoming_next:
		var tgo: float = rounds[0].tgo
		cue("incoming", Vector3.INF, 0.0, lerpf(1.25, 1.0, clampf(tgo / 1.5, 0.0, 1.0)))
		_incoming_next = _t + clampf(tgo * 0.3, 0.07, 0.4)


func _score_tick() -> void:
	var mine: int = world.teams.get(world.player.bird, -1)
	for team: int in world.score:
		var s := int(world.score[team])
		if _score.has(team) and s > int(_score[team]):
			cue("score_up" if team == mine else "score_down")
		_score[team] = s


# --- the forest -----------------------------------------------------------------------------------

func _forest_tick() -> void:
	var h := clampf(_height / CANOPY, 0.0, 1.0)
	_bed("forest_wind", lerpf(-14.0, -2.0, h))
	_bed("insects", lerpf(0.0, -40.0, clampf(_height / INSECT_TOP, 0.0, 1.0)))
	if _t < _song_next:
		return
	_song_next = _t + _rng.randf_range(1.5, 5.0) / (0.6 + h)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var ear := cam.global_position if cam != null else Vector3(0.0, _height, 0.0)
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(20.0, 60.0)
	var at := Vector3(ear.x + cos(a) * r, _rng.randf_range(5.0, 22.0), ear.z + sin(a) * r)
	cue(SoundRecipes.SONGBIRDS[_rng.randi() % SoundRecipes.SONGBIRDS.size()], at, -6.0 * r / 60.0)


## Keep a looping bed playing at `volume_db` over its cue's own level.
func _bed(name: String, volume_db: float) -> void:
	var v: Node = _beds.get(name)
	if not sfx.owns(v, name):
		if not sfx.enabled:
			return
		v = cue(name, Vector3.INF, volume_db)
		_beds[name] = v
	if v != null:
		v.set("volume_db", float(Sfx.CUES[name].get("volume_db", 0.0)) + volume_db)
