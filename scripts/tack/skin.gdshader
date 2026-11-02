// Skin (the rider's face, neck, eyelids): a weathered pilot's face -- warm base tone, flushed cheeks, nose and
// lips, darker in the creases and round the eyes, a day's stubble on the jaw and upper lip, fine pores, oilier
// (glossier) down the nose and on the lips, a little light through it. Attributes (Rider, HeadShape):
// UV real cm over the surface; COLOR (r flush, g cavity, b seed, a stubble).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/tack/tack_noise.gdshaderinc"

uniform vec3 base_col : source_color = vec3(0.8, 0.58, 0.46);
uniform vec3 flush_col : source_color = vec3(0.76, 0.42, 0.36);
uniform vec3 lip_col : source_color = vec3(0.66, 0.36, 0.33);
uniform vec3 crease_col : source_color = vec3(0.5, 0.32, 0.27);
uniform vec3 stubble_col : source_color = vec3(0.36, 0.3, 0.28);
uniform float rough = 0.55;
uniform float pore = 0.09;      // real cm
uniform float backlight = 0.3;   // light through thin parts (no SSS_STRENGTH: screen-space scattering streaks at this scale)

varying vec4 masks;

void vertex() {
	masks = COLOR;
}

float height(vec2 uv, float kp, float kh) {
	float h = 0.0;
	vec2 c = tk_cells(uv / pore + masks.b * 13.0);
	h -= kp * 0.004 * (1.0 - smoothstep(0.0, 0.25, c.x));          // pores
	h += kp * 0.003 * tk_noise(uv / (pore * 0.6));                  // fine bumps
	h -= kh * 0.006 * masks.a * smoothstep(0.55, 0.85, tk_noise(uv / 0.045 + 7.0));   // stubble's dots
	return h;
}

void fragment() {
	vec2 uv = UV;
	float fp = max(length(dFdx(uv)), length(dFdy(uv)));
	float kp = tk_keep(pore, fp);
	float kh = tk_keep(0.05, fp);
	float flush = masks.r;
	float cav = masks.g;
	float stub = masks.a;
	float m = tk_fbm(uv * 0.6 + masks.b * 5.0);
	vec3 col = base_col * (0.95 + 0.1 * m);
	col = mix(col, flush_col, clamp(flush, 0.0, 1.0) * (0.75 + 0.25 * m));
	float lip = smoothstep(0.75, 1.0, flush);
	col = mix(col, lip_col, lip);
	// Freckles and blotches, faint.
	float fr = smoothstep(0.72, 0.9, tk_noise(uv / 0.18 + 3.0)) * kp;
	col = mix(col, col * vec3(0.86, 0.76, 0.7), 0.35 * fr);
	// Stubble: up close the hairs' dots, far off a blue-grey shadow.
	float dots = smoothstep(0.55, 0.85, tk_noise(uv / 0.045 + 7.0));
	col = mix(col, stubble_col, stub * mix(0.32, 0.25 + 0.6 * dots, kh));
	col = mix(col, crease_col, cav * 0.8);
	ALBEDO = col;
	ROUGHNESS = clamp(rough - 0.18 * lip - 0.08 * (flush - lip) + 0.15 * stub + 0.06 * (m - 0.5), 0.25, 0.85);
	SPECULAR = 0.4;
	float e = max(pore * 0.2, fp * 0.5);
	float h0 = height(uv, kp, kh);
	float hx = height(uv + vec2(e, 0.0), kp, kh);
	float hy = height(uv + vec2(0.0, e), kp, kh);
	NORMAL_MAP = normalize(vec3(-(hx - h0) / e, -(hy - h0) / e, 1.0)) * 0.5 + 0.5;
	AO = 1.0 - 0.5 * cav;
	BACKLIGHT = vec3(0.35, 0.12, 0.08) * backlight;
}
