extends TestCase
## Short 3D sounds are heard (what reaches the speakers, recorded off the master bus): each short one-shot a
## positional cue plays -- a gun shot, a rocket launch, a bullet on wood, a perch catch, a bonk -- played AT 4 m in
## front of the listener peaks within HEARD_DB (and its distance loss, 20 log(4 / unit_size)) of the same take flat. An AudioStreamPlayer3D mixes at nothing until
## the physics tick after it starts, so a sound whose punch is in its first 20 ms (a gun shot is all crack) went
## unheard in 3D (13-15 dB under its flat self) until the bake put SoundRecipes.LEAD_3D of silence ahead of it.
## Needs the audio output: runs windowed (.\test_runner.ps1 runs it on its hidden desktop).

const CUES := ["gun_shot", "rocket_launch", "gun_strike_wood", "perch_catch", "bonk"]
const HEARD_DB := 8.0   ## past its distance loss: a centred 3D source loses ~3 dB to the pan law, some to the air filter
const AT := 4.0         ## m in front of the listener
const GAP := 0.4        ## s between plays

var _t0 := 0


func _init() -> void:
	timeout_sec = 900.0   # (game time: the runner steps frames as fast as it can, and this waits ~5 s of real time)


func setup() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var sfx := Sfx.new()
	sfx.enabled = true
	add_child(sfx)
	await frames(10)
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	var bus_fx := AudioServer.get_bus_effect_count(0) - 1
	rec.set_recording_active(true)
	_t0 = Time.get_ticks_msec()
	var at := []   # [cue, flat?, s into the recording]
	var k := 1
	for c: String in CUES:
		for flat in [true, false]:
			await _until(k * GAP)
			at.append([c, flat, (Time.get_ticks_msec() - _t0) / 1000.0])
			# (the same take both times: Sfx would pick another; a cue's takes are alike in level)
			sfx._picked[c] = -1
			sfx._rng.seed = 7
			sfx._last.erase(c)
			if flat:
				sfx.play(c)
			else:
				sfx.play_at(c, cam.global_position - cam.global_basis.z * AT)
			k += 1
	await _until((k + 1) * GAP)
	rec.set_recording_active(false)
	var wav := rec.get_recording()
	AudioServer.remove_bus_effect(0, bus_fx)
	rec = null
	sfx.queue_free()
	await frames(10)
	check(wav != null and wav.data.size() > 0, "the master bus recorded (an audio output is needed)")
	if wav == null or wav.data.is_empty():
		finish()
		return
	var m := _mono(wav)
	var rate := float(wav.mix_rate)
	var peak := {}
	for a: Array in at:
		var i0 := int(float(a[2]) * rate)
		var hi := 0.0
		for i in range(i0, mini(i0 + int(GAP * 0.9 * rate), m.size())):
			hi = maxf(hi, absf(m[i]))
		peak[[a[0], a[1]]] = linear_to_db(maxf(hi, 1e-6))
	for c: String in CUES:
		var flat: float = peak[[c, true]]
		var far: float = peak[[c, false]]
		print("%s: flat %.1f dB, 4 m off in 3D %.1f dB" % [c, flat, far])
		check(flat > -40.0, "%s plays (flat %.1f dB)" % [c, flat])
		var loss := maxf(0.0, 20.0 * log(AT / float(Sfx.CUES[c].unit_size)) / log(10.0))
		check(far > flat - loss - HEARD_DB, "%s 4 m off in 3D is heard: %.1f dB, within %.0f dB (and %.1f for the distance) of flat (%.1f)" % [c, far, HEARD_DB, loss, flat])
	finish()


func _until(sec: float) -> void:
	while Time.get_ticks_msec() - _t0 < int(sec * 1000.0):
		await get_tree().process_frame


## The recording (16-bit stereo) as mono samples -1..1.
static func _mono(w: AudioStreamWAV) -> PackedFloat32Array:
	var d := w.data
	var ch := 2 if w.stereo else 1
	var n := d.size() / (2 * ch)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var s := 0.0
		for c in ch:
			s += d.decode_s16((i * ch + c) * 2) / 32768.0
		out[i] = s / ch
	return out
