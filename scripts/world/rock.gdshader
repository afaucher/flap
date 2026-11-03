// The escarpment (EdgeBuilder._rock) and its boulders: pale grey limestone in world metres -- bedding planes in
// thin darker bands, water stains streaking down the steep faces, lichen in spots, cracks, and grass and heather
// on whatever faces up -- with a bump from the same noise.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float strata = 1.0;   // the bedding bands (0 for the boulders, which lie any way up)
uniform float bump = 0.6;

varying vec3 wp;
varying vec3 wn;
varying vec3 tint;   // (each block's own shade: the instance colour; white on the cliff's mesh)

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise3(p);
		p = p * 2.02 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s / 0.97;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb;
}

void fragment() {
	vec3 n = normalize(wn);
	float big = fbm3(wp * 0.07);
	float mid = fbm3(wp * 0.45 + 5.0);
	float fine = fbm3(wp * 3.1 + 11.0);
	// (albedo in the wood's own range -- its litter is about 0.15 -- and a little cool: the sun is warm and strong)
	// (cooler still than neutral: under the golden sun it reads as the concept's grey)
	vec3 col = mix(vec3(0.1, 0.112, 0.135), vec3(0.23, 0.25, 0.285), smoothstep(0.25, 0.8, big * 0.6 + mid * 0.5));
	col = mix(col, vec3(0.24, 0.225, 0.2), smoothstep(0.55, 0.8, fbm3(wp * 0.12 + 21.0)) * 0.4);   // warmer patches
	// Bedding: thin darker bands, wavering.
	float bed = sin(wp.y * 1.6 + big * 7.0);
	col *= 1.0 - 0.16 * smoothstep(0.82, 0.98, bed) * strata;
	// Water stains down the steep faces.
	float steep = 1.0 - smoothstep(0.35, 0.7, n.y);
	float streak = fbm3(vec3((wp.x + wp.z) * 0.9, wp.y * 0.05, (wp.x - wp.z) * 0.9));
	col = mix(col, vec3(0.08, 0.075, 0.07), steep * smoothstep(0.5, 0.75, streak) * 0.6);
	// Lichen.
	float li = fbm3(wp * 1.4 + 31.0);
	col = mix(col, vec3(0.3, 0.27, 0.16), smoothstep(0.68, 0.8, li) * 0.45);
	col = mix(col, vec3(0.06, 0.06, 0.055), smoothstep(0.72, 0.85, fbm3(wp * 2.3 + 41.0)) * 0.35);
	// Vertical joints between the blocks (along the cliff: its angle round the ring, in metres).
	float arc = atan(wp.x, wp.z) * length(wp.xz);
	float jt = fract(arc / 1.9 + fbm3(wp * vec3(0.3, 0.08, 0.3)) * 0.8);
	col *= 1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.03, min(jt, 1.0 - jt))) * steep * strata;
	// Cracks.
	float cr = abs(fbm3(wp * vec3(0.5, 0.25, 0.5) + 51.0) - 0.5);
	col *= 1.0 - 0.45 * (1.0 - smoothstep(0.0, 0.025, cr)) * steep;
	// Grass and heather on what faces up.
	float veg = smoothstep(0.62, 0.85, n.y) * smoothstep(0.2, 0.5, mid + 0.25);
	vec3 green = mix(vec3(0.1, 0.13, 0.05), vec3(0.13, 0.08, 0.09), smoothstep(0.45, 0.65, fbm3(wp * 0.3 + 61.0)));
	col = mix(col, green * (0.8 + 0.3 * fine), veg);
	col *= 0.88 + 0.24 * fine;
	ALBEDO = col * tint;
	ROUGHNESS = mix(0.88, 0.95, veg);
	SPECULAR = 0.3;
	// Bump from the same noise (surface gradient).
	float hgt = mid * 0.25 + fine * 0.06 + (1.0 - smoothstep(0.0, 0.025, cr)) * -0.05;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(hgt);
	float dhy = dFdy(hgt);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * bump);
}
