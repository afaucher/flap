extends TestCase
## Diagnostic: how much the oaks take from the wood's sightlines (Pinewood.sightlines, the share of level looks
## reaching 40 m), with the oaks as they are, without their leaves, and without their wood too.
## .\probe.ps1 -Headless probe_oak_sight [--seed 7] [--n 1000]


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_arg := Boot.arg_value(args, "--seed")
	var n_arg := Boot.arg_value(args, "--n")
	var n := int(n_arg) if n_arg != "" else 1000
	var a := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	var hs := [12.0, 18.0, 22.0]
	_report("as grown", Pinewood.sightlines(a, hs, n, 40.0, true), hs)
	for t: ArenaLayout.TreeData in a.trees:
		if t.kind == ArenaLayout.Kind.BROADLEAF:
			t.foliage = []
	_report("oaks without leaves", Pinewood.sightlines(a, hs, n, 40.0, true), hs)
	for t: ArenaLayout.TreeData in a.trees:
		if t.kind == ArenaLayout.Kind.BROADLEAF:
			for br in t.branches:
				br.solid = false
			t.stem = 0.01
	_report("oaks without leaves or limbs", Pinewood.sightlines(a, hs, n, 40.0, true), hs)
	finish()


func _report(what: String, r: Dictionary, hs: Array) -> void:
	print("SIGHT %-28s %s" % [what, ", ".join(hs.map(func(h): return "%.0f m %.0f%%" % [h, float(r[h][2]) * 100.0]))])
