class_name TargetBalloon
extends Node3D
## A target-practice balloon: a kite balloon of the riders' world -- a Caquot, 28 m long, at their 1:20.6, so
## LENGTH 1.36 m -- moored by a steel cable to a hand winch on a stump, riding nose into the breeze with its three
## lobed fins, a little basket under it with a straw observer in it. Its stages (stage()):
##   UP        whole, riding at the top of its cable;
##   HOLED     bullets have holed it (bullet_hit): each hole lets out LEAK of its gas a second;
##   SINKING   under LIMP of its gas it goes soft -- the nose cups in, the tail and fins droop, the canvas wrinkles --
##             and rides lower on its cable;
##   DOWN      under DOWN_GAS it can't hold itself up and settles on the ground, a limp heap (brought down);
##   BURNING   a burst near it (burst_near: a rocket's) sets it alight -- the fire runs over it from where it caught,
##             leaving charred strips -- and once FALL_FROM of it has gone it falls...
##   FALLING   ...trailing smoke, crumpling as it burns, and...
##   WRECK     ...ends a burnt-out heap on the ground, smouldering.
## The node's origin is the stump's foot (on the ground); `body` is the envelope's frame (nose -Z, up +Y), placed
## each step. Visual and its own state only: nothing here reads or moves a bird.

enum Stage { UP, HOLED, SINKING, DOWN, BURNING, FALLING, WRECK }

const S := 0.085 / 1.75                ## the riders' scale (Tack.RIDER_HEIGHT / TackMesh.REAL_H): model m per real m
const LENGTH := 28.0 * S               ## m, nose to tail
const RADIUS := 4.6 * S                ## m, the envelope at its widest
const RIG_DROP := 9.0 * S              ## m below the belly to the rigging's ring
const BASKET_DROP := 2.2 * S           ## m below the ring to the basket's rim
const STUMP_H := 0.2                   ## m, the stump the winch stands on
const NU := 40                         ## rings along the envelope
const NA := 32                         ## points round each ring
const FIN_NU := 14
const FIN_NA := 14
const FINS := [-PI * 0.5, PI / 6.0, PI * 5.0 / 6.0]   ## round the tail: one under, two up at the sides
const FIN_U := 0.82                    ## along the envelope, the fins' middle

const LEAK := 0.01                     ## of its gas a second, through each hole
const LIMP := 0.85                     ## of its gas under which it goes soft
const DOWN_GAS := 0.3                  ## of its gas under which it can't hold itself up
const HOLE_R := 0.007                  ## m, a bullet hole as drawn (and its scorch to 2.4x that)
const MAX_HOLES := 24
const BURN_SPEED := 0.6                ## m/s the fire runs over the envelope
const FALL_FROM := 0.3                 ## of it burnt, it falls
const FALL_SPEED := 4.5                ## m/s, a burning wreck's fall
const SINK_TIME := 1.2                 ## s it takes to settle to a new height on its cable
const DRAG := 0.22                     ## the breeze's push on it over its lift: how far it leans downwind
const HEAP_ON := 0.14                  ## m, the grass and ferns a heap lies on
const ENVELOPE_LAYER := 1 << 10        ## a render layer of the envelope's own (out of its fire light's reach)
const SMOULDER := 10.0                 ## s a wreck smokes on the ground

var cable := 10.0                      ## m of cable the winch has out
var breeze := Vector3(1.0, 0.0, 0.35).normalized()   ## the way the air goes (it rides nose into it)
var auto := true                       ## step itself each physics tick (probes step it by hand)
var leak := LEAK                       ## (probes hold a stage still with 0)

var gas := 1.0
var holes: Array = []                  ## Vector4: rest-space centre, radius
var burn_at := Vector3.ZERO            ## rest space: where it caught
var burn_r := -1.0                     ## m the fire has run from there (< 0: not alight)
var falling := false
var landed := -1.0                     ## s since it came down on the ground (< 0: it hasn't)
var body: Node3D
var clock := 0.0

var _seed := 0.0
var _vel := Vector3.ZERO
var _ring := Vector3.ZERO              ## the rigging's ring, node-local: where the cable meets the balloon
var _fall_tilt := 0.0
var _env: MeshInstance3D
var _mat: ShaderMaterial
var _lines: MeshInstance3D
var _line_mesh: ImmediateMesh
var _basket: Node3D
var _fire: MeshInstance3D
var _fire_mesh: ImmediateMesh
var _smoke: MeshInstance3D
var _smoke_mesh: ImmediateMesh
var _light: OmniLight3D
var _scorch: MeshInstance3D            ## the burnt ground under a wreck
var _puffs: Array = []                 ## [world pos, drift, t, size]
var _puff_due := 0.0
var _rest: PackedVector3Array          ## every envelope and fin vertex as built, taut
var _cur: PackedVector3Array           ## and where it is now (body space)
var _uv: PackedVector2Array
var _custom: PackedFloat32Array
var _index: PackedInt32Array
var _key := ""
var _rng := RandomNumberGenerator.new()
var _fx_rng := RandomNumberGenerator.new()   ## (the smoke and flames' own draws: the holes' stay the same however it's drawn)


func _init(seed_value := 0) -> void:
	_rng.seed = seed_value + 9137
	_seed = _rng.randf() * 100.0


func _ready() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://scripts/combat/balloon.gdshader")
	_mat.set_shader_parameter("radius", RADIUS)
	_mat.set_shader_parameter("roundel_z", (0.3 - 0.5) * LENGTH)
	_mat.set_shader_parameter("roundel_r", RADIUS * 0.52)
	_env = MeshInstance3D.new()
	_env.name = "Envelope"
	_env.layers = 1 | ENVELOPE_LAYER   # (the fire's light leaves it out: its burning edge glows of itself, and the light
	                                   # so close blew out the lining seen through the burn)
	body.add_child(_env)
	_line_mesh = ImmediateMesh.new()
	_lines = MeshInstance3D.new()
	_lines.name = "Lines"
	_lines.mesh = _line_mesh
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.roughness = 0.7
	lm.metallic = 0.3
	_lines.material_override = lm
	add_child(_lines)
	_basket = Node3D.new()
	_basket.name = "Basket"
	add_child(_basket)
	var bm := MeshInstance3D.new()
	bm.mesh = _basket_mesh()
	_basket.add_child(bm)
	var w := MeshInstance3D.new()
	w.name = "Winch"
	w.mesh = _winch_mesh()
	w.material_override = ArenaBuilder.timber_material({"weather": 0.6})
	add_child(w)
	_fire_mesh = ImmediateMesh.new()
	_fire = _fx_node(_fire_mesh, true)
	_smoke_mesh = ImmediateMesh.new()
	_smoke = _fx_node(_smoke_mesh, false)
	_scorch = MeshInstance3D.new()
	_scorch.name = "Scorch"
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.6, 2.6)
	_scorch.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = _soft_tex()
	sm.albedo_color = Color(0.02, 0.018, 0.015, 0.95)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.roughness = 1.0
	_scorch.material_override = sm
	_scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scorch.visible = false
	add_child(_scorch)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = 3.0
	_light.light_cull_mask = ~ENVELOPE_LAYER
	_light.light_energy = 0.0
	_light.visible = false
	body.add_child(_light)
	_build_rest()
	_ring = _ride_ring(1.0)
	step(0.0)


func _physics_process(dt: float) -> void:
	if auto:
		step(dt)


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	_draw_fx(cam.global_position if cam != null else global_position + Vector3(0, 0, 5))


# --- What it is now -------------------------------------------------------------------------------------------

func stage() -> Stage:
	if burn_r >= 0.0:
		if landed >= 0.0:
			return Stage.WRECK
		return Stage.FALLING if falling else Stage.BURNING
	if gas < DOWN_GAS:
		return Stage.DOWN
	if gas < LIMP:
		return Stage.SINKING
	return Stage.HOLED if not holes.is_empty() else Stage.UP


## Brought down: deflated on the ground, or alight (it's lost from then).
func is_down() -> bool:
	return stage() in [Stage.DOWN, Stage.BURNING, Stage.FALLING, Stage.WRECK]


## Of the envelope burnt, 0 .. 1.
func burnt() -> float:
	return clampf(burn_r / _burn_full(), 0.0, 1.0) if burn_r >= 0.0 else 0.0


## The envelope's middle, world.
func centre() -> Vector3:
	return body.global_position


## Can a balloon moored at `at` (on the ground) on `cable` m ride clear of `layout`'s wood and foliage, by `room` m?
## (Its cable's whole sweep, nearly upright, and the balloon at the top.)
static func clear_spot(layout: ArenaLayout, at: Vector3, cable_m: float, room := 1.5) -> bool:
	for t: ArenaLayout.TreeData in layout.trees:
		var flat := t.base.distance_to(Vector2(at.x, at.z))
		if flat > t.reach() + 12.0:
			continue
		if flat < t.reach() + room:
			return false
		for f in t.foliage:
			var c: Vector3 = f[0]
			var r: Vector3 = f[1]
			for k in 6:
				var p := at + Vector3.UP * cable_m * (0.3 + 0.14 * k)
				var q := (p - c) / (r + Vector3.ONE * (room + LENGTH * 0.5))
				if q.length() < 1.0:
					return false
	return true


# --- Hits -----------------------------------------------------------------------------------------------------

## A bullet through it at `at` (world), going `dir`: a hole where it went in and where it came out.
func bullet_hit(at: Vector3, dir: Vector3) -> void:
	if burn_r >= 0.0:
		return
	var a := _to_rest(at)
	_add_hole(a)
	# (out the far side: along the shot through the envelope's section)
	var d := body.global_basis.inverse() * dir.normalized()
	var far := a + d * RADIUS * 1.6
	_add_hole(_onto_surface(far))


## A burst at `at` (world) within reach: the envelope catches where it's nearest.
func burst_near(at: Vector3) -> void:
	if burn_r >= 0.0:
		return
	burn_at = _onto_surface(_to_rest(at))
	burn_r = 0.0


## Does the segment a -> b (world) pass through the envelope? Where it first does, or null.
func hit_point(a: Vector3, b: Vector3) -> Variant:
	if stage() in [Stage.FALLING, Stage.WRECK, Stage.DOWN]:
		return null
	var inv := body.global_transform.affine_inverse()
	var n := 12
	for i in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / n)
		var q := inv * p
		var u := q.z / LENGTH + 0.5
		if u >= 0.0 and u <= 1.0 and Vector2(q.x, q.y).length() < _r(u):
			return p
	return null


func _add_hole(rest_pos: Vector3) -> void:
	if holes.size() >= MAX_HOLES:
		holes.pop_front()
	holes.append(Vector4(rest_pos.x, rest_pos.y, rest_pos.z, HOLE_R * _rng.randf_range(0.8, 1.25)))


## A world point as the rest-space point it lies over (the taut envelope's).
func _to_rest(at: Vector3) -> Vector3:
	return _onto_surface(body.global_transform.affine_inverse() * at)


func _onto_surface(q: Vector3) -> Vector3:
	var u := clampf(q.z / LENGTH + 0.5, 0.0, 1.0)
	var a := atan2(q.y, q.x)
	var r := _r(u)
	return Vector3(r * cos(a), r * sin(a), (u - 0.5) * LENGTH)


# --- The step -------------------------------------------------------------------------------------------------

func step(dt: float) -> void:
	clock += dt
	if burn_r < 0.0:
		gas = maxf(0.0, gas - leak * holes.size() * dt)
	else:
		burn_r += BURN_SPEED * dt
		gas = maxf(0.0, gas - 0.6 * dt)
		if burnt() > FALL_FROM and landed < 0.0:
			falling = true
	var heap := _heap_y()
	if landed >= 0.0:
		landed += dt
	elif falling:
		_vel.y = move_toward(_vel.y, -FALL_SPEED, 9.8 * dt)
		_vel.x = move_toward(_vel.x, breeze.x * 0.6, dt)
		_vel.z = move_toward(_vel.z, breeze.z * 0.6, dt)
		body.position += _vel * dt
		_fall_tilt = move_toward(_fall_tilt, 1.0, dt * 0.8)
		if body.position.y <= heap:
			body.position.y = heap
			landed = 0.0
			falling = false
			_scorch.position = Vector3(body.position.x, 0.015, body.position.z)
			_scorch.rotation.y = _rng.randf() * TAU
			_scorch.visible = true
	else:
		var lift := clampf((gas - DOWN_GAS) / (1.0 - DOWN_GAS), 0.0, 1.0)
		var to := _ride_ring(lift)
		var k := 1.0 - exp(-dt / SINK_TIME) if dt > 0.0 else 0.0
		_ring = _ring.lerp(to, k)
		var bp := _ring + Vector3(0.0, RADIUS + RIG_DROP, 0.0)
		if gas < DOWN_GAS:
			bp.y = maxf(heap, body.position.y - 1.5 * dt)
			if bp.y <= heap + 1e-3:
				landed = 0.0
		body.position = bp
	_place_body()
	_shape()
	_update_lines()
	_update_material()
	_step_fx(dt)


## Where the ring rides with `lift` (0 .. 1 of its full lift): leaning downwind, lower as it fails.
func _ride_ring(lift: float) -> Vector3:
	var lean := minf(atan2(DRAG, maxf(lift, 0.05)), 0.6)
	var h := cable * cos(lean) * (0.22 + 0.78 * smoothstep(0.0, 0.6, lift))
	var w := Vector3(breeze.x, 0.0, breeze.z).normalized()
	return Vector3(0.0, STUMP_H + 0.06, 0.0) + w * cable * sin(lean) + Vector3.UP * h


## The body's height (node-local) when it lies on the ground: draped over the ground cover (HEAP_ON).
func _heap_y() -> float:
	return RADIUS * 0.28 + HEAP_ON


func _settle() -> float:
	return smoothstep(0.0, 0.7, landed) if landed >= 0.0 else 0.0


## Nose into the breeze, swaying on its cable; level as it settles; nose down as it falls.
func _place_body() -> void:
	var w := Vector3(breeze.x, 0.0, breeze.z).normalized()
	var yaw := atan2(w.x, w.z)   # (its -Z, the nose, into the breeze: +Z downwind)
	var t := clock + _seed
	var calm := 1.0 - _settle()
	var sway_yaw := (0.12 * sin(t * 0.83) + 0.05 * sin(t * 1.97)) * calm
	var roll := (0.05 * sin(t * 1.1 + 1.0) + 0.02 * sin(t * 2.7)) * calm
	var pitch := (0.03 * sin(t * 0.7 + 2.0)) * calm
	pitch -= 0.45 * _fall_tilt * calm
	roll += 0.3 * _fall_tilt * sin(t * 1.6) * calm
	body.basis = Basis(Vector3.UP, yaw + sway_yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	if landed < 0.0 and not falling:
		body.position.y += 0.025 * sin(t * 0.9) * calm


# --- The envelope's shape -------------------------------------------------------------------------------------

## The envelope's radius at `u` (0 nose .. 1 tail): a blunt nose, widest a third back, tapering to the tail.
static func _r(u: float) -> float:
	if u < 0.35:
		return RADIUS * pow(sin(PI * 0.5 * clampf(u / 0.35, 0.0, 1.0)), 0.5)
	return RADIUS * (1.0 - 0.86 * pow((u - 0.35) / 0.65, 1.8))


static func _u_at(i: int) -> float:
	return 0.5 - 0.5 * cos(PI * float(i) / NU)


func _burn_full() -> float:
	return LENGTH * 1.05


## Rest positions, UVs and the triangles: built once.
func _build_rest() -> void:
	_rest = PackedVector3Array()
	_uv = PackedVector2Array()
	_custom = PackedFloat32Array()
	_index = PackedInt32Array()
	var along := 0.0
	var prev := Vector3.ZERO
	for i in NU + 1:
		var u := _u_at(i)
		var r := _r(u)
		var z := (u - 0.5) * LENGTH
		var mid := Vector3(r, 0.0, z)
		if i > 0:
			along += mid.distance_to(prev)
		prev = mid
		for j in NA + 1:
			var a := TAU * j / NA
			var p := Vector3(r * cos(a), r * sin(a), z)
			_rest.append(p)
			_uv.append(Vector2(along, float(j) / NA))
			_custom.append_array([p.x, p.y, p.z, 0.0])
	for i in NU:
		for j in NA:
			var a := i * (NA + 1) + j
			var b := a + 1
			var c := a + NA + 1
			var d := c + 1
			_index.append_array([a, c, b, b, c, d])   # (clockwise seen from outside: Godot's front)
	for fi in FINS.size():
		var base := _rest.size()
		for i in FIN_NU + 1:
			for j in FIN_NA + 1:
				var p := _fin_point(fi, float(i) / FIN_NU, float(j) / FIN_NA, 0.0, 0.0)
				_rest.append(p)
				_uv.append(Vector2(float(i) / FIN_NU * 0.3, float(j) / FIN_NA))
				_custom.append_array([p.x, p.y, p.z, 1.0])
		for i in FIN_NU:
			for j in FIN_NA:
				var a := base + i * (FIN_NA + 1) + j
				var b := a + 1
				var c := a + FIN_NA + 1
				var d := c + 1
				_index.append_array([a, c, b, b, c, d])
	_cur = _rest.duplicate()


## A point on fin `fi`, its lobe parametrised `s` (0 front .. 1 back) and `t` (round it), `limp` and `crumple`
## 0 .. 1. A fin is a fat lobe, fatter behind, its root sunk in the envelope; limp, it flattens and droops.
func _fin_point(fi: int, s: float, t: float, limp: float, crumple: float) -> Vector3:
	var phi: float = FINS[fi]
	var big := 1.1 if fi == 0 else 1.0
	var rad := Vector3(cos(phi), sin(phi), 0.0)
	if limp > 0.0 and fi != 0:
		# (an upper fin droops toward the ground, round its root)
		var droop := 0.9 * limp
		var r1 := rad.rotated(Vector3.BACK, droop)
		var r2 := rad.rotated(Vector3.BACK, -droop)
		rad = r1 if r1.y < r2.y else r2
	var wdir := Vector3.BACK.cross(rad).normalized()
	var th := PI * s
	var ps := TAU * t
	var az := 0.13 * LENGTH * big
	var ar := 0.6 * RADIUS * big * (1.0 - 0.3 * limp) * (1.0 - 0.5 * crumple)
	var aw := 0.15 * RADIUS * big * (1.0 - 0.55 * limp)
	var fat := 0.45 + 0.75 * (1.0 - cos(th)) * 0.5   # (swept: deeper behind, a fin's outline more than a sausage's)
	var zc := (FIN_U - 0.5) * LENGTH
	var root := _r(FIN_U) + 0.2 * RADIUS * big
	var wr := 1.0 + limp * 0.12 * sin(ps * 3.0 + s * 9.0)
	var p := Vector3(0.0, 0.0, zc - az * cos(th))
	p += rad * (root * (1.0 - 0.25 * limp) + ar * fat * cos(ps) * sin(th) * wr)
	p += wdir * aw * fat * sin(ps) * sin(th)
	if fi == 0 and limp > 0.0:
		p.y -= limp * 0.15 * RADIUS * sin(th)   # (the lower fin hangs, a slack sack)
	return p


func _limp() -> float:
	return clampf((LIMP - gas) / (LIMP - DOWN_GAS * 0.5), 0.0, 1.0)


func _crumple() -> float:
	if burn_r >= 0.0:
		return smoothstep(0.05, 0.85, burnt())
	return 0.45 * _settle()


## A cheap smooth noise (-1 .. 1) of a rest point, per balloon.
func _n(p: Vector3, k: float) -> float:
	return sin(p.x * k * 1.7 + _seed) * sin(p.y * k * 2.3 + p.z * k * 0.9 + _seed * 1.3) + 0.5 * sin(p.z * k * 3.1 - p.x * k * 1.1 + _seed * 0.7)


## Where every vertex is now: limp, crumpled, settled on the ground.
func _shape() -> void:
	var l := _limp()
	var c := _crumple()
	var s := _settle()
	var key := "%.3f %.3f %.3f" % [l, c, s]
	if key == _key:
		return
	_key = key
	var n_env := (NU + 1) * (NA + 1)
	for i in NU + 1:
		var u := _u_at(i)
		for j in NA + 1:
			var k := i * (NA + 1) + j
			_cur[k] = _deform(_rest[k], u, TAU * j / NA, l, c, s)
	var per := (FIN_NU + 1) * (FIN_NA + 1)
	for fi in FINS.size():
		for i in FIN_NU + 1:
			for j in FIN_NA + 1:
				var k := n_env + fi * per + i * (FIN_NA + 1) + j
				var p := _fin_point(fi, float(i) / FIN_NU, float(j) / FIN_NA, l, c)
				_cur[k] = _settle_point(_crumple_point(p, _rest[k], c), s)
	_upload()


func _deform(p0: Vector3, u: float, a: float, l: float, c: float, s: float) -> Vector3:
	var r := _r(u)
	# Limp: the canvas wrinkles, worst behind; the top sags in; the tail droops and the nose lifts and cups in.
	var wr := l * (0.07 * sin(11.0 * a + 7.0 * u + _seed) + 0.04 * sin(23.0 * a - 13.0 * u)) * smoothstep(0.2, 0.9, u)
	var rr := r * (1.0 - 0.08 * l + wr)
	var x := rr * cos(a)
	var y := rr * sin(a)
	if y > 0.0:
		y *= 1.0 - 0.25 * l
	var z := (u - 0.5) * LENGTH
	y -= l * 0.2 * LENGTH * pow(smoothstep(0.3, 1.0, u), 2.0)
	y += l * 0.04 * LENGTH * pow(1.0 - smoothstep(0.0, 0.3, u), 2.0)
	z += l * 1.3 * RADIUS * pow(maxf(0.0, 1.0 - u / 0.16), 2.0)
	return _settle_point(_crumple_point(Vector3(x, y, z), p0, c), s)


## Burning: it shrinks and crumples, lumpy, shorter.
func _crumple_point(p: Vector3, p0: Vector3, c: float) -> Vector3:
	if c <= 0.0:
		return p
	var k := 1.0 - 0.6 * c + c * 0.3 * _n(p0, 14.0)
	var q := Vector3(p.x * k, p.y * k * (1.0 - 0.3 * c), p.z * (1.0 - 0.3 * c))
	q += Vector3(_n(p0, 21.0), _n(p0 + Vector3(3, 0, 0), 19.0), _n(p0 + Vector3(0, 5, 0), 17.0)) * 0.05 * c
	q.y -= c * 0.25 * RADIUS * (1.0 - absf(p0.z) / (LENGTH * 0.5))
	return q


## On the ground: flattened into a heap, spread a little.
func _settle_point(p: Vector3, s: float) -> Vector3:
	if s <= 0.0:
		return p
	var floor_y := -_heap_y()
	var y := floor_y + (p.y + RADIUS) * 0.22 + 0.02 * (1.0 + sin(p.x * 40.0 + p.z * 31.0 + _seed))
	return Vector3(p.x * (1.0 + 0.5 * s), lerpf(p.y, maxf(y, floor_y + 0.004), s), p.z * (1.0 + 0.1 * s))


func _upload() -> void:
	var nrm := PackedVector3Array()
	nrm.resize(_cur.size())
	for t in range(0, _index.size(), 3):
		var a := _index[t]
		var b := _index[t + 1]
		var c := _index[t + 2]
		var fn := (_cur[c] - _cur[a]).cross(_cur[b] - _cur[a])
		nrm[a] += fn
		nrm[b] += fn
		nrm[c] += fn
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 1e-14 else Vector3.UP
	# (the seam where each ring closes: one normal for both copies)
	for i in NU + 1:
		var a := i * (NA + 1)
		var b := a + NA
		var m := (nrm[a] + nrm[b]).normalized()
		nrm[a] = m
		nrm[b] = m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _cur
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = _uv
	arr[Mesh.ARRAY_CUSTOM0] = _custom
	arr[Mesh.ARRAY_INDEX] = _index
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	m.surface_set_material(0, _mat)
	_env.mesh = m


func _update_material() -> void:
	var hv := []
	for h in holes:
		hv.append(h)
	while hv.size() < MAX_HOLES:
		hv.append(Vector4.ZERO)
	_mat.set_shader_parameter("holes", hv)
	_mat.set_shader_parameter("hole_n", holes.size())
	_mat.set_shader_parameter("burn", Vector4(burn_at.x, burn_at.y, burn_at.z, burn_r if burn_r >= 0.0 else -1.0))
	_mat.set_shader_parameter("flicker", 0.5 + 0.5 * sin(clock * 23.0) * sin(clock * 7.3))
	_mat.set_shader_parameter("smoulder", 1.0 - smoothstep(0.0, SMOULDER, landed) if landed >= 0.0 and burn_r >= 0.0 else 0.0)


# --- Rigging, cable, basket, winch ----------------------------------------------------------------------------

## The ring, body space: under the belly, a little ahead of the middle.
func _ring_local() -> Vector3:
	var p := Vector3(0.0, -RADIUS - RIG_DROP, -0.08 * LENGTH)
	var c := _crumple()
	p.y += c * RIG_DROP * 0.3
	if _settle() > 0.0:
		p.y = lerpf(p.y, -_heap_y() + 0.01, _settle())
		p.x = lerpf(p.x, RADIUS * 1.3, _settle())
	return p


## The belly's rigging points (vertex indices along the bottom, either side).
func _rig_points() -> Array:
	var out := []
	for i in [9, 13, 17, 21, 25]:
		for j in [NA / 4 * 3 - 3, NA / 4 * 3 + 3]:   # (a = -PI/2 is j = 3/4 NA: the belly)
			out.append(i * (NA + 1) + j)
	return out


func _update_lines() -> void:
	var im := _line_mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rope := Color(0.42, 0.33, 0.22)
	var steel := Color(0.16, 0.16, 0.17)
	var ring := body.transform * _ring_local()
	var burnt_lines := burnt() > 0.6
	for k in _rig_points():
		var a := body.transform * _cur[k]
		if not burnt_lines or (k % 3) == 0:
			_tube(im, a, ring, 0.0016, rope if burn_r < 0.0 else Color(0.08, 0.07, 0.06))
	# The basket hangs plumb from the ring by four lines.
	var bpos := ring - Vector3(0.0, BASKET_DROP, 0.0)
	var ground := 0.004
	if bpos.y < ground + 0.03:
		bpos = Vector3(ring.x + 0.08, ground, ring.z + 0.05)
	_basket.position = bpos
	_basket.basis = Basis(Vector3.UP, body.rotation.y)
	var bw := 0.028
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_tube(im, ring, bpos + _basket.basis * Vector3(cx * bw, 0.055, cz * bw), 0.0012, rope)
	# The cable: from the ring down to the winch's drum, sagging as it slackens.
	var drum := Vector3(0.0, STUMP_H + 0.06, 0.0)
	var span := ring.distance_to(drum)
	var slack := maxf(0.0, cable - span)
	var sag := sqrt(0.375 * span * slack) if slack > 0.0 else 0.0
	sag = maxf(sag, span * 0.012)
	var prev := drum
	var segs := 28
	for i in range(1, segs + 1):
		var f := float(i) / segs
		var p := drum.lerp(ring, f)
		p.y -= 4.0 * sag * f * (1.0 - f)
		p.y = maxf(p.y, 0.006)
		_tube(im, prev, p, 0.0024, steel)
		prev = p
	im.surface_end()


static func _tube(im: ImmediateMesh, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	var d := b - a
	if d.length() < 1e-5:
		return
	var y := d.normalized()
	var x := (Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).cross(y).normalized()
	var z := y.cross(x)
	var sides := 4
	for s in sides:
		var a0 := TAU * s / sides
		var a1 := TAU * (s + 1) / sides
		var n0 := x * cos(a0) + z * sin(a0)
		var n1 := x * cos(a1) + z * sin(a1)
		im.surface_set_color(col)
		for v in [[a, n0], [b, n0], [b, n1], [a, n0], [b, n1], [a, n1]]:
			im.surface_set_normal(v[1])
			im.surface_add_vertex(v[0] + v[1] * r)


## The basket (rim at its origin's +0.055, a wicker box at the riders' scale) and the straw observer in it.
func _basket_mesh() -> ArrayMesh:
	var tm := TackMesh.new(0.085)
	var w := 0.028
	var h := 0.05
	# Wicker sides: a square tube, open at the top, with a floor.
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(w * 1.41, 0.0), Vector2(w * 1.45, h), Vector2(w * 1.36, h + 0.004), Vector2(w * 1.3, h * 0.2)])
	tm.lathe(prof, 4, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.ZERO))
	var m := tm.commit()
	m.surface_set_material(0, _wicker())
	var dummy := TackMesh.new(0.085)
	# A straw-stuffed sack in a tunic, its head in a leather helmet, standing in the basket.
	dummy.lathe(PackedVector2Array([Vector2(0.0, 0.01), Vector2(0.014, 0.012), Vector2(0.016, 0.04), Vector2(0.013, 0.062), Vector2(0.006, 0.07)]), 10, Transform3D.IDENTITY)
	m = dummy.commit(m)
	m.surface_set_material(1, TackMaterials.get_mat("canvas"))
	var head := TackMesh.new(0.085)
	var hp := PackedVector2Array()
	for k in 9:
		var t := PI * k / 8.0
		hp.append(Vector2(0.0085 * sin(t), 0.081 - 0.0095 * cos(t)))
	head.lathe(hp, 12, Transform3D.IDENTITY)
	m = head.commit(m)
	m.surface_set_material(2, TackMaterials.get_mat("helmet"))
	return m


static var _wicker_mat: Material
static func _wicker() -> Material:
	if _wicker_mat == null:
		var sm := ShaderMaterial.new()
		sm.shader = TackMaterials.CLOTH
		sm.set_shader_parameter("col", Color(0.62, 0.5, 0.32))
		sm.set_shader_parameter("dark_col", Color(0.3, 0.22, 0.12))
		sm.set_shader_parameter("weave", 0)
		sm.set_shader_parameter("pitch", 2.2)
		sm.set_shader_parameter("rough", 0.9)
		sm.set_shader_parameter("bump", 2.0)
		_wicker_mat = sm
	return _wicker_mat


## The stump and the hand winch on it (TimberMesh, planks.gdshader): two cheeks, the drum wound with cable, a crank.
func _winch_mesh() -> ArrayMesh:
	var tm := TimberMesh.new()
	var K := TimberMesh.Kind
	tm.cylinder("stump", Transform3D(Basis(), Vector3(0.0, STUMP_H * 0.5, 0.0)), 0.1, STUMP_H, K.ROUND, 0.37, 14, 0.092)
	var top := STUMP_H
	for sx in [-1.0, 1.0]:
		tm.box("cheek", Transform3D(Basis(), Vector3(sx * 0.045, top + 0.045, 0.0)), Vector3(0.012, 0.09, 0.07), K.BEAM, 0.5 + sx * 0.1)
		tm.bolt(Vector3(sx * 0.052, top + 0.06, 0.0), Vector3(sx, 0.0, 0.0), 0.005, 0.3)
	var axle := Basis(Vector3.BACK, PI * 0.5)   # (a cylinder's y across, along x)
	tm.cylinder("axle", Transform3D(axle, Vector3(0.0, top + 0.06, 0.0)), 0.006, 0.13, K.IRON, 0.2)
	tm.cylinder("drum", Transform3D(axle, Vector3(0.0, top + 0.06, 0.0)), 0.026, 0.075, K.ROPE, 0.6)
	for sx in [-1.0, 1.0]:
		tm.cylinder("flange", Transform3D(axle, Vector3(sx * 0.037, top + 0.06, 0.0)), 0.034, 0.004, K.IRON, 0.4)
	# The crank: an arm off the axle's end and its handle.
	tm.box("crank", Transform3D(Basis(), Vector3(0.068, top + 0.06 - 0.022, 0.0)), Vector3(0.005, 0.05, 0.008), K.IRON, 0.1)
	tm.cylinder("handle", Transform3D(axle, Vector3(0.08, top + 0.06 - 0.045, 0.0)), 0.004, 0.025, K.BEAM, 0.8)
	tm.torus("coil", Vector3(-0.07, 0.008, 0.08), Vector3.UP, 0.035, 0.005, K.ROPE, 0.4)
	return tm.commit()


# --- Fire and smoke -------------------------------------------------------------------------------------------

static var _soft: Texture2D
static func _soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


## A flame's shape: a teardrop, broad and bright at its foot, licking up to a ragged tip (64 x 128, white; its alpha
## the shape).
static var _flame: Texture2D
static func _flame_tex() -> Texture2D:
	if _flame == null:
		var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
		var n := FastNoiseLite.new()
		n.seed = 7
		n.frequency = 0.08
		for y in 128:
			var t := 1.0 - y / 127.0   # (0 at the foot, 1 at the tip)
			var half := 0.5 * pow(sin(PI * clampf(0.15 + 0.85 * t, 0.0, 1.0)), 0.7) * (1.0 - 0.75 * t)
			for x in 64:
				var u := (x / 63.0 - 0.5) + 0.08 * n.get_noise_2d(x, y) * t
				var a := 1.0 - smoothstep(half * 0.55, half, absf(u))
				a *= smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.75, 1.0, t + 0.15 * n.get_noise_2d(x * 2.0, y * 0.5)))
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
		_flame = ImageTexture.create_from_image(img)
	return _flame


func _fx_node(m: ImmediateMesh, hot: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _flame_tex() if hot else _soft_tex()
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if hot else BaseMaterial3D.BLEND_MODE_MIX
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.extra_cull_margin = 50.0
	add_child(mi)
	return mi


## How hard it's burning now, 0 .. 1.
func fire() -> float:
	if burn_r < 0.0:
		return 0.0
	var f := smoothstep(0.0, 0.15, burn_r) * (1.0 - smoothstep(0.85, 1.0, burnt()))
	if landed >= 0.0:
		f *= 1.0 - smoothstep(0.0, 2.0, landed)
	return f


## Rest-space envelope vertices on the burning edge (where the flames are), as body-space points now.
func _rim_points(n: int) -> Array:
	var out := []
	if burn_r < 0.0:
		return out
	var n_env := (NU + 1) * (NA + 1)
	var step_k := 3
	for k in range(_fx_rng.randi() % step_k, n_env, step_k):
		var d := _rest[k].distance_to(burn_at)
		if absf(d - burn_r) < 0.06 or (d < burn_r and _fx_rng.randf() < 0.02):
			out.append(_cur[k])
	out.shuffle()
	return out.slice(0, n)


func _step_fx(dt: float) -> void:
	var f := fire()
	_light.visible = f > 0.01
	if f > 0.01:
		var rim := _rim_points(6)
		var m := Vector3.ZERO
		for q in rim:
			m += q
		if not rim.is_empty():
			var out := m / rim.size()
			out += Vector3(out.x, out.y, 0.0).normalized() * RADIUS * 1.5 + Vector3.UP * 0.15
			_light.position = _light.position.lerp(out, 0.3)   # (in the flames, outside the envelope: they light the canvas round them, not its lining)
	_light.light_energy = 1.6 * f * (0.8 + 0.3 * sin(clock * 31.0) * sin(clock * 11.0))
	# Smoke puffs: thick off the fire, a thin wisp from a smouldering wreck.
	var rate := 60.0 * f
	if landed >= 0.0 and landed < SMOULDER and burn_r >= 0.0:
		rate = maxf(rate, 6.0 * (1.0 - landed / SMOULDER))
	_puff_due += rate * dt
	var rim := _rim_points(int(ceil(_puff_due))) if _puff_due >= 1.0 else []
	while _puff_due >= 1.0:
		_puff_due -= 1.0
		var at: Vector3 = body.global_transform * (rim[_fx_rng.randi() % rim.size()] if not rim.is_empty() else Vector3.ZERO)
		var drift := Vector3(breeze.x, 0.0, breeze.z) * _fx_rng.randf_range(0.3, 0.6) + Vector3(_fx_rng.randf_range(-0.1, 0.1), _fx_rng.randf_range(0.5, 0.9), _fx_rng.randf_range(-0.1, 0.1))
		_puffs.append([at, drift, 0.0, _fx_rng.randf_range(0.1, 0.18)])
	var keep := []
	for p in _puffs:
		p[2] += dt
		p[0] += p[1] * dt
		if p[2] < 3.5:
			keep.append(p)
	_puffs = keep


func _draw_fx(eye: Vector3) -> void:
	_smoke_mesh.clear_surfaces()
	_fire_mesh.clear_surfaces()
	if not _puffs.is_empty():
		_smoke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in _puffs:
			var age: float = p[2]
			var sz: float = p[3] * (1.0 + age * 2.6)
			var a := 0.75 * smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(1.4, 3.5, age))
			var g := lerpf(0.025, 0.14, smoothstep(0.0, 2.5, age))   # (doped canvas burns black, greying as it spreads)
			_billboard(_smoke_mesh, p[0], eye, sz, Color(g, g * 0.95, g * 0.9, a))
		_smoke_mesh.surface_end()
	var f := fire()
	if f > 0.01:
		_fire_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var rim := _rim_points(40)
		for i in rim.size():
			var q: Vector3 = rim[i]
			# (the tongue's foot just outside the canvas, so the fire's light doesn't wash over the hole it's made)
			var at: Vector3 = body.global_transform * (q + Vector3(q.x, q.y, 0.0).normalized() * 0.03)
			var fl := 0.6 + 0.4 * sin(clock * 17.0 + i * 2.3)
			var big := 0.6 + 0.8 * fmod(i * 0.618 + _seed, 1.0)   # (some tongues big, most small)
			var sz := (0.07 + 0.07 * fl) * big * (0.5 + 0.5 * f)
			var lean := Vector3(breeze.x, 0.0, breeze.z) * 0.35   # (the breeze bends them)
			_tongue(_fire_mesh, at, eye, sz * 0.6, sz * (2.0 + 1.4 * fl), Color(1.0, 0.3 + 0.1 * fl, 0.04, 0.4 * f), lean)
			_tongue(_fire_mesh, at, eye, sz * 0.32, sz * (1.2 + 0.8 * fl), Color(1.0, 0.6, 0.2, 0.28 * f), lean)
		_fire_mesh.surface_end()


## A flame's tongue: a quad standing up from `base`, `w` half wide and `h` tall, turned to the eye about the vertical
## (the fire texture's teardrop in it: _flame_tex, its foot at the quad's foot).
static func _tongue(m: ImmediateMesh, base: Vector3, eye: Vector3, w: float, h: float, col: Color, lean := Vector3.ZERO) -> void:
	var to := eye - base
	to.y = 0.0
	var right := Vector3.UP.cross(to.normalized()) if to.length() > 1e-4 else Vector3.RIGHT
	var tip := (Vector3.UP + lean) * h
	var pts := [base - right * w, base + right * w, base + right * w + tip, base - right * w + tip]
	# (UV v from 1 at the foot to 0 at the tip; the fire material's texture is the flame, not a round puff)
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 1, 2, 0, 2, 3]:
		m.surface_set_color(col)
		m.surface_set_uv(uvs[k])
		m.surface_add_vertex(pts[k])


static func _billboard(m: ImmediateMesh, c: Vector3, eye: Vector3, r: float, col: Color) -> void:
	var fwd := (eye - c).normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	if right.length() < 0.5:
		right = Vector3.RIGHT
	var up := fwd.cross(right)
	var pts := [c - right * r - up * r, c + right * r - up * r, c + right * r + up * r, c - right * r + up * r]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 1, 2, 0, 2, 3]:
		m.surface_set_color(col)
		m.surface_set_uv(uvs[k])
		m.surface_add_vertex(pts[k])
