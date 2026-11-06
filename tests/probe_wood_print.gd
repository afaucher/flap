extends TestCase
## Diagnostic: a fingerprint of the wood for a seed, the oaks apart from the rest: every other tree's place, height and
## radius, the openings, the outposts' trees, and the perches off the oaks -- so a change meant to touch only the oaks
## can be checked to leave the rest as it was (run it before and after). .\probe.ps1 -Headless probe_wood_print [--seed 7]


func setup() -> void:
	var seed_arg := Boot.arg_value(OS.get_cmdline_user_args(), "--seed")
	var a := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	var oaks := {}
	var rest := []
	for t in a.trees:
		if t.kind == ArenaLayout.Kind.BROADLEAF:
			oaks[t.id] = true
		else:
			rest.append([t.kind, t.form, snappedf(t.base.x, 0.001), snappedf(t.base.y, 0.001), snappedf(t.height, 0.001), snappedf(t.radius, 0.001), t.branches.size()])
	var perches := []
	for p in a.perches:
		if not oaks.has(p.tree_id):
			perches.append([p.tree_id, snappedf(p.position.x, 0.01), snappedf(p.position.y, 0.01), snappedf(p.position.z, 0.01)])
	var outposts := []
	for o in a.outposts:
		outposts.append(o.tree_id)
	print("trees (not oaks) %d  %d" % [rest.size(), hash(str(rest))])
	print("their places (kind, age, place, height, radius) %d" % hash(str(rest.map(func(r): return r.slice(0, 6)))))
	print("openings %d" % hash(str(a.openings)))
	print("perches (not on oaks) %d  %d" % [perches.size(), hash(str(perches))])
	print("outposts on trees %s" % [outposts])
	var on_oaks := 0
	for p in a.perches:
		on_oaks += int(oaks.has(p.tree_id))
	print("oaks %d, perches on them %d" % [oaks.size(), on_oaks])
	for q in perches:
		print("PERCHDUMP ", q)
	for o in a.outposts:
		print("OUTDUMP ", o.tree_id, " ", o.centre.snappedf(0.01), " ", o.out.snappedf(0.01))
	for sd in [1, 2]:
		var r := Pinewood.sightlines(a, [5.0, 12.0, 18.0], 1000, 40.0, true, sd)
		print("SIGHT12 seed %d: 5 m %.0f%%, 12 m %.0f%%, 18 m %.0f%%" % [sd, r[5.0][2] * 100.0, r[12.0][2] * 100.0, r[18.0][2] * 100.0])
	finish()
