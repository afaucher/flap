// The arm wing's surface on the GPU (BirdRig.gpu_body): the same loft as BirdRig._loft_arm -- its edge loop laid on
// the trunk, the connector rows, the arm's airfoil stations -- each vertex worked out from its row and column, the
// wing's pose this frame (arm_pose) and the bird's fixed tables (body_tab): position, the smoothed normal (as LoftMesh
// sums its triangles' normals), colour and feather coordinates. The loop's colour
// and feather coordinates are the trunk's where it lies (BodyShape.ring_at / half_width_at / uv_at, Plumage.body,
// ported here), worked out every frame. Included by the body shader and by tests/gpu_test_arm.gd's capture.
//
// arm_pose (RGBA32F, a row per side): 0 shoulder, span | 1 leading edge (unit), open | 2 wing normal, side sign |
//   3 elbow, humerus length | 4 wrist, forearm length | 5 winding (1 flipped), trunk scale, root chord, L |
//   6 normal sign, feather unit, -, -
// body_tab (RGBA32F): y0 rings (z, centre y, half width, top) | y1 (bottom, slopes of centre y, width, top) |
//   y2 (slope of bottom) | y3 the feather grid's ring z | y4 .. y4 + nz - 1 the trunk's feather grid (uv, uv2) |
//   y4 + nz plumage (0 back 1 rump 2 breast 3 belly 4 vent 5 flanks 6 band 7 bib 8 scapulars; 9 band from, to, bib
//   edge, has band; 10 scapulars from, to, has scapulars, has bib; 11 line, soft) |
//   y5 + nz .. : the arm stations' colours, side 0 then side 1 (12 rows of 16) | then the stations' (along, chord)
uniform sampler2D body_tab : filter_nearest, repeat_disable;
uniform sampler2D arm_pose : filter_nearest, repeat_disable;
uniform int body_rings = 2;
uniform int body_nz = 2;
uniform int body_around = 20;

const int AR_STATIONS = 10;
const int AR_AROUND = 16;
const int AR_ROOT = 4;
const int AR_ROWS = 16;    // AR_ROOT + AR_STATIONS + 2
const float AR_U0 = 0.2;
const float AR_CAMBER = 0.03;
const float AR_NO_PERIOD = 1000.0;
const float BS_NT = 2.6;
const float BS_NB = 1.8;
const float AR_TAU = 6.28318530718;

vec4 bt(int x, int y) {
	return texelFetch(body_tab, ivec2(x, y), 0);
}

vec4 ap(int side, int k) {
	return texelFetch(arm_pose, ivec2(k, side), 0);
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
	float fj = (ang - AR_TAU * floor(ang / AR_TAU)) / AR_TAU * float(body_around);
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

vec3 ar_slerp(vec3 a, vec3 b, float w) {
	float la = dot(a, a);
	float lb = dot(b, b);
	if (la == 0.0 || lb == 0.0) {
		return mix(a, b, w);
	}
	vec3 ax = cross(a, b);
	float al = dot(ax, ax);
	if (al == 0.0) {
		return mix(a, b, w);
	}
	ax /= sqrt(al);
	float sa = sqrt(la);
	float rl = mix(sa, sqrt(lb), w);
	float ang = atan(sqrt(al), dot(a, b)) * w;
	vec3 r = a * cos(ang) + cross(ax, a) * sin(ang) + ax * dot(ax, a) * (1.0 - cos(ang));
	return r * (rl / sa);
}

float ar_naca(float x) {
	return 5.0 * (0.2969 * sqrt(x) - 0.126 * x - 0.3516 * x * x + 0.2843 * x * x * x - 0.1036 * x * x * x * x);
}

int ar_mod(int a, int n) {
	int r = a - (a / n) * n;
	return r < 0 ? r + n : r;
}

// One airfoil station k (0 .. AR_STATIONS + 1): its centre on the leading edge, its frame, chord, thickness, lip.
void ar_station(int side, int k, out vec3 e, out vec3 nu, out vec3 aft_u, out float chord, out float thick, out float lip) {
	vec4 p0 = ap(side, 0);
	vec4 p1 = ap(side, 1);
	vec4 p2 = ap(side, 2);
	vec4 p3 = ap(side, 3);
	vec4 p4 = ap(side, 4);
	vec4 p5 = ap(side, 5);
	vec3 sh = p0.xyz;
	vec3 le = p1.xyz;
	float open = p1.w;
	float s = p2.w;
	float rc = p5.z;
	float u = mix(AR_U0, 1.0, clamp(float(k) / float(AR_STATIONS), 0.0, 1.0));
	e = sh + le * p0.w * u;
	nu = ar_slerp(vec3(0.0, 1.0, 0.0), p2.xyz, smoothstep(0.0, 0.4, u));
	nu = normalize(nu - le * dot(le, nu));
	aft_u = normalize(cross(le, nu) * s);
	float l_h = p3.w;
	float l_f = p4.w;
	float arc = u * (l_h + l_f);
	vec3 bone = arc <= l_h ? mix(sh, p3.xyz, arc / max(l_h, 1e-5)) : mix(p3.xyz, p4.xyz, (arc - l_h) / max(l_f, 1e-5));
	float depth = max(dot(bone - e, aft_u), 0.0);
	chord = (depth + rc * mix(0.42, 0.26, u)) * open;
	thick = rc * mix(0.14, 0.055, u) * (1.0 + 0.15 * exp(-pow((u - 0.25) / 0.2, 2.0))) * open;
	lip = (0.0075 * p5.w / 0.45 + AR_CAMBER * 0.45 * rc) * open;
	if (k == AR_STATIONS + 1) {
		chord = 0.0;
		thick = 0.0;
	}
}

float ar_angle(int side, int j) {
	return AR_TAU * float(ar_mod(j, AR_AROUND)) / float(AR_AROUND) * (ap(side, 5).x > 0.5 ? -1.0 : 1.0);
}

// A point of a station's airfoil section at column j, from the station's frame (ar_station).
vec3 ar_section(int side, int j, vec3 e, vec3 nu, vec3 aft_u, float chord, float thick, float lip) {
	float a = ar_angle(side, j);
	// (which side of the chord by the column, as the rig's sin(a) >= 0 falls in double precision: the upper side columns
	// 0 .. 8, or flipped 0 and 9 .. 15 -- at a = pi a float sin can land either side of 0)
	float x = 0.5 * (1.0 - cos(a));
	int jj = ar_mod(j, AR_AROUND);
	bool upper = ap(side, 5).x > 0.5 ? (jj == 0 || jj > AR_AROUND / 2) : jj <= AR_AROUND / 2;
	float half_t = ar_naca(x) * thick;
	float y = 0.02 * chord * sin(3.14159265359 * x) + lip * smoothstep(0.15, 1.0, x) + (upper ? -half_t : half_t);
	return e + aft_u * (x * chord) + nu * y;
}

// The loop's ellipse on the trunk round the shoulder (its centre z, half lengths in z and y), from the root chord.
vec3 ar_loop_frame(int side, float chord_root) {
	vec4 p0 = ap(side, 0);
	vec4 p5 = ap(side, 5);
	float z0 = p0.z - p5.w * 0.02;
	float z1 = p0.z + max(chord_root, p5.z * 0.2) * 0.8;
	return vec3((z0 + z1) * 0.5, (z1 - z0) * 0.5, p5.z * 0.09 * ap(side, 1).w);
}

// Loop point j (unscaled: where its colour and coordinates are read).
vec3 ar_loop_point(int side, int j, vec3 f) {
	vec4 p0 = ap(side, 0);
	float a = ar_angle(side, j);
	float z = f.x - f.y * cos(a);
	float y = p0.y - ap(side, 5).w * 0.01 - f.z * sin(a);
	return vec3(ap(side, 2).w * bs_half_width(z, y), y, z);
}

// Row r's points at columns j - 1, j, j + 1: the row's frame worked out once (station 0's and the loop's are passed in).
void ar_row3(int side, int r, int j, vec3 e0, vec3 nu0, vec3 aft0, float ch0, float th0, float lp0, vec3 lf, out vec3 pa, out vec3 pb, out vec3 pc) {
	if (r >= AR_ROOT) {
		vec3 e;
		vec3 nu;
		vec3 aft_u;
		float chord;
		float thick;
		float lip;
		ar_station(side, r - AR_ROOT, e, nu, aft_u, chord, thick, lip);
		pa = ar_section(side, j - 1, e, nu, aft_u, chord, thick, lip);
		pb = ar_section(side, j, e, nu, aft_u, chord, thick, lip);
		pc = ar_section(side, j + 1, e, nu, aft_u, chord, thick, lip);
		return;
	}
	float st = ap(side, 5).y;
	pa = ar_loop_point(side, j - 1, lf) * st;
	pb = ar_loop_point(side, j, lf) * st;
	pc = ar_loop_point(side, j + 1, lf) * st;
	if (r > 0) {
		float w = smoothstep(0.0, 1.0, float(r) / float(AR_ROOT));
		pa += (ar_section(side, j - 1, e0, nu0, aft0, ch0, th0, lp0) - pa) * w;
		pb += (ar_section(side, j, e0, nu0, aft0, ch0, th0, lp0) - pb) * w;
		pc += (ar_section(side, j + 1, e0, nu0, aft0, ch0, th0, lp0) - pc) * w;
	}
}

// One position (the capture and the image test's reference use ar_vertex_geometry; this is for tools).
vec3 ar_pos(int side, int r, int j) {
	vec3 e0;
	vec3 nu0;
	vec3 aft0;
	float ch0;
	float th0;
	float lp0;
	ar_station(side, 0, e0, nu0, aft0, ch0, th0, lp0);
	vec3 pa;
	vec3 pb;
	vec3 pc;
	ar_row3(side, r, j, e0, nu0, aft0, ch0, th0, lp0, ar_loop_frame(side, ch0), pa, pb, pc);
	return pb;
}

// One quad's two triangles (a c b, b c d), each as a unit normal -- none if degenerate. The rig places some points
// at one spot (the wrist end's leading point, rows 14 and 15), so their triangles are exactly nothing there; here the
// same points can land a rounding step apart and the compiler reorders the cross product, so "nothing" isn't zero:
// a triangle with an edge under 0.1 um is taken as none.
bool ar_tiny(vec3 u) {
	return dot(u, u) < 1e-14;
}

void ar_quad(vec3 a, vec3 b, vec3 c, vec3 d, out vec3 f1, out vec3 f2) {
	f1 = cross(c - a, b - a);
	f2 = cross(c - b, d - b);
	bool cb = ar_tiny(c - b);
	f1 = (cb || ar_tiny(c - a) || ar_tiny(b - a) || dot(f1, f1) <= 1e-24) ? vec3(0.0) : normalize(f1);
	f2 = (cb || ar_tiny(d - b) || ar_tiny(d - c) || dot(f2, f2) <= 1e-24) ? vec3(0.0) : normalize(f2);
}

// The vertex's position, and its normal as LoftMesh.normals smooths it over the 3 x 3 neighbours: each of the three
// rows' frames worked out once, station 0's and the loop's once for all. (The wrist end's chord and thickness go to
// nothing but its lip doesn't, so no ring closes to a point: LoftMesh's closed-ring rule never applies to the arm.)
// The neighbours are named, not kept in an array: indexed in a loop, this long a function came out wrong on the GPU.
void ar_vertex_geometry(int side, int r, int j, out vec3 pos, out vec3 nrm) {
	vec3 e0;
	vec3 nu0;
	vec3 aft0;
	float ch0;
	float th0;
	float lp0;
	ar_station(side, 0, e0, nu0, aft0, ch0, th0, lp0);
	vec3 lf = ar_loop_frame(side, ch0);
	vec3 p00;
	vec3 p01;
	vec3 p02;
	vec3 p10;
	vec3 p11;
	vec3 p12;
	vec3 p20;
	vec3 p21;
	vec3 p22;
	ar_row3(side, max(r - 1, 0), j, e0, nu0, aft0, ch0, th0, lp0, lf, p00, p01, p02);
	ar_row3(side, r, j, e0, nu0, aft0, ch0, th0, lp0, lf, p10, p11, p12);
	ar_row3(side, min(r + 1, AR_ROWS - 1), j, e0, nu0, aft0, ch0, th0, lp0, lf, p20, p21, p22);
	vec3 acc = vec3(0.0);
	vec3 f1;
	vec3 f2;
	if (r > 0) {
		ar_quad(p00, p01, p10, p11, f1, f2);   // the quad up and back: this vertex is its d
		acc += f2;
		ar_quad(p01, p02, p11, p12, f1, f2);   // up: its c
		acc += f1 + f2;
	}
	if (r < AR_ROWS - 1) {
		ar_quad(p10, p11, p20, p21, f1, f2);   // back: its b
		acc += f1 + f2;
		ar_quad(p11, p12, p21, p22, f1, f2);   // this vertex's own quad: its a
		acc += f1;
	}
	acc *= ap(side, 6).x;
	pos = p11;
	nrm = dot(acc, acc) > 1e-30 ? normalize(acc) : vec3(0.0, 1.0, 0.0);
}

// The trunk's colour and coordinates at loop point j.
void ar_loop_look(int side, int j, vec3 lf, out vec4 col, out vec4 fc) {
	vec3 p = ar_loop_point(side, j, lf);
	vec4 r = bs_ring(p.z);
	float hgt = p.y >= r.x ? r.z : r.w;
	float u = clamp((p.z - bt(0, 0).x) / (bt(body_rings - 1, 0).x - bt(0, 0).x), 0.0, 1.0);
	col = pl_body(u, clamp((p.y - r.x) / max(hgt, 1e-4), -1.0, 1.0), clamp(abs(p.x) / max(r.y, 1e-4), 0.0, 1.0));
	fc = bs_uv(p);
}

// Vertex (row r: 0 the loop .. 15 the wrist end; column j: 0 .. 16, the last the seam) of side `side`'s arm wing.
void arm_vertex(int side, int r, int j, out vec3 pos, out vec3 nrm, out vec4 col, out vec2 uv, out vec2 uv2) {
	int jj = ar_mod(j, AR_AROUND);
	ar_vertex_geometry(side, r, jj, pos, nrm);
	vec3 e0;
	vec3 nu0;
	vec3 aft0;
	float ch0;
	float th0;
	float lp0;
	ar_station(side, 0, e0, nu0, aft0, ch0, th0, lp0);
	vec3 lf = ar_loop_frame(side, ch0);
	vec4 lcol;
	vec4 lfc;
	ar_loop_look(side, jj, lf, lcol, lfc);
	vec4 fc0;
	vec4 c0;
	ar_loop_look(side, 0, lf, c0, fc0);   // (the coordinates' v runs from the loop's leading point)
	float s = ap(side, 2).w;
	float unit = ap(side, 6).y;
	bool flip = ap(side, 5).x > 0.5;
	int tab = 5 + body_nz + side * (AR_STATIONS + 2);
	int k = max(r - AR_ROOT, 0);
	vec4 au = bt(k, 5 + body_nz + 2 * (AR_STATIONS + 2));
	float a = AR_TAU * float(jj) / float(AR_AROUND);
	vec2 suv = vec2(lfc.x - s * au.x / unit, fc0.y + 0.5 * (1.0 - cos(a)) * au.y / unit);
	vec2 suv2 = vec2(AR_NO_PERIOD, -clamp(sin(a) * (flip ? -1.0 : 1.0) * 4.0, -1.0, 1.0));
	if (r >= AR_ROOT) {
		col = bt(jj, tab + k);
		uv = suv;
		uv2 = suv2;
	} else if (r == 0) {
		col = lcol;
		uv = lfc.xy;
		uv2 = lfc.zw;
	} else {
		float w = smoothstep(0.0, 1.0, float(r) / float(AR_ROOT));
		col = lcol + (bt(jj, tab) - lcol) * w;
		uv = lfc.xy + (suv - lfc.xy) * w;
		uv2 = lfc.zw + (suv2 - lfc.zw) * w;
	}
}
