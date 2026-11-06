extends TestCase
## Diagnostic: the range with your bird on two gun pods (LOADOUT=rockets,rockets etc. for another), a second of the
## range then F held a second: what GameAudio asked for, what Sfx played, the gun's live voices, and (GUN_AUDIO_OUT=<wav>)
## the master bus recorded -- what the mix put out (before the Master's mute: probe.ps1 runs are silent, FLAP_SOUND=1
## to hear it). Windowed: .\probe.ps1 probe_gun_audio


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	Boot.extra = PackedStringArray(["--loadout", OS.get_environment("LOADOUT") if OS.get_environment("LOADOUT") != "" else "gun,gun"])
	var r: Node = load("res://scenes/combat_range.tscn").instantiate()
	add_child(r)
	if not r.is_loaded:
		await r.loaded
	await frames(30)
	var ga: GameAudio = r.audio
	var l: Launcher = r.world.player
	print("sfx enabled %s; player weapon %s, gun rounds %d; launched connections %d" % [ga.sfx.enabled, l.weapon, l.left(Launcher.Weapon.GUN), r.world.launched.get_connections().size()])
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	rec.set_recording_active(true)
	var t0 := Time.get_ticks_msec()
	await frames(60)   # (a second of the range before firing)
	var n := ga.events.size()
	print("fire pressed at %.2f s into the recording" % ((Time.get_ticks_msec() - t0) / 1000.0))
	Input.action_press("fire")
	var out_db := -200.0   # (what the Master bus put out, after its mute: silence when the script started it muted)
	for k in 6:
		for f in 5:
			await frames(1)
			out_db = maxf(out_db, AudioServer.get_bus_peak_volume_left_db(0, 0))
		var cam := get_viewport().get_camera_3d()
		for q: AudioStreamPlayer3D in ga.sfx._p3d:
			if q.playing and q.stream != null and String(q.stream.resource_path).contains("gun_"):
				print("  gun voice: %.2f m from the camera (%s), vol %.1f dB, bus %s, unit %.1f, max %.0f, pos %.3f/%.3f s, stream %d bytes" % [q.global_position.distance_to(cam.global_position), cam.name, q.volume_db, q.bus, q.unit_size, q.max_distance, q.get_playback_position(), (q.stream as AudioStreamWAV).get_length(), (q.stream as AudioStreamWAV).data.size()])
	await frames(30)
	Input.action_release("fire")
	print("fire released at %.2f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	await frames(30)
	var cues := {}
	for e: Dictionary in ga.events.slice(n):
		cues[e.cue] = int(cues.get(e.cue, 0)) + 1
	print("shots %d; cues asked: %s" % [l.shots, cues])
	print("sfx played: %s" % ga.sfx.played)
	print("Master bus muted %s (FLAP_MUTE=%s): it put out %.1f dB while firing" % [AudioServer.is_bus_mute(0), OS.get_environment("FLAP_MUTE"), out_db])
	rec.set_recording_active(false)
	var wav := rec.get_recording()
	var out := OS.get_environment("GUN_AUDIO_OUT")
	if wav != null and out != "":
		wav.save_to_wav(out)
		print("recorded %s" % out)
	Boot.extra = PackedStringArray()
	finish()
