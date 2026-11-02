// Noise for the tack shaders (leather, metal, cloth). All in the tack's "real cm" texture space (TackMesh).

float tk_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 tk_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float tk_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(tk_hash12(i), tk_hash12(i + vec2(1.0, 0.0)), f.x), mix(tk_hash12(i + vec2(0.0, 1.0)), tk_hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float tk_fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * tk_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s / 0.9375;
}

// Cellular noise: (F1, F2) distances to the nearest two feature points, cells of size 1.
vec2 tk_cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = tk_hash22(i + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d1, d2);
}

// How much of a pattern with features `size` (cm) survives at `fp` cm per pixel: 1 sharp .. 0 averaged away.
float tk_keep(float size, float fp) {
	return 1.0 - smoothstep(size * 0.25, size * 0.9, fp);
}
