// Cloth (the rider's breeches and tunic, the silk scarf, sheepskin on the collar and under the saddle):
//   weave 0  wool twill: diagonal ribs, matte, a soft fuzz at grazing angles;
//   weave 1  silk: fine plain weave, smooth, a sheen that runs along the cloth (anisotropic);
//   weave 2  fleece: curly clumps, deep between them, very soft.
// Seams (seam_row > 0): a stitched seam in from each edge, as in leather.gdshader. Attributes as there.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/tack/tack_noise.gdshaderinc"

uniform vec3 col : source_color = vec3(0.55, 0.5, 0.36);
uniform vec3 dark_col : source_color = vec3(0.3, 0.26, 0.18);
uniform int weave = 0;
uniform float pitch = 0.25;          // real cm, the weave's (or the clumps') size
uniform float rough = 0.85;
uniform float fuzz = 0.45;
uniform float seam_row = 0.0;
uniform float bump = 1.0;

varying vec2 edge_uv;
varying vec4 masks;

void vertex() {
	edge_uv = UV2;
	masks = COLOR;
}

float height(vec2 uv, float k) {
	if (weave == 0) {
		float rib = 0.5 + 0.5 * sin(TAU * (uv.x + uv.y) / pitch);
		float thread = 0.5 + 0.5 * sin(TAU * (uv.x - uv.y) / (pitch * 0.5));
		return k * 0.02 * (rib * 0.8 + thread * 0.2);
	} else if (weave == 1) {
		float a = 0.5 + 0.5 * sin(TAU * uv.x / pitch);
		float b = 0.5 + 0.5 * sin(TAU * uv.y / pitch);
		return k * 0.006 * a * b;
	}
	vec2 c = tk_cells(uv / pitch + masks.b * 19.0);
	float curl = tk_noise(uv / pitch * 3.0);
	return k * 0.12 * (smoothstep(0.0, 0.5, c.y - c.x) * 0.8 + 0.2 * curl);
}

void fragment() {
	vec2 uv = UV;
	float fp = max(length(dFdx(uv)), length(dFdy(uv)));
	float k = tk_keep(pitch, fp);
	float m = tk_fbm(uv * 0.3 + masks.b * 11.0);
	float h0 = height(uv, k);
	float e = max(pitch * 0.1, fp * 0.5);
	float hx = height(uv + vec2(e, 0.0), k);
	float hy = height(uv + vec2(0.0, e), k);
	vec3 n = normalize(vec3(-(hx - h0) / e * bump, -(hy - h0) / e * bump, 1.0));
	float shade = weave == 2 ? h0 / max(0.12 * k, 1e-4) : h0 / max(0.02 * k, 1e-4);
	vec3 c = col * (0.92 + 0.16 * m);
	c = mix(mix(dark_col, c, 0.75 + 0.25 * shade), c, 1.0 - k);
	c *= 1.0 - 0.5 * masks.g;
	c = mix(c, dark_col, 0.35 * masks.r);   // (cloth wear: grime where it's handled)
	if (seam_row > 0.0) {
		float d = abs(edge_uv.x - seam_row);
		float on = step(fract(edge_uv.y / 0.35), 0.6);
		c = mix(c, dark_col, (1.0 - smoothstep(0.03, 0.08, d)) * mix(0.5, on, k));
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = weave == 1 ? 0.5 : 0.3;
	NORMAL_MAP = n * 0.5 + 0.5;
	AO = 1.0 - 0.6 * masks.g;
	RIM = fuzz;
	RIM_TINT = weave == 1 ? 0.2 : 0.7;
	if (weave == 1) {
		ANISOTROPY = 0.55;
		ANISOTROPY_FLOW = vec2(1.0, 0.0);
	}
}
