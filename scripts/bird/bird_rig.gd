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
## its own body. Legs are two-bone IK to the perch's grip point (or tucked), the head looks at a target and
## stays level with the world (head stabilisation). Feathers: primaries, secondaries, tertials, greater and
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

# --- Solved pose (rig space; read by tests) ------------------------------------------------------------
var wing_joints: Array = [[], []]     ## per side: [shoulder, elbow, wrist, hand tip]
var leg_joints: Array = [[], []]      ## per side: [hip, ankle, foot]
var head_basis := Basis()
var fold_anchor: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var fold_elbow: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]   ## folded elbow, on the flank
## Flat-colour feathers (the default). The feather shader (feather.gdshader) is parked: set this false to
## try it (rig gallery: --feather-shader). docs/research/feather_rendering.md has its status.
static var plain_feathers := true
static var flat_perch := false   ## rig gallery: the old level perched pose (before/after comparisons)
var feather_material: ShaderMaterial
var feather_xforms: Array[Transform3D] = []
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
var _colors := {}
var _head: Node3D
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
	_sh_up = _L * 0.06
	_tib = _L * 0.17
	_tars = _L * 0.15
	_hip = [Vector3(-_L * 0.06, -_L * 0.06, _L * 0.02), Vector3(_L * 0.06, -_L * 0.06, _L * 0.02)]
	_head_pos = Vector3(0.0, _L * 0.1, -_L * 0.3)
	_tail_base = Vector3(0.0, _L * 0.02, _L * 0.24)
	# The folded wing is a Z lying flat on the flank (research: a panel inside the body outline, never above
	# the back): the humerus runs back from the shoulder, the elbow tucked against the flank; the forearm runs
	# forward to the wrist -- the bend of the wing -- at the front of the breast; the hand runs back again.
	# Both are placed on the side of the body; the fold IK targets the wrist and bends toward the elbow.
	var l := shape.bone_lengths()
	for i in 2:
		var s: float = SIDES[i]
		var sh := Vector3(s * shape.shoulder.x, _sh_up, shape.shoulder.y)
		var elbow := sh + Vector3(0.0, -0.25, 1.0).normalized() * l[0]
		var front := sh + Vector3(0.0, -_L * 0.06, -_L * 0.1)
		fold_elbow[i] = elbow
		fold_anchor[i] = elbow + (front - elbow).normalized() * l[1]
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
	var names := ["body", "head", "tail"]
	for side in ["L", "R"]:
		for b in ["humerus", "forearm", "hand", "tibia", "tarsus"]:
			names.append("%s.%s" % [b, side])
	for n in names:
		_bones[n] = skeleton.add_bone(n)
	for side in ["L", "R"]:
		_parents["humerus." + side] = "body"
		_parents["forearm." + side] = "humerus." + side
		_parents["hand." + side] = "forearm." + side
		_parents["tibia." + side] = "body"
		_parents["tarsus." + side] = "tibia." + side
	_parents["head"] = "body"
	_parents["tail"] = "body"
	for n in _parents:
		skeleton.set_bone_parent(_bones[n], _bones[_parents[n]])


func _build_body(tint: Color) -> void:
	var body_mat := _plumage(tint.darkened(0.12)) if not plain_feathers else _material(tint.darkened(0.12))
	var leg_mat := _material(Color(0.72, 0.6, 0.32))
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = _L * 0.15
	cap.height = _L * 0.62
	body.mesh = cap
	body.rotation.x = PI * 0.5
	body.material_override = body_mat
	add_child(body)
	_head = Node3D.new()
	_head.position = _head_pos
	add_child(_head)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	var hr := _L * (0.15 if profile.id == "owl" else 0.105)
	sph.radius = hr
	sph.height = hr * 2.0
	head.mesh = sph
	head.material_override = body_mat
	_head.add_child(head)
	var beak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = _L * 0.035
	cone.height = _L * (0.07 if profile.id == "owl" else 0.12)
	beak.mesh = cone
	beak.rotation.x = -PI * 0.5
	beak.position = Vector3(0.0, -_L * 0.01, -hr - cone.height * 0.4)
	beak.material_override = leg_mat
	_head.add_child(beak)
	for e in [-1.0, 1.0]:   # eyes: dark dots so the look direction reads
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = hr * 0.18
		es.height = hr * 0.36
		eye.mesh = es
		eye.material_override = _material(Color(0.05, 0.05, 0.05))
		eye.position = Vector3(e * hr * (0.45 if profile.id == "owl" else 0.75), hr * 0.25, -hr * (0.8 if profile.id == "owl" else 0.55))
		_head.add_child(eye)
	for i in 2:
		var parts: Array = []
		for k in 6:
			var mi := MeshInstance3D.new()
			var c := CapsuleMesh.new()
			c.radius = _L * (0.03 if k == 0 else (0.018 if k == 1 else 0.01))
			c.height = 1.0   # rescaled per frame
			mi.mesh = c
			mi.material_override = body_mat if k == 0 else leg_mat
			add_child(mi)
			parts.append(mi)
		_leg_meshes[i] = parts


## The wing's thickness: the limb itself, the patagium (the skin web from shoulder to wrist) and the covert
## padding over them. Each is an ellipsoid along its bone with the bone at its front edge: thick and rounded
## at the leading edge, trailing back over the coverts, thinning from the root to the hand. The flight
## feathers carry on behind as the thin trailing edge.
func _build_fairings(c: Color) -> void:
	var mat := _plumage(c) if not plain_feathers else _material(c)
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 16
	sph.rings = 8
	for i in 2:
		var parts: Array = []
		for k in 4:
			var mi := MeshInstance3D.new()
			mi.mesh = sph
			mi.material_override = mat
			add_child(mi)
			parts.append(mi)
		_fairings[i] = parts


## Fairing size per piece as fractions of the root chord: [chordwise width, thickness].
const FAIRING := [[0.55, 0.13], [0.36, 0.12], [0.3, 0.09], [0.2, 0.055]]


func _place_fairing(mi: MeshInstance3D, a: Vector3, b: Vector3, n: Vector3, side: float, piece: int, fade: float) -> void:
	var rc := shape.root_chord()
	var d := b - a
	var length := d.length()
	if length < 1e-5 or fade <= 0.01:
		mi.visible = false
		return
	mi.visible = true
	var u := d / length
	var nn := (n - u * u.dot(n)).normalized()
	var aft := (u.cross(nn) * side).normalized()
	var w: float = FAIRING[piece][0] * rc * fade
	var t: float = FAIRING[piece][1] * rc * fade
	mi.transform = Transform3D(Basis(aft * w, nn * t, u * length * 1.15), (a + b) * 0.5 + aft * w * 0.32)


func _feather_mesh(profile_pts: Array) -> ArrayMesh:
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
		for q in 6:
			var v: Vector3 = vs[q]
			# A gentle arch along the feather (3% of its length at the middle): cambered, not a flat card.
			var arched := Vector3(v.x, CAMBER * sin(PI * v.z), v.z)
			# UV.x: -1..1 edge to edge across the vane (0 = the shaft); UV.y: 0..1 base to tip. Tangent: across.
			st.set_normal(Vector3.UP)
			st.set_tangent(Plane(1.0, 0.0, 0.0, 1.0))
			st.set_uv(uvs[q])
			st.add_vertex(arched)
	return st.commit()


func _build_feathers() -> void:
	var defs := shape.feathers(0.0)
	_plain_count = TAIL_FEATHERS
	_emarg_count = 0
	for f in defs:
		if f.emarg:
			_emarg_count += 2
		else:
			_plain_count += 2
	var mat: Material
	if plain_feathers:
		# The flat-colour look from before the feather shader (before/after comparisons).
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.vertex_color_is_srgb = true
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	if _emarg_count == 0:
		_emarg.visible_instance_count = 0


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


# --- Telemetry -> control values -------------------------------------------------------------------------

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
		k = 1.0
	if sitting:
		flap_t = deg_to_rad(-10.0)
		fold_t = 1.0
		sweep_t = 0.0
		twist_t = 0.0
	flap = lerpf(flap, flap_t, k)
	hand_lift = lerpf(hand_lift, lift_t, k)
	fold = lerpf(fold, fold_t, 1.0 - exp(-10.0 * dt))
	sweep = lerpf(sweep, sweep_t, ks)
	twist = lerpf(twist, twist_t, ks)
	var alula_t := 1.0 if (flare > 0.2 or (alpha > deg_to_rad(12.0) and speed < float(t.v_best) * 0.8)) and not sitting else 0.0
	alula = lerpf(alula, alula_t, 1.0 - exp(-20.0 * dt))
	slot = lerpf(slot, (1.0 - fold) * maxf(slow, flare), ks)
	var spread_t: float = 0.15 + 0.5 * absf(float(t.bank)) / maxf(float(t.max_bank), 0.1) + 0.6 * slow + flare
	tail_spread = lerpf(tail_spread, 0.0 if sitting else clampf(spread_t, 0.0, 1.0), ks)
	tail_pitch = lerpf(tail_pitch, 0.6 * flare if not sitting else deg_to_rad(float(POSE.get(profile.id, POSE["crow"]).tail_down)), ks)
	tail_twist = lerpf(tail_twist, -float(t.bank) * 0.25 if not sitting else 0.0, ks)
	# Airflow on the feathers: a little always, more with speed, almost none perched.
	var air := 0.04 if sitting else 0.15 + 0.6 * clampf((speed - float(t.v_best) * 0.5) / (float(t.v_best) * 1.5), 0.0, 1.0)
	if feather_material != null:
		feather_material.set_shader_parameter("flutter", air)

	# Head: look at the target, level with the world.
	var inv := global_transform.affine_inverse()
	var target_rig: Vector3 = inv * (t.look_target as Vector3)
	var want := (target_rig - _head_pos)
	if want.length() > 0.01:
		look_dir = look_dir.slerp(want.normalized(), 1.0 - exp(-10.0 * dt)).normalized()
	world_up = (global_transform.basis.inverse() * Vector3.UP).normalized()

	# Feet: on the grip point when there is one in reach, reaching forward in a flare, else tucked.
	for i in 2:
		var want_foot := _tucked_foot(i)
		var grip := 0.0
		if t.has_grip:
			var g: Vector3 = inv * (t.grip as Vector3)
			var side_off := Vector3(SIDES[i] * _L * 0.04, 0.0, 0.0)
			var reach := _tib + _tars
			if (g + side_off).distance_to(_hip[i]) < reach * 1.6:
				want_foot = g + side_off
				grip = 1.0 if sitting else 0.0
		elif flare > 0.3:
			want_foot = _hip[i] + Vector3(0.0, -_L * 0.22, -_L * 0.16)
		foot_targets[i] = foot_targets[i].lerp(want_foot, 1.0 if sitting else 1.0 - exp(-12.0 * dt))
		toe_grip = lerpf(toe_grip, grip, 1.0 - exp(-10.0 * dt))
	apply_pose()


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
	# Feather definitions only change with fold and slot, which move slowly: rebuild them when they do.
	if _defs.is_empty() or absf(fold - _defs_fold) > 0.002 or absf(slot - _defs_slot) > 0.01:
		_defs = shape.feathers(fold, slot)
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
		wing_joints[i] = [sh, elbow, wrist, hand]
		var hand_n := arm_n
		if absf(hand_lift) > 1e-3:
			hand_n = arm_n.rotated((wr_fk - el_fk).normalized(), s * deg_to_rad(hand_lift) * 0.7)
		# Folding, the wing becomes a panel against the side of the body: its surface turns to face outward.
		var side_n := Vector3(s, 0.2, 0.0).normalized()
		arm_n = arm_n.slerp(side_n, ik_w).normalized()
		hand_n = hand_n.slerp(side_n, ik_w).normalized()
		var segs := [[sh, elbow, arm_n], [elbow, wrist, arm_n], [wrist, hand, hand_n]]
		for f in defs:
			var seg: Array = segs[int(f.bone)]
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			var u := (b - a).normalized()
			var n: Vector3 = seg[2]
			n = (n - u * u.dot(n)).normalized()
			var aft := (u.cross(n) * s).normalized()
			var rel := deg_to_rad(f.rel)
			if f.kind == WingShape.Kind.ALULA:
				rel -= deg_to_rad(25.0) * alula   # deploys forward as a slat
			var d := (u * cos(rel) + aft * sin(rel)).normalized()
			# Folding, the IK swings the arm bones well away from their FK angles; the feathers instead blend
			# toward their designed folded direction (aft along the body), so the folded wing lies flat.
			if ik_w > 0.0:
				# Folded, every feather lies along the side of the body: aft, angled a few degrees down and in,
				# so the primaries cross over the tail instead of fanning out in a "V" above the back.
				var folded_dir := Vector3(-s * 0.05, -0.1, 1.0).normalized()
				if int(f.bone) != WingShape.Bone.HAND:
					d = d.slerp(_fk_feather_dir(i, f, fold), ik_w).normalized()
				d = d.slerp(folded_dir, ik_w * ik_w).normalized()
			var base: Vector3 = a.lerp(b, f.t) + n * (float(f.layer) * unit)
			if f.kind == WingShape.Kind.ALULA:
				base += n * _L * 0.02 * alula
			var xf := _feather_xform(base, d, n, f.len, f.w)
			feather_xforms.append(xf)
			feather_kinds.append(int(f.kind) + (0 if i == 1 else 100))   # (+100: left wing)
			if f.emarg:
				_emarg.set_instance_transform(emarg_i, xf)
				_emarg.set_instance_color(emarg_i, _colors[WingShape.Kind.PRIMARY])
				_emarg.set_instance_custom_data(emarg_i, Color(float(f.kind), _seed(i, f), 1.0, 0.0))
				emarg_i += 1
			else:
				_plain.set_instance_transform(plain_i, xf)
				_plain.set_instance_color(plain_i, _colors[int(f.kind)])
				_plain.set_instance_custom_data(plain_i, Color(float(f.kind), _seed(i, f), 0.0, 0.0))
				plain_i += 1
		var fr: Array = _fairings[i]
		_place_fairing(fr[0], sh, wrist, arm_n, s, 0, 1.0 - fold)   # the patagium folds away with the wing
		_place_fairing(fr[1], sh, elbow, arm_n, s, 1, 1.0)
		_place_fairing(fr[2], elbow, wrist, arm_n, s, 2, 1.0)
		_place_fairing(fr[3], wrist, hand, hand_n, s, 3, 1.0)
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
		_plain.set_instance_transform(plain_i, txf)
		_plain.set_instance_color(plain_i, _colors["tail"])
		_plain.set_instance_custom_data(plain_i, Color(6.0, fmod(k * 0.618, 1.0), 0.0, 0.0))
		plain_i += 1
	_pose_bone("tail", _tail_base, _tail_base + tb * Vector3(0, 0, profile.tail_length), tn)

	# Legs: hip -> ankle (bends aft, the bird's "backward knee") -> foot.
	for i in 2:
		var hip: Vector3 = _hip[i]
		var pole := hip + Vector3(0.0, -_L * 0.05, _L * 0.3)
		var ankle := two_bone(hip, foot_targets[i], _tib, _tars, pole)
		var foot := chain_end(ankle, foot_targets[i], _tars)
		leg_joints[i] = [hip, ankle, foot]
		var parts: Array = _leg_meshes[i]
		_place_capsule(parts[0], hip, ankle)
		_place_capsule(parts[1], ankle, foot)
		var curl := deg_to_rad(70.0) * toe_grip
		var toes := [Vector3(-0.35, 0.0, -1.0), Vector3(0.0, 0.0, -1.0), Vector3(0.35, 0.0, -1.0), Vector3(0.0, 0.0, 1.0)]
		for k in 4:
			var td: Vector3 = (toes[k] as Vector3).normalized()
			td = td.rotated(td.cross(Vector3.UP).normalized() if k < 3 else Vector3.RIGHT, -curl if k < 3 else curl)
			_place_capsule(parts[2 + k], foot, foot + td * _L * (0.07 if k < 3 else 0.05))
		_pose_bone("tibia." + ("L" if i == 0 else "R"), hip, ankle, Vector3.BACK)
		_pose_bone("tarsus." + ("L" if i == 0 else "R"), ankle, foot, Vector3.BACK)

	# Head: clamp the look to the neck's range, keep it level with the world.
	var fwd := look_dir
	var yaw := atan2(fwd.x, -fwd.z)
	var pitch := asin(clampf(fwd.y, -1.0, 1.0))
	yaw = clampf(yaw, deg_to_rad(-110.0), deg_to_rad(110.0))
	pitch = clampf(pitch, deg_to_rad(-60.0), deg_to_rad(60.0))
	fwd = Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
	var up := world_up.slerp(Vector3.UP, 0.3)
	if absf(fwd.dot(up.normalized())) > 0.98:
		up = Vector3.BACK
	head_basis = Basis.looking_at(fwd, up)
	_head.basis = head_basis
	_pose_bone("head", _head_pos, _head_pos + fwd * _L * 0.1, up)


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


## A feather's instance transform: the unit feather (+Z along, X across, Y normal) laid along `d`.
static func _feather_xform(base: Vector3, d: Vector3, n: Vector3, length: float, width: float) -> Transform3D:
	var z := d.normalized()
	var x := n.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x * width, y * length, z * length), base)   # (y scales the arch with the feather)


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
