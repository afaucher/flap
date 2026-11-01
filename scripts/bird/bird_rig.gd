class_name BirdRig
extends Node3D
## Greybox bird with articulated wings, built from the profile's dimensions
## (docs/research/wing_shapes_and_articulation.md, "Gameplay takeaways"):
##   body capsule + head + beak; per side a SHOULDER pivot -> inner arm panel -> WRIST pivot -> outer hand
##   panel -> four primary "fingers" (they splay apart when slow and spread: slotted tips); a TAIL fan of
##   five feathers that fans when slow, turning or flaring; two legs that swing forward to land and perch.
## Driven only by the bird's telemetry snapshot: flap phase, wing tuck, flare, bank, state.
## Local axes: -Z is the nose, +X the right wing, +Y up.

const FINGERS := 4
const TAIL_FEATHERS := 5

var profile: BirdProfile
var shoulders: Array[Node3D] = []   ## [left, right]
var wrists: Array[Node3D] = []
var fingers: Array = []             ## per side: Array[Node3D]
var tail: Node3D
var tail_feathers: Array[Node3D] = []
var legs: Array[Node3D] = []

var _flap_angle := 0.0
var _sweep := 0.0
var _wrist_fold := 0.0
var _spread_tail := 0.2
var _leg_fwd := 0.0
var _splay := 0.0


func build(p: BirdProfile) -> void:
	profile = p
	var L := p.body_length
	var chord := p.wing_area / p.span       # mean chord
	var tint := _tint(p.id)
	var body_mat := _material(tint.darkened(0.25))
	var wing_mat := _material(tint)
	var dark := _material(tint.darkened(0.5))
	var beak_mat := _material(Color(0.75, 0.62, 0.3))

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = L * 0.15
	cap.height = L * 0.78
	body.mesh = cap
	body.rotation.x = PI * 0.5
	body.material_override = body_mat
	add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = L * 0.13
	sph.height = L * 0.26
	head.mesh = sph
	head.position = Vector3(0, L * 0.05, -L * 0.42)
	head.material_override = body_mat
	add_child(head)
	var beak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = L * 0.045
	cone.height = L * 0.14
	beak.mesh = cone
	beak.rotation.x = -PI * 0.5
	beak.position = Vector3(0, L * 0.03, -L * 0.57)
	beak.material_override = beak_mat
	add_child(beak)

	var inner_len := p.span * 0.2
	var outer_len := p.span * 0.17
	var finger_len := p.span * 0.09
	for s in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(s * L * 0.1, L * 0.06, -L * 0.1)
		add_child(shoulder)
		shoulder.add_child(_panel(Vector3(inner_len, 0.012, chord * 1.2), Vector3(s * inner_len * 0.5, 0, chord * 0.25), wing_mat))
		var wrist := Node3D.new()
		wrist.position = Vector3(s * inner_len, 0, 0)
		shoulder.add_child(wrist)
		wrist.add_child(_panel(Vector3(outer_len, 0.01, chord * 0.95), Vector3(s * outer_len * 0.5, 0, chord * 0.2), wing_mat))
		var side_fingers: Array[Node3D] = []
		for f in FINGERS:
			var pivot := Node3D.new()
			pivot.position = Vector3(s * outer_len, 0, chord * (-0.15 + 0.17 * f))
			wrist.add_child(pivot)
			pivot.add_child(_panel(Vector3(finger_len, 0.008, chord * 0.16), Vector3(s * finger_len * 0.5, 0, 0), dark))
			side_fingers.append(pivot)
		shoulders.append(shoulder)
		wrists.append(wrist)
		fingers.append(side_fingers)

	tail = Node3D.new()
	tail.position = Vector3(0, L * 0.02, L * 0.36)
	add_child(tail)
	for i in TAIL_FEATHERS:
		var f := Node3D.new()
		tail.add_child(f)
		f.add_child(_panel(Vector3(p.tail_length * 0.26, 0.008, p.tail_length), Vector3(0, 0, p.tail_length * 0.5), wing_mat))
		tail_feathers.append(f)

	for s in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(s * L * 0.06, -L * 0.1, L * 0.02)
		add_child(hip)
		var leg := MeshInstance3D.new()
		var lc := CapsuleMesh.new()
		lc.radius = L * 0.025
		lc.height = L * 0.32
		leg.mesh = lc
		leg.position = Vector3(0, -L * 0.14, 0)
		leg.material_override = beak_mat
		hip.add_child(leg)
		legs.append(hip)


func _panel(size: Vector3, offset: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = offset
	mi.material_override = mat
	return mi


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


static func _tint(bird_id: String) -> Color:
	match bird_id:
		"owl": return Color(0.66, 0.58, 0.46)
		"hawk": return Color(0.55, 0.42, 0.32)
		"falcon": return Color(0.45, 0.5, 0.58)
		"sparrow": return Color(0.6, 0.5, 0.4)
	return Color(0.28, 0.28, 0.3)


## Pose the rig from a Bird.telemetry() snapshot.
func animate(t: Dictionary, dt: float) -> void:
	var k := 1.0 - exp(-14.0 * dt)
	var state: int = t.state
	var sitting := state == Bird.State.PERCHED or state == Bird.State.GROUNDED
	var landing := state == Bird.State.LANDING
	var flare: float = 1.0 if landing else t.flare
	var flap_target := deg_to_rad(5.0)   # gliding dihedral
	var wrist_target := 0.0
	var sweep_target: float = t.fold * deg_to_rad(30.0)
	wrist_target = t.fold * deg_to_rad(110.0)
	if t.flapping and not sitting:
		var ph: float = t.flap_phase
		flap_target = deg_to_rad(10.0 + 45.0 * cos(ph * TAU))   # top at 0, bottom at 0.5
		if ph > 0.5:
			wrist_target = maxf(wrist_target, deg_to_rad(55.0) * sin((ph - 0.5) * TAU))   # flexed upstroke
		k = 1.0   # wingbeats are fast: no smoothing
	if landing:
		flap_target = deg_to_rad(25.0)
		sweep_target = -deg_to_rad(12.0)   # wings swing forward in the flare
	if sitting:
		flap_target = deg_to_rad(-8.0)
		sweep_target = deg_to_rad(80.0)
		wrist_target = deg_to_rad(150.0)
	_flap_angle = lerpf(_flap_angle, flap_target, k)
	_sweep = lerpf(_sweep, sweep_target, 1.0 - exp(-12.0 * dt))
	_wrist_fold = lerpf(_wrist_fold, wrist_target, 1.0 - exp(-12.0 * dt))
	var slow := 1.0 - clampf((float(t.speed) - t.v_stall) / maxf(t.v_best, 0.1), 0.0, 1.0)
	_splay = lerpf(_splay, (1.0 - t.fold) * maxf(slow, flare), 1.0 - exp(-8.0 * dt))
	var tail_target: float = 0.15 + 0.5 * absf(t.bank) / maxf(t.max_bank, 0.1) + 0.6 * slow + flare
	if sitting:
		tail_target = 0.0
	_spread_tail = lerpf(_spread_tail, clampf(tail_target, 0.0, 1.0), 1.0 - exp(-8.0 * dt))
	_leg_fwd = lerpf(_leg_fwd, 1.0 if (landing or flare > 0.3) else (0.5 if sitting else 0.0), 1.0 - exp(-10.0 * dt))

	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		shoulders[i].rotation = Vector3(0.0, -s * _sweep, s * _flap_angle)
		wrists[i].rotation = Vector3(0.0, -s * _wrist_fold, 0.0)
		for f in FINGERS:
			var fan := (f - (FINGERS - 1) * 0.5) * deg_to_rad(7.0) * _splay
			fingers[i][f].rotation = Vector3(0.0, -s * fan, 0.0)
	var fan_total := lerpf(deg_to_rad(8.0), deg_to_rad(110.0), _spread_tail)
	for i in TAIL_FEATHERS:
		var u := float(i) / float(TAIL_FEATHERS - 1) - 0.5
		tail_feathers[i].rotation = Vector3(0.0, u * fan_total, 0.0)
	# Tail pitches down in the flare (airbrake), twists a little with bank.
	tail.rotation = Vector3(-flare * 0.6, 0.0, -float(t.bank) * 0.25)
	for leg in legs:
		# Hanging back (0) when flying, swung forward (1) to reach for the perch.
		leg.rotation = Vector3(lerpf(-1.2, 0.35, _leg_fwd), 0.0, 0.0)
