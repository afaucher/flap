class_name AirFx
extends Node3D
## What shows the rising air (drawn only): seed fluff and dust carried up each thermal (AirField), drifting round as it
## climbs and thinning out toward the top; up a ridge's face, the same along its edge. Enough to find a thermal
## from close by, and to see it working when circling in it.

const FLUFF_SIZE := 0.22      ## m across, a mote (a seed head, lit: it has to show against the haze)
const PER_M2 := 0.9          ## motes in the air per m^2 of a thermal's floor (its core's)


func build(air: AirField) -> void:
	for th in air.thermals:
		var r: float = th.radius
		var top: float = th.top
		var lift: float = th.lift
		var p := _motes(int(clampf(PI * r * r * PER_M2, 60.0, 900.0)), (top - AirField.THERMAL_FLOOR.x) / maxf(lift * 0.8, 0.3))
		var m := p.process_material as ParticleProcessMaterial
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		m.emission_ring_axis = Vector3.UP
		m.emission_ring_radius = r * 0.7
		m.emission_ring_inner_radius = 0.0
		m.emission_ring_height = 2.0
		m.direction = Vector3.UP
		m.initial_velocity_min = lift * 0.6
		m.initial_velocity_max = lift * 0.9
		m.orbit_velocity_min = 0.01
		m.orbit_velocity_max = 0.03
		p.position = Vector3(th.centre.x, ArenaLayout.GROUND_Y + AirField.THERMAL_FLOOR.x, th.centre.y)
		p.visibility_aabb = AABB(Vector3(-r * 1.2, -2.0, -r * 1.2), Vector3(r * 2.4, top + 4.0, r * 2.4))
		p.name = "Thermal%d" % get_child_count()
		add_child(p)
	for rd in air.ridges:
		var a: Vector3 = rd.a
		var b: Vector3 = rd.b
		var h: float = rd.height
		var len := a.distance_to(b)
		var p := _motes(int(clampf(len * h * 0.25, 40.0, 700.0)), 2.0 * h / maxf(float(rd.lift) * 0.8, 0.3))
		var m := p.process_material as ParticleProcessMaterial
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(len * 0.5, h * 0.3, h * 0.25)
		m.direction = Vector3.UP
		m.initial_velocity_min = float(rd.lift) * 0.6
		m.initial_velocity_max = float(rd.lift) * 0.9
		var out: Vector3 = rd.out
		p.basis = Basis.looking_at(-out, Vector3.UP) * Basis(Vector3.UP, PI * 0.5)
		p.position = (a + b) * 0.5 + out * h * 0.25 - Vector3.UP * h * 0.3
		p.visibility_aabb = AABB(Vector3(-len, -h, -h * 2.0), Vector3(len * 2.0, h * 4.0, h * 4.0))
		p.name = "Ridge%d" % get_child_count()
		add_child(p)


## Motes: `n` of them, each `life` s, soft round fluff lit by the sun, fading in at the floor and out up high.
static func _motes(n: int, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.preprocess = life   # (the column full from the start)
	p.fixed_fps = 30
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 6.0
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.15
	m.scale_min = 0.6
	m.scale_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(FLUFF_SIZE, FLUFF_SIZE)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.96, 0.86, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # (sunlit fluff glints whichever way it's seen)
	var dot := Gradient.new()
	dot.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var dt := GradientTexture2D.new()
	dt.gradient = dot
	dt.fill = GradientTexture2D.FILL_RADIAL
	dt.fill_from = Vector2(0.5, 0.5)
	dt.fill_to = Vector2(1.0, 0.5)
	dt.width = 32
	dt.height = 32
	mat.albedo_texture = dt
	quad.material = mat
	p.draw_pass_1 = quad
	return p
