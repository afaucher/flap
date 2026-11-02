extends TestCase
## Diagnostic (run by name): the legs through a lab landing (owl, land_level; edit BIRD / SCENARIO): per tick the
## state, flare, grip, and the right leg's foot target, knee, ankle and foot in the rig's frame (x right, y up the
## body, z toward the tail), with how far the foot is from the hip.

const BIRD := "falcon"
const SCENARIO := "land_side"


func setup() -> void:
	var lab := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(lab)
	await frames(2)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id(BIRD), lab, null)
	b.arena = arena
	LabScenarios.start(LabScenarios.by_id(SCENARIO), b, lab)
	for i in 200:
		await frames(1)
		var r := b.rig
		var t := b.telemetry()
		var lj: Array = r.leg_joints[1]
		print("%3d %-8s reach %.2f flare %.2f grip %s target %s knee %s ankle %s foot %s  reach %.3f" % [i, Bird.State.keys()[b.state], r.leg_reach[1], float(t.flare), t.has_grip, r.foot_targets[1].snapped(Vector3.ONE * 0.001), (lj[1] as Vector3).snapped(Vector3.ONE * 0.001), (lj[2] as Vector3).snapped(Vector3.ONE * 0.001), (lj[3] as Vector3).snapped(Vector3.ONE * 0.001), (lj[3] as Vector3).distance_to(lj[0])])
		if b.state == Bird.State.PERCHED and i > 20:
			break
	finish()
