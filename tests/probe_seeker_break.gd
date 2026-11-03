extends TestCase
## Diagnostic: seeker miss vs a breaking target, breaking from launch vs at its break time, over ranges and aspects.

func setup() -> void:
	for id in ["sparrow", "crow", "hawk"]:
		var st := CombatStyle.of(BirdProfile.by_id(id))
		var muzzle := Vector3(0, 12, 0)
		var vel := Vector3(0, 0, -9.0)
		for r in [12.0, 20.0, 28.0, 36.0]:
			for aa in [0.0, 45.0, 90.0]:
				var tp: Vector3 = muzzle + Vector3.FORWARD * r
				var tv: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(aa)) * st.v_best
				var turn := st.best_turn_rate(st.v_best)
				var early := 0.0
				var late := 0.0
				for t in [turn, -turn]:
					early = maxf(early, FireControl.miss(Projectile.Kind.SEEKER, muzzle, vel, Vector3.FORWARD, tp, tv, t, null, 0.0))
					late = maxf(late, FireControl.miss(Projectile.Kind.SEEKER, muzzle, vel, Vector3.FORWARD, tp, tv, t, null, st.seeker_break_tgo))
				print("%s r %2.0f aa %2.0f: from launch %.2f, at break time %.2f" % [id, r, aa, early, late])
	finish()
