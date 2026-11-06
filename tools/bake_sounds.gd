extends SceneTree
## Bake every sound (SoundRecipes) into assets/audio/sfx/<file>.wav and stamp the set with the recipes' MD5
## (test_sounds checks it). Run after changing SoundRecipes or SoundDsp:
##   & $godot --path . --headless --script res://tools/bake_sounds.gd [-- <name> ...]   (only those sounds)
## then import (.\test_runner.ps1 does) so the game can load them.

const OUT := "res://assets/audio/sfx/"
const STAMP := SoundRecipes.STAMP_PATH


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var only := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n := 0
	for name: String in SoundRecipes.SOUNDS:
		if not only.is_empty() and not only.has(name):
			continue
		var files := SoundRecipes.files_of(name)
		for i in files.size():
			var s := SoundRecipes.baked(name, i)   # (a 3D one-shot with its lead-in: SoundRecipes.LEAD_3D)
			var err := SoundDsp.to_wav(s).save_to_wav(OUT + files[i] + ".wav")
			print("%-22s %5.2f s  peak %5.1f dB%s" % [files[i], s.size() / float(SoundDsp.RATE),
					linear_to_db(SoundDsp.peak(s)), "" if err == OK else "  ERROR %d" % err])
			n += 1
	if only.is_empty():
		var f := FileAccess.open(STAMP, FileAccess.WRITE)
		f.store_string(SoundRecipes.source_md5())
		f.close()
	print("baked %d files in %d ms" % [n, Time.get_ticks_msec() - t0])
	quit()
