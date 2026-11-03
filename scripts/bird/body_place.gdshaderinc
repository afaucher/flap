// The body's own shape and look on the GPU, for the surfaces that join it (arm_place, trouser_place): BodyShape's
// rings (ring_at, half_width_at, gap, the shell's closed-form projection), its feather grid (uv_at) and the species'
// plumage zones (Plumage.body), from body_tab (written once: BirdRig._setup_gpu_arm). See arm_place.gdshaderinc for
// body_tab's layout.
#ifndef BODY_PLACE
#define BODY_PLACE
const float BS_TAU = 6.28318530718;
uniform sampler2D body_tab : filter_nearest, repeat_disable;
uniform int body_rings = 2;
uniform int body_nz = 2;
uniform int body_around = 20;

const float BS_NT = 2.6;
const float BS_NB = 1.8;

vec4 bt(int x, int y) {
	return texelFetch(body_tab, ivec2(x, y), 0);
}


// BodyShape.ring_at: (centre y, half width, top, bottom) at z, Hermite through the rings.
vec4 bs_ring(float z) {
	int n = body_rings;
	float fz = bt(0, 0).x;
	float bz = bt(n - 1, 0).x;
	if (z <= fz || z >= bz) {
		return vec4(z <= fz ? bt(0, 0).y : bt(n - 1, 0).y, 0.0, 0.0, 0.0);
	}
	int i = 0;
	while (i < n - 2 && z > bt(i + 1, 0).x) {
		i++;
	}
	vec4 a0 = bt(i, 0);
	vec4 a1 = bt(i, 1);
	vec4 b0 = bt(i + 1, 0);
	vec4 b1 = bt(i + 1, 1);
	vec4 pa = vec4(a0.y, a0.z, a0.w, a1.x);
	vec4 pb = vec4(b0.y, b0.z, b0.w, b1.x);
	float h = b0.x - a0.x;
	vec4 ma = vec4(a1.y, a1.z, a1.w, bt(i, 2).x) * h;
	vec4 mb = vec4(b1.y, b1.z, b1.w, bt(i + 1, 2).x) * h;
	float u = (z - a0.x) / h;
	float u2 = u * u;
	float u3 = u2 * u;
	vec4 o = (2.0 * u3 - 3.0 * u2 + 1.0) * pa + (u3 - 2.0 * u2 + u) * ma + (-2.0 * u3 + 3.0 * u2) * pb + (u3 - u2) * mb;
	return vec4(o.x, max(o.yzw, vec3(0.0)));
}

float bs_half_width(float z, float y) {
	vec4 r = bs_ring(z);
	float dy = y - r.x;
	float h = dy >= 0.0 ? r.z : r.w;
	if (h < 1e-4) {
		return 0.0;
	}
	float nexp = dy >= 0.0 ? BS_NT : BS_NB;
	return r.y * pow(max(1.0 - pow(min(abs(dy / h), 1.0), nexp), 0.0), 1.0 / nexp);
}

// BodyShape.uv_at: the trunk's feather coordinates (uv, uv2) at a point by its surface.
vec4 bs_uv(vec3 p) {
	int n = body_nz;
	float z0 = bt(0, 3).x;
	float zn = bt(n - 1, 3).x;
	float fi = clamp((p.z - z0) / (zn - z0) * float(n - 1), 0.0, float(n) - 1.001);
	int i = int(fi);
	vec4 r = bs_ring(clamp(p.z, z0, zn));
	float dy = p.y - r.x;
	float h = dy >= 0.0 ? r.z : r.w;
	float nexp = dy >= 0.0 ? BS_NT : BS_NB;
	float cx = sign(p.x) * pow(clamp(abs(p.x) / max(r.y, 1e-5), 0.0, 1.0), nexp / 2.0);
	float sy = sign(dy) * pow(clamp(abs(dy) / max(h, 1e-5), 0.0, 1.0), nexp / 2.0);
	float ang = atan(sy, cx);
	float fj = (ang - BS_TAU * floor(ang / BS_TAU)) / BS_TAU * float(body_around);
	int j = min(int(fj), body_around - 1);
	vec4 lo = mix(bt(j, 4 + i), bt(j + 1, 4 + i), fj - float(j));
	vec4 hi = mix(bt(j, 5 + i), bt(j + 1, 5 + i), fj - float(j));
	return mix(lo, hi, fi - float(i));
}

// Plumage.body: the body's colour at (u along it, v up its side, side out from the midline).
vec4 pl_body(float u, float v, float side) {
	int y = 4 + body_nz;
	vec4 band_at = bt(9, y);
	vec4 scap_at = bt(10, y);
	vec4 line = bt(11, y);
	vec4 dorsal = mix(bt(0, y), bt(1, y), smoothstep(0.5, 0.9, u));
	vec4 ventral = mix(bt(2, y), bt(3, y), smoothstep(0.25, 0.5, u));
	ventral = mix(ventral, bt(4, y), smoothstep(0.75, 0.95, u));
	ventral = mix(ventral, bt(5, y), smoothstep(0.55, 0.95, side) * 0.8);
	if (band_at.w > 0.5) {
		ventral = mix(ventral, bt(6, y), smoothstep(band_at.x - 0.05, band_at.x + 0.05, u) * (1.0 - smoothstep(band_at.y - 0.05, band_at.y + 0.05, u)) * 0.85);
	}
	if (scap_at.w > 0.5) {
		ventral = mix(ventral, bt(7, y), 1.0 - smoothstep(band_at.z - 0.05, band_at.z + 0.05, u));
	}
	if (scap_at.z > 0.5) {
		dorsal = mix(dorsal, bt(8, y), smoothstep(0.45, 0.8, side) * smoothstep(scap_at.x - 0.05, scap_at.x + 0.05, u) * (1.0 - smoothstep(scap_at.y - 0.05, scap_at.y + 0.05, u)) * 0.7);
	}
	return mix(ventral, dorsal, smoothstep(line.x - line.y, line.x + line.y, v));
}

// BodyShape.gap: how far a point is outside the shell (inside: negative).
float bs_gap(vec3 pt) {
	vec4 r = bs_ring(pt.z);
	float dy = pt.y - r.x;
	float h = dy >= 0.0 ? r.z : r.w;
	if (r.y < 1e-4 || h < 1e-4) {
		float ez = pt.z < 0.0 ? bt(0, 0).x : bt(body_rings - 1, 0).x;
		return distance(pt, vec3(0.0, r.x, ez));
	}
	float nexp = dy >= 0.0 ? BS_NT : BS_NB;
	float e = pow(pow(abs(pt.x) / r.y, nexp) + pow(abs(dy) / h, nexp), 1.0 / nexp);
	if (e < 1e-5) {
		return -min(r.y, h);
	}
	return length(vec2(pt.x, dy)) * (1.0 - 1.0 / e);
}

// The point of the shell straight out from its ring's centre through p (z kept off the ends by l x 0.01).
vec3 bs_onto_shell(vec3 p, float l) {
	float z = clamp(p.z, bt(0, 0).x + l * 0.01, bt(body_rings - 1, 0).x - l * 0.01);
	vec4 r = bs_ring(z);
	float dy = p.y - r.x;
	float h = dy >= 0.0 ? r.z : r.w;
	float nexp = dy >= 0.0 ? BS_NT : BS_NB;
	float e = pow(pow(abs(p.x) / max(r.y, 1e-5), nexp) + pow(abs(dy) / max(h, 1e-5), nexp), 1.0 / nexp);
	if (e < 1e-5) {
		return vec3(0.0, r.x - r.w, z);
	}
	return vec3(p.x / e, r.x + dy / e, z);
}
#endif
