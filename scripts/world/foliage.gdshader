// Foliage cards (ArenaBuilder's crowns, saplings and ferns; textures from FoliageTex): alpha-tested, two-sided,
// lit as part of a rounded clump -- the normal bent out from the clump's middle (INSTANCE_CUSTOM.xyz, world) so
// a crown shades like a mass, not like a pile of flat cards -- light through the leaves (BACKLIGHT), a tint per
// card (COLOR), and wind: the clump sways, the card flutters (phase INSTANCE_CUSTOM.w). Alpha keeps its coverage
// down the mips so far crowns don't thin to nothing. `bend` > 0 arches a frond (ferns: the card's v from base 1
// to tip 0, drooping toward its back).
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float tex_size = 512.0;
uniform float scissor = 0.45;
uniform float boost = 0.22;          // alpha gained per mip level down (coverage kept at a distance)
uniform vec3 tint : source_color = vec3(1.0);
uniform float backlight = 0.55;
uniform float clump_normal = 0.75;   // 0 the card's own normal .. 1 out from the clump's middle
uniform float sway = 0.05;           // m
uniform float flutter = 0.02;
uniform float bend = 0.0;            // ferns: how far the tip droops, of the frond's length

varying vec3 clump_n;

void vertex() {
	vec3 centre = INSTANCE_CUSTOM.xyz;
	float phase = INSTANCE_CUSTOM.w;
	if (bend > 0.0) {
		float t = 1.0 - UV.y;   // base 0 .. tip 1
		VERTEX.z -= bend * t * t;
		VERTEX.y -= bend * 0.35 * t * t;
	}
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 1.1 + phase * 6.283 + wp.x * 0.07) + 0.4 * sin(TIME * 2.3 + phase * 11.0 + wp.z * 0.11);
	float f = sin(TIME * 5.7 + phase * 37.0 + wp.y * 3.0);
	wp += vec3(0.8, 0.0, 0.5) * s * sway + vec3(0.0, 1.0, 0.0) * f * flutter * (1.0 - UV.x * 0.5);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
	clump_n = normalize(wp - centre + vec3(0.0, 0.15, 0.0));
}

void fragment() {
	vec4 t = texture(tex, UV);
	// Keep coverage down the mips: mipped alpha averages toward 0 at the thin needles' edges.
	vec2 px = UV * tex_size;
	float lod = max(0.0, log2(max(length(dFdx(px)), length(dFdy(px)))));
	float a = t.a * (1.0 + lod * boost);
	ALBEDO = t.rgb * tint * COLOR.rgb;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
	vec3 cn = normalize((VIEW_MATRIX * vec4(clump_n, 0.0)).xyz);
	vec3 own = FRONT_FACING ? NORMAL : -NORMAL;
	NORMAL = normalize(mix(own, cn, clump_normal));
	ROUGHNESS = 0.72;
	SPECULAR = 0.3;
	BACKLIGHT = ALBEDO * backlight;
}
