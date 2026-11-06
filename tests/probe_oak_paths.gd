extends TestCase
## Diagnostic: the oaks' limbs as drawn (TreeData.limbs), their trunks, leaf masses and perches, written as JSON for
## tools/oak_side_map.py to draw from the side beside the concept.
## .\probe.ps1 -Headless probe_oak_paths [--seed 7] [--out <json>]


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_arg := Boot.arg_value(args, "--seed")
	var out := Boot.arg_value(args, "--out")
	if out == "":
		out = ProjectSettings.globalize_path("res://test_logs/oak_paths.json")
	var a := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	var rails := {}
	for o in a.outposts:
		rails[o.rail_perch_id] = true
	var oaks := []
	for t: ArenaLayout.TreeData in a.trees:
		if t.kind != ArenaLayout.Kind.BROADLEAF:
			continue
		var limbs := []
		for l in t.limbs:
			var pts := []
			for p: Vector3 in l[0]:
				pts.append([p.x, p.y, p.z])
			limbs.append({"pts": pts, "r": Array(l[1]), "key": l[2]})
		var perches := []
		for p in a.perches:
			if p.tree_id == t.id:
				perches.append({"a": [p.a.x, p.a.y, p.a.z], "b": [p.b.x, p.b.y, p.b.z], "facing": [p.facing.x, p.facing.z], "outpost": rails.has(p.id)})
		var leaves := []
		for f in t.foliage:
			leaves.append({"c": [f[0].x, f[0].y, f[0].z], "r": [f[1].x, f[1].y, f[1].z]})
		oaks.append({"id": t.id, "base": [t.base.x, t.base.y], "height": t.height, "radius": t.radius,
				"crown_base": t.crown_base, "limbs": limbs, "perches": perches, "leaves": leaves})
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed": a.seed, "oaks": oaks}))
	f.close()
	print("wrote %d oaks to %s" % [oaks.size(), out])
	finish()
