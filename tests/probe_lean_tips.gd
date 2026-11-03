extends TestCase
## Which feathers' tips decide a sitting bird's lean (BirdRig._posture: the deepest of every feather's tip)? Runs
## test_posture's scenes (every species across and along the thinnest and thickest branch, and on the ground), and
## each frame compares the deepest tip of all feathers with the deepest of a few subsets. Prints per kind how often it
## was the deepest, and per subset the most it misses by while the lean is deciding (the deepest within 3 % L).


const KINDS := ["primary", "secondary", "tertial", "alula", "greater", "lesser", "tail", "under"]
var _counts := {}
var _miss := {"tail+primaries": 0.0, "tail": 0.0, "tail+primaries+tertials": 0.0, "tail+primaries+secondaries+tertials": 0.0}
var _frames := 0


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var layout := ArenaLayout.generate(7)
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var thin: Perch = null
	var thick: Perch = null
	for q in layout.perches:
		if q.kind == Perch.Kind.BRANCH:
			thin = q if thin == null or q.thickness < thin.thickness else thin
			thick = q if thick == null or q.thickness > thick.thickness else thick
	for p in BirdProfile.all():
		for perch: Perch in [thin, thick]:
			var b := Bird.new()
			add_child(b)
			b.setup(p, layout, ScriptedInput.new())
			b.arena = arena
			b.perch_at(perch)
			await _watch(b, 90)
			var along := perch.b - perch.a
			along.y = 0.0
			b.facing = along.normalized()
			await _watch(b, 150)
			b.queue_free()
			await frames(1)
		var g := Bird.new()
		add_child(g)
		g.setup(p, layout, ScriptedInput.new())
		g.arena = arena
		g.fly_from(Vector3(0, 0.3, 0), Vector3(1, -1, 0).normalized(), 1.0)
		await _watch(g, 180)
		g.queue_free()
		await frames(1)
	print("frames deciding: %d" % _frames)
	for k in _counts:
		print("  deepest: %-10s %d" % [k, _counts[k]])
	for s in _miss:
		print("  subset %-38s misses by at most %.5f m" % [s, _miss[s]])
	finish()


func _watch(b: Bird, n: int) -> void:
	for i in n:
		await frames(1)
		var srf: Dictionary = b.telemetry().surface
		if srf.is_empty() or b.rig.feather_xforms.is_empty():
			continue
		var xf := b.rig.global_transform
		var worst := -INF
		var wk := -1
		var by := {}
		for k in b.rig.feather_xforms.size():
			var f: Transform3D = b.rig.feather_xforms[k]
			var d := BirdRig._depth(srf, xf * (f.origin + f.basis.z))
			var kind: int = b.rig.feather_kinds[k] % 100
			by[kind] = maxf(float(by.get(kind, -INF)), d)
			if d > worst:
				worst = d
				wk = kind
		if worst < -b.rig._L * 0.03:
			continue
		_frames += 1
		var name: String = KINDS[wk] if wk < KINDS.size() else str(wk)
		_counts[name] = int(_counts.get(name, 0)) + 1
		var t: float = by.get(6, -INF)
		var pr: float = by.get(WingShape.Kind.PRIMARY, -INF)
		var te: float = by.get(WingShape.Kind.TERTIAL, -INF)
		var se: float = by.get(WingShape.Kind.SECONDARY, -INF)
		_miss["tail"] = maxf(_miss["tail"], worst - t)
		_miss["tail+primaries"] = maxf(_miss["tail+primaries"], worst - maxf(t, pr))
		_miss["tail+primaries+tertials"] = maxf(_miss["tail+primaries+tertials"], worst - maxf(maxf(t, pr), te))
		_miss["tail+primaries+secondaries+tertials"] = maxf(_miss["tail+primaries+secondaries+tertials"], worst - maxf(maxf(t, pr), maxf(te, se)))
