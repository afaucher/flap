// Feather card shader (docs/research/feather_rendering.md). One unit feather mesh: +Z runs base (0) to tip (1),
// X across the vane, Y the feather's normal. UV.x is -1..1 from vane edge to vane edge (0 = the shaft),
// UV.y is 0..1 along the feather. Per instance: COLOR = the feather's base colour, INSTANCE_CUSTOM =
// (kind, seed 0..1, emarginated 0/1, -). Kind: 0 primary, 1 secondary, 2 tertial, 3 alula, 4 greater covert,
// 5 lesser covert, 6 tail.
//
// Surface: the shaft (rachis), barbs running out from it toward the tip, a soft ragged edge (alpha to
// coverage), species pattern (bars, pale margins, dark tips, a dark centre streak), and occlusion toward the
// base where the row above covers it.
// Light: wrapped diffuse; transmission when backlit (pale, thin vanes glow, dark ones barely, the shaft shows
// dark); an anisotropic highlight streaked by the barbs (Ward, as for hair); thin-film-style iridescence
// tinting that highlight (crow). Vertex: flutter, tips only, along the feather's own normal and across it.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform float flutter : hint_range(0.0, 1.0) = 0.15;    // airflow on the feathers (set per bird each tick)
uniform float clock_override = -1.0;                      // >= 0: freeze the flutter clock (screenshots)
uniform float sheen : hint_range(0.0, 2.0) = 0.5;        // anisotropic highlight strength (glossy crow high)
uniform float iridescence : hint_range(0.0, 1.0) = 0.0;  // structural colour in the highlight (crow)
uniform float translucency : hint_range(0.0, 1.0) = 0.5; // backlit glow (scaled down by darkness)
uniform float barring : hint_range(0.0, 1.0) = 0.0;      // dark bars across flight and tail feathers
uniform float bar_freq = 7.0;                             // bars per feather length
uniform float pale_edge : hint_range(0.0, 1.0) = 0.0;    // pale vane margins
uniform float dark_tip : hint_range(0.0, 1.0) = 0.0;     // darker tips
uniform float centre_streak : hint_range(0.0, 1.0) = 0.0; // dark streak along the shaft (sparrow)
uniform float softness : hint_range(0.0, 0.4) = 0.12;    // how soft and ragged the vane edge is (owl high)

varying vec4 v_custom;
varying vec3 v_barb;       // view-space barb direction (for the highlight)
varying float v_trans;     // how much light this spot lets through

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	float t = clock_override >= 0.0 ? clock_override : TIME;
	float along = UV.y;
	float seed = INSTANCE_CUSTOM.y;
	float w = along * along;   // the base is held, the tip moves
	float f = 9.0 + seed * 6.0;
	VERTEX.y += (sin(t * f + seed * 6.283 + along * 2.0) * 0.045 + sin(t * f * 2.3 + seed * 17.0) * 0.015) * flutter * w;
	VERTEX.x += sin(t * f * 1.3 + seed * 3.1) * 0.02 * flutter * w;
}

vec3 to_linear(vec3 c) { return pow(c, vec3(2.2)); }

void fragment() {
	float a = UV.y;
	float u = UV.x;
	float au = abs(u);
	int kind = int(v_custom.x + 0.5);
	float seed = v_custom.y;
	bool flight = kind <= 2 || kind == 6;
	bool covert = kind == 4 || kind == 5;

	// Barbs: fine ridges running from the shaft out toward the tip.
	float barb_coord = (a - au * 0.35) * (covert ? 55.0 : 90.0) + seed * 40.0;
	float barbs = 0.5 + 0.5 * sin(barb_coord);
	// Edge: soft and ragged where barbs end (and part, near the tip), harder on stiff flight feathers.
	float rag = (barbs - 0.5) * softness + (hash(floor(barb_coord / 3.0) + seed * 91.0) - 0.5) * softness * 0.8;
	float edge = au + rag * smoothstep(0.45, 1.0, a) * smoothstep(0.5, 1.0, au);
	float soft_start = 1.0 - softness * 0.6 - 0.03;
	ALPHA = 1.0 - smoothstep(soft_start, 1.0, edge);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;

	// Shaft: a thin pale line, narrowing toward the tip.
	float shaft_w = (covert ? 0.05 : 0.07) * (1.0 - a * 0.7);
	float shaft = 1.0 - smoothstep(shaft_w * 0.5, shaft_w, au);

	vec3 base = to_linear(COLOR.rgb);
	float pattern = 1.0;
	if (flight) {
		float bar = smoothstep(0.35, 0.5, abs(fract(a * bar_freq + seed * 0.3) - 0.5) * 2.0);
		pattern *= 1.0 - barring * 0.45 * bar * smoothstep(0.1, 0.25, a);
		pattern *= 1.0 - dark_tip * 0.5 * smoothstep(0.72, 0.98, a);
	}
	pattern *= 1.0 - centre_streak * 0.45 * (1.0 - smoothstep(0.15, 0.45, au));
	base *= pattern;
	base = mix(base, base * 2.2 + vec3(0.03), pale_edge * smoothstep(0.62, 0.92, au));
	base = mix(base, base * 1.9 + vec3(0.04), shaft * 0.55);
	base *= 0.88 + 0.12 * barbs;
	// Occlusion: the base of each feather sits under the row in front of it.
	base *= mix(covert ? 0.8 : 0.7, 1.0, smoothstep(0.0, 0.4, a));
	ALBEDO = base;
	ROUGHNESS = 0.7;
	SPECULAR = 0.2;

	// Barb direction for the highlight: out from the shaft, angled toward the tip.
	v_barb = normalize(TANGENT * sign(u + 1e-4) - BINORMAL * 0.35);
	// Barbs are tiny ridges: tilt the shading normal across each one, so the shine breaks into streaks along
	// the barbs instead of mirroring off the whole (flat) card.
	vec3 across_barb = normalize(cross(NORMAL, v_barb));
	NORMAL = normalize(NORMAL + across_barb * (barbs - 0.5) * 0.9);
	// Light through the vane: pale and thin passes more; the shaft and dark pigment block it.
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	v_trans = translucency * (0.35 + 0.65 * smoothstep(0.0, 0.25, lum)) * (1.0 - shaft * 0.85) * (0.6 + 0.4 * au);
}

vec3 thin_film(float cos_v) {
	// A cheap stand-in for barbule thin-film interference: hue swings blue-violet -> green with viewing angle.
	float x = 1.0 - cos_v;
	return mix(vec3(0.35, 0.25, 1.0), vec3(0.2, 1.0, 0.55), smoothstep(0.15, 0.85, x));
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	vec3 lc = LIGHT_COLOR * ATTENUATION / PI;
	// Wrapped diffuse: thin, soft surfaces don't fall off hard at the terminator.
	DIFFUSE_LIGHT += lc * max(0.0, (ndl + 0.15) / 1.15);
	// Transmission: lit from behind, light comes through the vane, strongest looking toward the light.
	float back = max(0.0, -ndl);
	float toward = pow(max(0.0, dot(-VIEW, LIGHT)), 3.0);
	DIFFUSE_LIGHT += lc * v_trans * (back * 1.6 + toward * 3.0);
	// Anisotropic highlight (Ward): tight across the barbs, stretched along the shaft -- the parallel barbs
	// streak the shine the way strands do on hair. Tinted by iridescence.
	vec3 h = normalize(VIEW + LIGHT);
	vec3 t = normalize(v_barb - NORMAL * dot(v_barb, NORMAL));
	vec3 b = cross(NORMAL, t);
	float hn = max(dot(h, NORMAL), 1e-3);
	float ht = dot(h, t) / 0.1;
	float hb = dot(h, b) / 0.3;
	float s = exp(-(ht * ht + hb * hb) / (hn * hn)) * max(0.0, ndl);
	vec3 tint = mix(vec3(1.0), thin_film(max(0.0, dot(NORMAL, VIEW))), iridescence);
	SPECULAR_LIGHT += lc * s * sheen * 0.4 * tint;
}
