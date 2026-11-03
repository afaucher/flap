// The heath outside the wood (EdgeBuilder; the ground plane past the boundary and the hills): dry grass in
// straw and olive, heather in purple-brown patches, greener hollows, a little bare earth, in world metres.
vec3 heath_hash3(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float heath_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(heath_hash3(i).x, heath_hash3(i + vec2(1.0, 0.0)).x, f.x), mix(heath_hash3(i + vec2(0.0, 1.0)).x, heath_hash3(i + vec2(1.0, 1.0)).x, f.x), f.y);
}

float heath_fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * heath_vnoise(p);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + 1.7;
		a *= 0.5;
	}
	return s / 0.97;
}

vec3 heath_albedo(vec2 p) {
	float big = heath_fbm(p * 0.02);
	float mid = heath_fbm(p * 0.15 + 4.0);
	float fine = heath_fbm(p * 1.3 + 9.0);
	vec3 h_straw = vec3(0.21, 0.19, 0.09);
	vec3 h_olive = vec3(0.11, 0.14, 0.05);
	vec3 h_heather = vec3(0.13, 0.08, 0.1);
	vec3 h_earth = vec3(0.14, 0.1, 0.07);
	vec3 col = mix(h_straw, h_olive, smoothstep(0.35, 0.7, big * 0.6 + mid * 0.5));
	col = mix(col, h_heather, smoothstep(0.55, 0.72, heath_fbm(p * 0.06 + 13.0) * 0.7 + mid * 0.35) * 0.85);
	col = mix(col, h_earth, smoothstep(0.72, 0.85, heath_fbm(p * 0.4 + 21.0)) * 0.5);
	return col * (0.85 + 0.3 * fine);
}
