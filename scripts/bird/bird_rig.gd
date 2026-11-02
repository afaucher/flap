class_name BirdRig
extends Node3D
## The bird's visual model: a Skeleton3D posed every tick from a handful of control values, with
## individual feathers placed on its bones (docs/design/wing_rig.md; the drawings in wing_rig_plan.html use
## the same WingShape numbers).
##
## Per wing: shoulder -> humerus -> elbow -> forearm -> wrist -> hand, driven by FIVE values -- `flap`
## (shoulder elevation), `fold` (elbow + wrist, coupled), `sweep` (shoulder protraction), `twist` (arm-wing
## incidence) and `alula` -- plus `hand_lift` (the flexed, drooping hand of the upstroke) and `slot` (the
## emarginated primaries splaying in slow flight). The wing in flight is forward kinematics; folding blends
## in a two-bone IK that puts the wrist on an anchor on the body's flank, so any species' folded wing hugs
## its own body. The body (BodyShape; docs/design/body_rig_plan.html) is a rigid trunk whose feather shell is
## lofted round the skeleton's landmarks, a three-bone neck that retracts into an S or reaches (`neck_ext`),
## and three-bone legs (a short femur hidden in the belly, then tibiotarsus and tarsus) solved to the perch's grip
## point or tucked. The head looks at a target, level with the world, and holds still in world space while the
## trunk jolts (head stabilisation). Feathers: primaries, secondaries, tertials, greater and
## lesser coverts, alula, 12 rectrices -- one shared tapered mesh in two MultiMeshes (plain, emarginated).
##
## animate() maps a Bird.telemetry() snapshot to the control values (smoothed); apply_pose() solves and
## writes everything. Rig space: -Z is the nose, +X the right wing, +Y up (the Bird's body frame).

const SIDES := [-1.0, 1.0]   ## left, right
const TAIL_FEATHERS := 12
## Feather outlines: [position along (0 base .. 1 tip), full width as a share of the feather's width]. Broad
## nearly to a rounded tip, as real flight and tail feathers are (a pointed outline left saw-tooth gaps).
## The emarginated (slotted) outer primaries narrow sharply past the middle: the gaps there are real.
const PLAIN_PROFILE := [[0.0, 0.12], [0.05, 0.55], [0.2, 0.9], [0.5, 1.0], [0.8, 0.97], [0.9, 0.86], [0.96, 0.62], [1.0, 0.12]]
const EMARG_PROFILE := [[0.0, 0.12], [0.05, 0.55], [0.2, 0.9], [0.45, 1.0], [0.55, 0.75], [0.62, 0.45], [0.9, 0.42], [0.97, 0.3], [1.0, 0.08]]
const TAIL_WIDTH := 0.2   ## rectrix width / length (a hawk's ~22 cm tail feather is ~4.5 cm wide)
const TAIL_FAN_MAX := 100.0   ## deg, full tail spread
## Sitting posture per species (docs/research/body_poses_and_folded_wings.md; the angles are estimates to
## tune against photos): body pitch when perched and on the ground (+ = upright), and how far the tail bends
## down from the body line. Raptors and owls sit upright with the tail in line; crows and sparrows sit
## more level with the tail angled down.
const POSE := {
	"sparrow": {"perch_pitch": 25.0, "ground_pitch": 10.0, "tail_down": 15.0},
	"crow": {"perch_pitch": 35.0, "ground_pitch": 10.0, "tail_down": 20.0},
	"hawk": {"perch_pitch": 60.0, "ground_pitch": 30.0, "tail_down": 5.0},
	"falcon": {"perch_pitch": 65.0, "ground_pitch": 35.0, "tail_down": 5.0},
	"owl": {"perch_pitch": 72.0, "ground_pitch": 45.0, "tail_down": 5.0},
}
const CAMBER := 0.03   ## feather arch height, as a share of its length
const FEATHER_SHADER := preload("res://scripts/bird/feather.gdshader")
const MARKS_SHADER := preload("res://scripts/bird/feather_marks.gdshader")
const TEXTURE_SHADER := preload("res://scripts/bird/feather_texture.gdshader")   ## plumage level 6
const BODY_TEXTURE_SHADER := preload("res://scripts/bird/body_feathers.gdshader")
const DOWN_SHADER := preload("res://scripts/bird/body_down.gdshader")
static var outline_down := true   ## plumage level 6: down at the outline (body_down.gdshader; gallery --no-down)
## Per-species feather look (docs/research/feather_rendering.md): glossy iridescent crow, matte barred soft
## owl, barred hawk with darker tips, falcon with buff margins, sparrow with pale edges and dark centres.
const FEATHER_LOOK := {
	"crow": {"sheen": 1.2, "iridescence": 0.75, "translucency": 0.15, "barring": 0.0, "pale_edge": 0.0, "dark_tip": 0.0, "centre_streak": 0.0, "softness": 0.08},
	"owl": {"sheen": 0.12, "iridescence": 0.0, "translucency": 0.6, "barring": 0.6, "bar_freq": 9.0, "pale_edge": 0.25, "dark_tip": 0.0, "centre_streak": 0.0, "softness": 0.28},
	"hawk": {"sheen": 0.4, "iridescence": 0.0, "translucency": 0.55, "barring": 0.55, "bar_freq": 6.0, "pale_edge": 0.15, "dark_tip": 0.45, "centre_streak": 0.0, "softness": 0.12},
	"falcon": {"sheen": 0.55, "iridescence": 0.0, "translucency": 0.4, "barring": 0.45, "bar_freq": 8.0, "pale_edge": 0.35, "dark_tip": 0.35, "centre_streak": 0.0, "softness": 0.08},
	"sparrow": {"sheen": 0.25, "iridescence": 0.0, "translucency": 0.5, "barring": 0.0, "pale_edge": 0.6, "dark_tip": 0.0, "centre_streak": 0.55, "softness": 0.16},
}

var profile: BirdProfile
var shape: WingShape
var skeleton: Skeleton3D
var bone_ends := {}   ## bone name -> [joint, far end] (rig space), as last posed (the lab's bone view)

# --- Control values (set by animate(), or directly by tests, then apply_pose()) ------------------------
var flap := deg_to_rad(5.0)     ## rad, shoulder elevation (+ = wings up)
var hand_lift := 0.0            ## deg, upstroke wrist flex (hand folds back and droops)
var fold := 0.0                 ## 0 spread .. 1 folded
var sweep := 0.0                ## deg, + = whole wing swept forward
var twist := 0.0                ## rad, arm-wing incidence (+ = leading edge up)
var alula := 0.0                ## 0..1
var slot := 0.0                 ## 0..1
var tail_spread := 0.2
var tail_pitch := 0.0           ## rad, + = tail down
var tail_twist := 0.0           ## rad
var look_dir := Vector3.FORWARD ## rig space, where the head looks
var world_up := Vector3.UP      ## rig space, for head stabilisation
var foot_targets: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var toe_grip := 0.0             ## 0 open .. 1 curled round a branch
var neck_ext := 0.3             ## 0 retracted (head on the shoulders) .. 1 reaching
var head_offset := Vector3.ZERO ## rig space, head stabilisation: where the head lags its neck target
var fluff := 1.0                ## plumage volume (1 sleek .. ~1.15 fluffed)
var breath := 0.0               ## -1..1, the breathing cycle

# --- Solved pose (rig space; read by tests) ------------------------------------------------------------
var wing_joints: Array = [[], []]     ## per side: [shoulder, elbow, wrist, hand tip]
var leg_joints: Array = [[], []]      ## per side: [hip, knee, ankle, foot]
var neck_joints: Array = []           ## [neck base, lower bend, upper bend, atlas (head centre)]
var body: BodyShape
var head_basis := Basis()
var fold_anchor: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var fold_elbow: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## folded elbow, on the flank
## Flat-colour feathers (the default). The feather shader (feather.gdshader) is parked: set this false to
## try it (rig gallery: --feather-shader). docs/research/feather_rendering.md has its status.
static var plain_feathers := true
static var flat_perch := false   ## rig gallery: the old level perched pose (before/after comparisons)
var feather_material: ShaderMaterial
var feather_xforms: Array[Transform3D] = []
var feather_codes: PackedFloat32Array = []    ## plumage level 6: each feather_xforms entry's atlas code (INSTANCE_CUSTOM.b); tests
var feather_kinds: PackedInt32Array = []      ## WingShape.Kind per feather_xforms entry (6 = tail); tests   ## every feather this tick (the MultiMeshes' copy; tests, debug)

var _L := 0.45
var _sh_up := 0.0
var _hip: Array[Vector3] = []
var _tib := 0.0
var _tars := 0.0
var _head_pos := Vector3.ZERO
var _tail_base := Vector3.ZERO
var _bones := {}
var _parents := {}
var _plain: MultiMesh
var _emarg: MultiMesh
var _plain_count := 0
var _emarg_count := 0
var _plain_u: MultiMesh          ## the feathers' undersides (plumage level 1+)
var _emarg_u: MultiMesh
var _two_sided := false
var _under_row := false
var _paint_dirty := true
var marks_material: ShaderMaterial   ## plumage level 5
var body_texture_material: ShaderMaterial   ## plumage level 6: the body's contour-feather material
var _colors := {}
var _head: Node3D
var _trunk: MeshInstance3D
var _neck_mi: MeshInstance3D
var _neck_mesh: ArrayMesh
var _head_world := Vector3.INF
var _body_tint := Color.WHITE
var _jaw: Node3D
var _membranes: Array[Node3D] = []
var blink := 0.0                ## 0 open .. 1 the nictitating membrane across
static var face_anim := true     ## saccades, idle scanning and blinks (off: the head eases onto its target, no blinks)
var _rng := RandomNumberGenerator.new()
var _sac_t := -1.0
var _sac_dur := 0.1
var _sac_from := Vector3.FORWARD
var _sac_to := Vector3.FORWARD
var _goal := Vector3.FORWARD
var _fix_left := 0.0
var _blink_t := -1.0
var _blink_cool := 0.0
var _arm_col := Callable()
var arm_web: Array = [{}, {}]         ## per side, the arm wing's loft this pose: {from, to, depth (elbow behind the edge), chord_at_elbow}
var _last_carrier := Vector3.ZERO
var _clock_t := 0.0
var _stance := 0.0
var flex := 0.0                 ## feather bend along the length: + tips up (downstroke load), - tips back/down (upstroke)
var _leg_meshes: Array = [[], []]     ## per side: [tibia, tarsus, toe x4]
var _fairings: Array = [[], []]       ## per side: [patagium, humerus, forearm, hand] (the wing's thickness)
var _built := false
var _defs: Array = []
var _clock := -1.0
var _defs_fold := -1.0
var _defs_slot := -1.0


func build(p: BirdProfile) -> void:
	profile = p
	shape = WingShape.for_profile(p)
	_L = p.body_length
	body = BodyShape.for_profile(p, shape)
	_rng.seed = hash(p.id)
	_sh_up = body.shoulder.y
	_tib = body.tib
	_tars = body.tars
	_hip = [body.hip * Vector3(-1, 1, 1), body.hip]
	_head_pos = body.neck_base + Vector3(0.0, body.neck_rest, -body.neck_rest * 0.5)
	_tail_base = body.tail_base
	# The folded wing is a Z lying flat on the flank (research: a panel inside the body outline, never above
	# the back): the humerus runs back from the shoulder, the elbow tucked against the flank; the forearm runs
	# forward to the wrist -- the bend of the wing -- at the front of the breast; the hand runs back again.
	# Elbow and wrist are slid round onto the shell (bone lengths kept); the fold IK targets the wrist and
	# bends toward the elbow.
	var l := shape.bone_lengths()
	var pad := _L * 0.01
	for i in 2:
		var s: float = SIDES[i]
		var sh := Vector3(s * shape.shoulder.x, _sh_up, shape.shoulder.y)
		var elbow := sh + Vector3(0.0, -0.25, 1.0).normalized() * l[0]
		for k in 4:
			elbow = sh + (body.onto_flank(elbow, s, pad) - sh).normalized() * l[0]
		var front := sh + Vector3(0.0, -_L * 0.06, -_L * 0.1)
		var wrist := elbow + (front - elbow).normalized() * l[1]
		for k in 4:
			wrist = elbow + (body.onto_flank(wrist, s, pad) - elbow).normalized() * l[1]
		fold_elbow[i] = elbow
		fold_anchor[i] = wrist
		foot_targets[i] = _tucked_foot(i)
	var tint := _tint(p.id)
	_colors = {
		WingShape.Kind.PRIMARY: tint.darkened(0.3),
		WingShape.Kind.SECONDARY: tint.darkened(0.18),
		WingShape.Kind.TERTIAL: tint.darkened(0.1),
		WingShape.Kind.ALULA: tint.darkened(0.25),
		WingShape.Kind.GREATER_COVERT: tint.darkened(0.02),
		WingShape.Kind.LESSER_COVERT: tint.lightened(0.08),
		"tail": tint.darkened(0.22),
	}
	_build_skeleton()
	_build_body(tint)
	_build_fairings(_colors[WingShape.Kind.LESSER_COVERT])
	_build_feathers()
	if plain_feathers and Plumage.level >= 6:
		_texture_body()
		if silhouette_cards:
			_build_cards()
	_built = true
	apply_pose()


static func _tint(bird_id: String) -> Color:
	match bird_id:
		"owl": return Color(0.66, 0.58, 0.46)
		"hawk": return Color(0.55, 0.42, 0.32)
		"falcon": return Color(0.45, 0.5, 0.58)
		"sparrow": return Color(0.6, 0.5, 0.4)
	return Color(0.3, 0.3, 0.33)


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


## Body plumage: matte with a soft rim of light at grazing angles (the velvety look of contour feathers).
func _plumage(c: Color) -> StandardMaterial3D:
	var m := _material(c)
	m.roughness = 0.95
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	return m


# --- Construction ------------------------------------------------------------------------------------

func _build_skeleton() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	var names := ["body", "neck.0", "neck.1", "neck.2", "head", "tail"]
	for side in ["L", "R"]:
		for b in ["humerus", "forearm", "hand", "femur", "tibia", "tarsus"]:
			names.append("%s.%s" % [b, side])
	for n in names:
		_bones[n] = skeleton.add_bone(n)
	for side in ["L", "R"]:
		_parents["humerus." + side] = "body"
		_parents["forearm." + side] = "humerus." + side
		_parents["hand." + side] = "forearm." + side
		_parents["femur." + side] = "body"
		_parents["tibia." + side] = "femur." + side
		_parents["tarsus." + side] = "tibia." + side
	_parents["neck.0"] = "body"
	_parents["neck.1"] = "neck.0"
	_parents["neck.2"] = "neck.1"
	_parents["head"] = "neck.2"
	_parents["tail"] = "body"
	for n in _parents:
		skeleton.set_bone_parent(_bones[n], _bones[_parents[n]])


func _build_body(tint: Color) -> void:
	_body_tint = tint.darkened(0.12)
	# Body plumage colours ride on the vertices (Plumage: countershading, zones, head marks).
	var body_mat := _plumage(Color.WHITE) if not plain_feathers else _material(Color.WHITE)
	body_mat.vertex_color_use_as_albedo = true
	body_mat.vertex_color_is_srgb = true
	var leg_mat := _material(Color(0.72, 0.6, 0.32))
	# The trunk shell, lofted once round the landmarks; the neck tube is re-lofted each pose.
	_trunk = MeshInstance3D.new()
	_trunk.name = "Trunk"
	var collar := body.ring_at(body.collar_z)
	var collar_r := (collar[1] + 0.5 * (collar[2] + collar[3])) * 0.5
	_neck_entry = clampf(asin(minf(collar_r / (body.head_r * 0.5 * (body.skull.x + body.skull.y)), 1.0)), 0.9, 1.45)
	_init_feather_coords()
	_trunk.mesh = body.trunk_mesh(30, TRUNK_AROUND, _body_color_at, body.collar_z, _tile, _size_trunk, _neck_v0)
	_trunk.material_override = body_mat
	add_child(_trunk)
	_neck_mesh = ArrayMesh.new()
	_neck_mi = MeshInstance3D.new()
	_neck_mi.name = "Neck"
	_neck_mi.mesh = _neck_mesh
	_neck_mi.material_override = body_mat
	add_child(_neck_mi)
	_head = Node3D.new()
	_head.position = _head_pos
	add_child(_head)
	# The skull: the head sphere scaled per species (the crow's long head, the hawk's flat crown, the owl's flat
	# face); the eyes and brows ride on it.
	var skull := Node3D.new()
	skull.name = "Skull"
	skull.scale = body.skull
	_head.add_child(skull)
	var head := MeshInstance3D.new()
	head.name = "HeadSurface"
	var hr := body.head_r
	head.mesh = _build_head_mesh()
	head.material_override = body_mat
	_head.add_child(head)
	_build_face(skull, body_mat, hr)
	for i in 2:
		var parts: Array = []
		for k in 6:
			var mi := MeshInstance3D.new()
			var c := CapsuleMesh.new()
			c.radius = _L * (0.03 if k == 0 else (0.018 if k == 1 else 0.01))
			c.height = 1.0   # rescaled per frame
			mi.mesh = c
			mi.material_override = _material(_body_color_at(0.6, -0.6, 0.8)) if k == 0 else leg_mat   # (the feathered drumstick)
			add_child(mi)
			parts.append(mi)
		_leg_meshes[i] = parts


## The wing's thickness, from the anatomy (the arm is not a cylinder):
## - The PROPATAGIUM is a skin fold from shoulder to wrist, held taut by the tensor propatagialis tendon. It
##   makes the arm wing's leading edge a straight line in front of the elbow, rounded by the tendon along
##   its rim, and slackens away as the wing folds.
## - The HUMERUS carries the arm's muscle (biceps, triceps, deltoid): thickest near the shoulder.
## - The FOREARM's muscle bellies sit by the elbow and run out into tendons toward the wrist.
## - The HAND is bone and tendon: thin.
## Each piece is lofted once as a unit mesh with an airfoil section (round and thick at the front where the
## bone or tendon is, thin behind, a little cambered), the covert padding over the limb; the flight feathers
## carry on behind as the thin trailing edge. Per piece: [thickness at the root end, at the far end] and
## [chord at the root end, at the far end] as fractions of the root chord, and where a muscle belly bulges
## (u along the bone; -1 none). The propatagium's chord is a hump set per pose (the elbow's depth behind the
## leading edge).
const LIMB := [
	{"t": [0.06, 0.035], "c": [1.0, 1.0], "belly": -1.0},   # propatagium (chord scaled per pose)
	{"t": [0.12, 0.08], "c": [0.4, 0.32], "belly": 0.35},    # humerus
	{"t": [0.11, 0.045], "c": [0.34, 0.24], "belly": 0.15},  # forearm
	{"t": [0.05, 0.022], "c": [0.22, 0.1], "belly": -1.0},   # hand
]


## (chord, thickness) of limb piece `piece` at `u` (0 root end .. 1 far end), in the units of LIMB.
static func limb_section(piece: int, u: float) -> Vector2:
	var d: Dictionary = LIMB[piece]
	var uc := clampf(u, 0.0, 1.0)
	var t := lerpf(d.t[0], d.t[1], uc)
	if float(d.belly) >= 0.0:
		t *= 1.0 + 0.3 * exp(-pow((uc - float(d.belly)) / 0.22, 2.0))
	var c := lerpf(d.c[0], d.c[1], uc)
	if piece == 0:
		c = 0.15 + 0.85 * pow(sin(PI * uc), 0.6)   # the web is deepest mid-span, narrow at shoulder and wrist
	return Vector2(c, t)


## Half-thickness of a NACA 4-digit section of unit thickness at chord fraction x (max 0.5 near x = 0.3).
static func _naca(x: float) -> float:
	return 5.0 * (0.2969 * sqrt(x) - 0.126 * x - 0.3516 * x * x + 0.2843 * x * x * x - 0.1036 * x * x * x * x)


## Unit limb mesh: z 0..1 along the bone (with rounded caps just past each end), x aft (chord units), y the
## wing normal (root-chord units). The bone runs just behind the nose.
static func _limb_mesh(piece: int, color := Callable()) -> ArrayMesh:
	var rows: Array = []
	var cols: Array = []
	var uvs: Array = []   # (feather coordinates in the unit mesh's own frame: along the bone, aft; level 6)
	var uv2s: Array = []
	var around := 16
	var steps := 14
	for k in steps + 1:
		var urow: Array = []
		var u2row: Array = []
		for j in around + 1:
			var a := TAU * (j % around) / around
			urow.append(Vector2(lerpf(-0.06, 1.06, float(k) / steps) * 3.0, 0.5 * (1.0 - cos(a)) * 1.5))
			u2row.append(Vector2(NO_PERIOD, -clampf(sin(a) * 4.0, -1.0, 1.0)))
		uvs.append(urow)
		uv2s.append(u2row)
		var u := lerpf(-0.06, 1.06, float(k) / steps)
		var cap := sqrt(clampf(minf(u + 0.06, 1.06 - u) / 0.12, 0.0, 1.0))
		var sec := limb_section(piece, u)
		var c := sec.x * cap
		var t := sec.y * cap
		var nose := 0.0 if piece == 0 else 0.06   # the propatagium's leading edge IS the line
		var row: Array = []
		var crow: Array = []
		for j in around:
			var a := TAU * j / around
			var x := 0.5 * (1.0 - cos(a))          # 0 at the leading edge, 1 at the trailing edge
			var half := _naca(x) * t
			var y := 0.02 * c * sin(PI * x) + (-half if sin(a) >= 0.0 else half)   # (lower first: outward winding)
			row.append(Vector3((x - nose) * c, y, u))
			if color.is_valid():
				crow.append(color.call(piece, x, clampf(u, 0.0, 1.0), sin(a) >= 0.0))
		rows.append(row)
		cols.append(crow)
	return BodyShape.tube_mesh(rows, null, cols if color.is_valid() else [], uvs, uv2s)


func _build_fairings(c: Color) -> void:
	var mat := _plumage(Color.WHITE) if not plain_feathers else _material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	# Coloured per species: upperwing coverts on top; from plumage level 2 the under-coverts below, with the
	# patagial bar along the front underside and the dark wrist comma.
	var col := func(piece: int, x: float, u: float, under: bool) -> Color:
		return c if Plumage.level == 0 else Plumage.limb(profile.id, piece, x, u, under)
	var meshes: Array = []
	for k in 4:
		meshes.append(_limb_mesh(k, col))
	_arm_col = col   # (the arm wing, piece 0, is lofted every pose: _loft_arm)
	for i in 2:
		var parts: Array = []
		for k in 4:
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[k] if k > 0 else ArrayMesh.new()
			mi.material_override = mat
			add_child(mi)
			parts.append(mi)
		_fairings[i] = parts



const ARM_STATIONS := 10
const ARM_AROUND := 16
const ARM_U0 := 0.2     ## where the arm surface proper starts; inboard of it, connector rows to the body
const ROOT_ROWS := 4


## The arm wing's covering, lofted each pose from the body to the wrist. On a bird the skin web
## (propatagium), the arm's muscle and the small covert feathers over them read as ONE smooth surface -- the
## feathers hide where skin meets arm -- so this is one loft, not separate pieces with creases where they
## cross. Its leading edge is the straight line shoulder -> wrist (the propatagium's tendon); each station
## reaches back over the bone beneath it plus the coverts' padding; an airfoil section, thick at the root
## (the arm's muscle) and thin at the wrist. `open` fades it as the wing folds.
##
## It joins the body the way every joint here does: a fixed edge loop on the body (points ON the trunk's
## surface round the shoulder, coloured with the trunk's own colours there) and connector rows lofted from it
## to the arm's first section, so the join is continuous in shape and colour, and flexes as the wing moves.
func _loft_arm(i: int, mi: MeshInstance3D, sh: Vector3, elbow: Vector3, wrist: Vector3, n_in: Vector3, s: float, open: float) -> void:
	var span := sh.distance_to(wrist)
	if span < 1e-5 or open <= 0.01:
		mi.visible = false
		arm_web[i] = {}
		return
	mi.visible = true
	var rc := shape.root_chord()
	var le := (wrist - sh) / span
	var nn := (n_in - le * le.dot(n_in)).normalized()
	var aft := (le.cross(nn) * s).normalized()
	var flip := aft.cross(nn).dot(le) < 0.0   # (keep the faces' winding outward on either wing)
	var l_h := sh.distance_to(elbow)
	var l_f := elbow.distance_to(wrist)
	var depth_elbow := maxf((elbow - sh).dot(aft), 0.0)
	var rows: Array = []
	var cols: Array = []
	var aus: Array = []   # (per station: its distance out along the arm, and its rest chord: feather coordinates)
	var chord_elbow := 0.0
	var chord_root := 0.0
	for k in ARM_STATIONS + 2:   # stations ARM_U0 .. 1, then the closed wrist end (inside the hand's piece)
		var u := lerpf(ARM_U0, 1.0, clampf(float(k) / ARM_STATIONS, 0.0, 1.0))
		aus.append(Vector2((u - ARM_U0) * (l_h + l_f) + _L * 0.04, rc * lerpf(0.6, 0.35, u)))
		var e := sh + le * span * u
		# Near the body the surface flexes rather than pivots: its sections ease from the body's plane at the root
		# to the wing's by about 40% of the way out, so a raised or lowered wing bends at the shoulder.
		var nu := Vector3.UP.slerp(nn, smoothstep(0.0, 0.4, u))
		nu = (nu - le * le.dot(nu)).normalized()
		var aft_u := (le.cross(nu) * s).normalized()
		var arc := u * (l_h + l_f)
		var bone := sh.lerp(elbow, arc / maxf(l_h, 1e-5)) if arc <= l_h else elbow.lerp(wrist, (arc - l_h) / maxf(l_f, 1e-5))
		var depth := maxf((bone - e).dot(aft_u), 0.0)
		var chord := (depth + rc * lerpf(0.42, 0.26, u)) * open
		var thick := rc * lerpf(0.14, 0.055, u) * (1.0 + 0.15 * exp(-pow((u - 0.25) / 0.2, 2.0))) * open
		# The surface's trailing lip lies ON the greater coverts, as the small coverts do on a wing: raised over the
		# row (its stack layer, plus the cards' arch) instead of thinning to nothing at the bone's level, where the
		# coverts broke out through it.
		var lip := (0.0075 * _L / 0.45 + CAMBER * 0.45 * rc) * open
		if k == ARM_STATIONS + 1:
			chord = 0.0
			thick = 0.0
		if k == 0:
			chord_root = chord
		if absf(arc - l_h) < (l_h + l_f) / ARM_STATIONS * 0.5:
			chord_elbow = chord
		var row: Array = []
		var crow: Array = []
		for j in ARM_AROUND:
			var a := TAU * j / ARM_AROUND * (-1.0 if flip else 1.0)
			var x := 0.5 * (1.0 - cos(a))
			var half := _naca(x) * thick
			var y := 0.02 * chord * sin(PI * x) + lip * smoothstep(0.15, 1.0, x) + (-half if sin(a) >= 0.0 else half)
			row.append(e + aft_u * (x * chord) + nu * y)
			crow.append(_arm_col.call(2, x, u, sin(a) >= 0.0))
		rows.append(row)
		cols.append(crow)
	# The body's edge loop round the shoulder, in the same order as the sections (leading edge first, the lower
	# side first), and the connector rows out to the arm's first section.
	var st := fluff * (1.0 + 0.012 * breath)
	var z0 := sh.z - _L * 0.02
	var z1 := sh.z + maxf(chord_root, rc * 0.2) * 0.8
	var zc := (z0 + z1) * 0.5
	var az := (z1 - z0) * 0.5
	var ay := rc * 0.09 * open
	var loop: Array = []
	var lcols: Array = []
	var luv: Array = []
	var luv2: Array = []
	for j in ARM_AROUND:
		var a := TAU * j / ARM_AROUND * (-1.0 if flip else 1.0)
		var z := zc - az * cos(a)
		var y := sh.y - _L * 0.01 - ay * sin(a)
		var x := s * body.half_width_at(z, y)
		loop.append(Vector3(x, y, z) * st)
		var ring := body.ring_at(z)
		var hgt := ring[2] if y >= ring[0] else ring[3]
		lcols.append(_body_color_at(body.u_at(z), clampf((y - ring[0]) / maxf(hgt, 1e-4), -1.0, 1.0), clampf(absf(x) / maxf(ring[1], 1e-4), 0.0, 1.0)))
		var fc := body.uv_at(Vector3(x, y, z))   # (the trunk's own feather coordinates there)
		luv.append(fc[0])
		luv2.append(fc[1])
	# The arm's feather coordinates run on from the loop's: u outward along the arm (away from the spine, as the
	# trunk's u runs at the shoulder), v aft across the chord from the loop's leading point, in the coverts'
	# size; fixed per station and section point, so the coverts ride on the surface as it flexes and folds.
	var unit := _tile * ARM_FEATHER
	var auv: Array = []
	var auv2: Array = []
	for k in rows.size():
		var urow: Array = []
		var u2row: Array = []
		var au: Vector2 = aus[k]
		for j in ARM_AROUND + 1:
			var a := TAU * (j % ARM_AROUND) / ARM_AROUND
			urow.append(Vector2((luv[j % ARM_AROUND] as Vector2).x - s * au.x / unit, (luv[0] as Vector2).y + 0.5 * (1.0 - cos(a)) * au.y / unit))
			u2row.append(Vector2(NO_PERIOD, -clampf(sin(a) * (-1.0 if flip else 1.0) * 4.0, -1.0, 1.0)))
		auv.append(urow)
		auv2.append(u2row)
	var first: Array = rows[0]
	var fcols: Array = cols[0]
	var joined: Array = [loop]
	var jcols: Array = [lcols]
	var juv: Array = [luv + [luv[0]]]
	var juv2: Array = [luv2 + [luv2[0]]]
	for r in range(1, ROOT_ROWS):
		var w := smoothstep(0.0, 1.0, float(r) / ROOT_ROWS)
		var row: Array = []
		var crow: Array = []
		var urow: Array = []
		var u2row: Array = []
		for j in ARM_AROUND + 1:
			if j < ARM_AROUND:
				row.append((loop[j] as Vector3).lerp(first[j], w))
				crow.append((lcols[j] as Color).lerp(fcols[j], w))
			urow.append((juv[0][j] as Vector2).lerp(auv[0][j], w))
			u2row.append((juv2[0][j] as Vector2).lerp(auv2[0][j], w))
		joined.append(row)
		jcols.append(crow)
		juv.append(urow)
		juv2.append(u2row)
	arm_web[i] = {"from": sh, "to": wrist, "depth": depth_elbow, "chord_at_elbow": chord_elbow}
	BodyShape.tube_mesh(joined + rows, mi.mesh as ArrayMesh, jcols + cols, juv + auv, juv2 + auv2)

## Lay a unit limb mesh from `a` to `b`, its chord aft and its thickness along `n`; `chord` scales x (m).
## `tuck` (0..1): folding, the humerus and the hand run BACK along the body, so their "aft" side -- the muscle
## and covert padding behind the bone in the spread wing -- would point straight up, a slab standing above the
## back. Folded, that side turns in, through the body side (-n), until it lies inside the fold (toward the
## forearm), as the arm's trailing web does on a bird. Past halfway the piece is mirrored rather than turned on,
## so its upper face (the upperwing's colours) still faces out, not its pale underside.
func _place_limb(mi: MeshInstance3D, a: Vector3, b: Vector3, n: Vector3, side: float, chord: float, fade: float, thick := 1.0, tuck := 0.0) -> void:
	var d := b - a
	var length := d.length()
	if length < 1e-5 or fade <= 0.01:
		mi.visible = false
		return
	mi.visible = true
	var u := d / length
	var nn := (n - u * u.dot(n)).normalized()
	var aft := (u.cross(nn) * side).normalized()
	if tuck > 0.0:
		var th := PI * tuck
		var a2 := aft * cos(th) - nn * sin(th)
		nn = nn * absf(cos(th)) + aft * sin(th)
		aft = a2
	mi.transform = Transform3D(Basis(aft * chord * fade, nn * shape.root_chord() * fade * thick, d), a)


## `flip`: the underside copy -- the same surface, wound the other way with its normal down, so each copy
## (culling its back) draws one face in that face's colour.
func _feather_mesh(profile_pts: Array, flip := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in profile_pts.size() - 1:
		var a: Array = profile_pts[k]
		var b: Array = profile_pts[k + 1]
		var al := Vector3(-a[1] * 0.5, 0.0, a[0])
		var ar := Vector3(a[1] * 0.5, 0.0, a[0])
		var bl := Vector3(-b[1] * 0.5, 0.0, b[0])
		var br := Vector3(b[1] * 0.5, 0.0, b[0])
		var uvs := [Vector2(-1, a[0]), Vector2(1, a[0]), Vector2(1, b[0]), Vector2(-1, a[0]), Vector2(1, b[0]), Vector2(-1, b[0])]
		var vs := [al, ar, br, al, br, bl]
		if flip:
			uvs = [uvs[0], uvs[2], uvs[1], uvs[3], uvs[5], uvs[4]]
			vs = [al, br, ar, al, bl, br]
		for q in 6:
			var v: Vector3 = vs[q]
			# A gentle arch along the feather (3% of its length at the middle): cambered, not a flat card.
			var arched := Vector3(v.x, CAMBER * sin(PI * v.z), v.z)
			# UV.x: -1..1 edge to edge across the vane (0 = the shaft); UV.y: 0..1 base to tip. Tangent: across.
			st.set_normal(Vector3.DOWN if flip else Vector3.UP)
			st.set_tangent(Plane(1.0, 0.0, 0.0, 1.0))
			st.set_uv(uvs[q])
			st.add_vertex(arched)
	return st.commit()


func _build_feathers() -> void:
	_under_row = Plumage.level >= 2 and plain_feathers
	_two_sided = Plumage.level >= 1 and plain_feathers
	var defs := shape.feathers(0.0, 0.0, _under_row)
	_plain_count = TAIL_FEATHERS
	_emarg_count = 0
	for f in defs:
		if f.emarg:
			_emarg_count += 2
		else:
			_plain_count += 2
	var mat: Material
	if plain_feathers and Plumage.level >= 5:
		marks_material = ShaderMaterial.new()
		marks_material.shader = MARKS_SHADER if Plumage.level < 6 else TEXTURE_SHADER
		marks_material.set_shader_parameter("strip", Plumage.strip(profile.id))
		marks_material.set_shader_parameter("rows", float(Plumage.GROUPS.size() * 2))
		if Plumage.level >= 6:
			_texture_feathers(marks_material)
		mat = marks_material
	elif plain_feathers:
		# Flat colour per feather; from plumage level 1 each face its own copy (culling its back).
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.vertex_color_is_srgb = true
		sm.cull_mode = BaseMaterial3D.CULL_BACK if _two_sided else BaseMaterial3D.CULL_DISABLED
		sm.roughness = 0.9
		mat = sm
	else:
		feather_material = ShaderMaterial.new()
		feather_material.shader = FEATHER_SHADER
		var look: Dictionary = FEATHER_LOOK.get(profile.id, FEATHER_LOOK["crow"])
		for k in look:
			feather_material.set_shader_parameter(k, look[k])
		mat = feather_material
	_plain = _multimesh(_feather_mesh(PLAIN_PROFILE), _plain_count, mat, "Feathers")
	_emarg = _multimesh(_feather_mesh(EMARG_PROFILE), maxi(_emarg_count, 1), mat, "SlottedPrimaries")
	if _two_sided:
		_plain_u = _multimesh(_feather_mesh(PLAIN_PROFILE, true), _plain_count, mat, "FeathersUnder")
		_emarg_u = _multimesh(_feather_mesh(EMARG_PROFILE, true), maxi(_emarg_count, 1), mat, "SlottedPrimariesUnder")
	if _emarg_count == 0:
		_emarg.visible_instance_count = 0
		if _emarg_u != null:
			_emarg_u.visible_instance_count = 0
	_paint_dirty = true


## Plumage level 6: the feather atlas and each strip row's look (Plumage.texture_look) on the feather shader.
func _texture_feathers(m: ShaderMaterial) -> void:
	m.set_shader_parameter("atlas", FeatherAtlas.load_atlas())
	m.set_shader_parameter("atlas_n", FeatherAtlas.load_atlas_normal())
	m.set_shader_parameter("cell_rect", FeatherAtlas.cell_rects())
	m.set_shader_parameter("cell_shape", FeatherAtlas.cell_shapes())
	var spots := PackedVector4Array()
	var fringes := PackedVector4Array()
	var misc := PackedVector4Array()
	var gloss := PackedVector4Array()
	var vane_out := PackedVector4Array()
	var vane_in := PackedVector4Array()
	var vane_misc := PackedVector4Array()
	# (each flight group's longest feather: bars are read in metres from the tip, so they line up into bands
	# across feathers of different lengths -- docs/research/flight_feather_look.md 12)
	var longest := {}
	for f in shape.feathers(0.0, 0.0, _under_row):
		var fg := Plumage.group(int(f.kind), int(f.i), int(f.bone))
		longest[fg] = maxf(float(longest.get(fg, 0.0)), float(f.len))
	longest["tail"] = profile.tail_length
	for g in Plumage.GROUPS:
		for u in 2:
			var gl := Plumage.gloss(profile.id, g)
			gloss.append(Vector4(float(gl[0]), float(gl[1]), float(gl[2]), float(gl[3]) if gl.size() > 3 else 0.0))
			var look := Plumage.texture_look(profile.id, g, u == 1)
			var vn: Array = look.get("vane", ["#000000", 0.0, "#000000", 0.0])
			var vo := Plumage.hex(vn[0])
			var vi := Plumage.hex(vn[2])
			vane_out.append(Vector4(vo.r, vo.g, vo.b, float(vn[1])))
			vane_in.append(Vector4(vi.r, vi.g, vi.b, float(vn[3])))
			var fv: Array = look.get("fringe_vane", [1.0, 1.0])
			var flight: bool = g in ["primary", "secondary", "tertial", "tail"]
			vane_misc.append(Vector4(float(fv[0]), float(fv[1]), float(longest.get(g, 0.0)) if flight else 0.0, 1.0 if flight and u == 0 else 0.0))
			var sc := Plumage.hex(look.spot[0])
			var fc := Plumage.hex(look.fringe[0])
			spots.append(Vector4(sc.r, sc.g, sc.b, float(look.spot[1])))
			fringes.append(Vector4(fc.r, fc.g, fc.b, float(look.fringe[1])))
			misc.append(Vector4(float(look.spot[2]), float(look.shaft), float(look.detail), float(look.cup)))
	m.set_shader_parameter("spot", spots)
	m.set_shader_parameter("fringe", fringes)
	m.set_shader_parameter("misc", misc)
	m.set_shader_parameter("gloss", gloss)
	m.set_shader_parameter("vane_out", vane_out)
	m.set_shader_parameter("vane_in", vane_in)
	m.set_shader_parameter("vane_misc", vane_misc)


## Plumage level 6: one contour-feather material (body_feathers.gdshader) over the trunk, neck, head and the
## wing's arm loft and limb pieces, read through their shared feather coordinates (UV, UV2, COLOR.a; see
## "Feather coordinates"), so the pattern runs on across the joins.
func _texture_body() -> void:
	var look := Plumage.body_texture(profile.id)
	var m := ShaderMaterial.new()
	m.shader = BODY_TEXTURE_SHADER
	m.set_shader_parameter("scales", FeatherAtlas.load_body())
	m.set_shader_parameter("scales_n", FeatherAtlas.load_body_normal())
	var sc := Plumage.hex(look.spot[0])
	m.set_shader_parameter("spot_tint", Vector3(sc.r, sc.g, sc.b))
	m.set_shader_parameter("spot_back", float(look.spot[1]))
	m.set_shader_parameter("spot_belly", float(look.spot[2]))
	m.set_shader_parameter("spot_size", float(look.spot[3]))
	var fc := Plumage.hex(look.fringe[0])
	m.set_shader_parameter("fringe_col", Vector3(fc.r, fc.g, fc.b))
	m.set_shader_parameter("fringe_amt", float(look.fringe[1]))
	m.set_shader_parameter("fringe_w", float(look.fringe[2]))
	body_texture_material = m
	# Down and loose barb tips at the outline: two shells a few millimetres out, strands only where the surface is
	# seen edge-on (body_down.gdshader), drawn as next passes of the same meshes.
	if outline_down:
		var prev: Material = m
		for layer in [1.0, 2.0]:
			var d := ShaderMaterial.new()
			d.shader = DOWN_SHADER
			d.set_shader_parameter("height", 0.006 * _L / 0.45)
			d.set_shader_parameter("layer", layer)
			d.set_shader_parameter("layers", 2.0)
			prev.next_pass = d
			prev = d
	_trunk.material_override = m
	_neck_mi.material_override = m
	(_head.get_node("HeadSurface") as MeshInstance3D).material_override = m
	for i in 2:
		for k in 4:
			(_fairings[i][k] as MeshInstance3D).material_override = m

# --- Silhouette cards (plumage level 6) ---------------------------------------------------------------------
## Loose contour feathers where the body's outline shows (docs/research/feather_texture_study.md, "Silhouette").
## The textured shell is smooth, so its outline is a clean curve; on a bird the feathers there lie over each other
## and their tips break it. Small cards in the tracts that show most, each coloured with the body's own colour where
## it is rooted and drawn with the lesser-covert atlas cells (row "contour" of the feather material):
##   scapular  over each shoulder, onto the wing's root (and the top of the folded wing)
##   flank     low on each side, along the folded wing's lower edge
##   rump      the uppertail coverts, over the tail's base (they follow the tail's pitch part way)
##   vent      the undertail coverts
## (The legs' trousers belong to the leg rig.) Per tract: `rows` x `n` cards; `t` the angle round the trunk
## [from, to] (deg: 0 the side, 90 the back, -90 the keel; mirrored for the left side unless `centre`); `u` along
## the trunk [from, to] (0 front .. 1 back; "sh" / "hip" mark the shoulder's or hip's u, plus the offset); `len`
## (share of L) and `w` (share of len); `lift` (deg off the surface: the tip stands off it); `tail` how far the
## cards follow the tail's pitch; `arch` the cards' camber (1: a flight feather's).
static var silhouette_cards := true
const CARD_TRACTS := {
	"scapular": {"rows": 3, "n": 4, "t": [42.0, 72.0], "u": ["sh", -0.02, "sh", 0.22], "len": 0.1, "w": 0.45, "lift": 0.0, "tail": 0.0, "arch": 0.25},
	"flank": {"rows": 2, "n": 4, "t": [-36.0, -62.0], "u": ["sh", 0.12, "hip", 0.06], "len": 0.11, "w": 0.55, "lift": 4.0, "tail": 0.0},
	"rump": {"rows": 2, "n": 5, "t": [58.0, 122.0], "u": ["", 0.8, "", 0.95], "len": 0.12, "w": 0.6, "lift": 4.0, "tail": 0.5, "centre": true},
	"vent": {"rows": 2, "n": 4, "t": [-62.0, -118.0], "u": ["", 0.8, "", 0.95], "len": 0.11, "w": 0.6, "lift": 5.0, "tail": 0.4, "centre": true},
}
var card_xforms: Array[Transform3D] = []   ## each silhouette card this pose (trunk space; tests)
var card_tracts: PackedStringArray = []
var _cards: MultiMesh
var _cards_u: MultiMesh
var _card_defs: Array = []   ## per card: {pos, n, aft (trunk space), len, w, lift, tail, colour, row}
var _cards_pitch := INF
var _cover_fold := INF


## A point of the trunk's shell at angle `t` (rad, 0 the +X side, PI/2 the back) and `u` along it: [point, outward
## normal, aft tangent] (trunk space).
func _trunk_point(t: float, u: float) -> Array:
	var z := lerpf(body.front_z(), body.back_z(), u)
	var at := func(tt: float, zz: float) -> Vector3:
		var r := body.ring_at(zz)
		var h := r[2] if sin(tt) >= 0.0 else r[3]
		return Vector3(r[1] * BodyShape._se(cos(tt), sin(tt)), r[0] + h * BodyShape._se(sin(tt), sin(tt)), zz)
	var p: Vector3 = at.call(t, z)
	var dz := (body.back_z() - body.front_z()) * 0.01
	var aft: Vector3 = (at.call(t, z + dz) - at.call(t, z - dz)).normalized()
	var round_t: Vector3 = (at.call(t + 0.01, z) - at.call(t - 0.01, z)).normalized()
	var n := round_t.cross(aft).normalized()
	if n.dot(p - Vector3(0.0, body.ring_at(z)[0], z)) < 0.0:
		n = -n
	return [p, n, aft]


func _build_cards() -> void:
	_card_defs.clear()
	card_tracts.clear()
	var u_sh := body.u_at(body.shoulder.z)
	var u_hip := body.u_at(body.hip.z)
	for tract in CARD_TRACTS:
		var c: Dictionary = CARD_TRACTS[tract]
		var u0: float = (u_sh if c.u[0] == "sh" else (u_hip if c.u[0] == "hip" else 0.0)) + float(c.u[1])
		var u1: float = (u_sh if c.u[2] == "sh" else (u_hip if c.u[2] == "hip" else 0.0)) + float(c.u[3])
		for side in ([1.0] if c.get("centre", false) else [-1.0, 1.0]):
			for r in int(c.rows):
				var u := lerpf(u0, u1, (r + 0.5) / float(c.rows))
				for k in int(c.n):
					var f := clampf((k + 0.5 + 0.5 * float(r % 2) - 0.25) / float(c.n), 0.0, 1.0)
					var t := deg_to_rad(lerpf(c.t[0], c.t[1], f))
					if side < 0.0:
						t = PI - t
					var sp: Array = _trunk_point(t, u)
					# (front rows lie over the rows behind: their tips cover the next row's bases)
					_card_defs.append({"pos": sp[0], "n": sp[1], "aft": sp[2], "len": float(c.len) * _L, "w": float(c.len) * float(c.w) * _L,
						"lift": deg_to_rad(float(c.lift)), "tail": float(c.tail), "arch": float(c.get("arch", 0.6)), "colour": _body_color_at(u, sin(t), absf(cos(t))), "row": float(int(c.rows) - r)})
					card_tracts.append(tract)
	var n := _card_defs.size()
	_cards = _multimesh(_feather_mesh(PLAIN_PROFILE), n, marks_material, "SilhouetteCards")
	_cards_u = _multimesh(_feather_mesh(PLAIN_PROFILE, true), n, marks_material, "SilhouetteCardsUnder")
	for node_name in ["SilhouetteCards", "SilhouetteCardsUnder"]:   # (they ride on the trunk: its fluff and breathing scale them too)
		var mmi := get_node(node_name)
		remove_child(mmi)
		_trunk.add_child(mmi)
	var row_top := Plumage.row_index("contour", false)
	var row_under := Plumage.row_index("contour", true)
	marks_material.set_shader_parameter("contour_row", row_top)
	marks_material.set_shader_parameter("contour_fringe", float(Plumage.body_texture(profile.id).fringe[1]))
	for i in n:
		var d: Dictionary = _card_defs[i]
		var code := FeatherAtlas.cell("contour", false, i, 0) + 1.0
		var vseed := FeatherAtlas._hash(float(i) * 1.37, 4.2)
		_cards.set_instance_color(i, d.colour)
		_cards_u.set_instance_color(i, d.colour)
		_cards.set_instance_custom_data(i, Color(row_top, 0.0, code, vseed))
		_cards_u.set_instance_custom_data(i, Color(row_under, 0.0, code, vseed))
	_pose_cards()


## Lay the silhouette cards for this pose (only the rump's and vent's change: they follow the tail's pitch).
func _pose_cards() -> void:
	if _cards == null:
		return
	card_xforms.clear()
	var tail_dir := Basis(Vector3.RIGHT, tail_pitch) * Vector3.BACK
	var unit := _L / 0.45
	for i in _card_defs.size():
		var d: Dictionary = _card_defs[i]
		var n: Vector3 = d.n
		var aft: Vector3 = d.aft
		if float(d.tail) > 0.0:
			var td := (tail_dir - n * n.dot(tail_dir)).normalized()
			aft = aft.slerp(td, float(d.tail)).normalized()
		var dir := (aft * cos(float(d.lift)) + n * sin(float(d.lift))).normalized()
		var base: Vector3 = d.pos + n * ((0.0006 + 0.0004 * float(d.row)) * unit) - dir * float(d.len) * 0.08
		var xf := _feather_xform(base, dir, n, float(d.len), float(d.w), float(d.arch))
		card_xforms.append(xf)
		_cards.set_instance_transform(i, xf)
		_cards_u.set_instance_transform(i, xf)


func _multimesh(mesh: Mesh, count: int, mat: Material, node_name: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mm


## The face (Face; docs/research/eyes_and_beaks.md): the beak's two mandibles (the lower on a jaw pivot), the
## eyes as lens caps with their nictitating membranes, the hawk's and falcon's brow ridges, the owl's disc.
func _build_face(skull: Node3D, body_mat: Material, hr: float) -> void:
	var id := profile.id
	var fd := Face.spec(id)
	var disc: bool = fd.has("disc")
	# (the owl's facial disc is part of the head's surface: _head_point)
	var beak_base := Vector3(0.0, -0.05 * hr, -hr * body.skull.z * 0.85) if not disc else Vector3(0.0, -0.14 * hr, Face.disc_z(0.0, -0.14 * hr, 0.1, hr, body.skull) + 0.04 * hr)
	var bm: Array = Face.beak_meshes(id, hr, beak_base)
	var bill_mat := _material(Color.WHITE)
	bill_mat.vertex_color_use_as_albedo = true
	bill_mat.vertex_color_is_srgb = true
	bill_mat.roughness = 0.45
	var upper := MeshInstance3D.new()
	upper.name = "BeakUpper"
	upper.mesh = bm[0]
	upper.material_override = bill_mat
	_head.add_child(upper)
	_jaw = Node3D.new()   # the lower mandible hinges at the gape (a joint for calls and bites later)
	_jaw.name = "Jaw"
	_jaw.position = beak_base
	_head.add_child(_jaw)
	var lower := MeshInstance3D.new()
	lower.name = "BeakLower"
	lower.mesh = bm[1]
	lower.material_override = bill_mat
	lower.position = -beak_base
	_jaw.add_child(lower)
	var eye_mat := _material(Color.WHITE)
	eye_mat.vertex_color_use_as_albedo = true
	eye_mat.vertex_color_is_srgb = true
	eye_mat.roughness = 0.2
	var memb_mat := StandardMaterial3D.new()
	memb_mat.albedo_color = Color(0.86, 0.9, 0.95, 0.65)
	memb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	memb_mat.roughness = 0.3
	var er := float(fd.eye.r) * hr
	_membranes.clear()
	for e: float in [-1.0, 1.0]:
		var dir := Face.eye_dir(id, e)
		var eye := Node3D.new()
		eye.name = "Eye" + ("L" if e < 0.0 else "R")
		if disc:   # the owl's eyes sit in its disc, looking forward
			var px := e * 0.32 * hr
			var py := 0.12 * hr
			eye.position = Vector3(px, py, Face.disc_z(px, py, Face.disc_s(px, py, hr), hr, body.skull) - 0.015 * hr)
			_head.add_child(eye)
		else:
			eye.position = dir * hr * 0.97
			skull.add_child(eye)
		eye.basis = Basis.looking_at(dir, Vector3.UP)
		var cap := MeshInstance3D.new()
		cap.mesh = Face.eye_mesh(id, er)
		cap.material_override = eye_mat
		eye.add_child(cap)
		# The nictitating membrane: a translucent lid sweeping across from the bill side and back.
		var bill_side := eye.basis.inverse() * Vector3.FORWARD
		var v := Vector2(bill_side.x, bill_side.y)
		v = v.normalized() if v.length() > 1e-3 else Vector2(1.0, 0.0)
		var pivot := Node3D.new()
		pivot.position = Vector3(v.x * er, v.y * er, -0.26 * er)
		pivot.rotation.z = atan2(v.y, v.x)
		eye.add_child(pivot)
		var mem := MeshInstance3D.new()
		var ms := SphereMesh.new()
		ms.radius = er * 1.04
		ms.height = er * 2.08
		mem.mesh = ms
		mem.material_override = memb_mat
		mem.position = Vector3(-er, 0.0, 0.0)
		mem.scale = Vector3(1.0, 1.0, 0.25)
		pivot.add_child(mem)
		pivot.visible = false
		_membranes.append(pivot)
		if body.brow > 0.0 and not disc:   # the raptor's brow ridge over the eye: the frown
			var brow := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = 0.5
			bs.height = 1.0
			brow.mesh = bs
			brow.material_override = _material(_body_tint if Plumage.level == 0 else Plumage.head(id, Vector3.UP, dir))
			brow.position = eye.position + Vector3(e * 0.03, 0.2, 0.02) * hr
			brow.rotation = Vector3(deg_to_rad(-15.0), e * deg_to_rad(-35.0), 0.0)
			brow.scale = Vector3(0.42, 0.14 * body.brow, 0.34) * hr
			skull.add_child(brow)


## The body's colour at (u along the trunk, v up its side, side round to the flank); the old flat tint at
## plumage level 0.
func _body_color_at(u: float, v: float, side: float) -> Color:
	return _body_tint if Plumage.level == 0 else Plumage.body(profile.id, u, v, side)


const HEAD_AROUND := 60      ## 3 x TRUNK_AROUND: every third vertex of the head's neck ring is the neck's (fine, for crisp colour zones)
var _neck_entry := 1.1       ## rad: the neck meets the head this far round from its underside axis -- where the head is about as wide
                             ## as the collar it comes from (an owl's broad chest meets its big head near the head's widest)


## The head's underside axis (head space), where the neck comes in: below and a little behind the centre.
static func _neck_axis() -> Vector3:
	return Vector3(0.0, -1.0, 0.3).normalized()


## A point of the head's surface (head space), at polar angle `th` from the neck axis and `ph` round it: on
## the skull's ellipsoid, with the owl's facial disc raised on the front. The head is lofted in rings round
## the neck axis, so the neck's edge loop (th = _neck_entry) is one of its own rows.
func _head_point(th: float, ph: float) -> Vector3:
	var hr := body.head_r
	var d := _head_dir(th, ph)
	var p := Vector3(d.x * body.skull.x, d.y * body.skull.y, d.z * body.skull.z) * hr
	if Face.spec(profile.id).has("disc") and p.z < 0.0:
		var s := Face.disc_s(p.x, p.y, hr)
		if s < 1.12:
			p.z = Face.disc_z(p.x, p.y, s, hr, body.skull)
	return p


static func _head_dir(th: float, ph: float) -> Vector3:
	var ax := _neck_axis()
	var x2 := ax.cross(Vector3.RIGHT)
	return ax * cos(th) + (Vector3.RIGHT * cos(ph) + x2 * sin(ph)) * sin(th)


## The head's colour at (th, ph): the plumage's head zones, the owl's disc pale with its dark ruff.
func _head_color(th: float, ph: float) -> Color:
	if Plumage.level == 0:
		return _body_tint
	var d := _head_dir(th, ph)
	var c := Plumage.head(profile.id, d, Face.eye_dir(profile.id, 1.0))
	var h: Dictionary = Plumage.spec(profile.id).head
	if h.has("disc") and Face.spec(profile.id).has("disc") and d.z < 0.0:
		var hr := body.head_r
		var s := Face.disc_s(d.x * body.skull.x * hr, d.y * body.skull.y * hr, hr)
		if s < 1.12:
			var disc := Plumage.hex(h.disc[0]).lerp(Plumage.hex(h.disc[1]), smoothstep(0.82, 0.92, s))
			c = disc.lerp(c, smoothstep(1.0, 1.12, s))
	return c


## The head's mesh (head space): rings round the neck axis from the underside pole to the crown.
func _build_head_mesh() -> ArrayMesh:
	var ths: Array = [0.0, _neck_entry * 0.35, _neck_entry * 0.7, _neck_entry]
	for k in range(1, 29):
		ths.append(lerpf(_neck_entry, PI, k / 28.0))
	var rows: Array = []
	var cols: Array = []
	var uvs: Array = []
	var uv2s: Array = []
	for th in ths:
		var row: Array = []
		var crow: Array = []
		var urow: Array = []
		var u2row: Array = []
		for j in HEAD_AROUND:
			var ph := -TAU * j / HEAD_AROUND   # (wound outward)
			row.append(_head_point(th, ph))
			var c := _head_color(th, ph)
			var fc := _head_uv(th, ph)
			c.a = fc[2]
			crow.append(c)
			urow.append(fc[0])
			u2row.append(fc[1])
		rows.append(row)
		cols.append(crow)
		uvs.append(urow)
		uv2s.append(u2row)
	# (the head's u seam runs from the bill under the chin, across the rings: each triangle unwraps its own)
	return BodyShape.tube_mesh(rows, null, cols, uvs, uv2s, true)


# --- Feather coordinates (plumage level 6) ---------------------------------------------------------------
# One chart over the trunk, the neck, the head and the wing's arm loft, so the contour-feather texture runs on
# across every join (docs/research/feather_texture_study.md, "What the body mesh must provide"). In units of
# the species' feather tile (`_tile` m): u across the feathers' flow, v along it, tips toward +v.
# - Trunk: u round each ring from the spine, v back along it (BodyShape.trunk_mesh).
# - Head: polar coordinates round a pole on the forehead just above the bill, in which the neck's ring is a
#   coordinate circle (the stereographic disk the head projects to from the neck's pole, its centre moved to the
#   pole by a disk automorphism). The feathers run back from there over the crown, the cheeks and the chin, and
#   every point of the neck's ring has the same v, so the neck's rows start level. u's period shrinks toward the
#   pole (the texture fades there); its seam runs under the chin.
# - Neck: each vertex blends from its trunk partner's coordinates to its head partner's, as its position does,
#   so its feathers stretch and twist with it instead of sliding.
# - Arm loft: runs on from the trunk's coordinates at its edge loop on the shoulder (_loft_arm).
# UV2 = (u's period: the ring's girth, or 1000 for none; up: 1 back .. -1 belly). COLOR.a: the texture's
# strength there.
const BILL_AXIS := Vector3(0.0, -0.25, -1.0)   ## head space: toward the bill's base
const HEAD_POLE := 0.5       ## where the head chart's pole sits: 0 the crown's top .. 1 the bill's base (in the disk)
const HEAD_FEATHER := 0.4    ## head feather size, share of the body tile
const ARM_FEATHER := 0.7     ## the arm loft's small coverts
const HEAD_TEXTURE := 0.75   ## texture strength on the head (COLOR.a)
const NO_PERIOD := 1000.0
var _tile := 0.1
var _head_ku := 1.0          ## the head chart's scales: u (tile units per radian round the pole at the ring) ..
var _head_kv := 1.0          ## .. and v (tile units from the ring to the pole)
var _head_sense := 1.0
var _head_ref := 0.0         ## the angle round the pole of the nape (u = 0 there)
var _neck_v0 := PackedFloat32Array()   ## v round the trunk's front ring (one per point)
var _hb_uv: Array = []                 ## the head's neck ring (HEAD_AROUND points): its uv, uv2, colour
var _hb_uv2: Array = []
var _hb_col: Array = []


## Contour-feather size along the trunk (share of the tile): smaller at the breast's front, larger on the rump.
func _size_trunk(z: float) -> float:
	var u := body.u_at(z)
	return lerpf(0.75, 1.0, smoothstep(0.0, 0.3, u)) * lerpf(1.0, 1.12, smoothstep(0.6, 1.0, u))


## Stereographic projection of a head-space direction from the neck's pole (it goes to infinity, inside the neck).
static func _stereo(q: Vector3) -> Vector2:
	var ax := _neck_axis()
	return Vector2(q.dot(Vector3.RIGHT), q.dot(ax.cross(Vector3.RIGHT))) / maxf(1.0 - q.dot(ax), 1e-4)


static func _cmul(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x)


static func _cdiv(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / maxf(b.length_squared(), 1e-12)


## The head chart's pole in the projected disk (the neck's ring the unit circle round 0).
func _head_pole() -> Vector2:
	return _stereo(BILL_AXIS.normalized()) / _stereo(_head_dir(_neck_entry, 0.0)).length() * HEAD_POLE


## Direction `d` in the head chart's disk: the neck's ring is the unit circle, the chart's pole the centre.
func _head_disk(d: Vector3) -> Vector2:
	var z := _stereo(d) / _stereo(_head_dir(_neck_entry, 0.0)).length()
	var p := _head_pole()
	return _cdiv(z - p, Vector2(1.0, 0.0) - _cmul(Vector2(p.x, -p.y), z))


## The head's feather coordinates at (th, ph): [uv, uv2, strength]. u's angle is where the point's flow line
## (straight out from the pole, in the disk) meets the neck's ring, measured round the ring itself -- so u is
## spread evenly round the ring, as the neck's is, and doesn't bunch toward the side nearer the pole.
func _head_uv(th: float, ph: float) -> Array:
	var d := _head_dir(th, ph)
	var w := _head_disk(d)
	var r := w.length()
	var p := _head_pole()
	var e := w / maxf(r, 1e-6)
	var ring := _cdiv(e + p, Vector2(1.0, 0.0) + _cmul(Vector2(p.x, -p.y), e))   # (back to the ring, un-moved)
	var a := wrapf(ring.angle() - _head_ref, -PI, PI) * _head_sense
	var strength := HEAD_TEXTURE * lerpf(0.4, 1.0, smoothstep(0.05, 0.3, r))   # (the rows crowd at the pole)
	return [Vector2(a * r * _head_ku, -(1.0 - r) * _head_kv), Vector2(TAU * r * _head_ku, d.y), strength]


func _init_feather_coords() -> void:
	_tile = float(Plumage.body_texture(profile.id).tile) * _L
	var hr := body.head_r * (body.skull.x + body.skull.y + body.skull.z) / 3.0
	_head_ku = sin(_neck_entry) * hr / (HEAD_FEATHER * 1.2 * _tile)   # (the ring's girth; a little larger feathers there)
	_head_kv = (PI - _neck_entry) * 0.8 * hr / (HEAD_FEATHER * _tile)
	_head_ref = _stereo(_head_dir(_neck_entry, PI * 0.5)).angle()   # (the nape: ph = 90 deg is up the back)
	_head_sense = 1.0
	_head_sense = -signf((_head_uv(_neck_entry, 0.0)[0] as Vector2).x)   # (u < 0 on the +x side, as the trunk's)
	_hb_uv.clear()
	_hb_uv2.clear()
	_hb_col.clear()
	for q in HEAD_AROUND:
		var ph := -TAU * q / HEAD_AROUND
		var fc := _head_uv(_neck_entry, ph)
		_hb_uv.append(fc[0])
		_hb_uv2.append(fc[1])
		var c := _head_color(_neck_entry, ph)
		c.a = fc[2]
		_hb_col.append(c)
	# The trunk's front ring: each point's v is its head partner's (all 0, on the ring) plus the neck between, in
	# the neck's feather size -- so the neck's rows run on from the head's down to the trunk's.
	var ring := body.ring_at(body.collar_z)
	var ca := Vector3(0.0, ring[0], body.collar_z)
	var la: Array = []
	var lb: Array = []
	var cb := Vector3.ZERO
	for j in TRUNK_AROUND:
		var q := BodyShape.section(TAU * j / TRUNK_AROUND, ring[1], ring[2], ring[3])
		la.append(ca + Vector3(q.x, q.y, 0.0))
		var p := _head_pos + _head_point(_neck_entry, -TAU * j / TRUNK_AROUND)
		lb.append(p)
		cb += p / TRUNK_AROUND
	var m := _align_loops(la, ca, lb, cb)
	var s_n := 0.5 * (_size_trunk(body.collar_z) + HEAD_FEATHER * 1.2)
	_neck_v0.clear()
	for j in TRUNK_AROUND:
		var hq := m[j] * (HEAD_AROUND / TRUNK_AROUND)
		_neck_v0.append((_hb_uv[hq] as Vector2).y + (la[j] as Vector3).distance_to(lb[m[j]]) / (_tile * s_n))
	# (mostly levelled: the neck takes up the difference, so the trunk's rows don't slant hard where they start)
	var mean := 0.0
	for v in _neck_v0:
		mean += v / _neck_v0.size()
	for j in _neck_v0.size():
		_neck_v0[j] = lerpf(_neck_v0[j], mean, 0.6)
## Lay one feather (top copy, and its underside copy when two-sided); its colours only when they change (at
## build), since they don't move.
## `lead`: the side of the card (+1: +UV.x) the feather's leading, outer-vane edge is on (plumage level 6).
func _place(mm: MultiMesh, mmu: MultiMesh, idx: int, xf: Transform3D, kind: int, fi: int, bone: int, custom: Color, bend := 0.0, lead := 1.0) -> void:
	mm.set_instance_transform(idx, xf)
	if mmu != null:
		mmu.set_instance_transform(idx, xf)
	var g := Plumage.group(kind, fi, bone)
	# (level 6: the atlas cell -- neighbours never the same variant --, signed by the leading side; and a random
	# value per feather for its own small variation)
	var code := (FeatherAtlas.cell(g, mm == _emarg, fi, 0 if lead > 0.0 else 1) + 1.0) * lead if Plumage.level >= 6 else 0.0
	var vseed := FeatherAtlas._hash(custom.g * 97.0 + float(kind), lead + float(fi) * 0.1)
	feather_codes.append(code)
	if marks_material != null and not _paint_dirty:   # (the bend changes every pose; the rest only at build)
		mm.set_instance_custom_data(idx, Color(Plumage.row_index(g, false), bend, code, vseed))
		if mmu != null:
			mmu.set_instance_custom_data(idx, Color(Plumage.row_index(g, true), bend, code, vseed))
		return
	if not _paint_dirty:
		return
	var id := profile.id
	var fm: Array = Plumage.finger(id, fi) if kind == WingShape.Kind.PRIMARY else [1.0, 1.0]
	if marks_material != null:   # level 5: colour from the strip, the instance colour darkens
		mm.set_instance_color(idx, Color(fm[0], fm[0], fm[0]))
		mm.set_instance_custom_data(idx, Color(Plumage.row_index(g, false), bend, code, vseed))
		if mmu != null:
			mmu.set_instance_color(idx, Color(fm[1], fm[1], fm[1]))
			mmu.set_instance_custom_data(idx, Color(Plumage.row_index(g, true), bend, code, vseed))
		return
	var top: Color = _colors.get(kind, _colors["tail"])
	var under := top
	if _two_sided:
		top = _scaled(Plumage.flat(id, g, false), fm[0])
		under = _scaled(Plumage.flat(id, g, true), fm[1])
		if Plumage.level < 2 and g in ["greater", "lesser", "lesser_bar", "alula"]:
			under = top   # (the underwing's own colours come in at level 2)
	mm.set_instance_color(idx, top)
	mm.set_instance_custom_data(idx, custom)
	if mmu != null:
		mmu.set_instance_color(idx, under)
		mmu.set_instance_custom_data(idx, custom)


## A feather's layer: its height above its bone (spread) or the folded panel, in units of the bird (as WingShape's
## `layer`). One stacking order holds open and folded, as on a real wing, where the feathers' overlap never
## changes as it closes. WingShape's layers were set per kind, so neighbours in a row tied (overlapping cards in
## one plane), and the Z-fold, laying the humerus, forearm and hand over each other, tied rows from different
## bones (the humerus's and the forearm's lesser coverts, the hand's and the forearm's greater coverts, the three
## alula feathers): z-fighting. The stack, innermost first: the underwing coverts, the primaries, the primary
## coverts, the secondaries, the tertials, the forearm's greater coverts, the lesser coverts (the humerus's, which
## the scapulars hide on a bird, under the hand's, under the forearm's -- the sparrow's white bar), the alula.
## Within a row each inner feather lies on its outer neighbour, so feathers that slide over each other as the
## wing closes keep their order. FOLD_STEP apart at least (0.05 mm on the sparrow).
const FOLD_STEP := 0.00015


static func _stack_layer(f: Dictionary) -> float:
	var i := float(f.i)
	match int(f.kind):
		WingShape.Kind.UNDER_COVERT: return -0.0075 + FOLD_STEP * i
		WingShape.Kind.PRIMARY: return -0.002 + FOLD_STEP * (10.0 - i)
		WingShape.Kind.SECONDARY: return 0.0015 + FOLD_STEP * (i - 1.0)
		WingShape.Kind.TERTIAL: return 0.004 + FOLD_STEP * i
		WingShape.Kind.ALULA: return 0.0096 + 2.0 * FOLD_STEP * i
		WingShape.Kind.GREATER_COVERT:
			return (0.0048 if int(f.bone) == WingShape.Bone.FOREARM else -0.0003) + FOLD_STEP * i
		WingShape.Kind.LESSER_COVERT:
			match int(f.bone):
				WingShape.Bone.FOREARM: return 0.0087 + FOLD_STEP * (i - 4.0)
				WingShape.Bone.HAND: return 0.0082 + FOLD_STEP * (i - 8.0)
			return 0.0074 + FOLD_STEP * i
	return float(f.layer)


## How much a feather bends with the wing's `flex`: the long, outer primaries most, the stiff coverts barely.
static func _flex_share(f: Dictionary) -> float:
	match int(f.kind):
		WingShape.Kind.PRIMARY: return 0.6 + 0.04 * float(f.i)
		WingShape.Kind.SECONDARY: return 0.5
		WingShape.Kind.TERTIAL: return 0.3
		WingShape.Kind.GREATER_COVERT, WingShape.Kind.UNDER_COVERT: return 0.15
		WingShape.Kind.LESSER_COVERT: return 0.05
	return 0.0


static func _scaled(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


# --- Telemetry -> control values -------------------------------------------------------------------------

## Take another rig's control values and solve the same pose (the bird lab's onion-skin ghosts).
func copy_pose_from(src: BirdRig) -> void:
	for key in ["flap", "hand_lift", "fold", "sweep", "twist", "alula", "slot", "tail_spread", "tail_pitch", "tail_twist", "look_dir", "world_up", "toe_grip", "neck_ext", "head_offset", "fluff", "breath"]:
		set(key, src.get(key))
	foot_targets = src.foot_targets.duplicate()
	apply_pose()


## Fade every mesh of this rig (0 solid .. 1 invisible): the bird lab's ghosts.
func set_ghost(amount: float) -> void:
	for n in find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).transparency = amount
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Map a Bird.telemetry() snapshot to the control values (smoothed) and pose the rig.
func animate(t: Dictionary, dt: float) -> void:
	if not _built:
		return
	var state: int = t.state
	var sitting := state == Bird.State.PERCHED or state == Bird.State.GROUNDED
	var landing := state == Bird.State.LANDING
	var flare: float = 1.0 if landing else float(t.flare)
	var speed: float = t.speed
	var slow := 1.0 - clampf((speed - float(t.v_stall)) / maxf(float(t.v_best), 0.1), 0.0, 1.0)
	var alpha: float = t.alpha
	var k := 1.0 - exp(-14.0 * dt)
	var ks := 1.0 - exp(-8.0 * dt)

	var flap_t := deg_to_rad(5.0)
	var lift_t := 0.0
	if t.flapping and not sitting:
		var ph: float = t.flap_phase
		flap_t = deg_to_rad(10.0 + 45.0 * cos(ph * TAU))   # top at 0, bottom at 0.5
		if ph > 0.5:
			lift_t = 50.0 * sin((ph - 0.5) * TAU)
		k = 1.0   # wingbeats are fast: no smoothing
	var fold_t: float = t.fold
	var sweep_t := 12.0 * flare
	var twist_t := clampf(alpha * 0.6, deg_to_rad(-8.0), deg_to_rad(18.0))
	if landing:
		# The flare: two braking wingbeats with the wings swept forward at a high angle of attack, alula out;
		# in the last fifth the wings start to fold as the bird settles.
		var lt: float = t.landing_t
		var beat := fmod(lt * 2.0, 1.0)
		flap_t = deg_to_rad(30.0 + 40.0 * cos(beat * TAU))
		lift_t = 0.0
		fold_t = smoothstep(0.8, 1.0, lt) * 0.8
		sweep_t = 18.0 * (1.0 - smoothstep(0.8, 1.0, lt))
		twist_t = deg_to_rad(40.0)
		k = 1.0 - exp(-30.0 * dt)   # (fast, but eased: the wings swing into the braking beats, they don't jump)
	if sitting:
		flap_t = deg_to_rad(-10.0)
		fold_t = 1.0
		sweep_t = 0.0
		twist_t = 0.0
	flap = lerpf(flap, flap_t, k)
	hand_lift = lerpf(hand_lift, lift_t, k)
	# Feathers flex under load: in a downstroke the tips bend up, in the upstroke they trail back and down; a
	# little upward bend in a glide; none on a perch.
	var flex_t := 0.0
	if landing:
		flex_t = 0.12 * sin(fmod(float(t.landing_t) * 2.0, 1.0) * TAU)
	elif t.flapping and not sitting:
		flex_t = 0.16 * sin(float(t.flap_phase) * TAU) + 0.03
	elif not sitting:
		flex_t = 0.03 * clampf(float(t.load), 0.0, 3.0)
	flex = lerpf(flex, flex_t, k)
	fold = lerpf(fold, fold_t, 1.0 - exp(-10.0 * dt))
	sweep = lerpf(sweep, sweep_t, ks)
	twist = lerpf(twist, twist_t, ks)
	var alula_t := 1.0 if (flare > 0.2 or (alpha > deg_to_rad(12.0) and speed < float(t.v_best) * 0.8)) and not sitting else 0.0
	alula = lerpf(alula, alula_t, 1.0 - exp(-20.0 * dt))
	slot = lerpf(slot, (1.0 - fold) * maxf(slow, flare), ks)
	var spread_t: float = 0.15 + 0.5 * absf(float(t.bank)) / maxf(float(t.max_bank), 0.1) + 0.6 * slow + flare
	tail_spread = lerpf(tail_spread, 0.0 if sitting else clampf(spread_t, 0.0, 1.0), ks)
	var age: float = t.get("state_age", 10.0)
	var tail_t := 0.6 * flare if not sitting else deg_to_rad(float(POSE.get(profile.id, POSE["crow"]).tail_down))
	if sitting and age < 1.5:
		tail_t += 0.3 * exp(-age * 3.0) * sin(age * 14.0)   # a few balancing pumps after touching down
	tail_pitch = lerpf(tail_pitch, tail_t, ks)
	tail_twist = lerpf(tail_twist, -float(t.bank) * 0.25 if not sitting else 0.0, ks)
	# Airflow on the feathers: a little always, more with speed, almost none perched.
	var air := 0.04 if sitting else 0.15 + 0.6 * clampf((speed - float(t.v_best) * 0.5) / (float(t.v_best) * 1.5), 0.0, 1.0)
	if feather_material != null:
		feather_material.set_shader_parameter("flutter", air)

	# Body: the neck retracts on the perch, reaches out in flight (per species) and on the leap off a perch;
	# the plumage fluffs up perched and sleeks down fast; the bird breathes.
	var ext_t := body.neck_flight
	if sitting:
		ext_t = 0.05
	elif landing:
		ext_t = lerpf(body.neck_flight, 0.25, float(t.landing_t))
	elif age < 0.3:
		ext_t = maxf(body.neck_flight, 0.85)
	neck_ext = lerpf(neck_ext, ext_t, 1.0 - exp(-6.0 * dt))
	var v_best := maxf(float(t.v_best), 0.1)
	var fluff_t := body.fluff_perched if sitting else 1.0 - 0.06 * clampf((speed - v_best) / v_best, 0.0, 1.0)
	fluff = lerpf(fluff, fluff_t, 1.0 - exp(-2.0 * dt))
	_clock_t += dt
	breath = sin(TAU * 0.3 / sqrt(_L) * _clock_t) * (1.0 if sitting else 0.3)
	# Touchdown: the trunk sinks on flexing legs and comes back up (the feet stay on the grip).
	world_up = (global_transform.basis.inverse() * Vector3.UP).normalized()
	var dip := 0.0
	if sitting and age < 0.4:
		dip = sin(PI * age / 0.4) * (1.0 - age / 0.4) * _L * 0.12
	# Stance: sitting, the body rides at a natural height over its feet -- the hips about 70% of the leg's reach
	# above a branch (perched birds crouch), 85% above the ground -- so the feet meet the surface whatever the
	# species' proportions. Visual only: the bird's body for the game doesn't move.
	var stance_t := 0.0
	if sitting and t.has_grip:
		var parent_xf := get_parent_node_3d().global_transform if get_parent_node_3d() != null else Transform3D()
		var hip_w := parent_xf * ((_hip[0] + _hip[1]) * 0.5)
		var reach := body.femur + _tib + _tars
		var want_h := reach * (0.7 if state == Bird.State.PERCHED else 0.85)
		stance_t = want_h - (hip_w - (t.grip as Vector3)).dot(Vector3.UP)
	_stance = lerpf(_stance, stance_t, 1.0 if age < 0.05 else 1.0 - exp(-10.0 * dt))
	position = transform.basis * (world_up * (_stance - dip))

	# Head: look at the target, level with the world.
	var inv := global_transform.affine_inverse()
	var target_rig: Vector3 = inv * (t.look_target as Vector3)
	_gaze(target_rig - _head_pos, dt, sitting)
	# Head stabilisation: the head rides along with the bird but holds still through the trunk's jolts and
	# turns (the touchdown dip, the pitch from flare to perch), catching up within a few frames.
	var desired := global_transform * _neck_target(Vector3.ZERO)
	var carrier := get_parent_node_3d().global_position if get_parent_node_3d() != null else global_position
	if _head_world == Vector3.INF or _head_world.distance_to(desired) > _L * 0.5:
		_head_world = desired
	else:
		_head_world += carrier - _last_carrier
		_head_world = _head_world.lerp(desired, 1.0 - exp(-15.0 * dt))
	_last_carrier = carrier
	head_offset = (inv * _head_world - _neck_target(Vector3.ZERO)).limit_length(_L * 0.1)

	# Feet: on the grip point when there is one in reach, reaching forward in a flare, else tucked.
	for i in 2:
		var want_foot := _tucked_foot(i)
		var grip := 0.0
		if t.has_grip:
			var g: Vector3 = inv * (t.grip as Vector3)
			var side_off := Vector3(SIDES[i] * _L * 0.04, 0.0, 0.0)
			var reach := body.femur + _tib + _tars
			if (g + side_off).distance_to(_hip[i]) < reach * 1.6:
				want_foot = g + side_off
				grip = 1.0 if state == Bird.State.PERCHED else 0.0   # (on the ground the toes lie flat)
		elif flare > 0.3:
			want_foot = _hip[i] + Vector3(0.0, -_L * 0.22, -_L * 0.16)
		foot_targets[i] = foot_targets[i].lerp(want_foot, 1.0 if sitting else 1.0 - exp(-12.0 * dt))
		toe_grip = lerpf(toe_grip, grip, 1.0 - exp(-10.0 * dt))
	apply_pose()


## Where the head looks, as birds do it: hold a fixation (log-normal, the species' mean), then snap to the
## target in a fast saccade (eased out); a new target more than 10 deg off ends the fixation early. Perched with
## nothing new to look at, it scans: each fixation picks a point a little off the target. A big saccade usually
## comes with a nictitating blink, and there are background blinks at the species' rate.
func _gaze(want: Vector3, dt: float, sitting: bool) -> void:
	if want.length() < 0.01:
		return
	var w := want.normalized()
	var fd := Face.spec(profile.id)
	if not face_anim:
		look_dir = look_dir.slerp(w, 1.0 - exp(-10.0 * dt)).normalized()
		blink = 0.0
		return
	if _sac_t >= 0.0:
		_sac_t += dt
		var k := clampf(_sac_t / _sac_dur, 0.0, 1.0)
		look_dir = _sac_from.slerp(_sac_to, 1.0 - pow(1.0 - k, 3.0)).normalized()
		if k >= 1.0:
			_sac_t = -1.0
			_fix_left = Face.fixation(_rng, float(fd.fix_s) * (1.0 if sitting else 0.5))
	else:
		_fix_left -= dt
		if rad_to_deg(_goal.angle_to(w)) > 10.0 or _fix_left <= 0.0:
			var to := w
			if sitting and rad_to_deg(_goal.angle_to(w)) <= 10.0:   # idle: scan round the target
				to = w.rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-35.0, 35.0)))
				to = to.rotated(to.cross(Vector3.UP).normalized() if absf(to.y) < 0.95 else Vector3.RIGHT, deg_to_rad(_rng.randf_range(-12.0, 12.0))).normalized()
			_goal = w
			var amp := rad_to_deg(look_dir.angle_to(to))
			_sac_from = look_dir
			_sac_to = to
			_sac_dur = maxf(amp / float(fd.sac_speed), 0.03)
			_sac_t = 0.0
			if amp > 17.0 and _rng.randf() < 0.75:
				_start_blink()
	_blink_cool -= dt
	if _blink_t >= 0.0:
		_blink_t += dt
		blink = sin(PI * clampf(_blink_t / Face.BLINK_S, 0.0, 1.0))
		if _blink_t >= Face.BLINK_S:
			_blink_t = -1.0
			blink = 0.0
	elif _rng.randf() < float(fd.blink_pm) / 60.0 * dt:
		_start_blink()


func _start_blink() -> void:
	if _blink_cool > 0.0 or _blink_t >= 0.0:
		return
	_blink_t = 0.0
	_blink_cool = 0.5


func _tucked_foot(i: int) -> Vector3:
	return _hip[i] + Vector3(0.0, -_L * 0.05, _L * 0.26)


# --- Solving --------------------------------------------------------------------------------------------

## Two-bone IK: the middle joint for a chain root -> (l1) -> mid -> (l2) -> end reaching `target`, bent
## toward `pole`. Lengths are kept; an out-of-reach target is approached as far as the chain allows.
static func two_bone(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to := target - root
	var d := clampf(to.length(), absf(l1 - l2) + 1e-5, l1 + l2 - 1e-5)
	var dir := to.normalized() if to.length() > 1e-6 else Vector3.FORWARD
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var p := pole - root
	var perp := p - dir * dir.dot(p)
	if perp.length() < 1e-6:
		perp = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
	perp = perp.normalized()
	var a := acos(cos_a)
	return root + (dir * cos(a) + perp * sin(a)) * l1


## The end of a two-bone chain once its middle joint is known.
static func chain_end(mid: Vector3, target: Vector3, l2: float) -> Vector3:
	var to := target - mid
	return mid + (to.normalized() if to.length() > 1e-6 else Vector3.FORWARD) * l2


func _wing_plane(i: int) -> Basis:
	var s: float = SIDES[i]
	return Basis(Vector3.BACK, s * flap) * Basis(Vector3.RIGHT, twist)


## Plane (top view) point -> rig space, for one side, before IK.
func _to_rig(i: int, p2: Vector2) -> Vector3:
	var s: float = SIDES[i]
	var shoulder := Vector3(s * shape.shoulder.x, 0.0, shape.shoulder.y)
	var swept := p2
	if absf(sweep) > 1e-4:
		swept = shape.shoulder + (p2 - shape.shoulder).rotated(deg_to_rad(-sweep))
	var flat := Vector3(s * swept.x, 0.0, swept.y)
	return shoulder + _wing_plane(i) * (flat - shoulder) + Vector3(0.0, _sh_up, 0.0)


func apply_pose() -> void:
	_pose_bone("body", Vector3.ZERO, Vector3(0, 0, -_L * 0.3), Vector3.UP)
	var plain_i := 0
	var emarg_i := 0
	feather_xforms.clear()
	feather_kinds.clear()
	feather_codes.clear()
	# Feather definitions only change with fold and slot, which move slowly: rebuild them when they do.
	if _defs.is_empty() or absf(fold - _defs_fold) > 0.002 or absf(slot - _defs_slot) > 0.01:
		_defs = shape.feathers(fold, slot, _under_row)
		_defs_fold = fold
		_defs_slot = slot
	var defs := _defs
	var lengths := shape.bone_lengths()
	var j2 := shape.joints(fold)
	var ik_w := smoothstep(0.55, 1.0, fold)
	var unit := _L / 0.45   # feather layer offsets scale with the bird
	for i in 2:
		var s: float = SIDES[i]
		var sh := _to_rig(i, j2[0])
		var el_fk := _to_rig(i, j2[1])
		var wr_fk := _to_rig(i, j2[2])
		var hd_fk := _to_rig(i, j2[3])
		# Upstroke: the hand flexes back (in the wing plane) and droops about the forearm axis.
		var arm_n := _wing_plane(i) * Vector3.UP
		if absf(hand_lift) > 1e-3:
			var back := (hd_fk - wr_fk).rotated(arm_n, -s * deg_to_rad(hand_lift * 0.6))
			var fore_axis := (wr_fk - el_fk).normalized()
			hd_fk = wr_fk + back.rotated(fore_axis, s * deg_to_rad(hand_lift) * 0.7)
		# Fold IK: the wrist heads for the flank anchor as the wing folds; the elbow bends toward its FK place.
		var target := wr_fk.lerp(fold_anchor[i], ik_w)
		# Folded, the elbow lies back along the flank, not raised above the back.
		var pole := el_fk.lerp(fold_elbow[i], ik_w)
		var elbow := two_bone(sh, target, lengths[0], lengths[1], pole)
		var wrist := chain_end(elbow, target, lengths[1])
		var hand := wrist + (hd_fk - wr_fk)
		# Fluffed (the owl on its perch), the flank feathers stand out and the folded wing rides on them.
		var puff := Vector3(s * (fluff * (1.0 + 0.012 * breath) - 1.0) * _L * 0.2 * ik_w, 0.0, 0.0)
		sh += puff
		elbow += puff
		wrist += puff
		hand += puff
		wing_joints[i] = [sh, elbow, wrist, hand]
		var hand_n := arm_n
		if absf(hand_lift) > 1e-3:
			hand_n = arm_n.rotated((wr_fk - el_fk).normalized(), s * deg_to_rad(hand_lift) * 0.7)
		# Folding, the wing becomes a panel against the side of the body: its surface turns to face outward.
		var side_n := Vector3(s, 0.2, 0.0).normalized()
		arm_n = arm_n.slerp(side_n, ik_w).normalized()
		hand_n = hand_n.slerp(side_n, ik_w).normalized()
		var segs := [[sh, elbow, arm_n], [elbow, wrist, arm_n], [wrist, hand, hand_n]]
		# Folded, every feather lies along the side of the body: aft, angled a few degrees down and in, so the
		# primaries cross over the tail instead of fanning out in a "V" above the back. And they lie as one flat
		# stack -- a common normal (the panel's), each card's depth set by its layer alone -- so no two cross or
		# tie: the Z-fold lays the bones over each other, and normals or depths taken from each bone crossed
		# feathers through each other (z-fighting).
		var folded_dir := Vector3(-s * 0.05, -0.1, 1.0).normalized()
		var fold_y := (side_n - folded_dir * folded_dir.dot(side_n)).normalized()
		var panel := -INF
		for jp in [sh, elbow, wrist, hand]:
			panel = maxf(panel, (jp as Vector3).dot(fold_y))
		for f in defs:
			var seg: Array = segs[int(f.bone)]
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			var u := (b - a).normalized()
			var n: Vector3 = seg[2]
			# Across the wrist the surface twists smoothly from the arm's plane to the hand's: the inner primaries and
			# the secondaries by the wrist take a share of both, so the wing bends there instead of breaking into plates.
			if int(f.bone) == WingShape.Bone.HAND and f.kind != WingShape.Kind.ALULA:
				n = hand_n.slerp(arm_n, 0.5 * (1.0 - smoothstep(1.0, 4.0, float(f.i))))
			elif int(f.bone) == WingShape.Bone.FOREARM:
				n = arm_n.slerp(hand_n, 0.5 * smoothstep(0.7, 1.0, float(f.t)))
			n = (n - u * u.dot(n)).normalized()
			var aft := (u.cross(n) * s).normalized()
			var rel := deg_to_rad(f.rel)
			if f.kind == WingShape.Kind.ALULA:
				rel -= deg_to_rad(25.0) * alula   # deploys forward as a slat
			var d := (u * cos(rel) + aft * sin(rel)).normalized()
			# Folding, the IK swings the arm bones well away from their FK angles; the feathers instead blend
			# toward their designed folded direction (aft along the body), so the folded wing lies flat.
			if ik_w > 0.0:
				if int(f.bone) != WingShape.Bone.HAND:
					d = d.slerp(_fk_feather_dir(i, f, fold), ik_w).normalized()
				d = d.slerp(folded_dir, ik_w * ik_w).normalized()
				n = n.slerp(fold_y, ik_w).normalized()
			var root: Vector3 = a.lerp(b, f.t)
			root += fold_y * ((panel - root.dot(fold_y)) * ik_w)
			var base: Vector3 = root + n * (_stack_layer(f) * unit)
			if f.kind == WingShape.Kind.ALULA:
				# Rooted on the thumb: the base sits on the hand's leading edge (the top of its limb piece) and
				# stays there; deployed, the feather swings forward and its tip lifts, opening the slot.
				var thumb := shape.root_chord() * float(LIMB[3].t[0])
				base = root + n * lerpf(thumb * 0.45 + (0.0025 + 2.0 * FOLD_STEP * float(f.i)) * unit, _stack_layer(f) * unit, ik_w)   # (on the thumb, over the coverts there)
				d = (d + n * 0.35 * alula).normalized()
			# (folded, the feathers lie flat in their stack: their arch would cross them through the layer below)
			var sz := 1.0
			if f.kind == WingShape.Kind.LESSER_COVERT and int(f.bone) != WingShape.Bone.HAND:
				sz = maxf(smoothstep(0.3, 0.9, fold), 0.001)   # (spread, the arm's surface is these coverts; they come out as it slackens)
			var xf := _feather_xform(base, d, n, f.len * sz, f.w * sz, maxf(1.0 - ik_w, 0.02))
			feather_xforms.append(xf)
			feather_kinds.append(int(f.kind) + (0 if i == 1 else 100))   # (+100: left wing)
			if f.emarg:
				_place(_emarg, _emarg_u, emarg_i, xf, int(f.kind), int(f.i), int(f.bone), Color(float(f.kind), _seed(i, f), 1.0, 0.0), flex * _flex_share(f), s)
				emarg_i += 1
			else:
				_place(_plain, _plain_u, plain_i, xf, int(f.kind), int(f.i), int(f.bone), Color(float(f.kind), _seed(i, f), 0.0, 0.0), flex * _flex_share(f), s)
				plain_i += 1
		var fr: Array = _fairings[i]
		var rc := shape.root_chord()
		# The arm wing: one smooth surface over the skin web, the arm and its coverts (it slackens away as the
		# wing folds); the arm's own pieces sit inside it, slimmed, until folded.
		_loft_arm(i, fr[0], sh, elbow, wrist, arm_n, s, 1.0 - fold)
		# (slim: folded, they lie under the feather stack, which needs no filling between its layers)
		_place_limb(fr[1], sh, elbow, arm_n, s, rc, 1.0, 0.5, ik_w)
		_place_limb(fr[2], elbow, wrist, arm_n, s, rc, 1.0, 0.5)
		_place_limb(fr[3], wrist, hand, hand_n, s, rc, 1.0, 1.0, ik_w)
		_pose_bone("humerus." + ("L" if i == 0 else "R"), sh, elbow, arm_n)
		_pose_bone("forearm." + ("L" if i == 0 else "R"), elbow, wrist, arm_n)
		_pose_bone("hand." + ("L" if i == 0 else "R"), wrist, hand, hand_n)

	# Tail: 12 rectrices fanned, pitched and twisted as a group.
	# Full spread tops out where 12 feathers a fifth as wide as long still overlap (~100 deg), as on a real tail.
	var fan := deg_to_rad(lerpf(shape.tail_fan * 0.3, TAIL_FAN_MAX, tail_spread))
	var tb := Basis(Vector3.RIGHT, tail_pitch) * Basis(Vector3.BACK, tail_twist)
	var tn := tb * Vector3.UP
	for k in TAIL_FEATHERS:
		var u := (k - 5.5) / 5.5
		var length := profile.tail_length * _tail_shape(u)
		var d := tb * Vector3(sin(u * fan * 0.5), 0.0, cos(u * fan * 0.5))
		# Bases spread across the tail stump; the central pair sits on top and each outer feather tucks under
		# its inner neighbour, so the fan overlaps like a spread deck of cards.
		var base := _tail_base + Vector3(u * _L * 0.05, 0.0, 0.0) + tn * (0.0008 * (1.0 - absf(u)) * unit)
		var txf := _feather_xform(base, d, tn, length, length * TAIL_WIDTH)
		feather_xforms.append(txf)
		feather_kinds.append(6)
		_place(_plain, _plain_u, plain_i, txf, 6, k, -1, Color(6.0, fmod(k * 0.618, 1.0), 0.0, 0.0), 0.0, signf(u))
		plain_i += 1
	_paint_dirty = false
	if marks_material != null and Plumage.level >= 6 and absf(fold - _cover_fold) > 0.01:
		_cover_fold = fold   # (how much of each flight feather's inner vane its neighbour hides: more as the wing closes)
		marks_material.set_shader_parameter("cover", lerpf(0.45, 0.85, fold))
	_pose_bone("tail", _tail_base, _tail_base + tb * Vector3(0, 0, profile.tail_length), tn)
	if _cards != null and absf(tail_pitch - _cards_pitch) > 1e-3:
		_cards_pitch = tail_pitch
		_pose_cards()

	# Legs: hip -> knee (a short femur, near horizontal in the world, hidden in the belly) -> ankle (bends
	# aft, the bird's "backward knee") -> foot.
	var frame := _world_frame()
	var up_w: Vector3 = frame[0]
	var fwd_h: Vector3 = frame[1]
	for i in 2:
		var hip: Vector3 = _hip[i]
		var target: Vector3 = foot_targets[i]
		var fdir := (fwd_h * 0.9 - up_w * 0.3).normalized()
		fdir = (fdir + (target - hip).normalized() * 0.2).normalized()
		var knee := hip + fdir * body.femur
		var pole := knee - fwd_h * _L * 0.3 - up_w * _L * 0.05
		var ankle := two_bone(knee, target, _tib, _tars, pole)
		var foot := chain_end(ankle, target, _tars)
		leg_joints[i] = [hip, knee, ankle, foot]
		var parts: Array = _leg_meshes[i]
		_place_capsule(parts[0], knee, ankle)
		_place_capsule(parts[1], ankle, foot)
		var curl := deg_to_rad(70.0) * toe_grip
		var s: float = SIDES[i]
		# Three toes forward and one back; an owl swings its outer toe back too when it grips (2 + 2).
		var outer := Vector3(s * 0.35, 0.0, -1.0).lerp(Vector3(s * 0.6, 0.0, 0.8), toe_grip if body.zygo else 0.0)
		var toes := [Vector3(-s * 0.35, 0.0, -1.0), Vector3(0.0, 0.0, -1.0), outer, Vector3(0.0, 0.0, 1.0)]
		for k in 4:
			var td: Vector3 = (toes[k] as Vector3).normalized()
			td = td.rotated(td.cross(Vector3.UP).normalized(), -curl)   # every toe curls down round the branch
			_place_capsule(parts[2 + k], foot, foot + td * _L * (0.05 if k == 3 else 0.07))
		var side := "L" if i == 0 else "R"
		_pose_bone("femur." + side, hip, knee, Vector3.BACK)
		_pose_bone("tibia." + side, knee, ankle, Vector3.BACK)
		_pose_bone("tarsus." + side, ankle, foot, Vector3.BACK)

	# Neck: three bones from the front of the trunk to the head, folded into an S when retracted (the lower
	# neck bends forward, the middle back up).
	var nbase := body.neck_base
	var nb := body.neck_bone
	var atlas := _neck_target(head_offset)
	var nto := atlas - nbase
	if nto.length() > nb * 2.95:
		atlas = nbase + nto.normalized() * nb * 2.95
		nto = atlas - nbase
	var dn := nto.normalized() if nto.length() > 1e-5 else Vector3.UP
	var bend := acos(clampf(nto.length() / (3.0 * nb), 0.0, 1.0))
	var nj1 := nbase + dn.rotated(Vector3.RIGHT, -bend) * nb
	var nj2 := two_bone(nj1, atlas, nb, nb, nj1 + dn.rotated(Vector3.RIGHT, PI * 0.5) * nb)
	atlas = chain_end(nj2, atlas, nb)
	neck_joints = [nbase, nj1, nj2, atlas]
	_head_pos = atlas
	_head.position = atlas
	_trunk.scale = Vector3.ONE * fluff * (1.0 + 0.012 * breath)
	_pose_bone("neck.0", nbase, nj1, Vector3.UP)
	_pose_bone("neck.1", nj1, nj2, Vector3.UP)
	_pose_bone("neck.2", nj2, atlas, Vector3.UP)

	# Head: clamp the look to the neck's range, keep it level with the world.
	var fwd := look_dir
	var yaw := atan2(fwd.x, -fwd.z)
	var pitch := asin(clampf(fwd.y, -1.0, 1.0))
	var fd := Face.spec(profile.id)
	yaw = clampf(yaw, deg_to_rad(-float(fd.head_yaw)), deg_to_rad(float(fd.head_yaw)))
	pitch = clampf(pitch, deg_to_rad(float(fd.head_pitch[0])), deg_to_rad(float(fd.head_pitch[1])))
	for m in _membranes:   # the blink
		m.visible = blink > 0.01
		m.scale = Vector3(maxf(blink, 0.001), 1.0, 1.0)
	fwd = Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	var up := world_up.slerp(Vector3.UP, 0.3)
	if absf(fwd.dot(up.normalized())) > 0.98:
		up = Vector3.BACK
	head_basis = Basis.looking_at(fwd, up)
	_head.basis = head_basis
	_loft_neck()   # (after the head's basis: its end takes the head's colours in the head's frame)
	_pose_bone("head", _head_pos, _head_pos + fwd * _L * 0.1, up)


## [world up, level forward] in rig space: the frame the neck and femur hold to, whatever the trunk's pitch.
func _world_frame() -> Array:
	var up_w := world_up.normalized()
	var fwd_h := Vector3.FORWARD - up_w * up_w.dot(Vector3.FORWARD)
	fwd_h = fwd_h.normalized() if fwd_h.length() > 0.2 else Vector3.FORWARD
	return [up_w, fwd_h]


## Where the neck puts the head (rig space): retracted, on top of the neck base; reaching, out ahead (level in
## the world).
func _neck_target(offset: Vector3) -> Vector3:
	var frame := _world_frame()
	var up_w: Vector3 = frame[0]
	var fwd_h: Vector3 = frame[1]
	# Retracted, the head sits up and along the BODY's forward axis (rig -Z): on a level bird that is up and
	# ahead of the shoulders; on an upright owl or hawk the body's axis already points up, so the head sits
	# squarely on top, its nape flowing into the back (pushed forward in the world, the neck's back stood up
	# behind the head as a separate ridge).
	var rest_dir := (up_w + Vector3.FORWARD * 0.7).normalized()
	var reach_dir := (up_w * 0.15 + fwd_h).normalized()
	var dir := rest_dir.slerp(reach_dir, neck_ext)
	return body.neck_base + dir * lerpf(body.neck_rest, body.neck_reach, neck_ext) + offset


const TRUNK_AROUND := 20
const NECK_ROWS := 10


## The neck's feathered surface, lofted each pose between two fixed edge loops: the trunk's open front ring
## (same vertices, same colours) and the head's own ring where the neck enters it (same vertices, same
## colours, wherever the head has turned). It leaves the chest along the body's axis and enters the head along
## the head's neck axis; between, each vertex blends from its trunk partner to its head partner. So both joins
## are exact, in shape and in colour. The feathers smooth over the vertebrae's S, so it doesn't follow the bones.
func _loft_neck() -> void:
	var ring := body.ring_at(body.collar_z)   # [cy, w, top, bot]
	var st := fluff * (1.0 + 0.012 * breath)      # (the trunk's scale, so the first loop lands on it)
	var ca := Vector3(0.0, ring[0], body.collar_z) * st
	var u_neck := body.u_at(body.collar_z)
	var la: Array = []
	var ca_cols: Array = []
	for j in TRUNK_AROUND:
		var a := TAU * j / TRUNK_AROUND
		var q := BodyShape.section(a, ring[1], ring[2], ring[3])
		la.append(ca + Vector3(q.x, q.y, 0.0) * st)
		ca_cols.append(_body_color_at(u_neck, sin(a), absf(cos(a))))
	var lb: Array = []
	var lb60: Array = []
	var cb := Vector3.ZERO
	for q in HEAD_AROUND:
		var p: Vector3 = _head.transform * _head_point(_neck_entry, -TAU * q / HEAD_AROUND)
		lb60.append(p)
		if q % (HEAD_AROUND / TRUNK_AROUND) == 0:
			lb.append(p)
			cb += p / TRUNK_AROUND
	var m20 := _align_loops(la, ca, lb, cb)
	# Then the pairing at the head ring's own resolution (one of its 60 vertices per neck vertex, the twist in
	# thirds of a neck step), so the neck's feathers don't jump a whole step as the head turns.
	var m: Array[int] = []
	var best := INF
	for dq in [-1, 0, 1]:
		var cost := 0.0
		for j in TRUNK_AROUND:
			var hq := posmod(m20[j] * (HEAD_AROUND / TRUNK_AROUND) + dq, HEAD_AROUND)
			cost += ((la[j] as Vector3) - ca).normalized().distance_squared_to(((lb60[hq] as Vector3) - cb).normalized())
		if cost < best - 1e-9:
			best = cost
			m.clear()
			for j in TRUNK_AROUND:
				m.append(posmod(m20[j] * (HEAD_AROUND / TRUNK_AROUND) + dq, HEAD_AROUND))
	# Feather coordinates at both ends: the trunk's front ring's, and the head partners' (u unwrapped to run on
	# round the ring the same way as the trunk's).
	var ua: PackedVector2Array = body.trunk_uv[0] if not body.trunk_uv.is_empty() else PackedVector2Array()
	var ua2: PackedVector2Array = body.trunk_uv2[0] if not body.trunk_uv2.is_empty() else PackedVector2Array()
	var have_uv := ua.size() == TRUNK_AROUND + 1
	var ub := PackedVector2Array()
	if have_uv:
		var pb: float = (_hb_uv2[0] as Vector2).x
		var pa: float = ua2[0].x
		for j in TRUNK_AROUND + 1:
			var raw: Vector2 = _hb_uv[m[j % TRUNK_AROUND]]
			var ref := ua[0].x / pa * pb if j == 0 else ub[j - 1].x
			raw.x -= pb * roundf((raw.x - ref) / pb)
			ub.append(raw)
	var d := ca.distance_to(cb)
	var tb := (_head.transform.basis * -_neck_axis()).normalized()
	var p1 := ca + Vector3.FORWARD * d * 0.45
	var p2 := cb - tb * d * 0.35
	var rows: Array = []
	var cols: Array = []
	var uvs: Array = []
	var uv2s: Array = []
	for k in range(NECK_ROWS - 1, -1, -1):   # (head end first, so the faces wind outward like the trunk's)
		var u := float(k) / (NECK_ROWS - 1)
		var c := _bezier(ca, p1, p2, cb, u)
		var s := smoothstep(0.0, 1.0, u)
		var row: Array = []
		var crow: Array = []
		for j in TRUNK_AROUND:
			var oa: Vector3 = la[j] - ca
			var ob: Vector3 = lb60[m[j]] - cb
			row.append(c + oa.lerp(ob, s))
			# The body's own zones carry on up the neck (the sparrow's bib, the breast) -- as if the trunk ran on to its
			# front -- then blend into the head's colours by the head end. Both ends still equal their loops exactly.
			var a := TAU * j / TRUNK_AROUND
			var c_body: Color = ca_cols[j] if u <= 0.0 else _body_color_at(u_neck * (1.0 - u), sin(a), absf(cos(a)))
			crow.append(c_body.lerp(_hb_col[m[j]], smoothstep(0.75, 1.0, u)))   # (a short hand-over: zones stay crisp)
		rows.append(row)
		cols.append(crow)
		if have_uv:   # (the coordinates blend from end to end as the position does: the feathers ride on the neck)
			var urow := PackedVector2Array()
			var u2row := PackedVector2Array()
			for j in TRUNK_AROUND + 1:
				urow.append(ua[j].lerp(ub[j], s))
				u2row.append(ua2[j].lerp(_hb_uv2[m[j % TRUNK_AROUND]], s))
			uvs.append(urow)
			uv2s.append(u2row)
	BodyShape.tube_mesh(rows, _neck_mesh, cols, uvs, uv2s)


## Pair two equal edge loops for a connector between them: loop B's index for each of A's, keeping them
## turning the same way round and twisted as little as possible.
static func _align_loops(a: Array, ca: Vector3, b: Array, cb: Vector3) -> Array[int]:
	var n := a.size()
	var na := Vector3.ZERO
	var nb := Vector3.ZERO
	for j in n:
		na += ((a[j] as Vector3) - ca).cross((a[(j + 1) % n] as Vector3) - ca)
		nb += ((b[j] as Vector3) - cb).cross((b[(j + 1) % n] as Vector3) - cb)
	var rev := na.dot(nb) < 0.0
	var best := INF
	var best_k := 0
	for k in n:
		var cost := 0.0
		for j in n:
			var bj := (k + (n - j if rev else j)) % n
			cost += ((a[j] as Vector3) - ca).normalized().distance_squared_to(((b[bj] as Vector3) - cb).normalized())
		if cost < best:
			best = cost
			best_k = k
	var m: Array[int] = []
	for j in n:
		m.append((best_k + (n - j if rev else j)) % n)
	return m

static func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float) -> Vector3:
	var v := 1.0 - u
	return a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + d * u * u * u

## A feather's direction in the FK pose (its bone at the FK angle in the wing plane), in rig space.
func _fk_feather_dir(i: int, f: Dictionary, fold_v: float) -> Vector3:
	var a := WingShape.bone_angles(fold_v)
	var bone_deg: float = [a.x, a.y, a.z][int(f.bone)]
	var d2 := WingShape.dir2(bone_deg + float(f.rel) - (sweep if absf(sweep) > 1e-4 else 0.0))
	return (_wing_plane(i) * Vector3(SIDES[i] * d2.x, 0.0, d2.y)).normalized()


## Freeze or drive the feather clock (flutter), for repeatable screenshots. Negative: run on engine time.
func set_clock(seconds: float) -> void:
	_clock = seconds
	if feather_material != null:
		feather_material.set_shader_parameter("clock_override", seconds)


## A stable per-feather random value (pattern phase, flutter timing).
static func _seed(side: int, f: Dictionary) -> float:
	return fmod(float(f.kind) * 0.37 + float(f.i) * 0.618 + side * 0.29, 1.0)


func _tail_shape(u: float) -> float:
	match shape.tail_shape:
		"rounded": return 1.0 - 0.16 * u * u
		"fan": return 1.0 - 0.08 * u * u
		"notched": return 0.86 + 0.14 * absf(u)
		"narrow": return 1.0 - 0.1 * u * u
	return 1.0


## A feather's instance transform: the unit feather (+Z along, X across, Y normal) laid along `d`; `arch` scales
## its camber (1: CAMBER of its length).
static func _feather_xform(base: Vector3, d: Vector3, n: Vector3, length: float, width: float, arch := 1.0) -> Transform3D:
	var z := d.normalized()
	var x := n.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x * width, y * length * arch, z * length), base)   # (y scales the arch with the feather)


func _place_capsule(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 1e-5:
		mi.visible = false
		return
	mi.visible = true
	var y := d / length
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	var r: float = (mi.mesh as CapsuleMesh).radius
	mi.transform = Transform3D(Basis(x, y * maxf(length, r * 2.0), z), (a + b) * 0.5)


## Write a bone's pose so its origin is `a` and its -Z runs toward `b` (the skeleton mirrors the solve, for
## skinned art and the editor's bone view).
func _pose_bone(bone_name: String, a: Vector3, b: Vector3, up: Vector3) -> void:
	bone_ends[bone_name] = [a, b]
	var idx: int = _bones[bone_name]
	var d := b - a
	var basis := Basis.IDENTITY
	if d.length() > 1e-6:
		var u := up if absf(d.normalized().dot(up.normalized())) < 0.98 else Vector3.RIGHT
		basis = Basis.looking_at(d.normalized(), u)
	var global := Transform3D(basis, a)
	var parent := skeleton.get_bone_parent(idx)
	var local := global
	if parent >= 0:
		local = skeleton.get_bone_global_pose(parent).affine_inverse() * global
	skeleton.set_bone_pose_position(idx, local.origin)
	skeleton.set_bone_pose_rotation(idx, local.basis.get_rotation_quaternion())