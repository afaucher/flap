extends TestCase
## Diagnostic: where each species' launcher is drawn (rig space, the glide pose) against where the combat code
## fires from (Launcher.muzzle: 0.6 L ahead of the bird's middle, 0.1 L up), and whether the line of fire
## from the drawn muzzle clears the bird's head. Units: cm.

func setup() -> void:
	for id in BirdProfile.IDS:
		var rig := BirdRig.new()
		add_child(rig)
		var prof := BirdProfile.by_id(id)
		rig.build(prof)
		RigPoses.apply(rig, "glide", 0.0)
		var L := prof.body_length
		var hc: Vector3 = rig.neck_joints[3] + rig.head_offset
		var hr := rig.body.head_r
		var combat := Vector3(0.0, 0.1 * L, -0.6 * L)
		var line := "%-8s L %4.1f  head (%.1f, %.1f, %.1f) r %.1f  combat muzzle (%.1f, %.1f, %.1f)" % [id, L * 100, hc.x * 100, hc.y * 100, hc.z * 100, hr * 100, combat.x * 100, combat.y * 100, combat.z * 100]
		if Tack.RIDDEN.has(id):
			var tack := Tack.fit(rig)
			tack.update(0.0)
			var sc := tack.saddle.scale.x
			var base := tack.saddle.launcher_xf.origin * sc
			var mz := tack.saddle.muzzle * sc
			# the line of fire from the drawn muzzle, forward along -Z: how far it passes from the head's middle
			var t := maxf(-(hc.z - mz.z), 0.0)
			var rel := hc - mz
			var miss := Vector2(rel.x, rel.y).length() - hr
			line += "\n         drawn base (%.1f, %.1f, %.1f)  drawn muzzle (%.1f, %.1f, %.1f)  muzzle->combat %.1f  fire line passes the head with %.1f cm to spare%s" % [base.x * 100, base.y * 100, base.z * 100, mz.x * 100, mz.y * 100, mz.z * 100, mz.distance_to(combat) * 100, miss * 100, " (head ahead of the muzzle)" if hc.z < mz.z else " (muzzle ahead of the head)"]
		print(line)
		rig.queue_free()
		await frames(1)
	finish()
