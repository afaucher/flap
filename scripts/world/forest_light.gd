class_name ForestLight
extends RefCounted
## The pine wood's light (docs/design/concept_briefs.html, round four's outpost): a summer afternoon -- a low,
## warm sun raking through the trunks with soft-edged shadows, a blue sky, haze that turns the far trees
## blue-gold and shows the sun's shafts, bright highlights rolling off gently (AgX).
##   sun      ~30 deg up, golden; soft shadows (0.5 deg of angular size) in four cascades, the first tight
##            round the camera (the bird a few metres ahead) out to 160 m
##   sky      physical sky (Rayleigh blue, a little Mie glow round the sun); ambient from it
##   haze     volumetric fog, scattering forward (shafts toward the sun), over exponential depth fog with
##            sun scatter for the distance
##   GI       SDFGI off by default: in this open wood it barely shows (A/B, Nov 2026); SSAO for contact darkening
## Returns the sun.

const SUN_ELEVATION := 30.0
const SUN_AZIMUTH := 205.0     ## deg, round +Y from -Z


static func setup(parent: Node, gi := false) -> DirectionalLight3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := PhysicalSkyMaterial.new()
	sm.rayleigh_coefficient = 2.2
	sm.mie_coefficient = 0.008
	sm.mie_eccentricity = 0.85
	sm.turbidity = 8.0
	sm.sun_disk_scale = 1.0
	sm.ground_color = Color(0.32, 0.3, 0.22)
	sm.energy_multiplier = 1.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.4
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.sdfgi_enabled = gi
	env.sdfgi_cascades = 4
	env.sdfgi_use_occlusion = true
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_energy = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.92, 0.86, 0.74)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.2
	env.volumetric_fog_sky_affect = 0.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.7, 0.78)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.55
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-SUN_ELEVATION, SUN_AZIMUTH, 0.0)
	sun.light_color = Color(1.0, 0.85, 0.64)
	sun.light_energy = 2.4
	sun.light_angular_distance = 0.5
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_split_1 = 0.04
	sun.directional_shadow_split_2 = 0.14
	sun.directional_shadow_split_3 = 0.4
	sun.directional_shadow_blend_splits = true
	sun.shadow_normal_bias = 1.2
	sun.shadow_bias = 0.03
	parent.add_child(sun)
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	return sun
