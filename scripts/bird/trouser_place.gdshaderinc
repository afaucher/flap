// The legs' feather tubes ("trousers") on the GPU (BirdRig.gpu_body): LegRig._build_feathers's construction, every
// vertex every frame -- the loop on the trunk round where the leg leaves it (dropped onto the shell along the shell's
// normal there, as _shell_loop does: the closed-form projection, a bracket, then halving), the fillet from the trunk
// onto the leg, the rings down the leg with no fold at the ankle (each ring's point kept ahead of the one before along
// its own axis), the skirt and its hem (the skin's top ring as the skin draws it), colours, feather coordinates and
// MeshBuild's area-weighted normals. LegRig._gpu_layout lays out each leg's rows a pose (leg_pose); leg_static holds the
// skin's top ring in the tarsus bone's frame and the drawn trunk's colours and normals (its mesh's grid). Built on the
// unscaled trunk, as the rebuild built it; the loop and fillet then scale with the trunk, as its bone scaled them.
// Included by the body shader and by tests/gpu_test_trousers.gd's capture.
//
// leg_pose (RGBA32F, 16 wide; per leg a header row then a row per tail row, 12 rows a leg):
//   header: 0 exit point, trunk scale | 1 ankle, tarsus length | 2 tarsus direction, flag | 3 tarsus frame side, d_row |
//     4 tarsus frame front, tarsus radius | 5 the tube's axis at its start, shank | 6 thigh, unit_top, unit_bot, rows |
//     7 trouser colour, has one | 8-11 the tarsus bone (basis x, y, z, origin) | 12 pad centre, half width |
//     13 pad out, half height | 14 pad up, owl | 15 pad forward, d0
//   row: 0 centre, kind (0 ring, 1 skirt, 2 its edge, 3 hem, 4 owl halfway to the pad, 5 owl on the pad) |
//     1 side, radius to the side | 2 front, radius front | 3 axis, radius back | 4 distance down, colour weight
#include "res://scripts/bird/body_place.gdshaderinc"
uniform sampler2D leg_pose : filter_nearest, repeat_disable;
uniform sampler2D leg_static : filter_nearest, repeat_disable;
uniform int trunk_w = 21;
uniform float leg_l = 0.3;

const int TR_N = 12;       // LegRig.AROUND
const int TR_FIL = 3;      // LegRig.FILLET_W.size()
const int TR_MAXT = 11;    // LegRig.T_MAXT
const int TR_ROWS = 14;    // TR_FIL + TR_MAXT
const float TR_FLARE = 1.6;
const float TR_PI = 3.14159265359;

vec4 lp(int leg, int row, int k) {
	return texelFetch(leg_pose, ivec2(k, leg * (1 + TR_MAXT) + row), 0);
}

int tr_mod(int a, int n) {
	int r = a - (a / n) * n;
	return r < 0 ? r + n : r;
}

float tr_fillet_w(int r) {
	return r == 0 ? 0.0 : (r == 1 ? 0.3 : 0.6);
}

// A ring's point j (LegRig._ring): angle PI + TAU j / n, the side radius out, the front or back radius by the sine.
vec3 tr_ring(vec3 c, vec3 side, vec3 front, float rs, float rf, float rb, int j) {
	float a = TR_PI + 2.0 * TR_PI * float(tr_mod(j, TR_N)) / float(TR_N);
	float sa = sin(a);
	return c + side * (cos(a) * rs) + front * (sa * (sa >= 0.0 ? rf : rb));
}

vec3 tr_row_ring(int leg, int k, int j) {
	vec4 a = lp(leg, 1 + k, 0);
	vec4 b = lp(leg, 1 + k, 1);
	vec4 c = lp(leg, 1 + k, 2);
	vec4 d = lp(leg, 1 + k, 3);
	return tr_ring(a.xyz, b.xyz, c.xyz, b.w, c.w, d.w, j);
}

// LegRig._onto_pad: q slid along dir onto the foot pad's ellipsoid.
vec3 tr_onto_pad(int leg, vec3 q, vec3 dir) {
	vec4 f0 = lp(leg, 0, 12);
	vec4 f1 = lp(leg, 0, 13);
	vec3 up = lp(leg, 0, 14).xyz;
	vec3 fw = lp(leg, 0, 15).xyz;
	float pw = f0.w;
	float ph = f1.w;
	vec3 qq = q - f0.xyz;
	vec3 o = vec3(dot(qq, f1.xyz) / pw, dot(qq, up) / ph, dot(qq, fw) / pw);
	vec3 dd = vec3(dot(dir, f1.xyz) / pw, dot(dir, up) / ph, dot(dir, fw) / pw);
	float a = dot(dd, dd);
	float b = 2.0 * dot(o, dd);
	float c = dot(o, o) - 1.0;
	float disc = b * b - 4.0 * a * c;
	vec3 l;
	if (disc >= 0.0 && a > 1e-12) {
		float sq = sqrt(disc);
		float t0 = (-b - sq) / (2.0 * a);
		float t1 = (-b + sq) / (2.0 * a);
		l = o + dd * (abs(t0) < abs(t1) ? t0 : t1);
	} else {
		l = normalize(o);
	}
	return f0.xyz + f1.xyz * l.x * pw + up * l.y * ph + fw * l.z * pw;
}

// Tail row k's point j before the no-fold pass.
vec3 tr_tail_base(int leg, int k, int j) {
	int kind = int(lp(leg, 1 + k, 0).w + 0.5);
	if (kind == 0) {
		return tr_row_ring(leg, k, j);
	}
	if (kind >= 4) {   // the owl: its last ring (the row before these two) slid along the tarsus onto the pad
		vec3 q = tr_row_ring(leg, k - (kind == 4 ? 1 : 2), j);
		vec3 on_pad = tr_onto_pad(leg, q, lp(leg, 0, 2).xyz);
		return kind == 4 ? q + (on_pad - q) * 0.5 : on_pad;
	}
	vec4 h1 = lp(leg, 0, 1);
	vec4 h2 = lp(leg, 0, 2);
	vec4 h3 = lp(leg, 0, 3);
	vec4 h4 = lp(leg, 0, 4);
	vec3 ankle = h1.xyz;
	vec3 t2 = h2.xyz;
	int jj = tr_mod(j, TR_N);
	// The hem: the skin's top ring as the skin draws it (rest ring in the tarsus bone's frame, the bone this pose).
	vec3 hl = texelFetch(leg_static, ivec2(jj, leg), 0).xyz;
	vec3 hem = lp(leg, 0, 8).xyz * hl.x + lp(leg, 0, 9).xyz * hl.y + lp(leg, 0, 10).xyz * hl.z + lp(leg, 0, 11).xyz;
	if (kind == 3) {
		return hem;
	}
	float a = TR_PI + 2.0 * TR_PI * float(jj) / float(TR_N);
	float sa = sin(a);
	float ext = h2.w * (1.0 - 0.35 * sa) + h4.w * 0.5;
	float dr = dot(hem - ankle, t2) - 0.72 * ext;
	float d_edge = dr + ext;
	vec3 dir = h3.xyz * cos(a) + h4.xyz * sa;
	float shank = lp(leg, 0, 5).w;
	if (kind == 1) {
		return ankle + t2 * (dr + (d_edge - dr) * 0.5) + dir * shank * 0.97;
	}
	return ankle + t2 * d_edge + dir * shank * 0.8;
}

// Tail row k's point j as built: down the column, each row's point kept at least l x 0.004 ahead of the one before
// along its own row's axis (not the hem, which tucks back up under the skirt; the owl's runs to the pad).
vec3 tr_tail(int leg, int k, int j) {
	int nt = int(lp(leg, 0, 6).w + 0.5);
	bool owl = lp(leg, 0, 14).w > 0.5;
	int ke = min(k, nt - 1);
	int last = owl ? nt : nt - 1;
	vec3 prev = tr_tail_base(leg, 0, j);
	if (ke == 0) {
		return prev;
	}
	float gmin = leg_l * 0.004;
	vec3 cur = prev;
	for (int kk = 1; kk <= ke; kk++) {
		cur = tr_tail_base(leg, kk, j);
		if (kk < last) {
			vec3 ax = lp(leg, 1 + kk, 3).xyz;
			float ahead = dot(cur - prev, ax);
			if (ahead < gmin) {
				cur += ax * (gmin - ahead);
			}
		}
		prev = cur;
	}
	return cur;
}

// LegRig._trunk_at: the drawn trunk's colour and normal at a point by its surface (its mesh's grid, bilinear).
void tr_trunk_at(vec3 p, out vec4 col, out vec3 nrm) {
	int nz = body_nz;
	float z0 = bt(0, 3).x;
	float zn = bt(nz - 1, 3).x;
	float fi = clamp((p.z - z0) / (zn - z0) * float(nz - 1), 0.0, float(nz) - 1.001);
	int i = int(fi);
	vec4 r = bs_ring(clamp(p.z, z0, zn));
	float dy = p.y - r.x;
	float h = dy >= 0.0 ? r.z : r.w;
	float nexp = dy >= 0.0 ? BS_NT : BS_NB;
	float cx = sign(p.x) * pow(clamp(abs(p.x) / max(r.y, 1e-5), 0.0, 1.0), nexp / 2.0);
	float sy = sign(dy) * pow(clamp(abs(dy) / max(h, 1e-5), 0.0, 1.0), nexp / 2.0);
	float ang = atan(sy, cx);
	float fj = (ang - BS_TAU * floor(ang / BS_TAU)) / BS_TAU * float(trunk_w - 1);
	int j = min(int(fj), trunk_w - 2);
	float fu = fj - float(j);
	float fv = fi - float(i);
	vec4 c00 = texelFetch(leg_static, ivec2(j, 2 + i), 0);
	vec4 c01 = texelFetch(leg_static, ivec2(j + 1, 2 + i), 0);
	vec4 c10 = texelFetch(leg_static, ivec2(j, 3 + i), 0);
	vec4 c11 = texelFetch(leg_static, ivec2(j + 1, 3 + i), 0);
	vec4 ca = c00 + (c01 - c00) * fu;
	vec4 cb = c10 + (c11 - c10) * fu;
	col = ca + (cb - ca) * fv;
	vec3 n00 = texelFetch(leg_static, ivec2(j, 2 + nz + i), 0).xyz;
	vec3 n01 = texelFetch(leg_static, ivec2(j + 1, 2 + nz + i), 0).xyz;
	vec3 n10 = texelFetch(leg_static, ivec2(j, 3 + nz + i), 0).xyz;
	vec3 n11 = texelFetch(leg_static, ivec2(j + 1, 3 + nz + i), 0).xyz;
	vec3 na = n00 + (n01 - n00) * fu;
	vec3 nb = n10 + (n11 - n10) * fu;
	nrm = normalize(na + (nb - na) * fv);
}

// _shell_loop's projection: u dropped onto the shell along t (a bracket from the closed-form projection, or stepped
// in or out, then halved).
vec3 tr_project(vec3 u, vec3 t) {
	float l = leg_l;
	float t0 = dot(bs_onto_shell(u, l) - u, t);
	float bw = l * 0.004;
	float g_in = bs_gap(u + t * (t0 - bw));
	float g_out = bs_gap(u + t * (t0 + bw));
	float lo = 0.0;
	float hi = 0.0;
	bool found = false;
	int halvings = 16;
	if ((g_in > 0.0) != (g_out > 0.0)) {
		found = true;
		lo = g_in <= 0.0 ? t0 - bw : t0 + bw;
		hi = g_in <= 0.0 ? t0 + bw : t0 - bw;
		halvings = 10;
	} else {
		float step = l * 0.01 * (bs_gap(u) < 0.0 ? 1.0 : -1.0);
		for (int k = 0; k < 16; k++) {
			hi = lo + step;
			if ((bs_gap(u + t * hi) > 0.0) != (step < 0.0)) {
				found = true;
				break;
			}
			lo = hi;
		}
		if (step < 0.0) {
			float tmp = lo;
			lo = hi;
			hi = tmp;
		}
	}
	for (int k = 0; k < halvings; k++) {
		float mid = 0.5 * (lo + hi);
		if (bs_gap(u + t * mid) > 0.0) {
			hi = mid;
		} else {
			lo = mid;
		}
	}
	return found ? u + t * hi : bs_onto_shell(u, l);
}

// The loop's frame: where it lies on the trunk (the exit), the shell's normal there, the ellipse's axes and radii, and
// which way round it runs (the orientation closer to the first ring).
void tr_loop_frame(int leg, out vec3 eu, out vec3 nrm_e, out vec3 side_t, out vec3 front_t, out float r_s, out float rf, out float rb, out float sg) {
	float l = leg_l;
	eu = lp(leg, 0, 0).xyz;
	float hd = l * 0.002;
	nrm_e = normalize(vec3(bs_gap(eu + vec3(hd, 0.0, 0.0)) - bs_gap(eu - vec3(hd, 0.0, 0.0)), bs_gap(eu + vec3(0.0, hd, 0.0)) - bs_gap(eu - vec3(0.0, hd, 0.0)), bs_gap(eu + vec3(0.0, 0.0, hd)) - bs_gap(eu - vec3(0.0, 0.0, hd))));
	vec4 r1 = lp(leg, 1, 1);
	vec4 r2 = lp(leg, 1, 2);
	vec4 r3 = lp(leg, 1, 3);
	side_t = normalize(r1.xyz - nrm_e * dot(nrm_e, r1.xyz));
	front_t = normalize(cross(nrm_e, side_t));
	r_s = min(r1.w * TR_FLARE, max(abs(eu.x) - l * 0.008, l * 0.004) / max(abs(side_t.x), 0.3));
	rf = r2.w * TR_FLARE;
	rb = r3.w * TR_FLARE;
	float d_pos = 0.0;
	float d_neg = 0.0;
	for (int j = 0; j < TR_N; j++) {
		float a = TR_PI + 2.0 * TR_PI * float(j) / float(TR_N);
		float sa = sin(a);
		vec3 ring = tr_row_ring(leg, 0, j);
		vec3 base = eu + side_t * (cos(a) * r_s);
		vec3 fr = front_t * (sa * (sa >= 0.0 ? rf : rb));
		d_pos += distance(base + fr, ring);
		d_neg += distance(base - fr, ring);
	}
	sg = d_neg < d_pos ? -1.0 : 1.0;
}

vec3 tr_loop_point(int j, vec3 eu, vec3 nrm_e, vec3 side_t, vec3 front_t, float r_s, float rf, float rb, float sg) {
	float a = TR_PI + 2.0 * TR_PI * float(tr_mod(j, TR_N)) / float(TR_N);
	float sa = sin(a);
	return tr_project(eu + side_t * (cos(a) * r_s) + front_t * (sg * sa * (sa >= 0.0 ? rf : rb)), nrm_e);
}

// The fillet's point in column j (w: 0 the loop .. 0.6), from the loop's point, the trunk's normal there and the first
// ring's point: a cubic leaving along the trunk's surface and arriving along the leg.
vec3 tr_fillet(int leg, int r, vec3 loop, vec3 sn, vec3 first) {
	float w = tr_fillet_w(r);
	vec3 to = first - loop;
	float h = length(to) * 0.45;
	vec3 p1 = loop + normalize(to - sn * dot(sn, to)) * h;
	vec3 p2 = first - lp(leg, 0, 5).xyz * h;
	float w1 = 1.0 - w;
	return loop * w1 * w1 * w1 + p1 * 3.0 * w1 * w1 * w + p2 * 3.0 * w1 * w * w + first * w * w * w;
}

// Mesh row r's point in a column whose loop point and trunk normal are given (built unscaled).
vec3 tr_point(int leg, int r, int j, vec3 loop, vec3 sn) {
	if (r >= TR_FIL) {
		return tr_tail(leg, r - TR_FIL, j);
	}
	return tr_fillet(leg, r, loop, sn, tr_tail_base(leg, 0, j));
}

// Mesh row r's centre (MeshBuild's which-way-is-out test).
vec3 tr_centre(int leg, int r) {
	if (r >= TR_FIL) {
		return lp(leg, 1 + min(r - TR_FIL, int(lp(leg, 0, 6).w + 0.5) - 1), 0).xyz;
	}
	return lp(leg, 1, 0).xyz - lp(leg, 0, 5).xyz * lp(leg, 0, 6).x * (1.0 - tr_fillet_w(r));
}

// One triangle's area-weighted normal (MeshBuild.commit: (p2 - p0) x (p1 - p0)).
vec3 tr_tri(vec3 p0, vec3 p1, vec3 p2) {
	return cross(p2 - p0, p1 - p0);
}

// The feather coordinates the trunk's chart gives a point (uv, uv2), u run on to stay by `ref` (LegRig._trunk_chart).
vec4 tr_chart(vec3 p, float ref) {
	vec4 fc = bs_uv(p);
	if (fc.z < 500.0) {
		fc.x -= fc.z * round((fc.x - ref) / fc.z);
	}
	return fc;
}

// Vertex (mesh row r: 0 .. 2 the loop and fillet, then the tail rows; column j: 0 .. 12, the last the seam) of leg
// `leg`'s feather tube.
void trouser_vertex(int leg, int r, int j, out vec3 pos, out vec3 nrm, out vec4 col, out vec2 uv, out vec2 uv2) {
	int jj = tr_mod(j, TR_N);
	int jm = tr_mod(jj - 1, TR_N);
	int jp = tr_mod(jj + 1, TR_N);
	vec3 eu;
	vec3 nrm_e;
	vec3 side_t;
	vec3 front_t;
	float r_s;
	float rf;
	float rb;
	float sg;
	tr_loop_frame(leg, eu, nrm_e, side_t, front_t, r_s, rf, rb, sg);
	// Round the loop once: its points (this column's and its neighbours'), the trunk's colour and normal there, its
	// coordinates (u run on round it), its centre, its mean v and colour.
	vec3 lc = vec3(0.0);
	vec4 csum = vec4(0.0);
	float vsum = 0.0;
	vec3 loop_m;
	vec3 loop_0;
	vec3 loop_p;
	vec3 sn_m;
	vec3 sn_0;
	vec3 sn_p;
	vec4 lcol_0;
	vec4 luv_0;          // this column's (uv, uv2), run on
	vec3 lp0;            // columns 0 and 1 (the test quad's)
	vec3 lp1;
	vec3 ln0;
	vec3 ln1;
	float u_lo = 0.0;
	float u_mid = 0.0;
	float u_hi = 0.0;
	float prev_u = 0.0;
	for (int q = 0; q < TR_N; q++) {
		vec3 p = tr_loop_point(q, eu, nrm_e, side_t, front_t, r_s, rf, rb, sg);
		vec4 c;
		vec3 n;
		tr_trunk_at(p, c, n);
		vec4 fc = bs_uv(p);
		if (q > 0 && fc.z < 500.0) {
			fc.x -= fc.z * round((fc.x - prev_u) / fc.z);
		}
		prev_u = fc.x;
		lc += p;
		csum += c;
		vsum += fc.y;
		if (q == 0) {
			lp0 = p;
			ln0 = n;
		}
		if (q == 1) {
			lp1 = p;
			ln1 = n;
		}
		if (q == TR_N / 2 - 1) {
			u_lo = fc.x;
		}
		if (q == TR_N / 2) {
			u_mid = fc.x;
		}
		if (q == TR_N / 2 + 1) {
			u_hi = fc.x;
		}
		if (q == jm) {
			loop_m = p;
			sn_m = n;
		}
		if (q == jj) {
			loop_0 = p;
			sn_0 = n;
			lcol_0 = c;
			luv_0 = fc;
		}
		if (q == jp) {
			loop_p = p;
			sn_p = n;
		}
	}
	lc /= float(TR_N);
	float st = lp(leg, 0, 0).w;
	vec4 tcol = lp(leg, 0, 7).w > 0.5 ? vec4(lp(leg, 0, 7).xyz, 1.0) : vec4(csum.xyz / float(TR_N), 1.0);
	// The position (unscaled), and the normal as MeshBuild sums it: every triangle round the vertex, by area, wound as
	// the mesh's test quad says faces out; the loop's own rows shade as the trunk does there.
	int nt = int(lp(leg, 0, 6).w + 0.5);
	int m = TR_FIL + nt;
	int ti = clamp(m / 2, 0, m - 2);
	vec3 v00 = tr_point(leg, ti, 0, lp0, ln0);
	vec3 v01 = tr_point(leg, ti, 1, lp1, ln1);
	vec3 v10 = tr_point(leg, ti + 1, 0, lp0, ln0);
	bool flip = dot(cross(v01 - v00, v10 - v00), v00 - tr_centre(leg, ti)) < 0.0;
	int r0 = max(r - 1, 0);
	int r2 = min(r + 1, TR_ROWS - 1);
	vec3 p00 = tr_point(leg, r0, jj - 1, loop_m, sn_m);
	vec3 p01 = tr_point(leg, r0, jj, loop_0, sn_0);
	vec3 p02 = tr_point(leg, r0, jj + 1, loop_p, sn_p);
	vec3 p10 = tr_point(leg, r, jj - 1, loop_m, sn_m);
	vec3 p11 = tr_point(leg, r, jj, loop_0, sn_0);
	vec3 p12 = tr_point(leg, r, jj + 1, loop_p, sn_p);
	vec3 p20 = tr_point(leg, r2, jj - 1, loop_m, sn_m);
	vec3 p21 = tr_point(leg, r2, jj, loop_0, sn_0);
	vec3 p22 = tr_point(leg, r2, jj + 1, loop_p, sn_p);
	vec3 acc = vec3(0.0);
	// quad (a b / c d) = (row, col), (row, col + 1) / (row + 1, col), (row + 1, col + 1); triangles a c b, b c d (or
	// flipped a b c, b d c): the same triangles, so the same sums, either way round but for their sign.
	if (r > 0) {
		acc += tr_tri(p01, p10, p11);                       // quad up and back: this vertex its d (triangle b c d)
		acc += tr_tri(p01, p11, p02) + tr_tri(p02, p11, p12);   // quad up: its c (both triangles)
	}
	if (r < TR_ROWS - 1) {
		acc += tr_tri(p10, p20, p11) + tr_tri(p11, p20, p21);   // quad back: its b (both)
		acc += tr_tri(p11, p21, p12);                       // its own quad: its a (triangle a c b)
	}
	if (flip) {
		acc = -acc;
	}
	nrm = dot(acc, acc) > 1e-30 ? normalize(acc) : vec3(0.0, 1.0, 0.0);
	if (r == 0) {
		nrm = sn_0;
	}
	// Drawn: the loop and fillet scaled with the trunk (as its bone, by its weight there), the rest as built.
	pos = p11;
	if (r < TR_FIL) {
		float ws = smoothstep(0.0, 1.0, tr_fillet_w(r));
		pos *= (1.0 - ws) * st + ws;
	}
	// Colours and feather coordinates.
	float unit_top = lp(leg, 0, 6).y;
	float unit_bot = lp(leg, 0, 6).z;
	float per = 2.0 * TR_PI * lp(leg, 1, 1).w * TR_FLARE / unit_top;
	vec4 luv_j = luv_0;   // (the seam column, jj 0, carries column 0's again)
	if (r < TR_FIL) {
		float ws = smoothstep(0.0, 1.0, tr_fillet_w(r));
		vec4 mixed = lcol_0 + (tcol - lcol_0) * 0.3;
		col = lcol_0 + (mixed - lcol_0) * ws;
		if (r == 0) {
			uv = luv_j.xy;
			uv2 = luv_j.zw;
		} else {
			vec4 tc = tr_chart(p11, luv_j.x);
			uv = tc.xy;
			uv2 = tc.zw;
		}
		return;
	}
	int k = min(r - TR_FIL, nt - 1);
	float bw = k == 0 ? 0.35 : (k == 1 ? 0.7 : 1.0);
	vec4 rd = lp(leg, 1 + k, 4);
	col = lcol_0 + (tcol - lcol_0) * rd.y;
	col.a = mix(1.0, 0.45, sin(TR_PI * bw));
	float sgn = sign(u_hi - u_lo);
	sgn = sgn != 0.0 ? sgn : 1.0;
	vec3 axis = lp(leg, 0, 5).xyz;
	float v = vsum / float(TR_N);
	float d_prev = -dot(lp(leg, 1, 0).xyz - lc, axis);
	float d_end = lp(leg, 1 + nt - 1, 4).x;
	for (int kk = 0; kk <= k; kk++) {
		float d = lp(leg, 1 + kk, 4).x;
		v += (d - d_prev) / mix(unit_top, unit_bot, smoothstep(0.0, d_end * 0.8, 0.5 * (d + d_prev)));
		d_prev = d;
	}
	vec2 tuv = vec2(u_mid + sgn * (float(j) / float(TR_N) - 0.5) * per, v);
	vec2 own2 = vec2(per, -0.8);
	if (bw < 1.0) {
		vec4 tc = tr_chart(p11, luv_j.x);
		uv = tc.xy + (tuv - tc.xy) * bw;
		uv2 = tc.zw + (own2 - tc.zw) * bw;
	} else {
		uv = tuv;
		uv2 = own2;
	}
}
