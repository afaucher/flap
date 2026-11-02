// Weathered timber for the outposts (planks, bearers, braces, the hangar): procedural, in the piece's own frame
// (VERTEX, model space) so the grain runs along its length -- `grain_axis` 2 (z: deck planks, laid from the trunk
// out), 1 (y: posts, braces along their cylinder, upright boards) or 0 (x: bearers) -- with growth rings as long streaks, a knot or two, silver-grey
// weathering on top over warm wood, darker end grain and cracks, worn lighter edges, and a pair of iron nail
// heads near each end. Each piece varies by where it is (its seed from its position).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 wood : source_color = vec3(0.52, 0.4, 0.28);
uniform vec3 silver : source_color = vec3(0.56, 0.54, 0.5);
uniform vec3 dark : source_color = vec3(0.22, 0.17, 0.12);
uniform float weather = 0.55;      // 0 fresh .. 1 grey all over
uniform int grain_axis = 2;
uniform float length_m = 1.1;      // the piece's length along the grain (for the nails)
uniform bool nails = true;
// The weathered-planks photoscan (assets/LICENSES.md), when given: each piece takes one board of it (the scan is
// `scan_boards` boards across `scan_tile` m), picked by its seed, the grain along the piece.
uniform bool use_scan = false;
uniform sampler2D scan_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scan_tile = 2.0;
uniform float scan_boards = 9.5;
uniform float board_w = 0.17;      // m, the piece's width across the grain
uniform vec3 scan_tint : source_color = vec3(1.0);

varying vec3 lp;
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
	lp = VERTEX;
	vec3 o = NODE_POSITION_WORLD;
	seed = hash12(o.xz * 3.1 + o.y);
}

void fragment() {
	// (along, across) the grain, metres; `face`: the coordinate through the board.
	float along = grain_axis == 2 ? lp.z : (grain_axis == 1 ? lp.y : lp.x);
	float across = grain_axis == 0 ? lp.z : lp.x;
	float face = grain_axis == 1 ? lp.z : lp.y;
	vec2 g = vec2(along * 6.0, (across + face) * 160.0 + seed * 40.0);
	// Growth rings: long streaks, wavering round a knot.
	vec2 knot = vec2(seed * 0.8 - 0.4, (seed - 0.5) * 0.08);
	float kd = length(vec2(along - knot.x, (across - knot.y) * 4.0));
	float warp = 0.012 / (kd + 0.02);
	float rings = 0.5 + 0.5 * sin((across + face * 0.3) * 260.0 + vnoise(g * vec2(1.0, 0.05)) * 6.0 + warp * 40.0);
	float fine = vnoise(vec2(along * 40.0, across * 900.0 + seed * 9.0));
	vec3 col = mix(wood * 0.85, wood * 1.15, rings * 0.6 + fine * 0.4);
	// Weathering: silver-grey where the sun and rain reach (the upper face), streaked along the grain.
	float wst = vnoise(vec2(along * 3.0, across * 60.0 + seed * 17.0));
	float up = clamp(NORMAL.y, 0.0, 1.0);
	float grey = clamp(weather * (0.55 + 0.6 * wst) * (0.5 + 0.5 * up) + (seed - 0.5) * 0.3, 0.0, 1.0);
	col = mix(col, silver * (0.85 + 0.3 * fine), grey);
	// Cracks along the grain, and the knot itself.
	float crack = smoothstep(0.92, 0.98, vnoise(vec2(along * 2.0 + seed * 3.0, across * 300.0)));
	col = mix(col, dark, crack * 0.7);
	col = mix(col, dark * 1.2, (1.0 - smoothstep(0.012, 0.03, kd)) * 0.8);
	// Nail heads: two near each end, on the top face.
	float nail = 0.0;
	if (nails && grain_axis == 2) {
		for (int e = -1; e <= 1; e += 2) {
			for (int s = -1; s <= 1; s += 2) {
				vec2 np = vec2(float(e) * (length_m * 0.5 - 0.05), float(s) * 0.025);
				nail = max(nail, 1.0 - smoothstep(0.004, 0.007, length(vec2(along, across) - np)));
			}
		}
		nail *= step(0.5, up);
	}
	col = mix(col, vec3(0.12, 0.1, 0.09), nail);
	if (use_scan) {
		float board = floor(seed * scan_boards * 0.999);
		vec2 su = vec2((board + 0.08 + 0.84 * clamp(across / board_w + 0.5, 0.0, 1.0)) / scan_boards, along / scan_tile + seed * 7.0);
		vec3 sc = texture(scan_albedo, su).rgb * scan_tint;
		col = mix(sc, sc * mix(vec3(1.0), silver / max(wood, vec3(0.05)), 0.35), grey * 0.6);
		col = mix(col, dark, crack * 0.3);
		nail = 0.0;
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.45, nail);
	METALLIC = nail * 0.6;
	SPECULAR = 0.35;
	// Relief: the rings and cracks as a normal (face normal space: x across, y along).
	float h = rings * 0.3 + fine * 0.2 - crack * 0.8;
	NORMAL_MAP = normalize(vec3(dFdx(h) * 0.0 - (vnoise(vec2(along * 40.0, across * 900.0 + 1.0)) - fine) * 0.6, crack * -0.3, 1.0)) * 0.5 + 0.5;
	if (use_scan) {
		float board = floor(seed * scan_boards * 0.999);
		vec2 su = vec2((board + 0.08 + 0.84 * clamp(across / board_w + 0.5, 0.0, 1.0)) / scan_boards, along / scan_tile + seed * 7.0);
		vec3 sn = texture(scan_normal, su).rgb;
		NORMAL_MAP = grain_axis == 2 ? sn : sn.yxz;   // (the scan's boards run along v; on a rod, round it)
		ROUGHNESS = texture(scan_arm, su).g;
	}
}
