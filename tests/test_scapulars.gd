extends TestCase
## The scapular cards (BirdRig.CARD_TRACTS "scapular", docs/research/scapulars.md), measured as drawn: spread, they
## lie out over the wing's root beside the body -- where the arm wing's trailing edge leaves a gap to the innermost
## tertials, and the white underwing showed through -- running nearly straight back and flat on what is under them
## (no card standing off the bird); folded, they stay on the back, inside its outline; each side follows its own
## wing's fold (both ways).

const SHARDS := 2


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	Plumage.level = 6
	var birds := BirdProfile.all()
	for bi in birds.size():
		if not in_shard(bi % SHARDS):
			continue
		_check_bird(birds[bi])
	finish()


func _check_bird(p: BirdProfile) -> void:
	var rig := BirdRig.new()
	add_child(rig)
	rig.build(p)
	var inv: Transform3D = rig._trunk.transform.affine_inverse()
	RigPoses.apply(rig, "glide", 0.0)
	rig.apply_pose()
	var L: float = rig._L
	var sh: Vector3 = inv * (rig.wing_joints[1][0] as Vector3)
	var scap := _scapulars(rig)
	check(scap.size() >= 12, "%s: scapular cards drawn (%d)" % [p.id, scap.size()])
	for side: float in [-1.0, 1.0]:
		# The gap: beside the body, behind the shoulder, out toward the innermost tertial's root.
		var xt := INF
		for fi in rig.feather_xforms.size():
			if rig.feather_kinds[fi] == WingShape.Kind.TERTIAL:
				var o: Vector3 = inv * rig.feather_xforms[fi].origin
				xt = minf(xt, absf(o.x))   # (the wings mirror)
		var covered := 0
		var n := 0
		# (0.1-0.22 L behind the shoulder: behind the arm wing's covert web at the root, where the white showed through;
		# in front of it the arm wing itself covers the root)
		for k in 6:
			var z := sh.z + lerpf(0.1, 0.22, k / 5.0) * L * signf(rig.body.back_z() - rig.body.front_z())
			var w: float = rig.body.ring_at(z)[1]
			if not is_finite(xt) or xt <= w:
				continue
			var x := side * (w + 0.3 * (xt - w))
			n += 1
			if _covered(scap, side, Vector2(x, z)):
				covered += 1
			elif side > 0.0:
				print("  %s: uncovered at x %.3f z %.3f (body %.3f, tertial %.3f, shoulder z %.3f)" % [p.id, x, z, w, xt, sh.z])
		var need := 0.8 if float(BirdRig.SCAP_REACH.get(p.id, 0.8)) >= 0.99 else 0.5
		check(n > 0 and covered >= need * n, "%s side %+d: the scapulars lie over the wing's root beside the body (%d of %d points)" % [p.id, int(side), covered, n])
	# Each card runs nearly straight back, lies flat (its face up, not on edge) and its tip on what is under it.
	var worst_angle := 0.0
	var worst_up := 1.0
	var worst_tip := 0.0
	for xf: Transform3D in scap:
		var d := xf.basis.z.normalized()
		var back := Vector3(0, 0, signf(rig.body.back_z() - rig.body.front_z()))
		var plan := Vector3(d.x, 0.0, d.z).normalized()
		worst_angle = maxf(worst_angle, rad_to_deg(plan.angle_to(back)))
		worst_up = minf(worst_up, xf.basis.y.normalized().y)
		var tip := xf * Vector3(0, 0, 1)
		# (under it: the back's shell inside its outline, or the wing's root, as high as the shoulder -- the higher)
		var w: float = rig.body.ring_at(tip.z)[1]
		var surf: float = maxf(rig._shell_top(tip.x, tip.z) if absf(tip.x) < w else -INF, sh.y)
		worst_tip = maxf(worst_tip, absf(tip.y - surf))
	check(worst_angle < 32.0, "%s: the scapulars run nearly straight back (worst %.1f deg off)" % [p.id, worst_angle])
	check(worst_up > 0.6, "%s: and lie face up (worst up %.2f)" % [p.id, worst_up])
	check(worst_tip < 0.035 * L, "%s: each tip on what is under it (worst %.4f m, L %.3f)" % [p.id, worst_tip, L])
	# Folded: on the back, inside its outline.
	RigPoses.apply(rig, "folded", 0.0)
	rig.apply_pose()
	var out := -INF
	for xf: Transform3D in _scapulars(rig):
		var tip := xf * Vector3(0, 0, 1)
		out = maxf(out, absf(tip.x) - float(rig.body.ring_at(tip.z)[1]))
	check(out < 0.0, "%s: folded, the scapulars' tips stay inside the body's outline (worst %.4f m past it)" % [p.id, out])
	# Each side follows its own wing: fold the left alone, then the right alone.
	RigPoses.apply(rig, "glide", 0.0)
	rig.apply_pose()
	var spread := _side_reach(rig)
	for wi in 2:
		rig.roll_fold[wi] = 0.6
		rig.roll_fold[1 - wi] = 0.0
		rig.apply_pose()
		var r := _side_reach(rig)
		check(r[wi] < spread[wi] - 0.005 * L and absf(r[1 - wi] - spread[1 - wi]) < 0.1 * (spread[wi] - r[wi]), "%s: folding wing %d draws in its own scapulars only (%.4f -> %.4f, other %.4f -> %.4f)" % [p.id, wi, spread[wi], r[wi], spread[1 - wi], r[1 - wi]])
	rig.roll_fold[0] = 0.0
	rig.roll_fold[1] = 0.0
	rig.queue_free()


func _scapulars(rig: BirdRig) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for ci in rig.card_xforms.size():
		if rig.card_tracts[ci] == "scapular":
			out.append(rig.card_xforms[ci])
	return out


## Each side's scapulars' furthest tip out from the midline (left, right).
func _side_reach(rig: BirdRig) -> Array:
	var r := [0.0, 0.0]
	for xf: Transform3D in _scapulars(rig):
		var tip := xf * Vector3(0, 0, 1)
		var i := 0 if tip.x < 0.0 else 1
		r[i] = maxf(r[i], absf(tip.x))
	return r


## Whether a plan point (x, z) lies under one of this side's cards (its vane: from 15 % to 90 % of its length, the middle
## 90 % of its width).
func _covered(cards: Array[Transform3D], side: float, pt: Vector2) -> bool:
	for xf: Transform3D in cards:
		if xf.origin.x * side <= 0.0:
			continue
		var c := [xf * Vector3(-0.45, 0, 0.15), xf * Vector3(0.45, 0, 0.15), xf * Vector3(0.45, 0, 0.9), xf * Vector3(-0.45, 0, 0.9)]
		var poly := PackedVector2Array()
		for v: Vector3 in c:
			poly.append(Vector2(v.x, v.z))
		if Geometry2D.is_point_in_polygon(pt, poly):
			return true
	return false
