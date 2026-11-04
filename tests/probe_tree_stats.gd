extends TestCase
## Diagnostic: the pine wood's trees by kind -- how many, their heights, trunk radii, crown bases.
func setup() -> void:
	var a := Pinewood.generate(7)
	var by := {}
	for t in a.trees:
		var k: String = ArenaLayout.Kind.keys()[t.kind] + ("" if t.form == "" else " " + t.form)
		if not by.has(k):
			by[k] = []
		by[k].append(t)
	for k in by:
		var hs := []
		var rs := []
		var cb := []
		for t in by[k]:
			hs.append(t.height)
			rs.append(t.radius)
			cb.append(t.crown_base / maxf(t.height, 0.01))
		hs.sort()
		rs.sort()
		cb.sort()
		print("TREES %s: %d, height %.1f..%.1f (median %.1f), trunk radius %.2f..%.2f, crown base at %.0f..%.0f %% of height" % [k, hs.size(), hs[0], hs[-1], hs[hs.size() / 2], rs[0], rs[-1], cb[0] * 100, cb[-1] * 100])
	finish()
