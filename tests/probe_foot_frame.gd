extends TestCase
## Diagnostic (run by name): the right foot through a lab landing (edit BIRD / SCENARIO): per tick the sim time,
## state, leg_reach and leg_world, the middle toe's angle off the tarsus and its pitch off level in the world (deg,
## + up), and how far the toe's heading (and the tarsus) turned since the last tick.

const BIRD := "hawk"
const SCENARIO := "land_level"


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
	var last := Vector3.ZERO
	var last_t := Vector3.ZERO
	var last_q := Quaternion.IDENTITY
	for i in 400:
		await frames(1)
		var r := b.rig
		var lj: Array = r.leg_joints[1]
		var t2 := ((lj[3] as Vector3) - (lj[2] as Vector3)).normalized()
		var toe: Vector3 = r.legs.toe_heading[1][1]
		var up := r.world_up.normalized()
		var turn := rad_to_deg(last.angle_to(toe)) if last != Vector3.ZERO else 0.0
		last = toe
		var tturn := rad_to_deg(last_t.angle_to(t2)) if last_t != Vector3.ZERO else 0.0
		last_t = t2
		var q := r.legs.skeletons[1].get_bone_pose_rotation(LegRig.B_PAD)
		var pturn := rad_to_deg(last_q.angle_to(q))
		last_q = q
		print("%3d t %.2f %-8s reach %.2f world %.2f toe-tarsus %5.1f toe pitch %6.1f turn %5.1f tarsus turn %5.1f pad turn %5.1f grip_r %.3f" % [i, i / 60.0, Bird.State.keys()[b.state], r.leg_reach[1], r.leg_world, rad_to_deg(toe.angle_to(t2)), rad_to_deg(asin(clampf(toe.dot(up), -1.0, 1.0))), turn, tturn, pturn, r.grip_radius])
		if b.state == Bird.State.PERCHED and i > 20:
			break
	finish()
