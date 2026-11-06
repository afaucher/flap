extends TestCase
## Diagnostic: trees' limbs as drawn (TreeData.limbs), their trunks, leaf masses and perches, written as JSON for
## tools/tree_side_map.py to draw from the side beside reference pictures: every oak, or (--kind pine) a mature
## pine, a pole and a veteran, each the middle one by height of its age.
## .\probe.ps1 -Headless probe_tree_paths [--kind oak|pine] [--seed 7] [--out <json>]


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_arg := Boot.arg_value(args, "--seed")
	var out := Boot.arg_value(args, "--out")
	if out == "":
		out = ProjectSettings.globalize_path("res://test_logs/tree_paths.json")
	var pines := Boot.arg_value(args, "--kind") == "pine"
	var a := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	var rails := {}
	for o in a.outposts:
		rails[o.rail_perch_id] = true
	var picked: Array = []
	if pines:
		for form in ["", "pole", "veteran"]:
			var of_age := a.trees.filter(func(t): return t.kind == ArenaLayout.Kind.PINE and t.form == form)
			of_age.sort_custom(func(x, y): return x.height < y.height)
			if not of_age.is_empty():
				picked.append(of_age[of_age.size() / 2])
	else:
		picked = a.trees.filter(func(t): return t.kind == ArenaLayout.Kind.BROADLEAF)
	var oaks := []
	for t: ArenaLayout.TreeData in picked:
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
		oaks.append({"id": t.id, "name": ("pine (%s)" % (t.form if t.form != "" else "mature")) if pines else "oak", "base": [t.base.x, t.base.y], "height": t.height, "radius": t.radius,
				"crown_base": t.crown_base, "stem": t.trunk_top().y - ArenaLayout.GROUND_Y, "limbs": limbs, "perches": perches, "leaves": leaves})
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed": a.seed, "oaks": oaks}))
	f.close()
	print("wrote %d trees to %s" % [oaks.size(), out])
	finish()
