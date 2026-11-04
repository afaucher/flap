class_name SoundRecipes
extends RefCounted
## Every baked sound in the game (docs/design/audio_plan.md), as a recipe on SoundDsp: tools/bake_sounds.gd renders
## each into assets/audio/sfx/<file>.wav, where Sfx plays it. A cue with `takes` > 1 is baked as <name>_1.wav ...
## <name>_N.wav, each from its own seed, and Sfx picks among them (never the same one twice running).
##
## Synthesized except these, built on recordings:
## - the bursts: the bang of Rudmer_Rotteveel's "Whistle and Explosion Single_Firework" (Freesound 336008, CC0, the one
##   ..\cast uses for its goblin fireworks), pitched up and shortened to the war tack's pencil-sized rockets, with a
##   synthesized crack and debris over it;
## - the perch catch: the user's claws on a cat tree (CLAWS), one scratch a take;
## - the five species' calls and alarms: cut from Freesound recordings (CALLS).

const D = preload("res://scripts/audio/sound_dsp.gd")
const FIREWORK := "res://assets/audio/third_party/freesound/336008__rudmer_rotteveel__whistle-and-explosion-single_firework.wav"
## The user's recording (2026-11-02): nails scratching a cat tree, a dozen separate scratches.
const CLAWS := "res://assets/audio/recordings/claws_on_cat_tree.wav"
const SOURCE_PATH := "res://scripts/audio/sound_recipes.gd"
const DSP_PATH := "res://scripts/audio/sound_dsp.gd"
const SFX_PATH := "res://scripts/audio/sfx.gd"
const STAMP_PATH := "res://assets/audio/sfx/baked_from.md5"

## name -> {takes, loop (s, or 0: a one-shot)}. The recipe is the method _<name>(rng, take).
const SOUNDS := {
	# combat
	"rocket_launch": {"takes": 5}, "rocket_motor": {"loop": 0.6}, "seeker_launch": {"takes": 3},
	"seeker_motor": {"loop": 0.8}, "burst": {"takes": 4}, "burst_wood": {"takes": 3}, "burst_ground": {"takes": 2},
	"gun_shot": {"takes": 6}, "gun_strike_wood": {"takes": 4}, "gun_strike_ground": {"takes": 3}, "bullet_zip": {"takes": 3},
	"fizzle": {"takes": 2}, "feather_puff": {"takes": 3}, "downed_flutter": {"takes": 2}, "empty_click": {},
	"weapon_switch": {}, "friend_buzz": {}, "score_up": {}, "score_down": {}, "respawn": {},
	# locks and warnings
	"lock_beep": {}, "lock_tone": {"loop": 0.5}, "locked_warning": {}, "incoming": {},
	# the base
	"rearm_tick": {"takes": 3}, "rearmed": {},
	# your bird and the world
	"perch_catch": {"takes": 6}, "takeoff_push": {"takes": 2}, "ground_land": {"takes": 2}, "bonk": {"takes": 3},
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


## A 3D sound starts silent: an AudioStreamPlayer3D gets its volume and panning on the physics tick after it starts
## playing (until then it mixes at nothing, then ramps up), so a sound's first ~20 ms are lost in 3D. A gun shot is
## all crack in that time and went unheard; every short 3D one-shot lost its attack. So each sound a positional cue
## plays (Sfx.CUES) is baked with this much silence ahead of it: 30 ms, under two ticks, less than its own travel time
## from 10 m off.
const LEAD_3D := 0.03


## Take `take` (0-based) of `name`, as mono samples.
static func render(name: String, take := 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + take * 7919
	var s: PackedFloat32Array = SoundRecipes.new().call("_" + name, rng, take)
	if is_loop(name):
		return s   # (loops are made seamless by their recipe and keep their level)
	return D.normalize(s, -1.0)


## Take `take` of `name` as baked (tools/bake_sounds.gd): render() with LEAD_3D of silence ahead of a one-shot that a
## positional cue plays.
static func baked(name: String, take := 0) -> PackedFloat32Array:
	var s := render(name, take)
	if is_loop(name) or not positional(name):
		return s
	var out := D.silence(LEAD_3D)
	out.append_array(s)
	return out


## Does a positional cue (Sfx.CUES) play `name`?
static func positional(name: String) -> bool:
	for c: String in Sfx.CUES:
		if Sfx.sound_of(c) == name and bool(Sfx.CUES[c].get("positional", false)):
			return true
	return false


## The MD5 of the recipes, SoundDsp and the recordings together: tools/bake_sounds.gd stamps the baked set with it.
static func source_md5() -> String:
	var src := ""
	for p: String in [SOURCE_PATH, DSP_PATH, SFX_PATH]:   # (the cues say which sounds get a 3D lead-in)
		src += FileAccess.get_file_as_string(p).replace("\r\n", "\n")
	for p: String in [FIREWORK, CLAWS] + CALL_SOURCES:
		src += FileAccess.get_md5(p)
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


## A shot of the riders' belt-fed gun: pencil-sized, so a cap gun's crack, not a rifle's boom -- the firework's bang
## pitched up an octave and more and cut to a few ms, a crack on its front, a small knock of the receiver -- then the
## bolt's clack-clack as it cycles (two tiny metal clicks, about 20 and 45 ms on). Over in 80 ms, so ten a second
## (GUN_RATE) stay ten shots and don't run together.
func _gun_shot(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.gain(D.hit(D.cut(_bang(rng.randf_range(12.0, 15.0)), 0.0, 0.09), 0.0003, 0.01), -3.0)
	s = D.mix(s, _crack(rng, 2600.0, 0.004), 0.0, -2.0)
	s = D.mix(s, _knock(rng.randf_range(260.0, 310.0), 0.008, 0.06), 0.0, -8.0)
	var clicks := [[rng.randf_range(0.018, 0.024), 1.0, -12.0], [rng.randf_range(0.04, 0.048), 0.85, -9.0]]   # (back, home)
	for c: Array in clicks:
		var f: float = rng.randf_range(3200.0, 3800.0) * float(c[1])
		var clk := D.mix(D.noise_hit(rng, 0.02, f, f, 3.0, 0.0003, 0.002), D.modal(0.03, [f * 1.31, f * 2.07], [0.5, 0.3], [0.004, 0.003]), 0.0, -6.0)
		s = D.mix(s, clk, float(c[0]), float(c[2]))
	return D.fade(D.cut(s, 0.0, 0.085), 0.0, 0.012)


## A bullet into a trunk: a sharp thwack -- a click and a short wooden knock -- splinters, a little bark pattering.
func _gun_strike_wood(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := _crack(rng, 1800.0, 0.003)
	s = D.mix(s, _knock(rng.randf_range(320.0, 420.0), 0.012, 0.08), 0.0, -2.0)
	s = D.mix(s, D.noise_hit(rng, 0.06, 1800.0, 900.0, 1.5, 0.0005, 0.008), 0.0, -6.0)
	s = D.mix(s, _grains(rng, 8, 0.06, 2000.0, 5000.0, 0.4), 0.003)
	return D.mix(s, _grains(rng, 10, 0.3, 1000.0, 3500.0, 0.12), 0.04)


## A bullet into the needle litter: a dull thup and a puff of grit (darker than wood: no crack to speak of).
func _gun_strike_ground(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.hit(D.lowpass(D.white(rng, 0.1), 900.0, 2), 0.001, 0.012)
	s = D.mix(s, _knock(rng.randf_range(130.0, 160.0), 0.015, 0.1), 0.0, -3.0)
	s = D.mix(s, _crack(rng, 1500.0, 0.002), 0.0, -16.0)
	return D.mix(s, D.lowpass(_grains(rng, 14, 0.18, 700.0, 2500.0, 0.3), 2500.0), 0.01)


## A bullet going by you close. At 95 m/s it's under the speed of sound, so no supersonic crack: a zip, a short
## whistle of noise falling in pitch as it passes (Doppler: (343 + 95) / (343 - 95), so down to about 0.56 of where it
## started), swelling to the pass and gone in 0.15 s.
func _bullet_zip(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var sec := rng.randf_range(0.11, 0.15)
	var f0 := rng.randf_range(5000.0, 6500.0)
	var s := D.svf(D.white(rng, sec), D.sweep(f0, f0 * 0.56), 6.0, 1)
	return D.shape(s, func(k: float) -> float: return pow(k / 0.45, 2.0) if k < 0.45 else pow((1.0 - k) / 0.55, 1.5))


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

## Talons catching the bark: one scratch of the user's recording (CLAWS) a take, the six loudest of its dozen, in the
## order recorded; rumble cut, the hiss between the scratch's strokes gated out.
func _perch_catch(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	var s := D.load_wav(CLAWS)
	var evs := D.events(s)
	var loud := evs.duplicate()
	loud.sort_custom(func(a: Array, b: Array) -> bool: return D.peak(D.cut(s, a[0], a[1])) > D.peak(D.cut(s, b[0], b[1])))
	var pick := loud.slice(0, 6)
	pick.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var ev: Array = pick[mini(take, pick.size() - 1)]
	var c := D.highpass(D.cut(s, ev[0], ev[1]), 150.0)
	return D.fade(D.gate(c), 0.003, 0.05)


## Pushing off a branch: the branch's spring creak, then air.
func _takeoff_push(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var creak := D.tone(0.22, D.sweep(rng.randf_range(80.0, 95.0), 55.0), "saw")
	creak = D.shape(D.bandpass(creak, 950.0, 4.0), func(k: float) -> float: return sin(PI * k))
	return D.mix(D.gain(creak, -4.0), D.noise_hit(rng, 0.25, 600.0, 1600.0, 1.0, 0.03, 0.06), 0.05, -3.0)


## Landing in the pine-needle litter: a soft thump and a crunch.
func _ground_land(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.gain(_knock(rng.randf_range(90.0, 110.0), 0.04), -4.0)
	return D.mix(s, D.lowpass(_grains(rng, 35, 0.14, 1200.0, 4000.0, 0.6), 3500.0))


## Hitting a trunk or branch: a dull thud with no ring to it (a held low tone read as a honk): low noise dying in
## 25 ms, a knock whose pitch drops by half in 40 ms, the bird's own body thumping into it, a crack of bark, then bark
## crumbling and needles pattering down.
func _bonk(rng: RandomNumberGenerator, _take: int) -> PackedFloat32Array:
	var s := D.hit(D.lowpass(D.white(rng, 0.2), 320.0, 2), 0.002, 0.025)
	var knock := D.hit(D.tone(0.1, D.sweep(rng.randf_range(150.0, 175.0), 70.0)), 0.001, 0.015)
	s = D.mix(s, knock, 0.0, -4.0)
	s = D.mix(s, D.noise_hit(rng, 0.1, 1400.0, 600.0, 0.8, 0.002, 0.02), 0.0, -6.0)
	s = D.mix(s, _crack(rng, 2000.0, 0.004), 0.0, -9.0)
	s = D.mix(s, _grains(rng, 12, 0.2, 1000.0, 3500.0, 0.25), 0.01)
	return D.mix(s, _grains(rng, 20, 0.7, 3000.0, 7000.0, 0.08), 0.15)


# ---------------------------------------------------------------- calls (Freesound recordings)

## The species' calls, cut from Freesound recordings (HQ previews, in assets/audio/sources/freesound/, .gdignore'd so
## they're read raw and never exported; sources and licences in assets/LICENSES.md). All CC0 but the kestrel (CC BY
## 4.0, credited). Each take is a window of a recording [from, to] s, or a run of windows strung together (the alarms:
## several calls tighter and a little higher than the contact call).
const CALL_SRC := "res://assets/audio/sources/freesound/"
const CROW := CALL_SRC + "75162__nigelcoop__crow.mp3"
const CROW_2 := CALL_SRC + "361470__jofae__crow-caw.mp3"
const OWL := CALL_SRC + "101344__raoul_slayer__barnowl.mp3"
const HAWK := CALL_SRC + "616995__trp__red-tailed-hawk-call.mp3"
const HAWK_2 := CALL_SRC + "616926__trp__red-tailed-hawk-isolated-calls.mp3"
const KESTREL := CALL_SRC + "352263__ylearkisto__kestrel-warning.mp3"
const SPARROW := CALL_SRC + "404663__straget__house-sparrow.mp3"
## The recordings the calls are cut from, for the bake stamp.
const CALL_SOURCES := [CROW, CROW_2, OWL, HAWK, HAWK_2, KESTREL, SPARROW]
## Per species: the low cut (Hz; below the call, it takes off wind, traffic and the trees' hum), and for each take of
## its call and its alarm the windows [path, from s, to s], and for an alarm the gap between them (s) and its speed.
const CALLS := {
	"crow": {"hp": 300.0,
		"call": [[[CROW, 0.05, 1.85]], [[CROW, 1.9, 3.35]], [[CROW, 0.05, 2.45]]],
		"alarm": [[[CROW, 1.13, 1.8], [CROW_2, 0.0, 0.43], [CROW, 1.9, 2.42]],
				[[CROW, 2.74, 3.3], [CROW_2, 0.0, 0.43], [CROW, 1.13, 1.8]]],
		"gap": 0.07, "speed": 1.06},
	"owl": {"hp": 800.0,
		"call": [[[OWL, 17.82, 18.85]], [[OWL, 40.52, 41.52]]],
		"alarm": [[[OWL, 84.73, 85.6], [OWL, 46.74, 47.65]], [[OWL, 48.62, 49.55], [OWL, 101.6, 102.45]]],
		"gap": 0.05, "speed": 1.06},
	"hawk": {"hp": 1000.0,
		"call": [[[HAWK, 3.58, 4.3]], [[HAWK, 7.42, 8.1]]],
		"alarm": [[[HAWK_2, 4.56, 4.98], [HAWK_2, 6.69, 7.1]], [[HAWK_2, 9.25, 9.55], [HAWK_2, 12.3, 12.6], [HAWK_2, 4.56, 4.98]]],
		"gap": 0.1, "speed": 1.05},
	"falcon": {"hp": 1500.0,   # (the kestrel)
		"call": [[[KESTREL, 32.5, 33.2]], [[KESTREL, 68.2, 68.9]], [[KESTREL, 82.86, 83.55]]],
		"alarm": [[[KESTREL, 65.26, 65.95], [KESTREL, 28.06, 28.55]], [[KESTREL, 79.55, 80.05], [KESTREL, 36.49, 36.95]]],
		"gap": 0.04, "speed": 1.08},
	"sparrow": {"hp": 1500.0,
		"call": [[[SPARROW, 4.82, 5.72]], [[SPARROW, 7.54, 8.68]], [[SPARROW, 10.8, 11.9]]],
		"alarm": [[[SPARROW, 8.47, 8.66], [SPARROW, 9.73, 9.92], [SPARROW, 11.67, 11.87], [SPARROW, 14.68, 14.87], [SPARROW, 17.83, 18.02]],
				[[SPARROW, 36.61, 36.8], [SPARROW, 14.68, 14.87], [SPARROW, 9.73, 9.92], [SPARROW, 8.47, 8.66], [SPARROW, 11.67, 11.87]]],
		"gap": 0.03, "speed": 1.1},
}
static var _recs := {}   ## path -> its samples (each recording is decoded once a bake)


static func _rec(path: String) -> PackedFloat32Array:
	if not _recs.has(path):
		_recs[path] = D.load_sound(path)
	return _recs[path]


## One window of a recording, cleaned: the low cut, the background between notes gated out, soft ends.
func _window(w: Array, hp: float) -> PackedFloat32Array:
	var c := D.cut(_rec(w[0]), w[1], w[2])
	return D.fade(D.gate(D.highpass(c, hp, 2), 34.0, 12.0), 0.004, 0.04)


## Take `take` of `species`' "call" or "alarm": its windows strung together (`gap` s apart for an alarm, at its speed).
func _recorded(species: String, kind: String, take: int) -> PackedFloat32Array:
	var sp: Dictionary = CALLS[species]
	var wins: Array = sp[kind][mini(take, (sp[kind] as Array).size() - 1)]
	var out := D.silence(0.0)
	var at := 0.0
	for w: Array in wins:
		var piece := _window(w, sp.hp)
		out = D.mix(out, piece, at)
		at += piece.size() / float(D.RATE) + (float(sp.gap) if kind == "alarm" else 0.0)
	return D.resample(out, float(sp.speed)) if kind == "alarm" else out


func _call_crow(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("crow", "call", take)


func _alarm_crow(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("crow", "alarm", take)


func _call_owl(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("owl", "call", take)


func _alarm_owl(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("owl", "alarm", take)


func _call_hawk(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("hawk", "call", take)


func _alarm_hawk(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("hawk", "alarm", take)


func _call_falcon(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("falcon", "call", take)


func _alarm_falcon(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("falcon", "alarm", take)


func _call_sparrow(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("sparrow", "call", take)


func _alarm_sparrow(_rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	return _recorded("sparrow", "alarm", take)


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
