class_name Sfx
extends Node
## Plays the baked sounds (SoundRecipes, rendered into assets/audio/sfx/ by tools/bake_sounds.gd) by cue: pooled players,
## a cap on voices per cue, a minimum gap between plays, pitch jitter, and the takes of a cue picked at random but
## never the same one twice running. Ported from ..\cast scripts/fx/sfx.gd. GameAudio decides what plays; this only plays.
##
##   sfx.play("score_up")                  # non-positional
##   sfx.play_at("burst", pos)             # 3D at a world point
##   var v := sfx.play_at("rocket_motor", pos)   # a loop: keep the player, move it (v.global_position), stop() it
##
## CUES: the sound (a SoundRecipes name, default the cue's own), bus (default_bus_layout.tres), volume_db, pitch_jitter
## (a +- fraction), max_voices (the oldest voice of the cue is stolen past it), min_gap (s; a sooner play is dropped),
## positional, and for 3D cues unit_size / max_distance. 3D players track Doppler from the camera.
## Headless (tests) it is OFF unless `enabled` is set: nothing loads or plays, and play() returns null.

const DIR := "res://assets/audio/sfx/"
const CUES := {
	# combat (3D)
	"rocket_launch": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.05, "max_voices": 4, "positional": true, "unit_size": 4.0, "max_distance": 80.0},
	"rocket_motor": {"bus": "SFX", "volume_db": -10.0, "max_voices": 8, "positional": true, "unit_size": 3.0, "max_distance": 70.0},
	"seeker_launch": {"bus": "SFX", "volume_db": -4.0, "pitch_jitter": 0.04, "max_voices": 3, "positional": true, "unit_size": 5.0, "max_distance": 90.0},
	"seeker_motor": {"bus": "SFX", "volume_db": -8.0, "max_voices": 6, "positional": true, "unit_size": 4.0, "max_distance": 90.0},
	"burst": {"bus": "SFX", "volume_db": 0.0, "pitch_jitter": 0.06, "max_voices": 6, "min_gap": 0.02, "positional": true, "unit_size": 8.0, "max_distance": 150.0},
	"burst_wood": {"bus": "SFX", "volume_db": 0.0, "pitch_jitter": 0.05, "max_voices": 4, "min_gap": 0.02, "positional": true, "unit_size": 8.0, "max_distance": 150.0},
	"burst_ground": {"bus": "SFX", "volume_db": -1.0, "pitch_jitter": 0.05, "max_voices": 4, "min_gap": 0.02, "positional": true, "unit_size": 8.0, "max_distance": 150.0},
	"gun_shot": {"bus": "SFX", "volume_db": -4.0, "pitch_jitter": 0.04, "max_voices": 6, "positional": true, "unit_size": 4.0, "max_distance": 80.0},
	"gun_strike_wood": {"bus": "SFX", "volume_db": -9.0, "pitch_jitter": 0.06, "max_voices": 4, "min_gap": 0.02, "positional": true, "unit_size": 3.0, "max_distance": 60.0},
	"gun_strike_ground": {"bus": "SFX", "volume_db": -10.0, "pitch_jitter": 0.06, "max_voices": 4, "min_gap": 0.02, "positional": true, "unit_size": 3.0, "max_distance": 50.0},
	"bullet_zip": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.08, "max_voices": 3, "min_gap": 0.03, "positional": true, "unit_size": 2.0, "max_distance": 15.0},
	"fizzle": {"bus": "SFX", "volume_db": -10.0, "pitch_jitter": 0.1, "max_voices": 3, "positional": true, "unit_size": 4.0, "max_distance": 60.0},
	"feather_puff": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.08, "max_voices": 3, "min_gap": 0.05, "positional": true, "unit_size": 3.0, "max_distance": 40.0},
	"downed_flutter": {"bus": "SFX", "volume_db": -6.0, "max_voices": 2, "positional": true, "unit_size": 4.0, "max_distance": 60.0},
	# you (2D)
	"empty_click": {"bus": "UI", "volume_db": -8.0, "max_voices": 1, "min_gap": 0.08},
	"weapon_switch": {"bus": "UI", "volume_db": -8.0, "max_voices": 1, "min_gap": 0.08},
	"friend_buzz": {"bus": "UI", "volume_db": -10.0, "max_voices": 1, "min_gap": 0.3},
	"score_up": {"bus": "UI", "volume_db": -8.0, "max_voices": 1, "min_gap": 0.3},
	"score_down": {"bus": "UI", "volume_db": -8.0, "max_voices": 1, "min_gap": 0.3},
	"respawn": {"bus": "UI", "volume_db": -10.0, "max_voices": 1},
	"rearmed": {"bus": "UI", "volume_db": -8.0, "max_voices": 1, "min_gap": 0.5},
	# locks and warnings (2D)
	"lock_beep": {"bus": "UI", "volume_db": -12.0, "max_voices": 2},
	"lock_tone": {"bus": "UI", "volume_db": -12.0, "max_voices": 1},
	"locked_warning": {"bus": "UI", "volume_db": -6.0, "max_voices": 2},
	"incoming": {"bus": "UI", "volume_db": -5.0, "max_voices": 2},
	# the base, birds and the world (3D)
	"rearm_tick": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.04, "max_voices": 2, "positional": true, "unit_size": 3.0, "max_distance": 30.0},
	"perch_catch": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.06, "max_voices": 3, "min_gap": 0.05, "positional": true, "unit_size": 3.0, "max_distance": 35.0},
	"takeoff_push": {"bus": "SFX", "volume_db": -10.0, "pitch_jitter": 0.06, "max_voices": 3, "positional": true, "unit_size": 3.0, "max_distance": 35.0},
	"ground_land": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.06, "max_voices": 3, "positional": true, "unit_size": 3.0, "max_distance": 35.0},
	"bonk": {"bus": "SFX", "volume_db": -3.0, "pitch_jitter": 0.06, "max_voices": 3, "min_gap": 0.05, "positional": true, "unit_size": 5.0, "max_distance": 60.0},
	"call_crow": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 8.0, "max_distance": 120.0},
	"alarm_crow": {"bus": "SFX", "volume_db": -4.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 8.0, "max_distance": 120.0},
	"call_owl": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 8.0, "max_distance": 120.0},
	"alarm_owl": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 8.0, "max_distance": 120.0},
	"call_hawk": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 8.0, "max_distance": 140.0},
	"alarm_hawk": {"bus": "SFX", "volume_db": -4.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 8.0, "max_distance": 140.0},
	"call_falcon": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 8.0, "max_distance": 120.0},
	"alarm_falcon": {"bus": "SFX", "volume_db": -6.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 8.0, "max_distance": 120.0},
	"call_sparrow": {"bus": "SFX", "volume_db": -10.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 5.0, "max_distance": 80.0},
	"alarm_sparrow": {"bus": "SFX", "volume_db": -8.0, "pitch_jitter": 0.04, "max_voices": 4, "positional": true, "unit_size": 5.0, "max_distance": 80.0},
	# the forest (Ambience)
	"forest_wind": {"bus": "Ambience", "volume_db": -6.0, "max_voices": 1},
	"insects": {"bus": "Ambience", "volume_db": -6.0, "max_voices": 1},
	"song_eujay": {"bus": "Ambience", "volume_db": -12.0, "pitch_jitter": 0.04, "max_voices": 3, "positional": true, "unit_size": 10.0, "max_distance": 160.0},
	"song_crestit": {"bus": "Ambience", "volume_db": -12.0, "pitch_jitter": 0.04, "max_voices": 3, "positional": true, "unit_size": 10.0, "max_distance": 160.0},
	"song_gspot": {"bus": "Ambience", "volume_db": -12.0, "pitch_jitter": 0.04, "max_voices": 3, "positional": true, "unit_size": 10.0, "max_distance": 160.0},
	"song_coaltit": {"bus": "Ambience", "volume_db": -12.0, "pitch_jitter": 0.04, "max_voices": 3, "positional": true, "unit_size": 10.0, "max_distance": 160.0},
	"song_robin": {"bus": "Ambience", "volume_db": -12.0, "pitch_jitter": 0.04, "max_voices": 3, "positional": true, "unit_size": 10.0, "max_distance": 160.0},
	"song_chaffinch": {"bus": "Ambience", "volume_db": -12.0, "pitch_jitter": 0.04, "max_voices": 3, "positional": true, "unit_size": 10.0, "max_distance": 160.0},
}
const POOL_2D := 10
const POOL_3D := 24

## Sounds play (false headless unless a test sets it).
var enabled := DisplayServer.get_name() != "headless"
## Times each cue has started (tests, debug).
var played := {}

var _streams := {}       ## cue -> Array of its AudioStreams
var _last := {}          ## cue -> Time.get_ticks_msec() of its last play
var _picked := {}        ## cue -> index of the take it played last
var _p2d: Array[AudioStreamPlayer] = []
var _p3d: Array[AudioStreamPlayer3D] = []
var _voice := {}         ## player -> [cue, started msec]
var _rng := RandomNumberGenerator.new()


static func sound_of(cue: String) -> String:
	return str(CUES[cue].get("sound", cue))


## Play a non-positional cue. Returns the player, or null (off, unknown, too soon).
func play(cue: String, volume_db := 0.0, pitch_scale := 1.0) -> Node:
	return _start(cue, Vector3.INF, volume_db, pitch_scale)


## Play `cue` at a world point (a non-positional cue ignores the point). Returns the player, or null.
func play_at(cue: String, pos: Vector3, volume_db := 0.0, pitch_scale := 1.0) -> Node:
	return _start(cue, pos, volume_db, pitch_scale)


## Stop a voice play() returned (a loop, usually), if it is still that cue's.
func stop(p: Node, cue: String) -> void:
	if p != null and is_instance_valid(p) and _voice.get(p, [""])[0] == cue:
		p.call("stop")
		_voice[p] = ["", 0]


## Is `p` still playing `cue` (not stolen by another)?
func owns(p: Node, cue: String) -> bool:
	return p != null and is_instance_valid(p) and _voice.get(p, [""])[0] == cue and bool(p.get("playing"))


## The takes of `cue`, loaded on first use; a loop's are set to loop.
func streams_of(cue: String) -> Array:
	if _streams.has(cue):
		return _streams[cue]
	var found: Array = []
	var name := sound_of(cue)
	for f: String in SoundRecipes.files_of(name):
		var s := load(DIR + f + ".wav") as AudioStreamWAV
		if s == null:
			push_warning("Sfx: %s%s.wav missing (run tools/bake_sounds.gd)" % [DIR, f])
			continue
		if SoundRecipes.is_loop(name):
			s = s.duplicate() as AudioStreamWAV
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2
		found.append(s)
	_streams[cue] = found
	return found


func _start(cue: String, pos: Vector3, volume_db: float, pitch_scale: float) -> Node:
	if not enabled or not CUES.has(cue):
		return null
	var c: Dictionary = CUES[cue]
	var now := Time.get_ticks_msec()
	if _last.has(cue) and now - int(_last[cue]) < int(float(c.get("min_gap", 0.0)) * 1000.0):
		return null
	var s := _pick(cue)
	if s == null:
		return null
	var positional := bool(c.get("positional", false)) and pos != Vector3.INF
	var p: Node = _take(cue, positional, int(c.get("max_voices", 4)))
	_last[cue] = now
	p.set("stream", s)
	p.set("bus", StringName(str(c.get("bus", "Master"))))
	p.set("volume_db", float(c.get("volume_db", 0.0)) + volume_db)
	var jitter := float(c.get("pitch_jitter", 0.0))
	p.set("pitch_scale", pitch_scale * (1.0 + (_rng.randf_range(-jitter, jitter) if jitter > 0.0 else 0.0)))
	if positional:
		var p3 := p as AudioStreamPlayer3D
		p3.unit_size = float(c.get("unit_size", 10.0))
		p3.max_distance = float(c.get("max_distance", 0.0))
		p3.global_position = pos
	_voice[p] = [cue, now]
	p.call("play")
	played[cue] = int(played.get(cue, 0)) + 1
	return p


func _pick(cue: String) -> AudioStream:
	var all := streams_of(cue)
	if all.size() <= 1:
		return all[0] if not all.is_empty() else null
	var last := int(_picked.get(cue, -1))
	var i := _rng.randi_range(0, all.size() - (2 if last >= 0 else 1))
	if last >= 0 and i >= last:
		i += 1   # (every other take equally likely)
	_picked[cue] = i
	return all[i]


## A free player of the kind, or the one to steal: the cue's oldest voice past its limit, else the oldest of all.
func _take(cue: String, positional: bool, max_voices: int) -> Node:
	var pool: Array = _p3d if positional else _p2d
	var oldest_cue: Node = null
	var oldest_any: Node = null
	var count := 0
	var free: Node = null
	for p: Node in pool:
		if not p.get("playing"):
			if free == null:
				free = p
			continue
		var v: Array = _voice.get(p, ["", 0])
		if oldest_any == null or int(v[1]) < int(_voice[oldest_any][1]):
			oldest_any = p
		if v[0] == cue:
			count += 1
			if oldest_cue == null or int(v[1]) < int(_voice[oldest_cue][1]):
				oldest_cue = p
	if count >= max_voices and oldest_cue != null:
		oldest_cue.call("stop")
		return oldest_cue
	if free != null:
		return free
	if pool.size() < (POOL_3D if positional else POOL_2D):
		return _add_player(positional)
	oldest_any.call("stop")
	return oldest_any


func _add_player(positional: bool) -> Node:
	var p: Node
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.attenuation_filter_cutoff_hz = 6000.0   # (far sounds lose their top: the forest air)
		p3.attenuation_filter_db = -18.0
		p3.panning_strength = 0.8
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		_p3d.append(p3)
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		_p2d.append(p2)
		p = p2
	p.name = "Sfx3D%d" % _p3d.size() if positional else "Sfx2D%d" % _p2d.size()
	add_child(p)
	_voice[p] = ["", 0]
	return p
