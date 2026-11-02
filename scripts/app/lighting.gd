class_name Lighting
extends RefCounted
## Light for looking at the birds (rig gallery, landing reel); the game's own (Game.add_environment) shares
## the bird-scale shadow and occlusion settings. A bird is small: its feather rows and the wing over the body
## need shadows a few millimetres sharp and ambient occlusion with a radius of centimetres, not metres.
##   studio  sky ambient (a soft blue sky above, a warm ground below, so tops and undersides differ) and a weak
##           ground bounce, a sun with shadows (the wing shades the flank, rows the row behind; the flight feathers'
##           translucency reads its shadow map), small-radius SSAO. About +1.4 ms GPU at 1600x900 over flat.
##   flat    the old look: one ambient colour, no shadows (for A/B)

const BACKGROUND := Color(0.82, 0.85, 0.83)


## Lights and environment under `parent`. `back`: the sun low behind the bird, toward the camera (translucency).
static func studio(parent: Node, mode := "studio", back := false) -> DirectionalLight3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	if mode == "flat":
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.78, 0.8)
		env.ambient_light_energy = 0.7
	else:
		env.sky = Sky.new()
		env.sky.sky_material = sky_material()
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.ambient_light_energy = 0.9
		bird_occlusion(env, 1.0)
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0) if not back else Vector3(-25, 10, 0)
	sun.light_energy = 1.2
	if mode != "flat":
		sun.light_color = Color(1.0, 0.97, 0.92)
		bird_shadows(sun, 6.0)
	parent.add_child(sun)
	var bounce := DirectionalLight3D.new()   # light off the ground, so undersides read (no shadows)
	bounce.rotation_degrees = Vector3(70, 20, 0)
	bounce.light_energy = 0.35 if mode == "flat" else 0.25
	bounce.light_color = Color(0.95, 0.92, 0.85)
	parent.add_child(bounce)
	return sun


## A soft daytime sky: blue above, pale at the horizon, a warm green-brown ground below (the bounce under a bird).
static func sky_material() -> ProceduralSkyMaterial:
	var m := ProceduralSkyMaterial.new()
	m.sky_top_color = Color(0.45, 0.6, 0.8)
	m.sky_horizon_color = Color(0.78, 0.82, 0.85)
	m.ground_horizon_color = Color(0.78, 0.82, 0.85)
	m.ground_bottom_color = Color(0.5, 0.48, 0.38)
	return m


## Sun shadows fine enough for feathers on a bird near the camera: the first cascade only a few metres deep.
## `reach`: the shadow distance (m); `near`: the first cascade's depth (m), past the bird the camera follows.
static func bird_shadows(sun: DirectionalLight3D, reach: float, near := 1.0) -> void:
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = reach
	sun.directional_shadow_split_1 = minf(near / reach, 0.15)   # (the first cascade: the bird in front of the camera)
	sun.directional_shadow_split_2 = minf(near * 4.0 / reach, 0.35)
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.6
	sun.shadow_blur = 0.6


## Ambient occlusion at a bird's scale: the wing's root, between the rows, under the tail. `k` scales its strength.
static func bird_occlusion(env: Environment, k: float, radius := 0.08) -> void:
	env.ssao_enabled = true
	env.ssao_radius = radius
	env.ssao_intensity = 1.6 * k
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
