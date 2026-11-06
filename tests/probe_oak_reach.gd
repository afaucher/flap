extends TestCase
## Diagnostic: every perch on the oaks, whether the AI's planner finds a way to it from the start perch, and the
## perch's height, slope and reach from its trunk. .\probe.ps1 -Headless probe_oak_reach [--seed 7]


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var seed_arg := Boot.arg_value(OS.get_cmdline_user_args(), "--seed")
	var a := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	var planner := FlightPlanner.new(a)
	var sp := a.start_perch()
	print("start perch %d on tree %d at %s" % [sp.id, sp.tree_id, sp.position])
	var ok := 0
	var bad := 0
	for p in a.perches:
		var t: ArenaLayout.TreeData = a.trees[p.tree_id] if p.tree_id >= 0 else null
		if t == null or t.kind != ArenaLayout.Kind.BROADLEAF:
			continue
		var route := planner.plan_to_perch(sp.position + sp.facing, p, BirdProfile.crow(), sp.tree_id)
		var d := p.b - p.a
		var slope := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
		var out := Vector2(p.position.x - t.base.x, p.position.z - t.base.y).length()
		if route.size() >= 2:
			ok += 1
		else:
			bad += 1
		print("oak %d perch %d  y %.1f  out %.1f  slope %+.0f  len %.1f  %s" % [t.id, p.id, p.position.y, out, slope, d.length(), "route" if route.size() >= 2 else "NO ROUTE"])
	print("oak perches with a route %d, without %d" % [ok, bad])
	finish()
