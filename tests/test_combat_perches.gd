extends TestCase
## The combat AI's perch choices, in places of their own (FlightExam): which perch it picks doesn't then depend on how
## a generated wood grows round the fight (in the big-trees wood every perch near test_combat_ai's ambush is high
## enough, and every rest perch far enough, whatever the rule).
##   ambush  a pole pine just where an ambush perch would be (28 m out from the fight) but below the fight, a pine a
##           little further off with perches high above it: the owl picks the pine's (CombatTree._ambush_perch)
##   (and its flight AI is fitted to the bird: its routes keep that species' berth from the wood)
##   rest    a tired crow between two pines, the nearer one toward where it has seen the enemy fly: it rests in the
##           other, away from it and behind its trunk (CombatTree._nearest_perch)


func setup() -> void:
	await _ambush_above()
	await _rests_away()
	finish()


func _brain(a: ArenaLayout, id: String, at: Vector3) -> Array:
	var d := Duel.new()
	add_child(d)
	d.setup(a)
	await frames(1)
	var me: Dictionary = d.add_ai(id, 0, at, Vector3.RIGHT, CombatSkill.preset("pilot"), 5)
	for f in 2:   # (a tick or two: its picture of the fight is made on its first)
		await get_tree().physics_frame
	return [d, me.brain]


func _ambush_above() -> void:
	var a := FlightExam.place()
	var low := FlightExam.add_tree(a, "pole", Vector2(-28.0, 0.0), 3)
	var high := FlightExam.add_tree(a, "pine", Vector2(-20.0, 25.0), 4)
	var x: Array = await _brain(a, "owl", Vector3(-45.0, 24.0, 0.0))
	var br: CombatBrain = x[1]
	var want := AIPilot.plan_clearance(br.bird.profile)
	check(is_equal_approx(br.pilot.planner.clearance, want) and br.pilot.turn_radius > 0.0, "the combat AI's routes keep the owl's own berth from the wood (%.2f m, wants %.2f)" % [br.pilot.planner.clearance, want])
	br.fight_area = Vector3(0.0, 10.0, 0.0)
	br.fight_seen = 0.0
	var p := CombatTree._ambush_perch(br)
	print("ambush: the fight at 10 m; the pole's perches %s m, the pine's %s m; picked %s" % [_heights(a, low.id), _heights(a, high.id),
		("perch %d on the %s at %.1f m" % [p.id, "pine" if p.tree_id == high.id else "pole", p.position.y]) if p != null else "none"])
	check(p != null and p.tree_id == high.id and p.position.y >= br.fight_area.y + 4.0, "the owl waits in ambush above the fight, not on the nearer low tree")
	x[0].cleanup()
	x[0].queue_free()
	await frames(2)


func _rests_away() -> void:
	var a := FlightExam.place()
	var toward := FlightExam.add_tree(a, "pine", Vector2(32.0, 0.0), 6)
	var away := FlightExam.add_tree(a, "pine", Vector2(-42.0, 0.0), 6)
	var x: Array = await _brain(a, "crow", Vector3(0.0, 30.0, 0.0))
	var br: CombatBrain = x[1]
	br.fight_area = Vector3(60.0, 15.0, 0.0)
	br.fight_seen = 0.0
	var p := CombatTree._nearest_perch(br)
	print("rest: the enemy seen at +60 m; picked %s" % (("perch %d on the pine %s" % [p.id, "toward it (32 m)" if p.tree_id == toward.id else "away (42 m)"]) if p != null else "none"))
	check(p != null and p.tree_id == away.id, "the tired crow rests on the tree away from the enemy, not the nearer one toward it")
	x[0].cleanup()
	x[0].queue_free()
	await frames(2)


func _heights(a: ArenaLayout, tree_id: int) -> String:
	var ys: Array = []
	for q in FlightExam.perches_of(a, tree_id):
		ys.append(snappedf(q.position.y, 0.1))
	ys.sort()
	return str(ys)
