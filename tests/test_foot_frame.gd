extends TestCase
## The foot's frame (LegRig.foot_frame), every species, both legs, measured on the drawn skin: the pad's axis (its
## top pole to its bottom one) and the middle toe's heading (the pad's centre to the toe's base loop on it).
## - Tucked in flight (RigPoses glide: leg_reach 0) the toes trail back along the tarsus and the pad stands across
##   it; they once stayed level in the body's frame, pointing forward off a tarsus that points back, so the feet
##   looked on backwards.
## - Perched (RigPoses folded: leg_reach 1) the pad lies level in the world and the toe heads level.
## - Through a landing (level, from above, curving in from the side) and a take-off the drawn toe turns at most 30 deg a tick more
##   than the tarsus carrying it: the foot swings from tucked to level as the leg reaches (the owl's the most, from
##   up in its belly round to level), with no single-tick flip (the frame once flipped over 60 to 120 deg, where the
##   tarsus swung out past the body's side and the turn off level passed a half turn).


func _init() -> void:
	timeout_sec = 200.0


func setup() -> void:
	var was := LegRig.enabled
	LegRig.enabled = true
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		RigPoses.apply(rig, "glide", 0.0)
		for i in 2:
			var m := _measure(rig, i)
			var t2: Vector3 = m.tarsus
			var off := rad_to_deg((m.toe as Vector3).angle_to(t2))
			check(off < 30.0, "%s leg %d tucked: the toes trail along the tarsus (%.0f deg off it)" % [p.id, i, off])
			check(absf((m.up as Vector3).dot(t2)) < 0.35, "%s leg %d tucked: the pad stands across the tarsus (axis . tarsus %.2f)" % [p.id, i, (m.up as Vector3).dot(t2)])
		RigPoses.apply(rig, "folded", 0.0)
		var up := rig.world_up.normalized()
		for i in 2:
			var m := _measure(rig, i)
			var tilt := rad_to_deg((m.up as Vector3).angle_to(up))
			var pitch := rad_to_deg(asin(clampf((m.toe as Vector3).dot(up), -1.0, 1.0)))
			check(tilt < 5.0, "%s leg %d perched: the pad lies level (%.1f deg off)" % [p.id, i, tilt])
			check(absf(pitch) < 12.0, "%s leg %d perched: the toe heads level (%.1f deg)" % [p.id, i, pitch])
			check((m.toe as Vector3).angle_to(m.tarsus) > deg_to_rad(45.0), "%s leg %d perched: the toes stand off the tarsus (%.0f deg)" % [p.id, i, rad_to_deg((m.toe as Vector3).angle_to(m.tarsus))])
		rig.queue_free()
	await _landings()
	LegRig.enabled = was
	finish()


## Through lab landings and a take-off, every species.
func _landings() -> void:
	var lab := ArenaLayout.lab()
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(lab)
	await frames(2)
	for p in BirdProfile.all():
		for sid in ["land_level", "land_above", "land_side", "takeoff"]:
			await _landing(p, sid, lab, arena)
	arena.queue_free()


## One landing (until just after touchdown) or take-off (until the legs are tucked): each tick, how far each leg's drawn middle toe turned past its tarsus's own turn.
func _landing(p: BirdProfile, sid: String, lab: ArenaLayout, arena: ArenaBuilder) -> void:
	var b := Bird.new()
	add_child(b)
	b.setup(p, lab, null)
	b.arena = arena
	LabScenarios.start(LabScenarios.by_id(sid), b, lab)
	var last: Array = [{}, {}]
	var worst := [0.0, 0.0]
	var swung := [false, false]
	var touch := -1
	var takeoff := sid == "takeoff"
	for k in 400:
		await frames(1)
		for i in 2:
			var m := _measure(b.rig, i)
			var l: Dictionary = last[i]
			if not l.is_empty():
				var turn := rad_to_deg((l.toe as Vector3).angle_to(m.toe))
				var tturn := rad_to_deg((l.tarsus as Vector3).angle_to(m.tarsus))
				worst[i] = maxf(worst[i], turn - tturn)
			if b.rig.leg_reach[i] < 0.05:
				swung[i] = true
			last[i] = m
		if touch < 0 and (b.state == Bird.State.PERCHED if not takeoff else swung[0] and swung[1]):
			touch = k
		if touch >= 0 and k > touch + 10:
			break
	check(touch > 0, "%s %s: %s" % [p.id, sid, "the legs tucked" if takeoff else "perched"])
	for i in 2:
		check(swung[i], "%s %s leg %d: tucked in the air" % [p.id, sid, i])
		check(worst[i] < 30.0, "%s %s leg %d: the foot swings round with the leg, no jump (at most %.0f deg a tick past the tarsus's turn)" % [p.id, sid, i, worst[i]])
	b.queue_free()
	await frames(1)


## Leg `i` as drawn (rig space): {up: the pad's axis, toe: the middle toe's heading, tarsus: ankle -> foot}.
static func _measure(rig: BirdRig, i: int) -> Dictionary:
	var lr := rig.legs
	var arr := LegRig.drawn_arrays(lr.skin_mi[i])
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var pad: Vector3i = lr.parts_s[i]["pad"]
	var top := v[pad.x]
	var bottom := v[pad.x + (pad.y - 1) * pad.z]
	var centre := (top + bottom) * 0.5
	var toe: Vector3i = lr.parts_s[i]["toe1"]
	var ring := Vector3.ZERO
	for j in toe.z - 1:
		ring += v[toe.x + j]
	ring /= float(toe.z - 1)
	var lj: Array = rig.leg_joints[i]
	return {"up": (top - bottom).normalized(), "toe": (ring - centre).normalized(),
		"tarsus": ((lj[3] as Vector3) - (lj[2] as Vector3)).normalized()}
