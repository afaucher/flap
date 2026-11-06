class_name CombatFx
extends Node3D
## What a fight looks like when something goes off (CombatWorld owns one; visual only, nothing here changes the
## fight). Stepped on the physics tick, drawn in _process at the moment the frame draws the birds (Bird.drawn_lag).
##   burst          a one-frame white-hot flash (bright enough to bloom) and a short light on what's near (the bark,
##                  the bird and its rider); a brown-grey puff that swells to the blast's reach and drifts for a couple
##                  of seconds; embers flung out and falling. A seeker's is bigger than a rocket's. A fizzle (a round
##                  that ran out) is a small dull pop, no light. A bullet's strike (GUN) is a spark: a pinpoint flash, a
##                  few embers and a wisp of dust or splinters' smoke, no light.
##   muzzle flash   each bullet fired: a pinpoint flash at the gun's mouth for a frame or two.
##   knocked out    the feathers a hit took leave the wing where they were -- copies of the very cards the rig drew
##                  (BirdRig.feather_copy) -- and fall as feathers do: slowed hard by the air, tumbling, slipping from
##                  side to side, coming to rest on the ground, fading after a while.
##   down           a puff of small pale body feathers where the hit landed, gone in about a second.
##   shedding       a badly damaged bird (health at or under SHED_HEALTH) now and then loses a covert in flight: a
##                  loose feather drifting off behind it (it costs nothing).

const FLASH_TIME := 0.06       ## s of white-hot core
const LIGHT_TIME := 0.16       ## s the burst's light takes to die
const LIGHT_ENERGY := 6.0
const LIGHT_RANGE := 4.0       ## m
const SMOKE_TIME := 2.2        ## s a puff lasts
const EMBER_TIME := 0.8
const FALL_SPEED := 1.0        ## m/s, a loose feather's terminal descent
const FALL_LIFE := 8.0         ## s before a fallen feather is gone (its last second fading)
const DOWN_TIME := 1.1
const SHED_HEALTH := 0.5
const SHED_RATE := 0.35        ## loose coverts a second, at or under SHED_HEALTH
const MAX_LOOSE := 48
const GUN_BIG := 0.22          ## a bullet's strike, as a fraction of a rocket's burst
const MUZZLE_BIG := 0.08       ## a muzzle flash, likewise

var flashes_drawn: Array = []  ## where each muzzle flash was last drawn (tests)
var bursts: Array = []         ## {pos, t, kind, why, embers: [[pos, vel]], puffs: [[offset, drift, size]]}
var loose: Array = []          ## {node, pos, vel, t, spin, rock, phase, landed, ground}: falling feathers
var down: Array = []           ## {pos, vel, t, size, col, spin}
var clock := 0.0             ## the fight's time (CombatWorld sets it each tick, before anything goes off)
var _rng := RandomNumberGenerator.new()
var _mesh: ImmediateMesh
var _soft: ImmediateMesh
var _lights: Array = []        ## OmniLight3D pool: [light, burst]


func _ready() -> void:
	_rng.seed = 11
	_mesh = ImmediateMesh.new()
	_soft = ImmediateMesh.new()
	add_child(CombatWorld._mesh_node(_mesh, _material(true)))
	add_child(CombatWorld._mesh_node(_soft, _material(false)))
	for i in 4:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.omni_range = LIGHT_RANGE
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append([l, null])


## Unshaded, vertex-coloured, alpha. `hot`: additive, for the flash and the embers (their colour runs past 1: it blooms).
static func _material(hot: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if hot:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	return m


## A round went off at `at` ("fuse" | "hit" | "impact" | "expired"), a rocket, a seeker or a bullet (Projectile.Kind).
func burst(at: Vector3, why: String, kind: int) -> void:
	var gun := kind == Projectile.Kind.GUN
	var big := 1.35 if kind == Projectile.Kind.SEEKER else (GUN_BIG if gun else 1.0)
	var b := {"pos": at, "t": clock, "kind": kind, "why": why, "big": big, "embers": [], "puffs": []}
	var rng := RandomNumberGenerator.new()   # (each burst's own shape, from where it is)
	rng.seed = hash(Vector3i(at * 50.0))
	if why != "expired":
		for i in (5 if gun else roundi(16 * big)):
			var dir := Vector3(rng.randfn(), rng.randfn() * 0.8 + 0.25, rng.randfn()).normalized()
			b.embers.append([at, dir * rng.randf_range(3.5, 8.5) * maxf(big, 0.5), rng.randf_range(0.45, 1.0) * EMBER_TIME * (0.4 if gun else 1.0)])
		for i in (2 if gun else 6):
			var off := Vector3(rng.randfn(), rng.randfn() * 0.6, rng.randfn()) * 0.18 * big
			var drift := Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.15, 0.4), rng.randf_range(-0.15, 0.15))
			b.puffs.append([off, drift, rng.randf_range(0.7, 1.0)])
	bursts.append(b)
	if why == "expired" or gun:
		return
	var slot: Array = _lights[0]
	for s in _lights:   # (the free one, else the oldest)
		if s[1] == null:
			slot = s
			break
		if float(s[1].t) < float(slot[1].t if slot[1] != null else INF):
			slot = s
	slot[1] = b
	(slot[0] as OmniLight3D).global_position = at
	(slot[0] as OmniLight3D).visible = true


## A bullet left a gun's mouth at `at`, flying along `dir`: a pinpoint flash (no smoke, no embers, no light) on the
## gun's mouth as it's drawn (`mouth`, while `shooter` lives; else riding on `carrier`, its bird's velocity), so it stays
## at the muzzle as the bird flies on, not left behind it.
func muzzle_flash(at: Vector3, dir: Vector3, carrier := Vector3.ZERO, mouth := Callable(), shooter: Object = null) -> void:
	var off := dir.normalized() * 0.03
	bursts.append({"pos": at + off, "off": off, "vel": carrier, "mouth": mouth, "shooter": shooter, "t": clock, "kind": Projectile.Kind.GUN, "why": "muzzle", "big": MUZZLE_BIG, "embers": [], "puffs": []})


## A hit at `at` knocked out `keys` from `bird`: those feathers fall from where they were, and a puff of down.
## `away`: from the burst toward the bird.
func knocked_out(bird: Bird, at: Vector3, keys: Array, away: Vector3) -> void:
	for key in keys:
		_loose(bird, int(key), away * _rng.randf_range(1.0, 2.5))
	var tint := Color(0.86, 0.84, 0.8)
	for i in 24:
		var v := (away * 0.6 + Vector3(_rng.randfn(), _rng.randfn() * 0.7 + 0.3, _rng.randfn()).normalized()) * _rng.randf_range(0.8, 3.0)
		down.append({"pos": at.lerp(bird.global_position, 0.6), "vel": bird.model.velocity * 0.3 + v, "t": clock, "size": _rng.randf_range(0.012, 0.028), "col": tint.darkened(_rng.randf_range(0.0, 0.25)), "spin": _rng.randf_range(-9.0, 9.0)})


## Feather `key` of `bird` comes away, flung by `kick` (m/s, world) on top of the bird's own motion.
func _loose(bird: Bird, key: int, kick: Vector3) -> void:
	var node := bird.rig.feather_copy(key)
	if node == null:
		return
	add_child(node)
	var xf := bird.rig.global_transform * bird.rig.feather_xforms[bird.rig.feather_keys.find(key)]
	node.global_transform = xf
	var ground := ArenaLayout.GROUND_Y
	loose.append({"layout": bird.layout, "node": node, "basis": xf.basis, "pos": xf.origin, "vel": bird.model.velocity * 0.5 + kick, "t": clock,
		"spin": _rng.randf_range(-5.0, 5.0), "rock": _rng.randf_range(5.0, 9.0), "phase": _rng.randf() * TAU, "landed": false, "ground": ground, "path": 0.0})
	while loose.size() > MAX_LOOSE:
		(loose.pop_front().node as Node).queue_free()


func step(dt: float, world: CombatWorld) -> void:
	for b in bursts:
		for e in b.embers:
			e[1] = (e[1] as Vector3) * exp(-2.2 * dt) + Vector3.DOWN * 9.8 * dt
			e[0] = (e[0] as Vector3) + (e[1] as Vector3) * dt
	# Loose feathers: air drag that brings the fall to FALL_SPEED, a side-slip back and forth across the feather's
	# own width, a tumble along its length; on the ground they lie still.
	var k := 9.8 / FALL_SPEED
	for f in loose:
		if f.landed:
			continue
		var age: float = clock - float(f.t)
		var bs: Basis = f.basis
		var across := bs.x.normalized()
		var slip := across * sin(age * float(f.rock) + float(f.phase)) * 0.9
		var v: Vector3 = Vector3.DOWN * FALL_SPEED + ((f.vel as Vector3) - Vector3.DOWN * FALL_SPEED) * exp(-k * dt)
		f.vel = v
		var step_v: Vector3 = v + slip
		f.pos = (f.pos as Vector3) + step_v * dt
		f.path = float(f.path) + (slip * dt).length()
		f.basis = bs.rotated(bs.z.normalized(), float(f.spin) * dt).rotated(across, cos(age * float(f.rock)) * 0.9 * dt)
		var under: float = float(f.ground) + ((f.layout as ArenaLayout).ground((f.pos as Vector3).x, (f.pos as Vector3).z) if f.layout != null else 0.0)
		if (f.pos as Vector3).y <= under + 0.005:   # (on the floor, its mounds and all)
			f.landed = true
			var p: Vector3 = f.pos
			f.pos = Vector3(p.x, under + 0.005, p.z)
			var z := (f.basis as Basis).z
			var flat := Vector3(z.x, 0.0, z.z)
			var len_z := z.length()
			flat = flat.normalized() * len_z if flat.length() > 1e-4 else Vector3(0, 0, len_z)
			var xx := (f.basis as Basis).x
			var lay_x := Vector3.UP.cross(flat).normalized() * xx.length()
			f.basis = Basis(lay_x, Vector3.UP * (f.basis as Basis).y.length(), flat)
	for d in down:
		d.vel = (d.vel as Vector3) * exp(-4.0 * dt) + Vector3.DOWN * 0.5 * dt
		d.pos = (d.pos as Vector3) + (d.vel as Vector3) * dt
	# Shedding: a badly damaged bird in flight now and then loses a covert.
	if world != null:
		for b in world.birds:
			if is_instance_valid(b) and (b as Bird).state == Bird.State.FLYING and (b as Bird).health() <= SHED_HEALTH and _rng.randf() < SHED_RATE * dt:
				_shed(b)
	bursts = bursts.filter(func(q): return clock - float(q.t) < (FLASH_TIME * 2.0 if q.why == "muzzle" else SMOKE_TIME))
	down = down.filter(func(q): return clock - float(q.t) < DOWN_TIME)
	var keep := []
	for f in loose:
		if clock - float(f.t) < FALL_LIFE:
			keep.append(f)
		else:
			(f.node as Node).queue_free()
	loose = keep


## A covert comes loose from `bird`'s more damaged wing and drifts off (it isn't one it loses: purely a look).
func _shed(bird: Bird) -> void:
	var side := 1 if bird.model.wing_loss.y >= bird.model.wing_loss.x else -1
	var picks := []
	for key in bird.rig.feather_keys:
		if BirdRig.feather_side(key) == side and floori((int(key) % 1000) / 100.0) == WingShape.Kind.GREATER_COVERT:
			picks.append(key)
	if picks.is_empty():
		return
	_loose(bird, int(picks[_rng.randi() % picks.size()]), -bird.model.velocity * 0.2 + Vector3.UP * 0.5)


## Loose feathers shed by `bird` (or any) so far, still falling or fallen: for tests.
func loose_count() -> int:
	return loose.size()


func draw(eye: Vector3, now: float, lag: float) -> void:
	for f in loose:
		var p: Vector3 = f.pos
		if not f.landed:
			p -= (f.vel as Vector3) * lag
		var node: Node3D = f.node
		node.global_transform = Transform3D(f.basis, p)
		var age: float = now - float(f.t)
		node.visible = age < FALL_LIFE
	# The lights: bright at once, gone in LIGHT_TIME.
	for s in _lights:
		var l: OmniLight3D = s[0]
		if s[1] == null:
			continue
		var age: float = now - float(s[1].t)
		var e := clampf(1.0 - age / LIGHT_TIME, 0.0, 1.0)
		l.light_energy = LIGHT_ENERGY * float(s[1].big) * e * e
		if age >= LIGHT_TIME:
			l.visible = false
			l.light_energy = 0.0
			s[1] = null
	_mesh.clear_surfaces()
	_soft.clear_surfaces()
	flashes_drawn.clear()
	var hot := false
	var soft := false
	for b in bursts:
		var age: float = now - float(b.t)
		if age < 0.0:
			continue
		var pos: Vector3 = b.pos + (b.get("vel", Vector3.ZERO) as Vector3) * age
		var mouth: Callable = b.get("mouth", Callable())
		if mouth.is_valid() and is_instance_valid(b.get("shooter")):
			pos = (mouth.call() as Vector3) + (b.off as Vector3)
		var big: float = b.big
		if b.why == "muzzle":
			flashes_drawn.append(pos)
		var to_eye := (eye - pos).normalized()
		var right := to_eye.cross(Vector3.UP).normalized()
		if right.length() < 0.1:
			right = Vector3.RIGHT
		var up := right.cross(to_eye).normalized()
		var fizzle: bool = b.why == "expired"
		# The flash.
		if age < FLASH_TIME * 2.0:
			var fk := clampf(1.0 - age / (FLASH_TIME * 2.0), 0.0, 1.0)
			var r := (0.12 if fizzle else 0.45) * big * (0.6 + 0.4 * fk)
			var core := Color(5.0, 4.0, 2.6, fk) if not fizzle else Color(1.4, 1.1, 0.8, fk * 0.6)
			if not hot:
				_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				hot = true
			_fan(_mesh, pos, right, up, r, core, Color(core.r * 0.5, core.g * 0.3, core.b * 0.1, 0.0))
		# Embers: streaks along their motion, cooling from yellow-white to red.
		for e in b.embers:
			var life: float = e[2]
			if age > life:
				continue
			var ek := age / life
			var ep: Vector3 = e[0]
			var ev: Vector3 = e[1]
			ep -= ev * lag
			var tail := ep - ev * 0.03
			var col := Color(1.9, 0.95, 0.3, 1.0).lerp(Color(0.9, 0.18, 0.04, 0.0), ek)   # (orange cooling to red; tone-mapped, more would go white)
			var w := (ev.cross(eye - ep)).normalized() * 0.012 * big
			if not hot:
				_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				hot = true
			CombatWorld._quad(_mesh, tail - w, tail + w, ep + w, ep - w, Color(col, 0.0), Color(col, 0.0), col, col)
		# The smoke: soft puffs swelling to the blast's reach, drifting up, thinning out.
		for q in b.puffs:
			var sk := clampf(age / SMOKE_TIME, 0.0, 1.0)
			var grow := 1.0 - exp(-age / 0.12)
			var r: float = CombatWorld.blast * float(q[2]) * big * (0.35 + 0.65 * grow + 0.25 * sk)
			var c: Vector3 = pos + (q[0] as Vector3) * (1.0 + 3.0 * grow) + (q[1] as Vector3) * age
			var a := 0.55 * (1.0 - sk) * (1.0 - sk) * clampf(age / 0.05, 0.0, 1.0)
			if not soft:
				_soft.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				soft = true
			_fan(_soft, c, right, up, r * 0.8, Color(0.22, 0.2, 0.18, a), Color(0.3, 0.27, 0.24, 0.0))
	# Down: small pale bits, spinning, thinning out.
	for d in down:
		var age: float = now - float(d.t)
		if age < 0.0:
			continue
		var p: Vector3 = (d.pos as Vector3) - (d.vel as Vector3) * lag
		var to_eye := (eye - p).normalized()
		var right := to_eye.cross(Vector3.UP).normalized()
		var up := right.cross(to_eye).normalized()
		var spin := float(d.spin) * age
		var ax := (right * cos(spin) + up * sin(spin)) * float(d.size)
		var ay := (up * cos(spin) - right * sin(spin)) * float(d.size) * 0.55
		var c: Color = d.col
		c.a = clampf(1.0 - age / DOWN_TIME, 0.0, 1.0) * 0.9
		if not soft:
			_soft.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			soft = true
		CombatWorld._quad(_soft, p - ax - ay, p + ax - ay, p + ax + ay, p - ax + ay, c, c, c, c)
	if hot:
		_mesh.surface_end()
	if soft:
		_soft.surface_end()


## A soft disc facing the camera: `inner` at the centre fading to `outer` at radius `r`.
static func _fan(m: ImmediateMesh, c: Vector3, right: Vector3, up: Vector3, r: float, inner: Color, outer: Color) -> void:
	var n := 14
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		m.surface_set_color(inner)
		m.surface_add_vertex(c)
		m.surface_set_color(outer)
		m.surface_add_vertex(c + (right * cos(a0) + up * sin(a0)) * r)
		m.surface_set_color(outer)
		m.surface_add_vertex(c + (right * cos(a1) + up * sin(a1)) * r)
