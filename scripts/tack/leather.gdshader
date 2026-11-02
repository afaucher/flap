// Leather (saddle, straps, helmet, jacket, boots): vegetable-tanned hide with a pebbled grain, a mottled
// tone, burnished edges, a saddle-stitched row in from each edge, optional diamond quilting, and wear: rubbed
// high spots go lighter and smoother. Attributes (TackMesh): UV (along, across) real cm; UV2 (edge distance,
// along the edge) real cm; COLOR (wear, cavity, seed). Fine detail fades out where it would be smaller than a
// pixel or two (tk_keep), so the tack doesn't shimmer at game distance.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/tack/tack_noise.gdshaderinc"

uniform vec3 base_col : source_color = vec3(0.45, 0.27, 0.14);
uniform vec3 dark_col : source_color = vec3(0.16, 0.08, 0.04);    // creases, burnished edges, crevices
uniform vec3 worn_col : source_color = vec3(0.66, 0.46, 0.28);    // rubbed through the finish
uniform vec3 thread_col : source_color = vec3(0.86, 0.78, 0.58);  // waxed linen
uniform float grain = 0.22;          // real cm, pebble size
uniform float grain_depth = 1.0;
uniform float mottle = 0.4;
uniform float tone_var = 0.15;       // per-piece tone (COLOR.b)
uniform float rough = 0.58;
uniform float gloss_worn = 0.25;     // how much smoother the worn parts are
uniform float stitch_row = 0.4;      // real cm in from the edge (0: no stitching)
uniform float stitch_pitch = 0.7;
uniform float stitch_len = 0.62;     // share of the pitch the thread shows
uniform float stitch_w = 0.11;
uniform float edge_band = 0.22;      // burnished edge
uniform float quilt = 0.0;           // diamond quilting pitch (real cm; 0: none), where COLOR.a says
uniform float sheen = 0.18;
uniform float bump = 1.0;

varying vec2 edge_uv;
varying vec4 masks;

void vertex() {
	edge_uv = UV2;
	masks = COLOR;
}

// Height (real cm) of the surface detail at (uv, edge distance, along edge); `keep` fades each layer.
float height(vec2 uv, vec2 eu, float kg, float ks) {
	float h = 0.0;
	vec2 c = tk_cells(uv / grain + masks.b * 31.0);
	h += kg * grain_depth * 0.035 * smoothstep(0.0, 0.3, c.y - c.x);
	if (quilt > 0.0) {
		float qa = abs(fract((uv.x + uv.y) / quilt) - 0.5);
		float qb = abs(fract((uv.x - uv.y) / quilt) - 0.5);
		float q = min(qa, qb) * 2.0;   // 0 on a quilting line .. 1 at a puff's middle
		h += masks.a * (0.22 * sqrt(clamp(q, 0.0, 1.0)) - 0.05);
	}
	if (stitch_row > 0.0) {
		float d = abs(eu.x - stitch_row);
		h -= ks * 0.06 * (1.0 - smoothstep(0.0, stitch_w * 1.4, d));   // the groove the stitches lie in
		float ph = fract(eu.y / stitch_pitch);
		float on = smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(stitch_len - 0.08, stitch_len, ph));
		h += ks * 0.07 * on * (1.0 - smoothstep(0.0, stitch_w, d)) * sqrt(max(1.0 - d / stitch_w, 0.0));
	}
	float rollw = edge_band * 0.6;
	h -= 0.05 * (1.0 - smoothstep(0.0, rollw, eu.x));   // the edge is rounded and pressed down
	return h;
}

void fragment() {
	vec2 uv = UV;
	float fp = max(length(dFdx(uv)), length(dFdy(uv)));
	float kg = tk_keep(grain, fp);
	float ks = tk_keep(stitch_pitch * 0.5, fp);
	float wear = masks.r;
	float cav = masks.g;
	// Colour: mottled hide, a tone per piece, creases darker, rubbed high spots lighter.
	float m = tk_fbm(uv * 0.35 + masks.b * 17.0);
	vec3 col = base_col * (1.0 + tone_var * (masks.b - 0.5) * 2.0);
	col = mix(col, dark_col, mottle * smoothstep(0.35, 0.85, m));
	vec2 c = tk_cells(uv / grain + masks.b * 31.0);
	float crease = (1.0 - smoothstep(0.0, 0.12, c.y - c.x)) * kg;
	col = mix(col, dark_col, 0.35 * crease);
	float rub = clamp(wear * (0.55 + 0.9 * tk_fbm(uv * 1.3 + 4.0)) - 0.25, 0.0, 1.0);
	col = mix(col, worn_col, rub * (1.0 - 0.6 * crease));
	float burnish = 1.0 - smoothstep(0.0, edge_band, edge_uv.x);
	col = mix(col, dark_col, 0.65 * burnish);
	col *= 1.0 - 0.55 * cav;
	float r = rough + 0.12 * crease - gloss_worn * rub - 0.22 * burnish + 0.08 * (m - 0.5);
	float thread = 0.0;
	if (stitch_row > 0.0) {
		float d = abs(edge_uv.x - stitch_row);
		float ph = fract(edge_uv.y / stitch_pitch);
		float on = smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(stitch_len - 0.08, stitch_len, ph));
		float line = 1.0 - smoothstep(stitch_w * 0.6, stitch_w, d);
		thread = on * line;
		float hole = (1.0 - smoothstep(0.0, stitch_w * 0.8, length(vec2((ph - stitch_len - 0.1) * stitch_pitch, d)))) * (1.0 - on);
		float groove = 1.0 - smoothstep(0.0, stitch_w * 1.5, d);
		// Far off, the row is an average: a thin line of thread colour over the groove.
		col = mix(col, dark_col, ks * (0.4 * groove + 0.8 * hole) * (1.0 - thread));
		col = mix(col, thread_col * (0.85 + 0.15 * masks.b), thread * ks + (1.0 - ks) * line * stitch_len * 0.5);
		r = mix(r, 0.5, thread * ks);
	}
	ALBEDO = col;
	ROUGHNESS = clamp(r, 0.15, 0.95);
	SPECULAR = 0.45;
	// Relief from the height's slope in texture space (tangent space: x along UV.x, y along UV.y).
	// (the edge coordinates move with the texture's by their screen-space Jacobians: M = d edge / d uv)
	mat2 ju = mat2(dFdx(uv), dFdy(uv));
	mat2 je = mat2(dFdx(edge_uv), dFdy(edge_uv));
	float det = determinant(ju);
	mat2 mm = abs(det) > 1e-12 ? je * inverse(ju) : mat2(vec2(0.0, 1.0), vec2(1.0, 0.0));
	float e = max(grain * 0.15, fp * 0.5);
	float h0 = height(uv, edge_uv, kg, ks);
	float hx = height(uv + vec2(e, 0.0), edge_uv + mm * vec2(e, 0.0), kg, ks);
	float hy = height(uv + vec2(0.0, e), edge_uv + mm * vec2(0.0, e), kg, ks);
	vec3 n = normalize(vec3(-(hx - h0) / e * bump, -(hy - h0) / e * bump, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	AO = 1.0 - 0.6 * cav;
	RIM = sheen;
	RIM_TINT = 0.6;
}
