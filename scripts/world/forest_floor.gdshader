// The pine wood's floor: needle litter (warm brown, streaked with fallen needles at mm scale), moss in patches
// (greener, softer), bare darker earth in places, all in world metres (the ground plane), the fine detail fading
// with distance so it doesn't shimmer; far off it settles to an even olive-brown.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 litter : source_color = vec3(0.27, 0.22, 0.16);
uniform vec3 litter_hi : source_color = vec3(0.4, 0.33, 0.24);
uniform vec3 moss : source_color = vec3(0.24, 0.3, 0.13);
uniform vec3 earth : source_color = vec3(0.17, 0.14, 0.11);
// The photoscan of pine-needle litter (assets/LICENSES.md), when given: the base, at `scan_tile` m, sampled at two
// scales and rotations blended by noise so its 2 m repeat doesn't show from the air.
uniform bool use_scan = false;
uniform sampler2D scan_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scan_tile = 2.0;
uniform vec3 scan_tint : source_color = vec3(1.0);
// Past the wood's edge the litter gives way to heath (EdgeBuilder; heath.gdshaderinc), from heath_from to heath_to
// m out from the middle, raggedly.
uniform bool heath_on = false;
uniform float heath_from = 84.0;
uniform float heath_to = 98.0;

#include "res://scripts/world/heath.gdshaderinc"

varying vec2 wxz;

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

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + 1.7;
		a *= 0.5;
	}
	return s;
}

// Fallen needles: thin streaks in random directions per cell (cm scale).
float needles(vec2 p) {
	vec2 c = floor(p);
	float m = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = c + vec2(float(x), float(y));
			float a = hash12(g) * 6.283;
			vec2 o = g + vec2(hash12(g + 7.0), hash12(g + 13.0));
			vec2 d = p - o;
			vec2 dir = vec2(cos(a), sin(a));
			float along = dot(d, dir);
			float across = abs(dot(d, vec2(-dir.y, dir.x)));
			m = max(m, (1.0 - smoothstep(0.02, 0.05, across)) * (1.0 - smoothstep(0.4, 0.55, abs(along))));
		}
	}
	return m;
}

void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = wxz;
	float fp = length(fwidth(p));
	float big = fbm(p * 0.08);
	float mid = fbm(p * 0.6 + 3.0);
	float moss_m = smoothstep(0.52, 0.68, big * 0.7 + mid * 0.45);
	float earth_m = smoothstep(0.62, 0.78, fbm(p * 0.25 + 9.0)) * (1.0 - moss_m);
	vec3 col = mix(litter, litter_hi, smoothstep(0.3, 0.8, mid));
	float keep = 1.0 - smoothstep(0.004, 0.02, fp);
	float nd = needles(p * 18.0) * keep;
	col = mix(col, litter_hi * 1.15, nd * 0.6 * (1.0 - moss_m));
	vec3 scan_n = vec3(0.5, 0.5, 1.0);
	float scan_r = 0.9;
	if (use_scan) {
		vec2 u1 = p / scan_tile;
		vec2 u2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p / (scan_tile * 1.37) + 0.37;
		float w = smoothstep(0.35, 0.65, fbm(p * 0.15 + 11.0));
		col = mix(texture(scan_albedo, u1).rgb, texture(scan_albedo, u2).rgb, w) * scan_tint * (0.85 + 0.3 * big);
		scan_n = mix(texture(scan_normal, u1).rgb, texture(scan_normal, u2).rgb, w);
		scan_r = mix(texture(scan_arm, u1).g, texture(scan_arm, u2).g, w);
		nd = 0.0;
	}
	col = mix(col, moss * (0.85 + 0.3 * fbm(p * 4.0)), moss_m);
	col = mix(col, earth, earth_m * 0.7);
	col *= 0.9 + 0.2 * fbm(p * 2.5 + 5.0);
	float heath_k = 0.0;
	if (heath_on) {
		heath_k = smoothstep(heath_from, heath_to, length(p) + (big - 0.5) * 16.0 + (mid - 0.5) * 4.0);
		col = mix(col, heath_albedo(p), heath_k);
	}
	ALBEDO = col;
	ROUGHNESS = mix(mix(use_scan ? scan_r : 0.95, 0.85, moss_m), 0.95, heath_k);
	SPECULAR = 0.25;
	// Relief: the needle streaks and the moss's lumps, as a normal.
	float e = 0.01;
	float h0 = mid * 0.4 + nd * 0.3;
	float hx = fbm((p + vec2(e, 0.0)) * 0.6 + 3.0) * 0.4 + needles((p + vec2(e, 0.0)) * 18.0) * keep * 0.3;
	float hy = fbm((p + vec2(0.0, e)) * 0.6 + 3.0) * 0.4 + needles((p + vec2(0.0, e)) * 18.0) * keep * 0.3;
	vec3 pn = normalize(vec3((h0 - hx) / e * 0.02, (h0 - hy) / e * 0.02, 1.0));
	NORMAL_MAP = mix(use_scan ? mix(scan_n, pn * 0.5 + 0.5, moss_m) : pn * 0.5 + 0.5, vec3(0.5, 0.5, 1.0), heath_k * 0.7);
}
