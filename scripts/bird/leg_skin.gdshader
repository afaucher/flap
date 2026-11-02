// The bare skin of the legs and feet, and the claws (LegRig; docs/design/legs_and_feet.md): the podotheca's
// scales drawn procedurally over the leg meshes' own coordinates. Per vertex (LegRig builds every piece with them):
//   COLOR.rgb  the skin's colour (sRGB); the claws' horn colour on the claws
//   COLOR.a    keratin: 0 skin .. 1 claw (smooth and glossier, no scales)
//   UV         (u round the tube, v along it), in scales: u = 0 on the front of the tarsus and the top of a toe
//   UV2        (u's period: the ring's girth in scales, where u comes round on itself; how far front plates may
//              show there: 1 on the tarsus and toes, 0 on the foot pad)
// Front plates (scutes, the acrotarsium and the tops of the toes) where `scutes` and UV2.y allow, small polygonal
// reticulate scales elsewhere and on the soles; the owl's feathered toes (`fuzz`) are soft streaks instead. The
// pattern fades out where a scale gets smaller than about two pixels, so a distant leg is its plain colour.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float scutes = 1.0;       // front plates: 1 scutellate (hawk, crow, sparrow) .. 0 reticulate all round (falcon)
uniform float fuzz = 0.0;         // feathered / bristled toes (owl)
uniform float relief = 1.0;       // the scales' bump (0: flat)
uniform float scale_m = 0.003;    // a scale's size (m), for the bump's slope
uniform bool show_chart = false;  // debug: the coordinates as a grid

varying vec2 info;

void vertex() {
	info = UV2;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash22(i).x;
	float b = hash22(i + vec2(1.0, 0.0)).x;
	float c = hash22(i + vec2(0.0, 1.0)).x;
	float d = hash22(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Reticulate scales: a jittered cell pattern. Returns (distance to the nearest cell edge, the cell's own random value).
vec2 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 best = vec2(8.0);
	vec2 best_o = vec2(0.0);
	vec2 best_id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = g + 0.15 + 0.7 * hash22(i + g) - f;
			float d = dot(o, o);
			if (d < best.x) {
				best = vec2(d, best.x);
				best_o = o;
				best_id = i + g;
			}
		}
	}
	float edge = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = g + 0.15 + 0.7 * hash22(i + g) - f;
			vec2 dd = o - best_o;
			if (dot(dd, dd) > 1e-5) {
				edge = min(edge, dot(0.5 * (best_o + o), normalize(dd)));
			}
		}
	}
	return vec2(edge, hash22(best_id + 7.0).x);
}

void fragment() {
	float period = max(info.x, 0.05);
	float uw = UV.x - period * round(UV.x / period);   // 0 on the front / top
	float around = abs(uw) / period;                   // 0 front .. 0.5 back / sole
	float keratin = clamp(COLOR.a, 0.0, 1.0);
	// Front plates: transverse bands, each plate overlapping the next one down (its lower edge raised), in a band
	// down the front; small reticulate scales everywhere else.
	float front = 1.0 - smoothstep(0.16, 0.24, around);
	float sw = clamp(scutes * info.y, 0.0, 1.0) * front;
	vec2 cc = cells(UV * vec2(1.0, 1.15));
	float h_ret = smoothstep(0.0, 0.16, cc.x) * (0.85 + 0.15 * cc.y);
	float fv = fract(UV.y * 0.8);
	float h_scu = smoothstep(0.0, 0.08, fv) * (0.55 + 0.45 * fv) * smoothstep(0.24, 0.17, around);
	float h = mix(h_ret, h_scu, sw);
	// Fade the pattern out where a scale is under about two pixels.
	float px = max(length(fwidth(UV)), 1e-5);
	float detail = (1.0 - smoothstep(0.3, 0.7, px)) * (1.0 - keratin);
	vec3 col = to_linear(COLOR.rgb);
	float sk = detail * (1.0 - fuzz);
	col *= mix(1.0, mix(0.76, 1.03, h), sk);
	col *= 1.0 + (cc.y - 0.5) * 0.1 * sk * (1.0 - sw);
	// Feathered toes: fine soft streaks along the toe.
	float fz = fuzz * (1.0 - keratin) * (1.0 - smoothstep(0.5, 1.2, px));
	float streak = value_noise(vec2(uw * 7.0, UV.y * 1.4)) * 0.6 + value_noise(vec2(uw * 15.0, UV.y * 3.0)) * 0.4;
	col *= mix(1.0, 0.82 + 0.3 * streak, fz);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.62, 0.95, fuzz), 0.3, keratin);
	SPECULAR = mix(0.4, 0.65, keratin);
	if (show_chart) {
		vec2 g = abs(fract(vec2(uw, UV.y)) - 0.5);
		ALBEDO = vec3(smoothstep(0.42, 0.48, g.x), smoothstep(0.42, 0.48, g.y), info.y) * 0.8 + 0.1;
	}
	// Relief: the scales' height as a bump (surface gradient from screen derivatives; the meshes need no tangents).
	float hb = h * sk * relief * scale_m * 0.25;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(hb) * r1 + dFdy(hb) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
}
