extends TestCase
## The combat AI's fire control (docs/design/combat_ai.md, 4.5), checked against real shots:
##   - a rocket fired at FireControl.lead hits a real bird crossing left or right, and one fired at the bird itself
##     misses -- what the solution predicted, both ways;
##   - with a trunk in the lane the AI holds fire, without it it fires;
##   - seekers: fired at a crow tail-on or a sparrow crossing (no level break beats one here), held for a bird off
##     the seeker's gimbal or beyond its reach.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	for side in [1.0, -1.0]:
		await _real_shot(side, true)
		await _real_shot(side, false)
	await _lane()
	_seekers()
	finish()


## A crossing target, a rocket from 22 m out: at fire control's lead it hits, at the bird it misses.
func _real_shot(side: float, at_lead: bool) -> void:
	var layout := ArenaLayout.new()
	var d := Duel.new()
	add_child(d)
	d.setup(layout)
	await frames(1)
	var target := d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(-side * 6.0, 12.0, -22.0), Vector3(side, 0, 0))
	var shooter := d.add_bird("crow", 0, ScriptedInput.new(), null, Vector3(0, 12.0, 0), Vector3.FORWARD)
	var tb: Bird = target.bird
	var l: Launcher = shooter.launcher
	var muzzle := l.muzzle()
	var aim := (FireControl.lead(muzzle, shooter.bird.model.velocity, tb.global_position, tb.model.velocity) if at_lead else tb.global_position) - muzzle
	var predicted := FireControl.miss(Projectile.Kind.ROCKET, muzzle, shooter.bird.model.velocity, aim, tb.global_position, tb.model.velocity)
	d.world.spawn(Projectile.launch(Projectile.Kind.ROCKET, muzzle, shooter.bird.model.velocity, aim, shooter.bird))
	for f in 70:
		await get_tree().physics_frame
	var hit := int(d.world.hits.get(tb, 0)) > 0
	var what := "crossing %s, aimed %s" % ["right" if side > 0 else "left", "at the lead" if at_lead else "at the bird"]
	print("%s: predicted miss %.2f m, hit %s" % [what, predicted, hit])
	check(hit == at_lead, "%s: %s" % [what, "hits" if at_lead else "misses"])
	check((predicted < Projectile.fuse) == hit, "%s: the solution predicted it (%.2f m)" % [what, predicted])
	d.cleanup()
	d.queue_free()
	await frames(2)


## The AI's rocket check holds fire with a trunk in the lane, and fires without.
func _lane() -> void:
	for with_trunk in [false, true]:
		var layout := ArenaLayout.new()
		if with_trunk:
			var t := ArenaLayout.TreeData.new()
			t.id = 0
			t.base = Vector2(0.0, -10.0)
			t.height = 30.0
			t.radius = 0.3
			layout.trees.append(t)
			ArenaLayout._add_to_hash(layout._tree_hash, t.base, t.id)
		var d := Duel.new()
		add_child(d)
		d.setup(layout)
		await frames(1)
		var them: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(0, 12, -20), Vector3.FORWARD)
		var tv: Vector3 = them.bird.model.velocity
		var lead := FireControl.lead(Vector3(0, 12, 0), Vector3.FORWARD * BirdProfile.sparrow().v_best, them.bird.global_position, tv)
		var me: Dictionary = d.add_ai("sparrow", 0, Vector3(0, 12, 0), lead - Vector3(0, 12, 0))   # (its gunsight on the lead)
		var tr := CombatSense.Track.new()
		tr.bird = them.bird
		tr.pos = them.bird.global_position
		tr.vel = them.bird.model.velocity
		tr.visible = true
		var weapons := me.launcher.controller as AICombat
		var ok := weapons._would_hit(me.launcher, tr)
		check(ok != with_trunk, "a tail-on shot %s: %s" % ["through a trunk" if with_trunk else "in the open", "held" if with_trunk else "fired"])
		d.cleanup()
		d.queue_free()
		await frames(2)


## A seeker locked on: a crow tail-on at 15 m, or a sparrow crossing at 20 m, is caught whichever way it breaks; one
## off the gimbal, or fast and far going away, is out of its reach.
func _seekers() -> void:
	var muzzle := Vector3(0, 12, 0)
	var vel := Vector3(0, 0, -9.0)
	var crow := CombatStyle.of(BirdProfile.crow())
	var sparrow := CombatStyle.of(BirdProfile.sparrow())
	var tail_on := Vector3(0, 12, -15)
	var cv := Vector3(0, 0, -crow.v_best)
	var r := crow.best_turn_rate(crow.v_best)
	for turn in [0.0, r, -r]:
		var m := FireControl.miss(Projectile.Kind.SEEKER, muzzle, vel, Vector3.FORWARD, tail_on, cv, turn, null, crow.seeker_break_tgo)
		check(m < Projectile.fuse, "a seeker on a crow tail-on hits however it breaks (turn %.1f: %.2f m)" % [turn, m])
	# (A level break doesn't beat a locked seeker in this flight model, not even a sparrow's at its best timing:
	# fire control shoots one crossing too. What it holds for is a shot the seeker can't make.)
	for side in [1.0, -1.0]:
		var crossing := Vector3(-side * 4.0, 12, -20)
		var sv := Vector3(side * sparrow.v_best, 0, 0)
		var sr := sparrow.best_turn_rate(sparrow.v_best)
		var worst := 0.0
		for turn in [0.0, sr, -sr]:
			worst = maxf(worst, FireControl.miss(Projectile.Kind.SEEKER, muzzle, vel, (crossing - muzzle).normalized(), crossing, sv, turn, null, sparrow.seeker_break_tgo))
		check(worst < Projectile.fuse, "a sparrow crossing %s, breaking either way at its break time, is still caught (worst miss %.2f m)" % ["right" if side > 0 else "left", worst])
		# Off the seeker's gimbal (65 deg off the nose, going away): it loses it.
		var off := Vector3.FORWARD.rotated(Vector3.UP, side * deg_to_rad(65.0))
		var m := FireControl.miss(Projectile.Kind.SEEKER, muzzle, vel, Vector3.FORWARD, muzzle + off * 20.0, off * 9.0)
		check(m > Projectile.fuse, "a bird 65 deg off to the %s, going away, is outside the seeker's gimbal: held (%.2f m)" % ["right" if side > 0 else "left", m])
	# Out of reach: a fast bird 40 m out and going away (the seeker burns out short).
	var far := FireControl.miss(Projectile.Kind.SEEKER, muzzle, vel, Vector3.FORWARD, muzzle + Vector3.FORWARD * 40.0, Vector3.FORWARD * 18.0)
	check(far > Projectile.fuse, "a fast bird 40 m out going away is beyond a seeker's reach: held (%.2f m)" % far)
