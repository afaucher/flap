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
##   far blur a slight softening of the far wood only (depth of field, far side: from FAR_BLUR_FROM, nothing nearer,
##            so the bird, its rider and the trees you fly among stay sharp); `far_blur` false (--no-far-blur) or
##            F5 in the game and the range turns it off
## Returns the sun.

const SUN_ELEVATION := 30.0
const SUN_AZIMUTH := 205.0     ## deg, round +Y from -Z
const FAR_BLUR_FROM := 45.0    ## m: nothing nearer is blurred
const FAR_BLUR_OVER := 45.0    ## m over which it fades in (full by ~90 m: the arena's edge)
const FAR_BLUR_AMOUNT := 0.035 ## Godot's dof amount (its default 0.1 is a strong photographic blur)
static var far_blur := true


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
	env.ambient_light_energy = 0.36
	env.ambient_light_sky_contribution = 0.7   # (the rest a warm bounce off the needle litter: shadows warm, not blue)
	env.ambient_light_color = Color(0.56, 0.48, 0.38)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true   # (AgX rolls bright colour toward white: give the warmth back)
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.08
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
	env.volumetric_fog_density = 0.003
	env.volumetric_fog_albedo = Color(1.0, 0.93, 0.8)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.2
	env.volumetric_fog_sky_affect = 0.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.72, 0.66)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.6
	env.fog_density = 0.0011
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	var cam := CameraAttributesPractical.new()
	cam.dof_blur_far_enabled = far_blur
	cam.dof_blur_far_distance = FAR_BLUR_FROM
	cam.dof_blur_far_transition = FAR_BLUR_OVER
	cam.dof_blur_amount = FAR_BLUR_AMOUNT
	we.camera_attributes = cam
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-SUN_ELEVATION, SUN_AZIMUTH, 0.0)
	sun.light_color = Color(1.0, 0.8, 0.57)
	sun.light_energy = 3.0
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


## The far blur on or off for the world `node` is in (F5). Returns whether it's on now.
static func toggle_far_blur(node: Node) -> bool:
	var a := node.get_viewport().world_3d.camera_attributes as CameraAttributesPractical
	if a == null:
		return false
	a.dof_blur_far_enabled = not a.dof_blur_far_enabled
	far_blur = a.dof_blur_far_enabled
	return far_blur
