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
## Routes (kind "ai", `arena` "forest": the pine wood, Pinewood.generate(FOREST_SEED), not the one-tree arena): the AI
## flies the bird (AIPilot, as in the game) and the lab's route view (RouteView, P) shows its lattice, route and
## predicted path. `goal` "rail": it's sent to land on an outpost's rail (the race's start rail, RaceCourse.starts_for),
## starting `out` m out, `bearing` degrees round from the way the rail faces, `up` m above it, heading for it at cruise.
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
	# Wood: glances, bonks and the reflexes.
	{"id": "glance_left", "label": "Glance: brushing the trunk on its left", "kind": "hit", "deg": 15.0, "side": -1.0, "speed": 1.0},
	{"id": "glance_right", "label": "Glance: brushing the trunk on its right", "kind": "hit", "deg": 15.0, "side": 1.0, "speed": 1.0},
	{"id": "bonk_steep", "label": "Bonk: into the trunk at 60 deg", "kind": "hit", "deg": 60.0, "side": -1.0, "speed": 1.0},
	{"id": "bonk_slow", "label": "Bonk: square on, slow", "kind": "hit", "deg": 90.0, "side": -1.0, "speed": 0.5},
	{"id": "head_on", "label": "Head-on: the flare reflex brakes", "kind": "hit", "deg": 90.0, "side": -1.0, "speed": 1.0},
	{"id": "wing_clip", "label": "Wing past the trunk: the tuck reflex", "kind": "hit", "gap": 0.12, "side": -1.0, "speed": 1.0},
	# Routes: the AI in the pine wood (RouteView).
	{"id": "rail_front", "label": "Route: AI lands on an outpost rail", "kind": "ai", "arena": "forest", "goal": "rail", "out": 36.0, "bearing": 50.0, "up": 5.0, "time": 40.0},
	{"id": "rail_behind", "label": "Route: AI to a rail from behind its tree", "kind": "ai", "arena": "forest", "goal": "rail", "out": 36.0, "bearing": 160.0, "up": 5.0, "time": 50.0},
	{"id": "ai_wander", "label": "Route: AI picks its own perches", "kind": "ai", "arena": "forest", "out": 30.0, "bearing": 90.0, "up": 8.0, "time": 90.0},
	# Combat (LabFight).
	{"id": "fight_gun", "label": "Combat: gun burst at a bird ahead", "kind": "fight", "fight": "gun"},
	{"id": "fight_rocket", "label": "Combat: hit by a rocket", "kind": "fight", "fight": "rocket"},
	{"id": "fight_seeker", "label": "Combat: seeker lock and launch", "kind": "fight", "fight": "seeker"},
	{"id": "fight_downed", "label": "Combat: downed (out of control)", "kind": "fight", "fight": "downed"},
	{"id": "fight_rearm", "label": "Combat: rearming on the base", "kind": "fight", "fight": "rearm"},
]


const FOREST_SEED := 7


## Does scenario `s` fly in the pine wood (not the lab's one tree)?
static func in_forest(s: Dictionary) -> bool:
	return s.get("arena", "") == "forest"


## The rail the route scenarios land on: the race's start rail (an outpost near the middle of the wood).
static func rail(layout: ArenaLayout) -> Perch:
	var all := RaceCourse.starts_for(layout)
	return all[0] if not all.is_empty() else layout.start_perch()


## Where a route scenario starts: `out` m out from the rail, `bearing` degrees round from its facing (the nearest
## free air to that, trying further round each way), `up` m above it. [position, heading].
static func route_start(s: Dictionary, layout: ArenaLayout) -> Array:
	var r := rail(layout)
	var face := Vector3(r.facing.x, 0.0, r.facing.z).normalized()
	for turn in [0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0, 90.0, -90.0]:
		for d in [1.0, 0.8, 1.2]:
			var dir := face.rotated(Vector3.UP, deg_to_rad(float(s.get("bearing", 0.0)) + float(turn)))
			var pos: Vector3 = r.position + dir * float(s.get("out", 30.0)) * float(d) + Vector3.UP * float(s.get("up", 5.0))
			if Vector2(pos.x, pos.z).length() < layout.reach(Vector2(pos.x, pos.z)) - 8.0 and layout.clear_by(pos, 3.0):
				var to := r.position - pos
				return [pos, Vector3(to.x, 0.0, to.z).normalized()]
	return [r.position + face * 30.0 + Vector3.UP * 5.0, -face]


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
		"hit":
			pilot.kind = LabPilot.Kind.GLIDE
			bird.perch_assist = 0.0
			# (a straight line past the axis at b meets the trunk -- R + r out, the body's sphere on its bark -- at
			# acos(b / (R + r)) off along its surface; heading +z the bird's left is +x)
			var tree: ArenaLayout.TreeData = layout.trees[0]
			var rr := tree.radius + maxf(0.06, p.body_length * 0.28)
			var b := rr * cos(deg_to_rad(float(s.deg))) * 0.995 if not s.has("gap") else rr + float(s.gap)   # (gap: passing clear)
			var axis := Vector3(tree.base.x, perch.position.y - 2.0, tree.base.y)
			bird.fly_from(axis + Vector3(float(s.side) * b, 0.0, -6.0), Vector3(0, 0, 1), p.v_best * float(s.speed))
		"ai":
			pilot.kind = LabPilot.Kind.AI
			pilot.ai = AIPilot.new(layout, 11)
			pilot.ai._fit(bird)   # (before the first plan, as RacePilot does: the bird's clearance and turning circle)
			var at := route_start(s, layout)
			bird.fly_from(at[0], at[1], p.v_best)
			if s.get("goal", "") == "rail":
				pilot.goal = rail(layout)
				pilot.ai.go_to_perch(bird, pilot.goal)
		"fight":
			pilot.kind = LabPilot.Kind.DROP   # (hands off: a drop that never lets go; LabFight places the bird)
			pilot.wait = INF
	return pilot
