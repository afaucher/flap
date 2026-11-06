// The bill (Face.beak_meshes; docs/research/eyes_and_beaks.md): keratin over the lofted mandibles, every mark
// drawn per pixel from the mesh's own coordinates, so its edges stay sharp however coarse the loft:
//   UV     (share of the way to the tip, height up the rib: 0 the cutting edge .. 1 the culmen; the lower: 0 its
//          underside .. 1 its cutting edge)
//   UV2    the point in the bill's frame (head radii; x forward along the gape, y up)
//   COLOR  r: across the bill (0 left .. 1 right); g: the surface (0 the upper's outside, 1/3 the palate, 2/3 the
//          lower's outside, 1 the mouth's floor)
// The colour runs from `bill` at the base to `tip` toward the point; fine lengthwise growth lines and a paler
// cutting edge on the keratin; the raptors' cere (bare waxy skin over the base, its front edge leaning back as it
// runs down to the gape) with the nostril in it (the falcon's with its bony tubercle); the crow's nasal bristles,
// stiff feathers lying forward over the base; the mouth's lining inside.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 bill : source_color = vec3(0.1);
uniform vec3 tip : source_color = vec3(0.08);
uniform vec2 tip_range = vec2(0.5, 1.0);     // the share of the way along where the tip colour comes in
uniform vec3 mouth : source_color = vec3(0.6, 0.4, 0.4);
uniform float cere = 0.0;                    // 1: a cere
uniform vec3 cere_col : source_color = vec3(0.9, 0.75, 0.3);
uniform vec2 cere_end = vec2(0.3, 0.0);      // where the cere ends on the culmen (bill frame)
uniform float cere_lean = 0.5;               // its front edge runs back this far per unit down
uniform vec4 nostril = vec4(0.0);            // centre (bill frame), radii; zero radii: none shows
uniform float tubercle = 0.0;                // the falcon's bony tubercle in the nostril
uniform float bristles = 0.0;                // 1: nasal bristles (the crow)
uniform vec3 bristle_col : source_color = vec3(0.05);
uniform vec2 bristle_end = vec2(0.6, 0.0);   // where they end on the culmen
uniform float bristle_lean = 0.8;            // their front edge runs back this far per unit down
uniform float edge = 0.25;                   // the cutting edge paler by this much
uniform float gloss = 0.3;                   // the keratin's roughness

varying vec2 fp;
varying float lat;
varying float part;

void vertex() {
	fp = UV2;
	lat = COLOR.r * 2.0 - 1.0;
	part = COLOR.g * 3.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 on the near side of an edge at `x` (fp.x below it), anti-aliased over a pixel.
float before(float v, float x) {
	float aa = fwidth(v) * 0.75 + 1e-5;
	return 1.0 - smoothstep(x - aa, x + aa, v);
}

void fragment() {
	float outer_up = 1.0 - step(0.5, part);
	float outer_lo = step(1.5, part) * (1.0 - step(2.5, part));
	float inside = 1.0 - outer_up - outer_lo;
	// Keratin: the colour along the bill, fine growth lines running lengthwise and a faint mottle.
	vec3 c = mix(bill, tip, smoothstep(tip_range.x, tip_range.y, UV.x));
	float lines = vnoise(vec2(fp.x * 9.0, UV.y * 55.0 + lat * 17.0));
	float mottle = vnoise(fp * 40.0);
	c *= 0.92 + 0.1 * lines + 0.06 * mottle;
	// The cutting edge (the upper's foot, the lower's top): a thin paler line.
	float rim = outer_up * (1.0 - smoothstep(0.0, 0.07, UV.y)) + outer_lo * smoothstep(0.93, 1.0, UV.y);
	c = mix(c, c * (1.0 + 4.0 * edge) + 0.02 * edge, rim * edge * 2.0);
	float rough = gloss + 0.12 * lines;
	// The cere: bare skin over the upper bill's base, its front edge leaning back as it runs down.
	float on_cere = cere * outer_up * before(fp.x, cere_end.x - (cere_end.y - fp.y) * cere_lean);
	vec3 cc = cere_col * (0.9 + 0.15 * vnoise(fp * 160.0));
	c = mix(c, cc, on_cere);
	rough = mix(rough, 0.55, on_cere);
	// The nostril, on each side (not across the culmen's top): a dark opening with a lip.
	if (nostril.z > 0.0) {
		float d = length((fp - nostril.xy) / nostril.zw);
		float side = smoothstep(0.2, 0.45, abs(lat)) * outer_up;
		float hole = before(d, 1.0) * side;
		float lip = (before(d, 1.35) - hole) * side;
		c = mix(c, c * 0.75, lip);
		vec3 dark = vec3(0.03, 0.02, 0.02);
		dark = mix(dark, cc * 0.8, tubercle * before(d, 0.42));   // (the falcon's tubercle, a knob in the middle)
		c = mix(c, dark, hole);
		rough = mix(rough, 0.8, hole);
	}
	// The crow's nasal bristles: stiff feathers lying forward over the base, their ends ragged.
	if (bristles > 0.0) {
		float hair = vnoise(vec2(fp.x * 6.0, UV.y * 140.0 + lat * 40.0));
		float reach = bristle_end.x - (bristle_end.y - fp.y) * bristle_lean + 0.05 * (hair - 0.5);
		float on_br = bristles * outer_up * before(fp.x, reach) * smoothstep(0.25, 0.4, UV.y);
		vec3 bc = bristle_col * (0.6 + 0.9 * hair * hair);
		c = mix(c, bc, on_br);
		rough = mix(rough, 0.85, on_br);
	}
	c = mix(c, mouth, inside);
	rough = mix(rough, 0.5, inside);
	ALBEDO = c;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = 0.5;
}
