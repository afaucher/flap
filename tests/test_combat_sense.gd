extends TestCase
## What a combat AI bird sees (CombatSense, docs/design/combat_ai.md 2 and 4.1), measured on real birds in flight:
##   - a bird it can see is tracked where it is now: what it saw a reaction time ago, carried on along the velocity
##     it saw then (crossing left and right);
##   - one straight behind, in the blind cone, isn't seen until it checks six; one ahead is;
##   - a trunk between them hides it, and it is remembered (carried on) for a while, then dropped;
##   - a bird in a steady banked turn is seen turning at the rate it really turns, to its right or its left;
##   - a brain looks every CombatBrain.THINK_EVERY ticks: at each look a bird flying straight is tracked where it is
##     (the history it reads a reaction time back is kept every tick, not only at looks), and on the ticks between, its
##     picture is carried on (each bird in sight moves on by its velocity), so fire control and the defence never read
##     where a bird was a tick ago -- whichever tick its looks fall on.


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	for side in [1.0, -1.0]:
		await _dead_reckoning(side)
	await _blind_cone()
	await _behind_a_trunk()
	for side in [1.0, -1.0]:
		await _turn_rate(side)
	for s in [3, 4]:   # (the two think phases)
		await _coasts_between_looks(s)
	finish()


## A combat brain watching a crow cross ahead, flying straight (its own bird flies straight too; it only watches): at
## each look the crow is tracked where it is, and on every tick between looks its track moves on by its velocity.
func _coasts_between_looks(brain_seed: int) -> void:
	var d: Duel = await _world(ArenaLayout.new())
	var them: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(-12, 30, -25), Vector3.RIGHT)
	var me: Dictionary = d.add_ai("sparrow", 0, Vector3(0, 30, 0), Vector3.FORWARD, null, brain_seed)
	(me.bird as Bird).controller = ScriptedInput.new()
	(me.launcher as Launcher).controller = null
	var br: CombatBrain = me.brain
	for f in 40:
		await get_tree().physics_frame
		br.tick(1.0 / 60.0)
	var between := 0
	var stuck := 0
	var looks := 0
	var worst := 0.0   # m between the track and the crow, at a look
	for f in 20:
		var pic := br.picture
		var tr := pic.track_of(them.bird)
		var was: Vector3 = tr.pos if tr != null else Vector3.INF
		await get_tree().physics_frame
		br.tick(1.0 / 60.0)
		if br.picture != pic or tr == null:
			var now := br.picture.track_of(them.bird)
			if now != null:
				looks += 1
				worst = maxf(worst, now.pos.distance_to((them.bird as Bird).global_position))
			continue   # (a look: a fresh picture)
		between += 1
		var moved := tr.pos.distance_to(was)
		if absf(moved - tr.vel.length() / 60.0) > 0.1 * tr.vel.length() / 60.0:
			stuck += 1
	print("brain seed %d: %d looks, the crow tracked within %.3f m of it; %d ticks between looks, %d with the crow not carried on" % [brain_seed, looks, worst, between, stuck])
	check(looks >= 5 and worst < 0.05, "brain seed %d: at each look, a crow flying straight is tracked where it is (%.3f m off at worst)" % [brain_seed, worst])
	check(between >= 5, "brain seed %d: it looks every other tick (%d ticks between looks in 20)" % [brain_seed, between])
	eq(stuck, 0, "brain seed %d: between looks, the crow's track moves on by its velocity" % brain_seed)
	_drop(d)
	await frames(2)


## A crow ahead holding a bank: after it settles into the turn, the track's turn rate is what its heading really
## does (within 25%), the right sign.
func _turn_rate(side: float) -> void:
	var d: Duel = await _world(ArenaLayout.new())
	var me: Dictionary = d.add_bird("crow", 0, ScriptedInput.new(), null, Vector3(0, 30, 0), Vector3.FORWARD)
	var stick := ScriptedInput.new()
	stick.stick = Vector2(side * 0.5, 0.0)
	var them: Dictionary = d.add_bird("crow", 1, stick, null, Vector3(0, 30, -20), Vector3.FORWARD)
	var sense := CombatSense.new(me.bird, d.world, CombatSkill.preset("pilot"))
	var tb: Bird = them.bird
	var t: CombatSense.Track
	var h0 := Vector3.ZERO
	var measured := 0.0
	for f in 90:
		await get_tree().physics_frame
		sense.record(1.0 / 60.0)
		t = sense.update(1.0 / 60.0).track_of(tb)
		var v := Vector3(tb.model.velocity.x, 0.0, tb.model.velocity.z)
		if f == 59:
			h0 = v
		elif f == 89:
			measured = -h0.signed_angle_to(v, Vector3.UP) / 0.5   # (+ = to its right, as the track's)
	var what := "a crow banked to its %s" % ("right" if side > 0 else "left")
	var seen := t.turn if t != null else 0.0
	print("%s: turning %.2f rad/s, seen turning %.2f" % [what, measured, seen])
	check(absf(measured) > 0.3 and signf(seen) == signf(measured) and absf(seen - measured) < absf(measured) * 0.25, "%s: seen turning at its rate (%.2f vs %.2f rad/s)" % [what, seen, measured])
	await _drop(d)


func _world(layout: ArenaLayout) -> Duel:
	var d := Duel.new()
	add_child(d)
	d.setup(layout)
	await frames(1)
	return d


func _drop(d: Duel) -> void:
	d.cleanup()
	d.queue_free()
	await frames(2)


## A crow crossing 25 m ahead at its cruising speed: after a second the track is within half a metre of it, though
## what the watcher saw is a quarter second old (2.5 m back along its path).
func _dead_reckoning(side: float) -> void:
	var d: Duel = await _world(ArenaLayout.new())
	var me: Dictionary = d.add_bird("crow", 0, ScriptedInput.new(), null, Vector3(0, 20, 0), Vector3.FORWARD)
	var them: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(-side * 5.0, 20, -25), Vector3(side, 0, 0))
	var skill := CombatSkill.preset("pilot")
	var sense := CombatSense.new(me.bird, d.world, skill)
	var pic: CombatSense.Picture
	for f in 60:
		await get_tree().physics_frame
		sense.record(1.0 / 60.0)
		pic = sense.update(1.0 / 60.0)
	var t := pic.track_of(them.bird)
	var tb: Bird = them.bird
	var what := "crossing %s" % ("right" if side > 0 else "left")
	check(t != null and t.visible, "%s ahead: seen" % what)
	if t != null:
		var err := t.pos.distance_to(tb.global_position)
		var lag := tb.model.velocity.length() * skill.reaction
		print("%s: track %.2f m from the bird (it moved %.1f m in the reaction time)" % [what, err, lag])
		check(err < 0.5 and lag > 2.0, "%s: the track is carried on to where the bird is now (%.2f m off)" % [what, err])
		check(t.vel.normalized().dot(tb.model.velocity.normalized()) > 0.99, "%s: its seen velocity is the bird's" % what)
	await _drop(d)


## Straight behind, 20 m: not seen while the watcher looks ahead; seen once it checks six. Ahead: seen at once.
func _blind_cone() -> void:
	var d: Duel = await _world(ArenaLayout.new())
	var me: Dictionary = d.add_bird("crow", 0, ScriptedInput.new(), null, Vector3(0, 20, 0), Vector3.FORWARD)
	var behind: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(0, 20, 20), Vector3.FORWARD)
	var ahead: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(0, 20, -20), Vector3.FORWARD)
	var skill := CombatSkill.preset("pilot")
	skill.scan_every = 1.0
	var sense := CombatSense.new(me.bird, d.world, skill)
	var seen_behind_at := -1.0
	var pic: CombatSense.Picture
	var ahead_ok := true
	for f in 75:
		await get_tree().physics_frame
		sense.record(1.0 / 60.0)
		pic = sense.update(1.0 / 60.0)
		var tb := pic.track_of(behind.bird)
		var ta := pic.track_of(ahead.bird)
		var t := (f + 1) / 60.0
		if t > 0.5 and (ta == null or not ta.visible):
			ahead_ok = false
		if t > 0.5 and seen_behind_at < 0.0 and tb != null and tb.visible:
			seen_behind_at = t
	print("blind cone: the bird behind seen again at %.2f s (checks six every %.1f s)" % [seen_behind_at, skill.scan_every])
	check(ahead_ok, "a bird ahead stays in view")
	check(seen_behind_at >= 0.95 and seen_behind_at < 1.25, "a bird straight behind is seen only when it checks six (%.2f s)" % seen_behind_at)
	await _drop(d)


## A bird crossing behind a trunk: hidden while the trunk is between them, remembered meanwhile -- carried on along
## its last velocity, so the track stays with it -- and seen again past the trunk.
func _behind_a_trunk() -> void:
	var layout := ArenaLayout.new()
	var tree := ArenaLayout.TreeData.new()
	tree.id = 0
	tree.base = Vector2(0.0, -20.0)
	tree.height = 40.0
	tree.radius = 1.0
	layout.trees.append(tree)
	ArenaLayout._add_to_hash(layout._tree_hash, tree.base, tree.id)
	var d: Duel = await _world(layout)
	var me: Dictionary = d.add_bird("crow", 0, ScriptedInput.new(), null, Vector3(0, 20, 0), Vector3.FORWARD)
	var them: Dictionary = d.add_bird("crow", 1, ScriptedInput.new(), null, Vector3(-8, 20, -40), Vector3.RIGHT)
	var sense := CombatSense.new(me.bird, d.world, CombatSkill.preset("ace"))
	var hidden := 0
	var forgot := false
	var worst := 0.0
	var seen_after := false
	for f in 120:
		await get_tree().physics_frame
		sense.record(1.0 / 60.0)
		var t := sense.update(1.0 / 60.0).track_of(them.bird)
		if t == null:
			forgot = true
		elif not t.visible:
			hidden += 1
			worst = maxf(worst, t.pos.distance_to(them.bird.global_position))
		elif hidden > 0:
			seen_after = true
	print("behind a trunk: hidden %d ticks, the remembered track at most %.2f m off" % [hidden, worst])
	check(hidden >= 6, "the trunk hides it (%d ticks)" % hidden)
	check(not forgot, "while hidden it is remembered")
	check(worst < 1.0, "the remembered track goes on with it (%.2f m off)" % worst)
	check(seen_after, "seen again past the trunk")
	await _drop(d)
