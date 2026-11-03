extends TestCase
## The combat AI's fire control (docs/design/combat_ai.md, 4.5), checked against real shots:
##   - a rocket fired at FireControl.lead hits a real bird crossing left or right, and one fired at the bird itself
##     misses -- what the solution predicted, both ways;
##   - with a trunk in the lane the AI holds fire, without it it fires;
##   - a rocket that would pass outside the fuse (if inside the blast) is held: it never goes off near the bird --
##     fly it and see;
##   - a target that breaks only as the round arrives is still hit; one that broke from the launch is missed (the
##     solution breaks the target when it would see the round coming, not before);
##   - seekers: fired at a crow tail-on or a sparrow crossing (no level break beats one here), held for a bird off
##     the seeker's gimbal or beyond its reach;
##   - a bird in a banked turn, as the AI sees it: a rocket at the brain's lead (which follows the turn it sees) hits
##     it, turning right or left; one at the lead for flying straight misses.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	for side in [1.0, -1.0]:
		await _real_shot(side, true)
		await _real_shot(side, false)
	await _lane()
	for side in [1.0, -1.0]:
		await _outside_fuse(side)
		_late_break(side)
		await _turning_shot(side, true)
		await _turning_shot(side, false)
	_seekers()
	finish()


## A crow 28 m ahead, crossing and banked hard into a turn to its `side`; an AI sparrow watches it for 3/4 s (its
## brain ticked by hand, flying straight), then a rocket goes off from its muzzle at the brain's lead (a hit), or
## (`turn` false) at the lead for flying straight on (a miss).
func _turning_shot(side: float, turn: bool) -> void:
	var d := Duel.new()
	add_child(d)
	d.setup(ArenaLayout.new())
	await frames(1)
	var bank := ScriptedInput.new()
	bank.stick = Vector2(side * 0.8, 0.0)
	var them: Dictionary = d.add_bird("crow", 1, bank, null, Vector3(-side * 8.0, 20, -28), Vector3(side, 0, 0))
	var me: Dictionary = d.add_ai("sparrow", 0, Vector3(0, 20, 0), Vector3.FORWARD)
	var b: Bird = me.bird
	var l: Launcher = me.launcher
	var br: CombatBrain = me.brain
	b.controller = ScriptedInput.new()   # (flies straight: the brain only watches)
	l.controller = null
	for f in 45:
		await get_tree().physics_frame
		br.tick(1.0 / 60.0)
	var tr := br.picture.track_of(them.bird)
	var lead := br.rocket_lead(tr)
	var straight := FireControl.lead(l.muzzle(), b.model.velocity, tr.pos, tr.vel)
	d.world.spawn(Projectile.launch(Projectile.Kind.ROCKET, l.muzzle(), b.model.velocity, (lead if turn else straight) - l.muzzle(), b))
	for f in 70:
		await get_tree().physics_frame
	var what := "a crow turning to its %s (seen at %.1f rad/s; the turn's lead %.1f m from the straight one)" % ["right" if side > 0 else "left", tr.turn, lead.distance_to(straight)]
	var hit := int(d.world.hits.get(them.bird, 0)) > 0
	print("%s, aimed at the %s lead: hit %s" % [what, "turning" if turn else "straight", hit])
	check(hit == turn, "%s: a rocket at the %s lead %s" % [what, "brain's (turning)" if turn else "straight", "hits" if turn else "misses"])
	d.cleanup()
	d.queue_free()
	await frames(2)


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


## The gunsight a little off the lead, so the rocket would pass a crow crossing 20 m out between the fuse and the
## blast's reach: the AI holds it -- and fired anyway, it passes without going off.
func _outside_fuse(side: float) -> void:
	var d := Duel.new()
	add_child(d)
	d.setup(ArenaLayout.new())
	await frames(1)
	var them: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(-side * 5.0, 12, -20), Vector3(side, 0, 0))
	var tb: Bird = them.bird
	var muzzle0 := Vector3(0, 12, 0)
	var lead := FireControl.lead(muzzle0, Vector3.FORWARD * BirdProfile.sparrow().v_best, tb.global_position, tb.model.velocity)
	# Raise the gunsight until the predicted pass is 1.6-2 m off: outside the fuse, inside fuse + blast.
	var me: Dictionary = d.add_ai("sparrow", 0, muzzle0, lead - muzzle0)
	var l: Launcher = me.launcher
	var mb: Bird = me.bird
	var predicted := 0.0
	for k in 60:
		mb.fly_from(muzzle0, (lead + Vector3.UP * 0.05 * k - muzzle0).normalized(), mb.profile.v_best)
		predicted = FireControl.miss(Projectile.Kind.ROCKET, l.muzzle(), mb.model.velocity, l.aim(), tb.global_position, tb.model.velocity)
		if predicted > 1.6:
			break
	var tr := CombatSense.Track.new()
	tr.bird = tb
	tr.pos = tb.global_position
	tr.vel = tb.model.velocity
	tr.visible = true
	var what := "crossing %s, the rocket passing %.2f m off" % ["right" if side > 0 else "left", predicted]
	print(what)
	check(predicted > Projectile.fuse * 1.4 and predicted < FireControl.reach(), "%s: outside the fuse, inside the blast's reach" % what)
	check(not (l.controller as AICombat)._would_hit(l, tr), "%s: held" % what)
	d.world.spawn(Projectile.launch(Projectile.Kind.ROCKET, l.muzzle(), me.bird.model.velocity, l.aim(), me.bird))
	for f in 70:
		await get_tree().physics_frame
	check(int(d.world.hits.get(tb, 0)) == 0, "%s: fired anyway, it doesn't go off near it" % what)
	d.cleanup()
	d.queue_free()
	await frames(2)


## A rocket at the lead of a crow crossing 20 m out: if it breaks hard only 0.1 s before the pass it is still hit,
## if it broke at the launch it is missed -- both ways round.
func _late_break(side: float) -> void:
	var muzzle := Vector3(0, 12, 0)
	var v0 := Vector3.FORWARD * 9.0
	var t_pos := Vector3(-side * 5.0, 12, -20)
	var crow := CombatStyle.of(BirdProfile.crow())
	var t_vel := Vector3(side * crow.v_best, 0, 0)
	var aim := FireControl.lead(muzzle, v0, t_pos, t_vel) - muzzle
	for turn in [crow.corner_rate, -crow.corner_rate]:
		var late := FireControl.miss(Projectile.Kind.ROCKET, muzzle, v0, aim, t_pos, t_vel, turn, null, 0.1)
		var early := FireControl.miss(Projectile.Kind.ROCKET, muzzle, v0, aim, t_pos, t_vel, turn, null, 0.0)
		var what := "crossing %s, breaking %s" % ["right" if side > 0 else "left", "right" if turn > 0 else "left"]
		check(late < Projectile.fuse, "%s 0.1 s before the pass: still hit (%.2f m)" % [what, late])
		check(early > Projectile.fuse * 1.5, "%s from the launch: missed (%.2f m)" % [what, early])


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
