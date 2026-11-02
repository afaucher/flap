extends TestCase
## Diagnostic: standing perched, where the hand loops are from the rider's shoulders (up, away from the bird,
## across; real cm), and the lean.

func setup() -> void:
	for id in BirdProfile.IDS:
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(BirdProfile.by_id(id))
		var tack := Tack.fit(rig)
		RigPoses.apply(rig, "folded", 0.0)
		tack.sitting = true
		tack.update(0.0)
		var r := tack.rider
		var u := rig.world_up.normalized()
		var away := -tack.saddle.seat_normal
		away = -(away - u * away.dot(u)).normalized()
		var sh := ((r.joints.shoulder0 as Vector3) + (r.joints.shoulder1 as Vector3)) * 0.5
		var h := (tack.saddle.holds[0] + tack.saddle.holds[1]) * 0.5 * tack.saddle.scale.x
		var d := (h - sh) / r.k
		var torso: Vector3 = (r.joints.chest as Vector3) - (r.joints.pelvis as Vector3)
		print("STAND %-8s stand %.2f  lean %.0f  holds from shoulders: up %.0f, toward bird %.0f, dist %.0f (arm %.0f)" % [id, r.stand, rad_to_deg(torso.angle_to(u)), d.dot(u), -d.dot(away), d.length(), float(Rider.REAL.upper_arm) + float(Rider.REAL.forearm)])
		for i in 2:
			var hp: Vector3 = tack.saddle.holds[i] * tack.saddle.scale.x
			print("      hand %d: shoulder%d->loop %.0f, other shoulder %.0f, hand->loop %.1f, saddle x of loop %.1f, of shoulder %.1f" % [i, i, (r.joints["shoulder%d" % i] as Vector3).distance_to(hp) / r.k, (r.joints["shoulder%d" % (1 - i)] as Vector3).distance_to(hp) / r.k, (r.joints["hand%d" % i] as Vector3).distance_to(hp) / r.k, hp.x / r.k, (r.joints["shoulder%d" % i] as Vector3).x / r.k])
		rig.queue_free()
		await frames(1)
	finish()
