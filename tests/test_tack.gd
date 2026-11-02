extends TestCase
## The war tack (scripts/tack), measured on what's built and posed, for each species big enough to ride:
## the pad and skirt sit snugly on the trunk (on it, never in it) and stay on the strip of back the wings
## never reach; the harness straps lie flat on the body; no wing feather, folded or beating, comes into the
## saddle's space; the head misses the launcher and the rider, perched (neck retracted) and in flight; the
## rider rides the seat in a racer's tuck in flight (knees into the tank, feet on the side pegs) and stands upright on the footrest perched, knees hinging like knees
## (bent forward, within a human range) left and right, hands within reach of the grips; on a shallow perch
## (the crow) the rider kneels up instead of standing; the owl and the sparrow carry none; the launcher points
## along the body and shows the rounds left.



func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	for id in Tack.RIDDEN:
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(BirdProfile.by_id(id))
		var tack := Tack.fit(rig)
		_fit(id, rig, tack)
		for pose in ["glide", "folded"]:
			RigPoses.apply(rig, pose, 0.0)
			tack.sitting = pose == "folded"
			tack.update(0.0)
			_rider(id, pose, rig, tack)
			_head(id, pose, rig, tack)
		_wings(id, rig, tack)
		_launcher(id, tack)
		_goggles(id, tack)
		rig.queue_free()
		await frames(1)
	finish()


## The goggle strap runs from each cup's outer rim round the back of the helmet: nothing of it lies across
## the face between the cups, and it reaches both cups (goggles' own frame, real cm; the face is within 9.2
## of the head's centre, the cups at x = +-3.6).
func _goggles(id: String, tack: Tack) -> void:
	var mi := tack.rider.get_node("head/goggles").get_child(0) as MeshInstance3D
	var k := tack.rider.k
	var across := 0
	var cups := [0, 0]
	var behind := 0
	for v in ((mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		var p := v / k
		if p.z < -8.0:
			if absf(p.x) < 5.5:
				across += 1
			else:
				cups[0 if p.x < 0.0 else 1] += 1
		elif p.z > 8.0:
			behind += 1
	eq(across, 0, "%s: no goggle strap across the face" % id)
	check(cups[0] > 0 and cups[1] > 0, "%s: the goggle strap reaches both cups" % id)
	check(behind > 0, "%s: the goggle strap goes round the back" % id)


## Vertices of the saddle's mesh for material `id`, rig space.
func _verts(tack: Tack, id: String) -> PackedVector3Array:
	var mi := tack.saddle.get_node("Tack_" + id) as MeshInstance3D
	var out := PackedVector3Array()
	var m := mi.mesh as ArrayMesh
	for sfc in m.get_surface_count():
		for v in (m.surface_get_arrays(sfc)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			out.append(tack.saddle.transform * v)
	return out


func _fit(id: String, rig: BirdRig, tack: Tack) -> void:
	var b := rig.body
	RigPoses.apply(rig, "glide", 0.0)
	tack.update(0.0)
	for part in ["fleece", "saddle"]:
		var vs := _verts(tack, part)
		var lo := INF
		var low_elev := 90.0
		var gaps := []
		for v in vs:
			var g := b.gap(v)
			lo = minf(lo, g)
			gaps.append(g)
			low_elev = minf(low_elev, rad_to_deg(atan2(v.y - b.ring_at(v.z)[0], absf(v.x))))
		gaps.sort()
		check(lo > -0.0003, "%s: the %s is never inside the body (deepest %.2f mm)" % [id, part, lo * 1000.0])
		check(float(gaps[gaps.size() / 20]) < 0.0012, "%s: the %s sits on it (5th percentile %.2f mm off)" % [id, part, float(gaps[gaps.size() / 20]) * 1000.0])
		check(low_elev > Saddle.FREE_ELEVATION, "%s: the %s stays on the back (lowest at %.0f deg elevation)" % [id, part, low_elev])
	var worst := 0.0
	var inside := 0.0
	for path in tack.saddle.strap_paths:
		for p in (path as PackedVector3Array):
			worst = maxf(worst, b.gap(p))
			inside = minf(inside, b.gap(p))
	check(worst < 0.0012 and inside > -0.0003, "%s: harness straps lie flat on the body (%.2f .. %.2f mm off)" % [id, inside * 1000.0, worst * 1000.0])
	check(tack.saddle.strap_paths.size() == 4, "%s: two loops, each in front of and behind one wing" % id)


## No wing feather comes into the saddle's space: over the back strip (above FREE_ELEVATION) along the
## saddle's length and within 4 cm of the shell -- folded, gliding, and through a wingbeat.
func _wings(id: String, rig: BirdRig, tack: Tack) -> void:
	var b := rig.body
	var zs := []
	for v in _verts(tack, "fleece"):
		zs.append(v.z)
	zs.sort()
	var z0: float = zs[0]
	var z1: float = zs[zs.size() - 1]
	var states := [["folded", 0.0], ["glide", 0.0], ["upstroke", 0.0]]
	for k in 8:
		states.append(["flap", k / 16.0])
	for s in states:
		RigPoses.apply(rig, s[0], s[1])
		var n := 0
		for xf in rig.feather_xforms.slice(0, rig.feather_xforms.size() - BirdRig.TAIL_FEATHERS):
			var t := xf as Transform3D
			for u in [0.0, 0.5, 1.0]:
				for w in [-0.5, 0.5]:
					var q: Vector3 = t.origin + t.basis.z * u + t.basis.x * w
					if q.z < z0 or q.z > z1 or b.gap(q) > 0.04:
						continue
					if rad_to_deg(atan2(q.y - b.ring_at(q.z)[0], absf(q.x))) > Saddle.FREE_ELEVATION:
						n += 1
		eq(n, 0, "%s %s %.2f: no wing feather in the saddle's space" % [id, s[0], s[1]])


func _rider(id: String, pose: String, rig: BirdRig, tack: Tack) -> void:
	var r := tack.rider
	var j := r.joints
	var b := rig.body
	var up := rig.world_up
	var torso: Vector3 = (j.chest as Vector3) - (j.pelvis as Vector3)
	var fwd := -(r.get_node("pelvis") as MeshInstance3D).transform.basis.z
	var standing := r.stand > 0.5
	if pose == "folded":
		check(rad_to_deg(torso.angle_to(up)) < 15.0, "%s perched: the rider is upright (%.0f deg off)" % [id, rad_to_deg(torso.angle_to(up))])
		eq(standing, id != "crow", "%s perched: %s" % [id, "stands on the footrest (a steep back)" if id != "crow" else "kneels up (a shallow back)"])
	else:
		var lean := rad_to_deg(torso.angle_to(tack.saddle.seat_normal))
		check(lean > 40.0 and lean < 70.0, "%s flying: the rider tucks down over the launcher (%.0f deg)" % [id, lean])
		check((j.pelvis as Vector3).distance_to(tack.saddle.seat_point) < r.height * 0.15, "%s flying: on the seat" % id)
	for i in 2:
		var side := "left" if i == 0 else "right"
		var hip: Vector3 = j["hip%d" % i]
		var kn: Vector3 = j["knee%d" % i]
		var an: Vector3 = j["ankle%d" % i]
		var flex := 180.0 - rad_to_deg((hip - kn).angle_to(an - kn))
		check(flex >= 0.0 and flex <= 165.0, "%s %s %s knee bends %.0f deg (0..165)" % [id, pose, side, flex])
		check((kn - (hip + an) * 0.5).dot(fwd) > 0.0, "%s %s %s knee points forward (hinges like a knee)" % [id, pose, side])
		var support: Vector3 = tack.saddle.pegs[i] if standing else tack.saddle.heels[i]
		check(an.distance_to(support) < r.height * 0.15, "%s %s %s foot on its support (%.1f mm)" % [id, pose, side, an.distance_to(support) * 1000.0])
		var sh: Vector3 = j["shoulder%d" % i]
		var reach := r._r("upper_arm") + r._r("forearm")
		var hold: Vector3 = tack.saddle.holds[i] if standing else tack.saddle.grips[i]
		check(sh.distance_to(hold) < reach * 1.02, "%s %s %s hand reaches its %s (%.1f of %.1f mm)" % [id, pose, side, "hand loop" if standing else "grip", sh.distance_to(hold) * 1000.0, reach * 1000.0])
	# The rider's body clears the launcher (the torso, a capsule from the pelvis to the chest).
	var pel: Vector3 = j.pelvis
	var che: Vector3 = j.chest
	var closest := INF
	for v in _verts(tack, "blued"):
		closest = minf(closest, v.distance_to(Geometry3D.get_closest_point_to_segment(v, pel, che)))
	check(closest > r._r("hip_w") * 0.9, "%s %s: the rider's body clears the launcher (%.1f mm)" % [id, pose, closest * 1000.0])
	# Nothing of the rider inside the bird.
	for key in j:
		check(b.gap(j[key] as Vector3) > 0.0015, "%s %s: rider's %s clear of the body (%.1f mm)" % [id, pose, key, b.gap(j[key] as Vector3) * 1000.0])


func _head(id: String, pose: String, rig: BirdRig, tack: Tack) -> void:
	var hc: Vector3 = rig.neck_joints[3] + rig.head_offset
	var hr := rig.body.head_r * 1.1
	var hits := 0
	for part in ["blued", "brass"]:
		for v in _verts(tack, part):
			if v.distance_to(hc) < hr:
				hits += 1
	for key in tack.rider.joints:
		if (tack.rider.joints[key] as Vector3).distance_to(hc) < hr + tack.rider.height * 0.06:
			hits += 1
	eq(hits, 0, "%s %s: the head clears the launcher and the rider" % [id, pose])


func _launcher(id: String, tack: Tack) -> void:
	var s := tack.saddle
	var axis := (s.muzzle - s.launcher_xf.origin).normalized()
	check(axis.angle_to(Vector3.FORWARD) < deg_to_rad(5.0), "%s: the launcher points along the body" % id)
	tack.set_ammo(4, 1)
	var shown := 0
	for r in s.rockets:
		shown += int(r.visible)
	eq(shown, 4, "%s: rockets left show in their tubes" % id)
	shown = 0
	for k in s.seekers:
		shown += int(k.visible)
	eq(shown, 1, "%s: seekers left show on the rack" % id)
	eq(s.rockets.size(), 6, "%s: six tubes" % id)
