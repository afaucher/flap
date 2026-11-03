extends TestCase
## What a combat AI bird sees (CombatSense, docs/design/combat_ai.md 2 and 4.1), measured on real birds in flight:
##   - a bird it can see is tracked where it is now: what it saw a reaction time ago, carried on along the velocity
##     it saw then (crossing left and right);
##   - one straight behind, in the blind cone, isn't seen until it checks six; one ahead is;
##   - a trunk between them hides it, and it is remembered (carried on) for a while, then dropped.


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	for side in [1.0, -1.0]:
		await _dead_reckoning(side)
	await _blind_cone()
	await _behind_a_trunk()
	finish()


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
