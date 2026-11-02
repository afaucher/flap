extends TestCase
## Diagnostic (run by name): the detailed toes' curl on the folded pose's branch -- each toe's turns (deg: root,
## joints, claw base), and how far its joints and claw tip sit from the branch's axis against the bark's radius.


func setup() -> void:
	var was := LegRig.enabled
	LegRig.enabled = true
	for id: String in ["hawk", "owl", "sparrow"]:
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(BirdProfile.by_id(id))
		RigPoses.apply(rig, "folded", 0.0)
		var lr := rig.legs
		var fr := lr._pad_frame(1, rig.leg_joints[1][3], rig._world_frame()[0], rig._world_frame()[1])
		var right: Vector3 = rig._world_frame()[1].cross(rig._world_frame()[0]).normalized()
		var axis_p: Vector3 = (fr[0] as Vector3) - (fr[2] as Vector3) * (lr.sole_height() + rig.grip_radius)
		for k in 4:
			var yaw := deg_to_rad(float(LegRig.YAW[k]))
			var base := ((fr[3] as Vector3) * cos(yaw) + right * sin(yaw)).normalized()
			var phal: Array = LegRig.PHALANGES[k]
			var length := float(lr.spec.toe) * lr.L * float(lr.spec.toe_len[k])
			var t := lr._curl(phal, length, float(lr.spec.toe_r) * lr.L, float(lr.spec.claws[LegRig.CLAW_OF[k]]) * lr.L, deg_to_rad(float(lr.spec.arc)), base, fr)
			var deg := PackedStringArray()
			for a in t:
				deg.append("%.0f" % rad_to_deg(a))
			var tip: Vector3 = lr.toe_tips[1][k]
			var q := tip - axis_p
			var dist := (q - right * q.dot(right)).length()
			print("%s toe %d turns [%s]  tip from axis %.4f (bark %.4f)" % [id, k, ", ".join(deg), dist, rig.grip_radius])
		rig.queue_free()
	LegRig.enabled = was
	finish()
