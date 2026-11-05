class_name LabScenarios
extends RefCounted
## What the bird lab can show (scripts/app/bird_lab.gd). Poses are the rig alone (RigPoses); the rest are the
## real game -- a Bird with its flight model, perch logic and rig -- flown by a LabPilot in the lab's
## one-tree arena (ArenaLayout.lab(): a level branch along +X at 3.5 m, approached from -Z).
##
## Landings start at an offset from the aim point on the branch (60% of the way out along its grip line),
## heading `dir` at `speed` x the bird's best-glide speed (the horizontal offset stretched for birds faster than 9 m/s,
## which need longer to brake), and aim `aim_up` above the branch.
##
## Combat (kind "fight", at the end): LabFight builds the fight round the lab bird -- a gun burst, a rocket's burst
## knocking out feathers, a seeker's lock and launch, a bird downed, rearming on the base.

const LIST := [
	{"id": "pose_glide", "label": "Pose: glide", "pose": "glide"},
	{"id": "pose_flap", "label": "Pose: flapping", "pose": "flap"},
	{"id": "pose_upstroke", "label": "Pose: upstroke", "pose": "upstroke"},
	{"id": "pose_folded", "label": "Pose: perched", "pose": "folded"},
	{"id": "pose_flare", "label": "Pose: landing flare", "pose": "flare"},
	{"id": "takeoff", "label": "Take-off: push and flap", "kind": "takeoff"},
	{"id": "drop", "label": "Take-off: drop off (catch)", "kind": "drop"},
	{"id": "ground", "label": "Take-off: from the ground", "kind": "ground"},
	{"id": "land_level", "label": "Landing: level, head-on", "kind": "land", "from": Vector3(0, 0.5, -12), "dir": Vector3(0, 0, 1), "speed": 1.0},
	{"id": "land_above", "label": "Landing: gliding down from above", "kind": "land", "from": Vector3(0, 3.0, -16), "dir": Vector3(0, -0.2, 1), "speed": 1.0, "swoop": 0.3},
	{"id": "land_below", "label": "Landing: swooping up from below", "kind": "land", "from": Vector3(0, -2.2, -12), "dir": Vector3(0, 0.05, 1), "speed": 1.15, "aim_up": 0.6},
	{"id": "land_side", "label": "Landing: curving in from the side", "kind": "land", "from": Vector3(-10, 1.8, -10), "dir": Vector3(1, 0, 0.3), "speed": 1.0, "swoop": 1.5},
	{"id": "land_along", "label": "Landing: along the branch", "kind": "land", "from": Vector3(9, 0.6, -0.5), "dir": Vector3(-1, 0, 0.05), "speed": 1.0},
	{"id": "land_slow", "label": "Landing: slow, short final", "kind": "land", "from": Vector3(0, 0.7, -5), "dir": Vector3(0, 0, 1), "speed": 0.75},
	{"id": "land_fast", "label": "Landing: too fast (no braking)", "kind": "land", "from": Vector3(0, 0.5, -12), "dir": Vector3(0, 0, 1), "speed": 1.5, "bleed": false},
	# Combat (LabFight).
	{"id": "fight_gun", "label": "Combat: gun burst at a bird ahead", "kind": "fight", "fight": "gun"},
	{"id": "fight_rocket", "label": "Combat: hit by a rocket", "kind": "fight", "fight": "rocket"},
	{"id": "fight_seeker", "label": "Combat: seeker lock and launch", "kind": "fight", "fight": "seeker"},
	{"id": "fight_downed", "label": "Combat: downed (out of control)", "kind": "fight", "fight": "downed"},
	{"id": "fight_rearm", "label": "Combat: rearming on the base", "kind": "fight", "fight": "rearm"},
]


static func by_id(id: String) -> Dictionary:
	for s in LIST:
		if s.id == id:
			return s
	return LIST[0]


static func is_pose(s: Dictionary) -> bool:
	return s.has("pose")


## The point on the lab branch landings aim at.
static func aim_point(perch: Perch) -> Vector3:
	return perch.a.lerp(perch.b, 0.6)


## Put `bird` in the scenario's starting state and give it its pilot.
static func start(s: Dictionary, bird: Bird, layout: ArenaLayout) -> LabPilot:
	var pilot := LabPilot.new()
	var perch: Perch = layout.perches[0]
	var p := bird.profile
	bird.controller = pilot
	match s.get("kind", ""):
		"takeoff", "drop":
			pilot.kind = LabPilot.Kind.TAKEOFF if s.kind == "takeoff" else LabPilot.Kind.DROP
			bird.perch_at(perch)
			bird.perch_grip = aim_point(perch)
			bird.global_position = Perch.seat_at(bird.perch_grip, p)
			bird.model.position = bird.global_position
		"ground":
			pilot.kind = LabPilot.Kind.TAKEOFF
			pilot.wait = 1.0   # (settling onto the ground first)
			bird.fly_from(Vector3(2.0, 0.3, -5.0), Vector3(0.0, -1.0, 1.0).normalized(), 1.0)
		"land":
			pilot.kind = LabPilot.Kind.APPROACH
			pilot.target = aim_point(perch)
			pilot.aim_up = s.get("aim_up", 0.45)
			pilot.bleed = s.get("bleed", true)
			pilot.swoop = s.get("swoop", -1.0)
			var speed: float = maxf(p.v_best * float(s.speed), p.v_stall * 1.05)
			# Faster birds need a longer final to brake: the start moves out with best-glide speed.
			var from: Vector3 = s.from
			var k := maxf(1.0, p.v_best / 9.0)
			pilot.room = k
			bird.fly_from(pilot.target + Vector3(from.x * k, from.y, from.z * k), (s.dir as Vector3).normalized(), speed)
		"fight":
			pilot.kind = LabPilot.Kind.DROP   # (hands off: a drop that never lets go; LabFight places the bird)
			pilot.wait = INF
	return pilot
