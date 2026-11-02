// Bark for the pine wood's trunks and limbs (ArenaBuilder, Pinewood): photoscanned bark (assets/LICENSES.md) on
// a tapered cylinder, laid on in metres -- round the trunk a whole number of tiles (no seam), up it by height
// -- with, per instance (MultiMesh custom data): x radius (m), y height or length (m), z a seed, w the top's
// radius as a share of the bottom's.
//   two barks  A low (the plated bark of an old pine's lower trunk), B high (the thin, flaky, orange bark of
//              its crown), blended by height through a ragged band where B shows in A's fissures first
//              (A's displacement); `b_only` for limbs.
//   detail     a fine procedural grain (cm) close up, fading with distance (no shimmer), so the 2 m photo isn't
//              a blur from a bird's-eye a few cm off
//   variation  slow tint noise up the trunk and a tint per tree (the seed), so trunks don't repeat
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_a : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D disp_a : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float tile_a = 2.0;                       // m the photo spans (across)
uniform float aspect_a = 1.0;                     // its height over its width
uniform sampler2D albedo_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_b : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_b = 1.7;
uniform float aspect_b = 1.0;
uniform vec3 tint_a : source_color = vec3(1.0);
uniform vec3 tint_b : source_color = vec3(1.0);   // B recoloured (the upper bark's orange)
uniform float blend_lo = 0.5;                     // of the height: A below, B above
uniform float blend_hi = 0.75;
uniform bool b_only = false;
uniform float normal_depth = 1.2;
uniform float detail_scale = 0.03;                // m, the grain
uniform float detail_depth = 0.35;
uniform float tint_var = 0.12;

varying vec2 m_uv;       // (round, up) in metres
varying float h_frac;
varying float seed;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float r = INSTANCE_CUSTOM.x;
	float h = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.z;
	h_frac = VERTEX.y + 0.5;
	// Round the trunk: a whole number of A tiles at the base (so the wrap meets itself), in metres.
	float tile = b_only ? tile_b : tile_a;
	float around = max(1.0, round(TAU * r / tile)) * tile;
	m_uv = vec2(UV.x * around, h_frac * h);
}

void fragment() {
	vec2 off = vec2(seed * 13.7, seed * 71.3);
	vec2 ua = (m_uv + off) / vec2(tile_a, tile_a * aspect_a);
	vec2 ub = (m_uv + off.yx) / vec2(tile_b, tile_b * aspect_b);
	// How much of B: by height, ragged by noise, into A's fissures first.
	float dA = texture(disp_a, ua).r;
	float n = vnoise(m_uv * vec2(0.6, 0.25) + seed * 5.0);
	float t = b_only ? 1.0 : smoothstep(blend_lo, blend_hi, h_frac + (n - 0.5) * 0.18);
	float wb = b_only ? 1.0 : clamp((t * 1.6 - dA) * 3.0 + t * 0.6 - 0.3, 0.0, 1.0);
	vec3 ca = texture(albedo_a, ua).rgb * tint_a;
	vec3 cb = texture(albedo_b, ub).rgb * tint_b;
	vec3 na = texture(normal_a, ua).rgb;
	vec3 nb = texture(normal_b, ub).rgb;
	vec3 ma = texture(arm_a, ua).rgb;
	vec3 mb = texture(arm_b, ub).rgb;
	vec3 col = mix(ca, cb, wb);
	vec3 nm = mix(na, nb, wb);
	vec3 arm = mix(ma, mb, wb);
	// Variation: slow noise up the trunk, a tint per tree.
	float slow = vnoise(m_uv * vec2(0.35, 0.12) + 17.0 + seed * 3.0);
	col *= 1.0 + tint_var * ((slow - 0.5) * 1.4 + (fract(seed * 7.31) - 0.5));
	// Detail: a fine grain normal close up, gone by the time it would alias.
	float fp = length(fwidth(m_uv));
	float keep = 1.0 - smoothstep(detail_scale * 0.15, detail_scale * 0.6, fp);
	vec2 dp = m_uv / detail_scale;
	float e = 0.35;
	float g0 = vnoise(dp * vec2(1.0, 0.35));
	float gx = vnoise((dp + vec2(e, 0.0)) * vec2(1.0, 0.35));
	float gy = vnoise((dp + vec2(0.0, e)) * vec2(1.0, 0.35));
	vec2 dn = vec2(g0 - gx, g0 - gy) / e * detail_depth * keep;
	vec3 nn = nm * 2.0 - 1.0;
	nn.xy = nn.xy * normal_depth + dn;
	ALBEDO = col;
	ROUGHNESS = clamp(arm.g * 1.05, 0.4, 1.0);
	METALLIC = 0.0;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.3;
	NORMAL_MAP = normalize(nn) * 0.5 + 0.5;
}
