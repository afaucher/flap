extends TestCase
## Combat AI geometry and styles (docs/design/combat_ai.md, 4.4 and 5): Engagement's angles, closure and pursuit
## points for targets left and right, ahead and behind; the species' styles derived from their profiles in the
## order the design expects.


func setup() -> void:
	_angles()
	_pursuit_points()
	_styles()
	finish()


func _angles() -> void:
	var me := Vector3.ZERO
	var fwd := Vector3.FORWARD
	near(Engagement.ata(me, fwd, Vector3(0, 0, -20)), 0.0, 1e-4, "dead ahead: ATA 0")
	near(rad_to_deg(Engagement.ata(me, fwd, Vector3(20, 0, 0))), 90.0, 1e-3, "to the right: ATA 90")
	near(rad_to_deg(Engagement.ata(me, fwd, Vector3(-20, 0, 0))), 90.0, 1e-3, "to the left: ATA 90")
	near(rad_to_deg(Engagement.ata(me, fwd, Vector3(0, 0, 20))), 180.0, 1e-3, "behind: ATA 180")
	# AA: a target ahead flying away from me shows me its tail (0); one coming at me, its nose (180).
	near(Engagement.aa(me, Vector3(0, 0, -20), Vector3(0, 0, -10)), 0.0, 1e-4, "its tail toward me: AA 0")
	near(rad_to_deg(Engagement.aa(me, Vector3(0, 0, -20), Vector3(0, 0, 10))), 180.0, 1e-3, "head-on: AA 180")
	near(rad_to_deg(Engagement.aa(me, Vector3(0, 0, -20), Vector3(10, 0, 0))), 90.0, 1e-3, "crossing right: AA 90")
	near(rad_to_deg(Engagement.aa(me, Vector3(0, 0, -20), Vector3(-10, 0, 0))), 90.0, 1e-3, "crossing left: AA 90")
	near(Engagement.closure(me, Vector3(0, 0, -10), Vector3(0, 0, -20), Vector3(0, 0, -6)), 4.0, 1e-4, "closing at 4 m/s on a slower bird ahead")
	near(Engagement.closure(me, Vector3(0, 0, -10), Vector3(0, 0, -20), Vector3(0, 0, -14)), -4.0, 1e-4, "opening on a faster one")
	eq(Engagement.side_of(me, fwd, Vector3(5, 0, -5)), 1.0, "a point ahead-right is on the right")
	eq(Engagement.side_of(me, fwd, Vector3(-5, 0, -5)), -1.0, "a point ahead-left is on the left")
	near(Engagement.energy_height(Vector3(0, 10, 0), Vector3(0, 0, 9.81)), 10.0 + 9.81 * 0.5, 1e-3, "energy height: y + v^2 / 2g")


## A target crossing in front: the lead point is ahead of it along its path (on its side of travel), the lag point
## behind it -- both ways.
func _pursuit_points() -> void:
	for side in [1.0, -1.0]:
		var t_pos := Vector3(0, 10, -25)
		var t_vel := Vector3(side * 9.0, 0, 0)
		var lead := Engagement.lead_point(Vector3(0, 10, 0), 9.0, t_pos, t_vel, 34.0, false)
		var lag := Engagement.lag_point(t_pos, t_vel, 6.0)
		check((lead.x - t_pos.x) * side > 3.0, "crossing %s: the lead point is ahead of it (%.1f m)" % ["right" if side > 0 else "left", lead.x - t_pos.x])
		check((lag.x - t_pos.x) * side < -5.9, "crossing %s: the lag point is behind it" % ["right" if side > 0 else "left"])
		# Fire control's lead is where a rocket really meets it: fly one there.
		var aim := FireControl.lead(Vector3(0, 10, 0), Vector3(0, 0, -9.0), t_pos, t_vel) - Vector3(0, 10, 0)
		var miss := FireControl.miss(Projectile.Kind.ROCKET, Vector3(0, 10, 0), Vector3(0, 0, -9.0), aim, t_pos, t_vel)
		check(miss < Projectile.fuse * 0.5, "crossing %s: a rocket at fire control's lead passes well inside the fuse (%.2f m)" % ["right" if side > 0 else "left", miss])
		# ... and against one turning toward or away, the lead for that turn.
		for turn in [1.5, -1.5]:
			var at := FireControl.lead(Vector3(0, 10, 0), Vector3(0, 0, -9.0), t_pos, t_vel, turn) - Vector3(0, 10, 0)
			check(FireControl.miss(Projectile.Kind.ROCKET, Vector3(0, 10, 0), Vector3(0, 0, -9.0), at, t_pos, t_vel, turn) < Projectile.fuse, "crossing %s, turning %s: the lead for its turn hits" % ["right" if side > 0 else "left", "right" if turn > 0 else "left"])
		var straight := FireControl.miss(Projectile.Kind.ROCKET, Vector3(0, 10, 0), Vector3(0, 0, -9.0), t_pos - Vector3(0, 10, 0), t_pos, t_vel)
		check(straight > Projectile.fuse * 1.5, "crossing %s: one at the bird itself misses behind it (%.2f m)" % ["right" if side > 0 else "left", straight])


## The styles follow from the numbers: the sparrow rolls fastest and fights low; the hawk and falcon need their
## energy and stay high; the owl ambushes; the crow is the all-rounder. Seekers for crow and owl, rockets for the rest.
func _styles() -> void:
	var s := {}
	for id in BirdProfile.IDS:
		s[id] = CombatStyle.of(BirdProfile.by_id(id))
		print(s[id].describe())
	check(s.sparrow.roll90 < s.crow.roll90 and s.crow.roll90 < s.owl.roll90 and s.owl.roll90 < s.hawk.roll90, "roll times: sparrow < crow < owl < hawk")
	check(s.sparrow.understory_ok and not s.hawk.understory_ok and not s.falcon.understory_ok, "the sparrow fights in the understory, the hawk and falcon don't")
	check(s.hawk.prefers_height and s.falcon.prefers_height and not s.crow.prefers_height, "hawk and falcon are energy fighters")
	check(s.owl.ambusher and not s.crow.ambusher, "the owl ambushes")
	eq(s.crow.weapon, Launcher.Weapon.SEEKERS, "the crow carries seekers")
	eq(s.falcon.weapon, Launcher.Weapon.ROCKETS, "the falcon carries rockets")
	check(s.falcon.turn_radius > s.crow.turn_radius, "the falcon turns wider than the crow (%.1f vs %.1f m)" % [s.falcon.turn_radius, s.crow.turn_radius])
	check(s.sparrow.seeker_break_tgo < s.hawk.seeker_break_tgo, "a sparrow can leave its break against a seeker later than a hawk")
	# Lift limits the bank low and slow, not fast.
	var c: CombatStyle = s.crow
	check(c.lift_bank(c.v_stall * 1.1) < c.lift_bank(c.v_best * 1.3), "less bank to hold near the stall than at speed")
	check(c.best_turn_rate(c.v_best) > c.best_turn_rate(c.v_stall * 1.05), "a crow turns faster at v* than just above its stall")
