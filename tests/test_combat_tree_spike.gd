extends TestCase
## The combat AI's decision layer is a Beehave behaviour tree (docs/design/combat_ai.md, 3.2): this checks the
## vendored addon (addons/beehave, 2.9.2) works in Flap -- a tree built in code, ticked by hand once per physics
## tick (MANUAL), deciding for a real bird that a controller then flies -- and that the run prints no engine
## ERROR / WARNING (the runner fails on any). It also measures a tick's cost for six trees.


class Low extends ConditionLeaf:
	func tick(actor: Node, _bb: Blackboard) -> int:
		return SUCCESS if (actor as Bird).global_position.y < 14.0 else FAILURE


class Climb extends ActionLeaf:
	func tick(_actor: Node, bb: Blackboard) -> int:
		bb.set_value("gamma", deg_to_rad(15.0))
		return RUNNING


class Level extends ActionLeaf:
	func tick(_actor: Node, bb: Blackboard) -> int:
		bb.set_value("gamma", 0.0)
		return SUCCESS


## Flies the path angle the tree last asked for (ticking the tree first, as the combat pilot will).
class TreePilot extends RefCounted:
	var tree: BeehaveTree
	func sample(b: Bird, _dt: float) -> FlightInput:
		tree.tick()
		var gamma: float = tree.blackboard.get_value("gamma", 0.0)
		return FlightInput.new(Vector2(0.0, clampf((gamma - b.model.path_angle) * 3.0, -0.6, 0.6)), false, gamma > 0.0 or b.model.speed < b.profile.v_best * 0.9)


func setup() -> void:
	var layout := ArenaLayout.new()
	var birds: Array[Bird] = []
	for i in 6:
		var pilot := TreePilot.new()
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.crow(), layout, pilot)
		b.rig.visible = false
		pilot.tree = _build(b)
		b.fly_from(Vector3(i * 10.0, 8.0, 0.0), Vector3.FORWARD, b.profile.v_best)
		birds.append(b)
	var t0 := Time.get_ticks_usec()
	var climbed := false
	for f in 240:
		await get_tree().physics_frame
		climbed = climbed or birds[0].global_position.y > 14.0
	var per_tick := float(Time.get_ticks_usec() - t0) / 240.0
	print("six birds, trees ticked by hand: %.0f us per physics tick (all of it, flight included)" % per_tick)
	check(climbed, "the tree's Climb branch flew the bird up past 14 m")
	var gamma_now: float = (birds[0].controller as TreePilot).tree.blackboard.get_value("gamma", 1.0)
	check(gamma_now == 0.0, "then the tree went over to its Level branch (asking for %.1f deg)" % rad_to_deg(gamma_now))
	check(absf(birds[0].global_position.y - 14.0) < 4.0, "and it held the bird near there (%.1f m)" % birds[0].global_position.y)
	var t1 := Time.get_ticks_usec()
	for i in 1000:
		(birds[0].controller as TreePilot).tree.tick()
	print("a tree tick: %.1f us" % (float(Time.get_ticks_usec() - t1) / 1000.0))
	for b in birds:
		b.queue_free()
	await frames(2)
	finish()


## Selector [ ReactiveSequence [Low?, Climb], Level ], built in code, a child of the bird, ticked by hand. The sequence
## is the reactive kind, so Low? is asked again every tick: a plain one resumes at its RUNNING Climb and never gets
## back to Low?, so Level never ran (the bird only came out near 14 m while its flapping climb was slow).
func _build(b: Bird) -> BeehaveTree:
	var tree := BeehaveTree.new()
	tree.process_thread = BeehaveTree.ProcessThread.MANUAL
	var root := SelectorComposite.new()
	var seq := SequenceReactiveComposite.new()
	seq.add_child(Low.new())
	seq.add_child(Climb.new())
	root.add_child(seq)
	root.add_child(Level.new())
	tree.add_child(root)
	tree.actor = b
	b.add_child(tree)
	return tree
