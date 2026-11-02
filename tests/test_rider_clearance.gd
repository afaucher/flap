extends TestCase
## The rider doesn't pass through anything, for every species, through every pose (gliding, a whole wingbeat,
## the upstroke, the landing flare, perched -- kneeling or standing -- and the landing's half-rest): a coarse
## net for the big intersections, not a fine fit test (test_tack does those). The rider is taken as capsules
## on the solved joints (torso, head, upper arms, forearms, thighs, shins), each its segment's real girth:
##   - no capsule's axis goes into the bird's body;
##   - the arms stay out of the torso and the head, and the left and right limbs don't cross each other;
##   - no capsule runs into a weapon pod;
##   - no wing feather (a flapping wing included) and not the bird's head comes through the rider.

const POSES := [["glide", 0.0, false], ["flap", 0.0, false], ["flap", 0.125, false], ["flap", 0.25, false], ["flap", 0.375, false], ["upstroke", 0.0, false], ["flare", 0.0, false], ["folded", 0.0, true]]
## real cm: each capsule's radius (a little under the drawn girth: a graze isn't a "major" intersection)
const MAJOR := 0.85   ## a pair counts as intersecting when their axes come within this share of their radii's sum
const R := {"torso": 10.0, "head": 9.0, "upper_arm": 4.5, "forearm": 3.5, "thigh": 6.5, "shin": 4.5}


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	for id in Tack.RIDDEN:
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(BirdProfile.by_id(id))
		var tack := Tack.fit(rig)
		for p in POSES:
			RigPoses.apply(rig, p[0], p[1])
			tack.sitting = p[2]
			tack.update(0.0)
			_check_pose("%s %s %.3f" % [id, p[0], p[1]], rig, tack)
		rig.queue_free()
		await frames(1)
	finish()


## The rider's capsules: [name, a, b, radius] (rig space).
func _capsules(tack: Tack) -> Array:
	var r := tack.rider
	var j := r.joints
	var k := r.k
	var out := [["torso", j.pelvis, j.chest, R.torso * k], ["head", j.head, j.head, R.head * k]]
	for i in 2:
		out.append(["upper_arm%d" % i, j["shoulder%d" % i], j["elbow%d" % i], R.upper_arm * k])
		out.append(["forearm%d" % i, j["elbow%d" % i], j["hand%d" % i], R.forearm * k])
		out.append(["thigh%d" % i, j["hip%d" % i], j["knee%d" % i], R.thigh * k])
		out.append(["shin%d" % i, j["knee%d" % i], j["ankle%d" % i], R.shin * k])
	return out


static func _seg_dist(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	var best := INF
	for u in 9:
		var p := a0.lerp(a1, u / 8.0)
		best = minf(best, p.distance_to(Geometry3D.get_closest_point_to_segment(p, b0, b1)))
	for u in 9:
		var p := b0.lerp(b1, u / 8.0)
		best = minf(best, p.distance_to(Geometry3D.get_closest_point_to_segment(p, a0, a1)))
	return best


func _check_pose(tag: String, rig: BirdRig, tack: Tack) -> void:
	var caps := _capsules(tack)
	var body := rig.body
	# Into the bird's body.
	var into := []
	for c in caps:
		for u in 5:
			var p: Vector3 = (c[1] as Vector3).lerp(c[2], u / 4.0)
			if body.gap(p) < 0.0:
				into.append(c[0])
				break
	eq(into.size(), 0, "%s: the rider stays out of the bird's body %s" % [tag, str(into)])
	# Arms into the torso or the head; left and right limbs through each other.
	var self_hits := []
	var by := {}
	for c in caps:
		by[c[0]] = c
	for i in 2:
		for limb in ["forearm%d" % i, "upper_arm%d" % i]:
			var c: Array = by[limb]
			for other in ["torso", "head"]:
				var o: Array = by[other]
				# (the upper arm starts at the shoulder, on the torso: measure it from a third of the way down)
				var a0: Vector3 = (c[1] as Vector3).lerp(c[2], 0.35) if limb.begins_with("upper") else c[1]
				if _seg_dist(a0, c[2], o[1], o[2]) < (float(c[3]) + float(o[3])) * MAJOR:
					self_hits.append("%s-%s" % [limb, other])
	for limb in ["forearm", "upper_arm", "thigh", "shin"]:
		var a: Array = by[limb + "0"]
		var b: Array = by[limb + "1"]
		if _seg_dist(a[1], a[2], b[1], b[2]) < (float(a[3]) + float(b[3])) * MAJOR:
			self_hits.append(limb + "s crossed")
	eq(self_hits.size(), 0, "%s: the rider's limbs stay out of each other %s" % [tag, str(self_hits)])
	# Into a weapon pod (its axis, behind the trunnion to ahead of it, and its half width).
	var sv := tack.saddle
	var sc := sv.scale.x
	var pods := []
	for m in sv.mounts:
		var pv: Transform3D = m.pivot
		var half: float = (9.5 if m.kind == "rockets" else 7.5) / sv.cm * sc
		pods.append([pv * Vector3(0, 0, 14.0 / sv.cm) * sc, pv * Vector3(0, 0, -60.0 / sv.cm) * sc, half])
	var pod_hits := []
	for c in caps:
		for pd in pods:
			var d := _seg_dist(c[1], c[2], pd[0], pd[1])
			if d < (float(c[3]) + float(pd[2])) * MAJOR:
				pod_hits.append("%s (%.0f of %.0f real cm)" % [c[0], d * sv.cm / sc, (float(c[3]) + float(pd[2])) * sv.cm / sc])
	eq(pod_hits.size(), 0, "%s: the rider stays out of the weapon pods %s" % [tag, str(pod_hits)])
	# The bird through the rider: wing feathers and the head.
	var through := {}
	for xf in rig.feather_xforms:
		var t := xf as Transform3D
		for u in [0.0, 0.5, 1.0]:
			var q: Vector3 = t.origin + t.basis.z * u
			for c in caps:
				var p := Geometry3D.get_closest_point_to_segment(q, c[1], c[2])
				if q.distance_to(p) < float(c[3]) * 0.8:
					through["feathers-" + String(c[0])] = true
	var hc: Vector3 = rig.neck_joints[3] + rig.head_offset
	for c in caps:
		var p := Geometry3D.get_closest_point_to_segment(hc, c[1], c[2])
		if hc.distance_to(p) < body.head_r + float(c[3]) * 0.8:
			through["bird head-" + String(c[0])] = true
	eq(through.size(), 0, "%s: no part of the bird comes through the rider %s" % [tag, str(through.keys())])
