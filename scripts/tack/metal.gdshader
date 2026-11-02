// Metal (brass fittings, the launcher, rings and buckles; blued steel; nickel): fine machining lines along UV.x,
// tarnish that gathers in crevices and low places, verdigris deep in the crevices, polished where it's handled
// (wear), optional enamel paint chipped at the edges, soot (COLOR.a) at a muzzle, and a roundel pattern.
// Attributes as in leather.gdshader: UV real cm; UV2 (edge distance, along); COLOR (wear, cavity, seed, soot).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/tack/tack_noise.gdshaderinc"

uniform vec3 metal_col : source_color = vec3(0.88, 0.68, 0.36);    // brass
uniform vec3 tarnish_col : source_color = vec3(0.34, 0.24, 0.11);
uniform vec3 verdigris_col : source_color = vec3(0.36, 0.56, 0.46);
uniform float rough = 0.3;
uniform float tarnish = 0.55;
uniform float verdigris = 0.25;
uniform float brushed = 0.7;
uniform float line_pitch = 0.05;     // real cm between machining lines
uniform vec3 paint_col : source_color = vec3(0.3, 0.33, 0.2);
uniform float paint = 0.0;           // enamel over the metal (0 none .. 1 all), chipped
uniform float chip = 0.35;
uniform int pattern = 0;             // 1: a roundel on UV centred at 0 (radius roundel_r)
uniform float roundel_r = 1.2;

varying vec2 edge_uv;
varying vec4 masks;

void vertex() {
	edge_uv = UV2;
	masks = COLOR;
}

void fragment() {
	vec2 uv = UV;
	float fp = max(length(dFdx(uv)), length(dFdy(uv)));
	float wear = masks.r;
	float cav = masks.g;
	float m = tk_fbm(uv * 0.45 + masks.b * 13.0);
	float t = tarnish * clamp(0.25 + 0.5 * m + 0.6 * cav - 0.9 * wear, 0.0, 1.0);
	float v = verdigris * smoothstep(0.45, 0.9, cav + 0.35 * tk_fbm(uv * 2.2 + 3.0) - 0.4 * wear);
	vec3 col = mix(metal_col, tarnish_col, t);
	float met = 1.0;
	float lines = (tk_hash12(vec2(floor(uv.y / line_pitch), masks.b * 91.0)) - 0.5) * tk_keep(line_pitch * 3.0, fp);
	float r = rough + 0.28 * t + 0.1 * brushed * lines + 0.06 * (tk_fbm(uv * 0.9 + 7.0) - 0.5) - 0.12 * wear;
	col *= 1.0 + 0.06 * brushed * lines;
	col = mix(col, verdigris_col, v);
	met = mix(met, 0.15, v);
	r = mix(r, 0.85, v);
	if (paint > 0.0) {
		float ch = smoothstep(chip, chip + 0.06, tk_fbm(uv * 1.6 + 5.0) * (0.6 + 1.6 * (1.0 - smoothstep(0.0, 0.6, edge_uv.x))) + wear * 0.6 - 0.35);
		float pa = paint * (1.0 - ch);
		vec3 pc = paint_col * (0.9 + 0.2 * m);
		if (pattern == 1) {
			float rr = length(uv) / roundel_r;
			pc = rr > 1.0 ? paint_col : (rr > 0.66 ? vec3(0.08, 0.16, 0.42) : (rr > 0.36 ? vec3(0.86, 0.84, 0.78) : vec3(0.62, 0.08, 0.06)));
		}
		col = mix(col, pc, pa);
		met = mix(met, 0.0, pa);
		r = mix(r, 0.42 + 0.1 * m, pa);
	}
	float soot = masks.a * (0.6 + 0.4 * m);
	col = mix(col, vec3(0.03, 0.025, 0.02), soot);
	met = mix(met, 0.2, soot);
	r = mix(r, 0.9, soot);
	ALBEDO = col * (1.0 - 0.35 * cav);
	METALLIC = met;
	ROUGHNESS = clamp(r, 0.08, 0.95);
	AO = 1.0 - 0.5 * cav;
}
