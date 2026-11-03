class_name SoundRecipes
extends RefCounted
## Every baked sound in the game (docs/design/audio_plan.md), as a recipe on SoundDsp: tools/bake_sounds.gd renders
## each into assets/audio/sfx/<file>.wav, where Sfx plays it. A cue with `takes` > 1 is baked as <name>_1.wav ...
## <name>_N.wav, each from its own seed, and Sfx picks among them (never the same one twice running).
##
## Synthesized except the bursts, which are built on one CC0 recording: the bang of Rudmer_Rotteveel's "Whistle and
## Explosion Single_Firework" (Freesound 336008, the one ..\cast uses for its goblin fireworks), pitched up and
## shortened to the war tack's pencil-sized rockets, with a synthesized crack and debris over it.
## Stand-ins, until a recording replaces them: perch_catch (the user is recording claws on a cat tree), and the five
## species' calls (synthesized after their real calls, squirrel-racer style).

const D = preload("res://scripts/audio/sound_dsp.gd")
const FIREWORK := "res://assets/audio/third_party/freesound/336008__rudmer_rotteveel__whistle-and-explosion-single_firework.wav"
const SOURCE_PATH := "res://scripts/audio/sound_recipes.gd"
const DSP_PATH := "res://scripts/audio/sound_dsp.gd"
const STAMP_PATH := "res://assets/audio/sfx/baked_from.md5"

## name -> {takes, loop (s, or 0: a one-shot)}. The recipe is the method _<name>(rng, take).
const SOUNDS := {
	# combat
	"rocket_launch": {"takes": 5}, "rocket_motor": {"loop": 0.6}, "seeker_launch": {"takes": 3},
	"seeker_motor": {"loop": 0.8}, "burst": {"takes": 4}, "burst_wood": {"takes": 3}, "burst_ground": {"takes": 2},
	"fizzle": {"takes": 2}, "feather_puff": {"takes": 3}, "downed_flutter": {"takes": 2}, "empty_click": {},
	"weapon_switch": {}, "friend_buzz": {}, "score_up": {}, "score_down": {}, "respawn": {},
	# locks and warnings
	"lock_beep": {}, "lock_tone": {"loop": 0.5}, "locked_warning": {}, "incoming": {},
	# the base
	"rearm_tick": {"takes": 3}, "rearmed": {},
	# your bird and the world
	"perch_catch": {"takes": 3}, "takeoff_push": {"takes": 2}, "ground_land": {"takes": 2}, "bonk": {"takes": 3},
	# calls: a contact call and an alarm for each species
	"call_crow": {"takes": 3}, "alarm_crow": {"takes": 2}, "call_owl": {"takes": 2}, "alarm_owl": {"takes": 2},
	"call_hawk": {"takes": 2}, "alarm_hawk": {"takes": 2}, "call_falcon": {"takes": 3}, "alarm_falcon": {"takes": 2},
	"call_sparrow": {"takes": 3}, "alarm_sparrow": {"takes": 2},
	# the forest
	"forest_wind": {"loop": 20.0}, "insects": {"loop": 12.0},
	"song_eujay": {"takes": 2}, "song_crestit": {"takes": 2}, "song_gspot": {"takes": 2}, "song_coaltit": {"takes": 2},
	"song_robin": {"takes": 3}, "song_chaffinch": {"takes": 3},
}
## The pinewood's own birds (..\squirrel-racer's Caledonian Pinewood): the distant song ForestAmbience plays.
const SONGBIRDS := ["song_eujay", "song_crestit", "song_gspot", "song_coaltit", "song_robin", "song_chaffinch"]


## The file names (without .wav) of a sound: its takes.
static func files_of(name: String) -> Array:
	var n := int(SOUNDS[name].get("takes", 1))
	if n <= 1:
		return [name]
	var out := []
	for i in n:
		out.append("%s_%d" % [name, i + 1])
	return out


static func is_loop(name: String) -> bool:
	return float(SOUNDS[name].get("loop", 0.0)) > 0.0


## Take `take` (0-based) of `name`, as mono samples.
static func render(name: String, take := 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + take * 7919
	var s: PackedFloat32Array = SoundRecipes.new().call("_" + name, rng, take)
	if is_loop(name):
		return s   # (loops are made seamless by their recipe and keep their level)
	return D.normalize(s, -1.0)


## The MD5 of the recipes and SoundDsp together: tools/bake_sounds.gd stamps the baked set with it.
static func source_md5() -> String:
	var src := ""
	for p: String in [SOURCE_PATH, DSP_PATH]:
		src += FileAccess.get_file_as_string(p).replace("\r\n", "\n")
	return src.md5_text()


# ---------------------------------------------------------------- shared pieces

## The firework's bang alone (it lands at 1.15 s, after a quiet whistle), `semi` semitones up.
func _bang(semi: float) -> PackedFloat32Array:
	var s := D.load_wav(FIREWORK)
	var at := 1.1
	var best := 0.0
	for i in range(D.n_of(1.0), mini(s.size(), D.n_of(1.4))):
		if absf(s[i]) > best:
			best = absf(s[i])
			at = float(i) / D.RATE
	return D.fade(D.pitch(D.cut(s, at - 0.004, at + 0.9), semi), 0.002, 0.25)


## A sharp crack: a few ms of high-passed noise.
func _crack(rng: RandomNumberGenerator, hz := 1200.0, tau := 0.012) -> PackedFloat32Array:
	return D.hit(D.highpass(D.white(rng, 0.12), hz), 0.0008, tau)


## Grains of debris (bark, needles, grit): `n` tiny band-passed clicks over `sec` s, thinning out.
func _grains(rng: RandomNumberGenerator, n: int, sec: float, f_lo: float, f_hi: float, level: float) -> PackedFloat32Array:
	var out := D.silence(sec + 0.05)
	for i in n:
		var t := sec * pow(rng.randf(), 1.6)
		var g := D.noise_hit(rng, 0.03, rng.randf_range(f_lo, f_hi), rng.randf_range(f_lo, f_hi), 3.0, 0.0005, 0.004)
		out = D.mix(out, g, t, linear_to_db(level * rng.randf_range(0.4, 1.0) * (1.0 - t / sec * 0.6)))
	return out


## A low knock: a decaying sine dropping a little in pitch.
func _knock(hz: float, tau: float, sec := 0.25) -> PackedFloat32Array:
	return D.hit(D.tone(sec, D.sweep(hz, hz * 0.8)), 0.002, tau)


# ---------------------------------------------------------------- combat

## An air-rifle pop and the ignition hiss of a pencil-sized rocket: under 0.2 s so four a second stay apart.
func _rocket_launch(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.gain(_crack(rng, 1800.0, 0.008), -2.0)
	s = D.mix(s, _knock(rng.randf_range(150.0, 180.0), 0.03), 0.0, -6.0)
	var hiss := D.svf(D.white(rng, 0.18), D.sweep(2500.0, 6500.0), 1.2, 1)
	s = D.mix(s, D.shape(hiss, func(k: float) -> float: return minf(1.0, k * 8.0) * pow(1.0 - k, 1.5)), 0.01, -4.0)
	return s


## The rocket's burn, a seamless loop: a fierce bright hiss with a crackle in it (CombatWorld moves it with the round).
func _rocket_motor(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var sec := 0.6 + 0.1
	var s := D.gain(D.bandpass(D.white(rng, sec), 4200.0, 0.8), -8.0)
	s = D.mix(s, _grains(rng, 40, sec, 2500.0, 7000.0, 0.25))
	return D.make_loop(s, 0.6, 0.1)


## A heavier thunk and a longer ignition.
func _seeker_launch(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.gain(_crack(rng, 900.0, 0.015), -4.0)
	s = D.mix(s, _knock(rng.randf_range(95.0, 110.0), 0.06, 0.35), 0.0, -2.0)
	var hiss := D.svf(D.white(rng, 0.4), D.sweep(1200.0, 4500.0), 1.0, 1)
	return D.mix(s, D.shape(hiss, func(k: float) -> float: return minf(1.0, k * 5.0) * pow(1.0 - k, 1.2)), 0.02, -5.0)


## The seeker's burn, a seamless loop: lower and steadier than a rocket's, with a faint whine (a guided thing).
func _seeker_motor(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var sec := 0.8 + 0.15
	var s := D.gain(D.bandpass(D.pink(rng, sec), 2600.0, 0.7), -8.0)
	var whine := D.tone(sec, func(k: float) -> float: return 1850.0 + 25.0 * sin(TAU * 10.0 * k * sec))   # 10 Hz vibrato
	s = D.mix(s, whine, 0.0, -30.0)
	return D.make_loop(s, 0.8, 0.15)


## A proximity burst: the firework's bang pitched up 4-7 semitones (small and sharp), a crack on its front, a few
## grains of debris.
func _burst(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := _bang(rng.randf_range(4.0, 7.0))
	s = D.mix(s, _crack(rng, 1500.0, 0.01), 0.0, -3.0)
	return D.mix(s, _grains(rng, 10, 0.25, 1500.0, 5000.0, 0.15), 0.01)


## A burst on a trunk: the bang, wood splintering and a knock, bark pattering after.
func _burst_wood(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.gain(_bang(rng.randf_range(4.0, 6.0)), -2.0)
	s = D.mix(s, _knock(rng.randf_range(170.0, 220.0), 0.05), 0.0, -4.0)
	s = D.mix(s, _grains(rng, 18, 0.12, 1500.0, 4500.0, 0.5), 0.004)
	return D.mix(s, _grains(rng, 25, 0.6, 800.0, 3000.0, 0.18), 0.08)


## A burst on the ground: the bang dulled, a dirt thump and grit falling.
func _burst_ground(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.lowpass(_bang(rng.randf_range(3.0, 5.0)), 3500.0)
	s = D.mix(s, _knock(rng.randf_range(65.0, 80.0), 0.08, 0.35), 0.0, -1.0)
	return D.mix(s, D.lowpass(_grains(rng, 30, 0.5, 600.0, 2500.0, 0.25), 2500.0), 0.03)


## A round that burned out in the air: a small dull pop, plainly harmless.
func _fizzle(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.hit(D.lowpass(D.white(rng, 0.15), 700.0, 2), 0.002, 0.03)
	return D.mix(s, _crack(rng, 2500.0, 0.004), 0.0, -18.0)


## Flight feathers knocked out: a soft puff, a band of noise rising and falling.
func _feather_puff(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var sec := rng.randf_range(0.16, 0.22)
	var s := D.svf(D.white(rng, sec), func(k: float) -> float: return 1500.0 + 4500.0 * sin(PI * k), 1.5, 1)
	return D.shape(s, func(k: float) -> float: return minf(1.0, k * 6.0) * pow(1.0 - k, 2.0))


## A downed bird falling: ragged wingbeats (noise beating at 9-13 Hz) sinking in pitch and fading.
func _downed_flutter(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var sec := 1.2
	var rate := rng.randf_range(9.0, 13.0)
	var s := D.svf(D.white(rng, sec), D.sweep(1400.0, 450.0), 1.2, 1)
	return D.shape(s, func(k: float) -> float:
		var t := k * sec
		return pow(maxf(0.0, sin(TAU * rate * t + 1.3 * sin(TAU * 1.7 * t))), 3.0) * pow(1.0 - k, 1.3))


## Fire pressed with nothing loaded: a dry double click.
func _empty_click(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := _crack(rng, 3500.0, 0.002)
	return D.mix(s, D.gain(_crack(rng, 3000.0, 0.002), -4.0), 0.035)


## Switching weapons: a small mechanical clack-clack.
func _weapon_switch(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.mix(D.noise_hit(rng, 0.05, 2200.0, 2000.0, 2.0, 0.0005, 0.006), _knock(420.0, 0.012, 0.06), 0.0, -6.0)
	return D.mix(s, D.noise_hit(rng, 0.05, 1300.0, 1200.0, 2.0, 0.0005, 0.008), 0.06, -2.0)


## Firing with a teammate in the line: a short muted buzz, "hold fire".
func _friend_buzz(_rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.lowpass(D.tone(0.16, func(_k: float) -> float: return 160.0, "square"), 900.0, 2)
	return D.shape(s, func(k: float) -> float: return minf(1.0, k * 20.0) * minf(1.0, (1.0 - k) * 8.0))


## A short warm two-note sting: a rising fourth (we scored) or a falling minor third (they did).
func _sting(f0: float, f1: float) -> PackedFloat32Array:
	var s := D.silence(0.0)
	for i in 2:
		var f: float = [f0, f1][i]
		var n := D.mix(D.tone(0.5, func(_k: float) -> float: return f), D.tone(0.5, func(_k: float) -> float: return f * 2.0, "triangle"), 0.0, -14.0)
		s = D.mix(s, D.hit(n, 0.01, 0.16), i * 0.13)
	return s


func _score_up(_rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return _sting(659.3, 880.0)   # E5, A5


func _score_down(_rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return D.gain(_sting(587.3, 493.9), -3.0)   # D5, B4


## Back on the base after being downed: a soft settling rustle.
func _respawn(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.bandpass(D.white(rng, 0.45), 3000.0, 0.8)
	return D.shape(s, func(k: float) -> float: return sin(PI * k) * (0.6 + 0.4 * sin(TAU * 7.0 * k)))


# ---------------------------------------------------------------- locks and warnings (signals, not foley)

## One beep of a lock building (GameAudio repeats it faster and higher as the lock grows).
func _lock_beep(_rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.mix(D.tone(0.07, func(_k: float) -> float: return 1100.0), D.tone(0.07, func(_k: float) -> float: return 3300.0), 0.0, -18.0)
	return D.shape(s, func(k: float) -> float: return minf(1.0, k * 15.0) * minf(1.0, (1.0 - k) * 6.0))


## Locked: a steady high tone, a seamless loop (0.5 s holds a whole number of cycles of both partials).
func _lock_tone(_rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.mix(D.tone(0.5, func(_k: float) -> float: return 1900.0), D.tone(0.5, func(_k: float) -> float: return 3800.0), 0.0, -16.0)
	return D.gain(s, -14.0)


## Someone has a lock on you: a low, soft-edged pulse, nothing like your own lock's beeps.
func _locked_warning(_rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.lowpass(D.tone(0.16, func(_k: float) -> float: return 420.0, "square"), 1600.0, 2)
	return D.shape(s, func(k: float) -> float: return sin(PI * k))


## A seeker coming for you: a fast rising warble (GameAudio repeats it faster as it closes).
func _incoming(_rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.tone(0.12, D.sweep(700.0, 1500.0), "triangle")
	return D.shape(s, func(k: float) -> float: return minf(1.0, k * 12.0) * minf(1.0, (1.0 - k) * 5.0))


# ---------------------------------------------------------------- the base

## A round going back into the rack: a small brass clink (inharmonic partials of a short tube).
func _rearm_tick(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var f := rng.randf_range(2300.0, 2600.0)
	var s := D.modal(0.3, [f, f * 2.76, f * 5.4], [1.0, 0.55, 0.25], [0.09, 0.05, 0.025])
	return D.mix(s, _crack(rng, 4000.0, 0.002), 0.0, -12.0)


## The rack is full: a small bright chime (C6 E6 G6), the cue to leave.
func _rearmed(_rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.silence(0.0)
	var notes := [1046.5, 1318.5, 1568.0]
	for i in notes.size():
		var f: float = notes[i]
		s = D.mix(s, D.modal(0.9, [f, f * 2.0], [1.0, 0.2], [0.25, 0.12]), i * 0.07)
	return s


# ---------------------------------------------------------------- your bird

## STAND-IN until the user's recording (claws on a cat tree): talons on bark, a scratch and a small knock.
func _perch_catch(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.gain(_knock(rng.randf_range(200.0, 260.0), 0.025, 0.12), -6.0)
	var scratch := D.svf(D.white(rng, 0.09), D.sweep(3500.0, 2200.0), 1.5, 1)
	s = D.mix(s, D.shape(scratch, func(k: float) -> float: return (0.6 + 0.4 * sin(TAU * 4.0 * k)) * pow(1.0 - k, 1.5)), 0.005, -2.0)
	return D.mix(s, _grains(rng, 4, 0.08, 2000.0, 5000.0, 0.4), 0.0)


## Pushing off a branch: the branch's spring creak, then air.
func _takeoff_push(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var creak := D.tone(0.22, D.sweep(rng.randf_range(80.0, 95.0), 55.0), "saw")
	creak = D.shape(D.bandpass(creak, 950.0, 4.0), func(k: float) -> float: return sin(PI * k))
	return D.mix(D.gain(creak, -4.0), D.noise_hit(rng, 0.25, 600.0, 1600.0, 1.0, 0.03, 0.06), 0.05, -3.0)


## Landing in the pine-needle litter: a soft thump and a crunch.
func _ground_land(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.gain(_knock(rng.randf_range(90.0, 110.0), 0.04), -4.0)
	return D.mix(s, D.lowpass(_grains(rng, 35, 0.14, 1200.0, 4000.0, 0.6), 3500.0))


## Hitting a trunk or branch: a dull bark thud, bark crumbling, needles pattering down.
func _bonk(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := _knock(rng.randf_range(100.0, 125.0), 0.05, 0.3)
	s = D.mix(s, D.noise_hit(rng, 0.12, 900.0, 400.0, 1.0, 0.001, 0.03), 0.0, -3.0)
	s = D.mix(s, _grains(rng, 12, 0.2, 1000.0, 3500.0, 0.25), 0.01)
	return D.mix(s, _grains(rng, 20, 0.7, 3000.0, 7000.0, 0.08), 0.15)


# ---------------------------------------------------------------- calls (stand-ins after the real calls)

## "Caw": a harsh, falling, nasal note (a saw through a formant at about 1.3 kHz with rasp), in twos and threes.
func _caw(rng: RandomNumberGenerator, n: int, gap: float, len_s: float) -> PackedFloat32Array:
	var s := D.silence(0.0)
	for i in n:
		var f := rng.randf_range(560.0, 640.0)
		var v := D.tone(len_s, D.sweep(f, f * 0.78), "saw")
		v = D.mix(D.bandpass(v, 1300.0, 1.6), D.bandpass(v, 2600.0, 3.0), 0.0, -6.0)
		v = D.mix(v, D.bandpass(D.white(rng, len_s), 1500.0, 1.0), 0.0, -12.0)
		v = D.shape(v, func(k: float) -> float: return minf(1.0, k * 10.0) * pow(1.0 - k, 0.7) * (0.75 + 0.25 * sin(TAU * 38.0 * k * len_s)))
		s = D.mix(s, v, i * gap)
	return s


func _call_crow(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return _caw(rng, rng.randi_range(2, 3), 0.42, 0.3)


func _alarm_crow(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return _caw(rng, 5, 0.2, 0.17)   # (mobbing: harsh and fast)


## A barn owl's screech: a long, hoarse, falling hiss-scream (barn owls don't hoot).
func _screech(rng: RandomNumberGenerator, sec: float) -> PackedFloat32Array:
	var s := D.svf(D.white(rng, sec), D.sweep(rng.randf_range(4200.0, 4800.0), 3000.0), 2.5, 1)
	s = D.mix(s, D.svf(D.white(rng, sec), D.sweep(2400.0, 1800.0), 3.0, 1), 0.0, -6.0)
	return D.shape(s, func(k: float) -> float: return minf(1.0, k * 6.0) * pow(1.0 - k, 0.8) * (0.8 + 0.2 * sin(TAU * 23.0 * k * sec)))


func _call_owl(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return _screech(rng, rng.randf_range(0.9, 1.2))


func _alarm_owl(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := _screech(rng, 0.45)
	return D.mix(s, D.gain(D.highpass(D.white(rng, 0.35), 3000.0), -14.0), 0.5)   # and a hiss


## The red-tailed hawk's scream, "kee-eeer": a long, rasping, falling whistle.
func _scream(rng: RandomNumberGenerator, sec: float) -> PackedFloat32Array:
	var f := rng.randf_range(2700.0, 3000.0)
	var s := D.tone(sec, func(k: float) -> float: return f * (1.0 + 0.06 * sin(PI * minf(1.0, k * 3.0))) * pow(0.68, k))
	s = D.mix(s, D.svf(D.white(rng, sec), D.sweep(f, f * 0.68), 6.0, 1), 0.0, -4.0)
	return D.shape(s, func(k: float) -> float: return minf(1.0, k * 8.0) * pow(1.0 - k, 0.6) * (0.65 + 0.35 * sin(TAU * 45.0 * k * sec)))


func _call_hawk(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return _scream(rng, rng.randf_range(1.0, 1.3))


func _alarm_hawk(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := _scream(rng, 0.45)
	return D.mix(s, _scream(rng, 0.4), 0.55)


## A kestrel's "kee-kee-kee": quick, shrill, even notes.
func _kee(rng: RandomNumberGenerator, n: int, dt: float, f: float) -> PackedFloat32Array:
	var list := D.rep(n, dt, func(t: float) -> Array: return [[t, f, f * 0.93, dt * 0.62, "triangle", 0.8], [t, f * 2.0, f * 1.86, dt * 0.62, "sine", 0.15]])
	return D.notes(rng, D.vary(rng, list))


func _call_falcon(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return _kee(rng, rng.randi_range(4, 6), 0.14, 3100.0)


func _alarm_falcon(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return _kee(rng, 9, 0.09, 3500.0)


## A house sparrow's "chirrup": a bright up-down chirp, twice; its alarm a rattling scold.
func _call_sparrow(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var list := []
	for i in rng.randi_range(2, 3):
		var t := i * rng.randf_range(0.28, 0.36)
		list.append_array([[t, 3300.0, 4300.0, 0.05, "sine", 0.7], [t + 0.05, 4300.0, 3200.0, 0.07, "sine", 0.7], [t, 6600.0, 8000.0, 0.1, "noise", 0.2, 0.0, 4.0]])
	return D.notes(rng, D.vary(rng, list))


func _alarm_sparrow(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var list := D.rep(12, 0.04, func(t: float) -> Array: return [[t, 4200.0, 3600.0, 0.025, "noise", 1.0, 0.0, 3.0]])
	return D.notes(rng, D.vary(rng, list))


# ---------------------------------------------------------------- the forest

## The canopy in the wind, a 20 s seamless loop: band-passed pink noise (squirrel racer's canopy wind) swelling in
## gusts every few seconds, the needles hissing on the strongest.
func _forest_wind(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var sec := 20.0 + 2.0
	var gust := []   # a gust's level every 0.5 s, smoothly interpolated
	for i in int(sec * 2.0) + 2:
		gust.append(rng.randf_range(0.25, 1.0))
	var g := func(k: float) -> float:
		var x := k * sec * 2.0
		var i := int(x)
		return lerpf(gust[i], gust[i + 1], smoothstep(0.0, 1.0, x - i))
	var body := D.svf(D.pink(rng, sec), func(k: float) -> float: return 300.0 + 450.0 * float(g.call(k)), 0.6, 1)
	body = D.shape(body, func(k: float) -> float: return 0.3 + 0.7 * float(g.call(k)))
	var needles := D.shape(D.highpass(D.pink(rng, sec), 2800.0), func(k: float) -> float: return pow(float(g.call(k)), 3.0))
	return D.gain(D.make_loop(D.mix(body, needles, 0.0, -8.0), 20.0, 2.0), -10.0)


## A warm afternoon near the ground, a 12 s seamless loop: crickets chirping in fours, a grasshopper's buzz now and then.
func _insects(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var sec := 12.0 + 1.0
	var s := D.silence(sec)
	var t := 0.0
	while t < sec - 0.4:
		var f := rng.randf_range(4300.0, 4800.0)
		var chirp := D.rep(4, 0.055, func(u: float) -> Array: return [[u, f, f, 0.03, "sine", 0.5]])
		s = D.mix(s, D.notes(rng, chirp), t, rng.randf_range(-14.0, -4.0))
		t += rng.randf_range(0.25, 0.9)
	for i in 3:
		var at := rng.randf_range(0.5, sec - 2.0)
		var buzz := D.svf(D.white(rng, 1.4), func(_k: float) -> float: return 6500.0, 4.0, 1)
		buzz = D.shape(buzz, func(k: float) -> float: return sin(PI * k) * pow(maxf(0.0, sin(TAU * 32.0 * k)), 2.0))
		s = D.mix(s, buzz, at, -12.0)
	return D.gain(D.make_loop(s, 12.0, 1.0), -14.0)


## The pinewood's birds, ..\squirrel-racer's recipes (index.html CALLS), a fresh take each.
func _song_eujay(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return D.notes(rng, D.vary(rng, [[0, 2200, 1800, 0.5, "noise", 0.7], [0, 1900, 1700, 0.45, "sawtooth", 0.3]]))


func _song_crestit(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return D.notes(rng, D.vary(rng, [[0, 6500, 6400, 0.04, "sine", 0.6], [0.08, 6500, 6400, 0.04, "sine", 0.6], [0.2, 4800, 4700, 0.45, "sine", 0.6, 45]]))


func _song_gspot(rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	var list := D.rep(2, 0.35, func(t: float) -> Array: return [[t, 3200, 3000, 0.04, "square", 0.35]])
	if take == 0:   # one take drums: a fast, fading roll
		list.append_array(D.rep(18, 0.05, func(t: float) -> Array: return [[0.9 + t, 900, 800, 0.02, "noise", 0.8 * (1.0 - t)]]))
	return D.notes(rng, D.vary(rng, list))


func _song_coaltit(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	return D.notes(rng, D.vary(rng, D.rep(4, 0.32, func(t: float) -> Array: return [[t, 5200, 4800, 0.1, "sine", 0.7], [t + 0.12, 3800, 3600, 0.1, "sine", 0.7]])))


func _song_robin(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var a := []
	var t := 0.0
	for m in 4:
		var k := rng.randf()
		if k < 0.35:
			var f := rng.randf_range(5500.0, 7500.0)
			for i in 3 + rng.randi_range(0, 3):
				a.append([t, f, f * 0.9, 0.03, "sine", 0.5])
				t += 0.04
		elif k < 0.7:
			var f := rng.randf_range(2600.0, 4000.0)
			a.append([t, f, f * rng.randf_range(1.4, 1.9), 0.16, "sine", 0.6])
			t += 0.2
			a.append([t, f * 1.7, f * rng.randf_range(0.8, 1.1), 0.14, "sine", 0.55])
			t += 0.17
		else:
			var f := rng.randf_range(6000.0, 7500.0)
			for i in 3 + rng.randi_range(0, 2):
				a.append([t, f, f * 0.92, 0.05, "sine", 0.55])
				f *= 0.86
				t += 0.07
		t += rng.randf_range(0.08, 0.18)
	return D.notes(rng, D.vary(rng, a))


func _song_chaffinch(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var a := []
	var t := 0.0
	var dt := 0.13
	for i in 12:
		a.append([t, 5200 - i * 130, 5000 - i * 130, 0.05, "sine", 0.65])
		t += dt
		dt = maxf(0.055, dt * 0.9)
	a.append_array([[t + 0.08, 3200, 5200, 0.12, "sine", 0.7], [t + 0.22, 5200, 2800, 0.14, "sine", 0.7]])
	return D.notes(rng, D.vary(rng, a))
