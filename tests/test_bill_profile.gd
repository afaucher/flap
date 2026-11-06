extends TestCase
## The bills as drawn against their reference photos (docs/images/beak_profiles_*.jpg; tools/beak_profiles.py): each
## species' bill in profile -- the top and bottom of its silhouette along it, its tip -- where the traced photo has
## them; the eye as far behind the bill's base as in the photo; the mandibles meeting along the gape; the bill
## the same both sides; the cere ending and the nostril sitting on the bill as drawn; the bill's base on the face
## (the snout drawn out to it); the eyes facing out from where they sit.
##
## Units: head radii, in the bill's frame (Face.beak_meshes: the culmen's base at the origin, x forward along the gape
## line, y up). REF is read off the photo traces in tools/beak_profiles.py (the culmen, gape and underside lines,
## scaled by the measured bill and the life head; tools/bill_profiles_emit.py's `curves`), not the ribs the mesh is
## lofted on: at five points along the culmen's reach [x, top, bottom] (a quarter of the way to 0.85, clear of
## where a line starts), the tip, the eye's centre.
const REF := {
	"crow": {"tip": [1.893, -0.769], "eye": [-0.423, -0.542], "at": [[0.473, -0.137, -0.876], [0.757, -0.188, -0.832], [1.041, -0.254, -0.811], [1.325, -0.345, -0.793], [1.609, -0.478, -0.787]]},
	"sparrow": {"tip": [0.978, -0.591], "eye": [-1.013, -0.061], "at": [[0.244, -0.089, -0.753], [0.391, -0.151, -0.728], [0.538, -0.236, -0.698], [0.685, -0.337, -0.669], [0.831, -0.447, -0.642]]},
	"hawk": {"tip": [0.793, -0.791], "eye": [-0.898, -0.415], "at": [[0.208, 0.006, -0.616], [0.333, -0.048, -0.611], [0.458, -0.086, -0.603], [0.583, -0.166, -0.593], [0.708, -0.295, -0.631]]},
	"falcon": {"tip": [0.448, -0.787], "eye": [-0.568, 0.051], "at": [[0.125, -0.063, -0.624], [0.199, -0.13, -0.631], [0.274, -0.195, -0.623], [0.349, -0.247, -0.595], [0.424, -0.314, -0.667]]},
	# (the owl: its lower bill isn't seen in the photo, and its bill is set in the facial disc: the culmen and tip only)
	"owl": {"tip": [0.291, 0.000], "at": [[0.073, 0.106], [0.116, 0.121], [0.16, 0.118], [0.204, 0.103], [0.247, 0.075]]},
}
const EYE_SHARE := 0.85   ## the eye at least this share of the photo's distance behind the culmen's base


func setup() -> void:
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		rig.look_dir = Vector3.FORWARD
		rig.apply_pose()
		var id := p.id
		var hr := rig.body.head_r
		var ref: Dictionary = REF[id]
		var base := Face.bill_base(id, hr, rig.body.skull)
		var unpitch := Basis(Vector3.RIGHT, deg_to_rad(float(Face.spec(id).beak.pitch))).inverse()
		var frame := func(v: Vector3) -> Vector3:   # head space -> the bill's frame (x forward, y up, z across)
			var q: Vector3 = unpitch * (v - base) / hr
			return Vector3(-q.z, q.y, q.x)
		var up := _outside(rig, "BeakUpper", 0.0, frame)
		var lo := _outside(rig, "Jaw/BeakLower", 2.0 / 3.0, frame)
		var lines := [up.top, up.bottom, lo.top, lo.bottom]
		var length: float = ref.tip[0]
		var tol := 0.03 + 0.04 * length
		# The silhouette along the bill, top and bottom, as the photo's.
		for st in ref.at:
			var top := _extent(lines, float(st[0]), true)
			near(top, float(st[1]), tol, "%s bill's top at x %.2f r (drawn %.3f, photo %.3f)" % [id, st[0], top, st[1]])
			if st.size() > 2:
				var bottom := _extent(lines, float(st[0]), false)
				near(bottom, float(st[2]), tol, "%s bill's bottom at x %.2f r (drawn %.3f, photo %.3f)" % [id, st[0], bottom, st[2]])
		# The tip: the upper bill's furthest point from the culmen's base, ahead of it.
		var tip := Vector3.ZERO
		for v in up.pts:
			if v.x > 0.0 and Vector2(v.x, v.y).length() > Vector2(tip.x, tip.y).length():
				tip = v
		check(Vector2(tip.x, tip.y).distance_to(Vector2(ref.tip[0], ref.tip[1])) < tol,
			"%s bill's tip at (%.3f, %.3f) r, the photo's (%.3f, %.3f)" % [id, tip.x, tip.y, ref.tip[0], ref.tip[1]])
		# The mandibles meet along the gape: over the lower bill's length, its top reaches the upper's cutting edge (not
		# the owl's: its lower bill is hidden in the disc, made up, not traced).
		if ref.has("eye"):
			var lo_start: float = lo.top[0].x
			var lo_end: float = lo.top[-1].x
			var worst := 0.0
			for k in 7:
				var x := lerpf(lo_start, lo_end, 0.05 + 0.8 * k / 6.0)
				worst = maxf(worst, _extent([up.bottom], x, false) - _extent([lo.top], x, true))
			check(worst < 0.015, "%s mandibles meet along the gape (widest gap %.3f r)" % [id, worst])
		# The same both sides.
		var left := 0.0
		var right := 0.0
		for v in up.pts + lo.pts:
			left = minf(left, v.z)
			right = maxf(right, v.z)
		near(-left, right, 1e-4 + 1e-3 * right, "%s bill the same both sides" % id)
		# The eye as far behind the bill's base as in the photo (the owl's bill is in its disc: not held to it).
		var eye: Node3D = rig._head.find_child("EyeR", true, false)
		var e: Vector3 = frame.call((rig._head.global_transform.affine_inverse() * eye.global_transform).origin)
		if ref.has("eye"):
			var want := Vector2(ref.eye[0], ref.eye[1]).length()
			var got := Vector2(e.x, e.y).length()
			check(got > EYE_SHARE * want and got < want * 1.15, "%s eye %.2f r behind the bill's base, the photo's %.2f" % [id, got, want])
		# Each eye faces out from where it sits (a cap turned off the head's surface sinks into it on one side).
		for side in ["EyeL", "EyeR"]:
			var en: Node3D = rig._head.find_child(side, true, false)
			if not Face.spec(id).has("disc"):
				var out_dir := en.position.normalized()   # (in the skull's unscaled sphere)
				check((-en.basis.z).dot(out_dir) > 0.999, "%s %s faces out from its seat (%.4f)" % [id, side, (-en.basis.z).dot(out_dir)])
		# The bill's base on the face: the head's drawn surface reaches the culmen's base (the snout drawn out to it).
		var hm := (rig._head.get_node("HeadSurface") as MeshInstance3D)
		var hx := rig._head.global_transform.affine_inverse() * hm.global_transform
		var gap := INF
		for v in (hm.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			gap = minf(gap, (hx * (v as Vector3)).distance_to(base))
		check(gap < 0.15 * hr, "%s bill's base on the face (head surface %.3f r from it)" % [id, gap / hr])
		# The cere ends, and the nostril sits, on the bill as drawn.
		var marks: Dictionary = BillProfiles.DATA[id].marks
		if marks.has("cere ends"):
			var c: Array = marks["cere ends"]
			var top_c := _extent([up.top], float(c[0]), true)
			near(top_c, float(c[1]), 0.03, "%s cere ends on the drawn culmen (%.3f, %.3f)" % [id, top_c, c[1]])
		var n: Array = Face.spec(id).beak.nostril
		if n.size() == 4:
			var hi := _extent([up.top], float(n[0]), true)
			var low := _extent([up.bottom], float(n[0]), false)
			check(float(n[1]) + float(n[3]) < hi and float(n[1]) - float(n[3]) > low,
				"%s nostril on the upper bill's side (%.3f between %.3f and %.3f)" % [id, n[1], low, hi])
		rig.queue_free()
	finish()


## The mandible's outside surface (COLOR.g: `part`) in the bill's frame, ring by ring along the bill (UV.x; the base's
## section, and its heel carried into the head, left out): {"pts": every point, "top": each ring's highest point,
## "bottom": its lowest} (the rings' tops and bottoms are the profile's lines, as the photo's were traced).
func _outside(rig: BirdRig, path: String, part: float, frame: Callable) -> Dictionary:
	var mi := rig._head.get_node(path) as MeshInstance3D
	var xf := rig._head.global_transform.affine_inverse() * mi.global_transform
	var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var cs := arr[Mesh.ARRAY_COLOR] as PackedColorArray
	var uv := arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var vs := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var rings := {}
	var pts: Array = []
	for k in vs.size():
		if absf(cs[k].g - part) > 0.05 or uv[k].x <= 0.0:
			continue
		var v: Vector3 = frame.call(xf * vs[k])
		pts.append(v)
		var key := snappedf(uv[k].x, 1e-4)
		if not rings.has(key):
			rings[key] = [v, v]
		if v.y > rings[key][0].y:
			rings[key][0] = v
		if v.y < rings[key][1].y:
			rings[key][1] = v
	var keys := rings.keys()
	keys.sort()
	var top: Array = []
	var bottom: Array = []
	for key in keys:
		top.append(rings[key][0])
		bottom.append(rings[key][1])
	return {"pts": pts, "top": top, "bottom": bottom}


## The profile's top (or bottom) at x: where the given lines cross x, the highest (lowest).
func _extent(lines: Array, x: float, top: bool) -> float:
	var best := -INF if top else INF
	for line in lines:
		for i in line.size() - 1:
			var a: Vector3 = line[i]
			var b: Vector3 = line[i + 1]
			if (a.x - x) * (b.x - x) <= 0.0 and absf(b.x - a.x) > 1e-9:
				var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
				best = maxf(best, y) if top else minf(best, y)
	return best
