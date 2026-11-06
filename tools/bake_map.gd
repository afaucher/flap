extends SceneTree
## Bake a pine wood's map: grow seed <n> fresh with today's generator (Pinewood.grow) and write it to
## maps/pinewood_<n>.map (MapFile), which Pinewood.generate then reads in place of growing it. Baking again replaces
## the shipped map: everything tuned on it (race courses, the combat AI's tests, best times) must be checked again.
##   & $godot --path . --headless --script res://tools/bake_map.gd -- <seed> [<seed> ...]

func _initialize() -> void:
	var seeds := OS.get_cmdline_user_args()
	if seeds.is_empty():
		seeds = PackedStringArray(["7"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MapFile.DIR))
	var ok := true
	for sd in seeds:
		var t0 := Time.get_ticks_msec()
		Pinewood.cliff = false
		var a := Pinewood.grow(int(sd))
		var path := MapFile.path_for("pinewood_%d" % int(sd))
		var err := MapFile.save(a, path, "Pinewood.grow(%d), %s" % [int(sd), Time.get_datetime_string_from_system(true)])
		ok = ok and err == OK
		print("%s: %d trees, %d perches, %d outposts, %d openings; %d KB in %d ms%s" % [path, a.trees.size(), a.perches.size(),
				a.outposts.size(), a.openings.size(), FileAccess.get_file_as_bytes(path).size() / 1024, Time.get_ticks_msec() - t0,
				"" if err == OK else "  ERROR %d" % err])
	quit(0 if ok else 1)
