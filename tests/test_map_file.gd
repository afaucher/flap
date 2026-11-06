extends TestCase
## Maps kept as data (MapFile): a wood written out and read back is the same wood -- every kept variable of every
## tree, limb, branch, perch, outpost, opening, the floor's field and the air -- and answers the queries the same
## (the spatial hashes rebuilt). The game's arena (Pinewood.generate(Menu.ARENA_SEED)) is read from its baked map.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var grown := Pinewood.grow(7)
	var path := "user://test_map_file.map"
	eq(MapFile.save(grown, path, "test"), OK, "written")
	var back := MapFile.read(path)
	check(back != null, "read back")
	if back == null:
		finish()
		return
	# Every kept variable, deep (floats exact: the file keeps them whole).
	var a: Dictionary = MapFile._encode(grown)
	var b: Dictionary = MapFile._encode(back)
	var differ := []
	for k in a:
		if not b.has(k) or a[k] != b[k]:
			differ.append(k)
	eq(differ.size(), 0, "the same wood read back (differing: %s)" % ", ".join(differ))
	eq(back.trees.size(), grown.trees.size(), "as many trees (%d)" % grown.trees.size())
	eq(back.perches.size(), grown.perches.size(), "as many perches (%d)" % grown.perches.size())
	check(back.perches.size() > 0 and back.perches[0] is Perch, "perches are Perches, in a typed array")
	check(back.floor_field != null and back.floor_field.data == grown.floor_field.data, "the floor's field the same")
	# The queries: the hashes are rebuilt, not kept.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var same := 0
	var n := 200
	for i in n:
		var p := Vector3(rng.randf_range(-80, 80), rng.randf_range(0.5, 30.0), rng.randf_range(-80, 80))
		var q := p + Vector3(rng.randf_range(-15, 15), rng.randf_range(-5, 5), rng.randf_range(-15, 15))
		var ok := _ids(grown.trees_near_segment(p, q, 2.0)) == _ids(back.trees_near_segment(p, q, 2.0))
		ok = ok and grown.segment_clear(p, q, 0.3) == back.segment_clear(p, q, 0.3)
		ok = ok and _ids(grown.perches_near(p, 12.0)) == _ids(back.perches_near(p, 12.0))
		ok = ok and is_equal_approx(grown.ground(p.x, p.z), back.ground(p.x, p.z))
		ok = ok and grown.air.at(p) == back.air.at(p)
		same += int(ok)
	eq(same, n, "the same answers to the queries (%d of %d spots)" % [same, n])
	eq(back.max_perch_reach, grown.max_perch_reach, "the perches' reach rebuilt")
	# The game's arena comes from its file.
	var shipped := MapFile.path_for("pinewood_%d" % Menu.ARENA_SEED)
	check(FileAccess.file_exists(shipped), "the game's arena is baked (%s)" % shipped)
	var game := Pinewood.generate(Menu.ARENA_SEED)
	var file := MapFile.read(shipped)
	check(file != null and MapFile._encode(game) == MapFile._encode(file), "Pinewood.generate reads it")
	Pinewood.baked = false
	var fresh := Pinewood.generate(Menu.ARENA_SEED)
	Pinewood.baked = true
	check(fresh.trees.size() > 0, "and grows the wood fresh when told not to")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	finish()


func _ids(arr: Array) -> Array:
	var out := []
	for o in arr:
		out.append(o.id)
	out.sort()
	return out
