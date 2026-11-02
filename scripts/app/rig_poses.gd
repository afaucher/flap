class_name RigPoses
extends RefCounted
## Static poses for looking at the rig (rig gallery, bird lab): the control values set directly, no flight.
## glide holds the wings spread; flap loops a wingbeat (2 per second); upstroke freezes mid-upstroke;
## folded is the perched pose (species posture, feet gripping a branch under the body); flare is the
## landing pose (wings forward, alula out, tail fanned down, feet reaching).

const NAMES := ["glide", "flap", "upstroke", "folded", "flare"]
const BRANCH_R := 0.045   ## the folded pose's branch radius, share of L (the rig gallery's --branch draws it)


## Pose `r` (positioned by its own transform) at `time` s. `neck` / `fluff` override the pose's own when >= 0.
static func apply(r: BirdRig, pose: String, time: float, neck := -1.0, fluff := -1.0) -> void:
	r.fold = 0.0
	r.sweep = 0.0
	r.twist = 0.0
	r.alula = 0.0
	r.slot = 0.3
	r.hand_lift = 0.0
	r.flap = deg_to_rad(5.0)
	r.tail_spread = 0.3
	r.tail_pitch = 0.0
	r.toe_grip = 0.0
	r.grip_radius = 0.0
	r.neck_ext = r.body.neck_flight
	r.fluff = 1.0
	r.flex = 0.0
	if pose != "folded":
		r.rotation_degrees.x = 0.0
	for i in 2:
		r.foot_targets[i] = r._tucked_foot(i)
		r.leg_reach[i] = 1.0 if pose == "folded" or pose == "flare" else 0.0   # (in flight the legs ride tucked)
	match pose:
		"flap", "upstroke":
			var ph := fmod(time * 2.0, 1.0) if pose == "flap" else 0.75
			r.flap = deg_to_rad(10.0 + 45.0 * cos(ph * TAU))
			r.hand_lift = 50.0 * sin((ph - 0.5) * TAU) if ph > 0.5 else 0.0
			r.flex = 0.16 * sin(ph * TAU) + 0.03   # (tips bend up in the downstroke, trail down in the upstroke)
		"folded":
			# Perched: the species' posture, tail at its angle, feet gripping a branch under the body.
			var sit: Dictionary = BirdRig.POSE.get(r.profile.id, BirdRig.POSE["crow"])
			r.rotation_degrees.x = 0.0 if BirdRig.flat_perch else float(sit.perch_pitch)
			r.fold = 1.0
			r.flap = deg_to_rad(-10.0)
			r.slot = 0.0
			r.tail_spread = 0.0
			r.tail_pitch = deg_to_rad(float(sit.tail_down)) if not BirdRig.flat_perch else 0.15
			r.toe_grip = 1.0
			r.grip_radius = BRANCH_R * r._L
			r.neck_ext = 0.05
			r.fluff = r.body.fluff_perched
			# (the branch's top under the hips at POSE.stance of the leg's reach, as a perched Bird stands)
			var hips := r.transform * ((r._hip[0] + r._hip[1]) * 0.5)
			var top := hips.y - (r.body.femur + r._tib + r._tars) * float(sit.stance)
			for i in 2:
				var grip_world := Vector3(r.position.x + BirdRig.SIDES[i] * r._L * 0.04, top, r.position.z)
				r.foot_targets[i] = r.transform.affine_inverse() * grip_world
		"flare":
			r.flap = deg_to_rad(25.0)
			r.sweep = 12.0
			r.twist = deg_to_rad(30.0)
			r.alula = 1.0
			r.slot = 1.0
			r.tail_spread = 1.0
			r.tail_pitch = 0.6
			r.neck_ext = 0.3
			for i in 2:
				r.foot_targets[i] = r._hip[i] + Vector3(0.0, -r._L * 0.22, -r._L * 0.16)
	if neck >= 0.0:
		r.neck_ext = neck
	if fluff >= 0.0:
		r.fluff = fluff
	r.look_dir = (r.basis.inverse() * Vector3(0, -0.2, -1)).normalized()   # (level ahead in the world, whatever the posture)
	r.world_up = (r.basis.inverse() * Vector3.UP).normalized()
	r.apply_pose()
