// The neck's surface on the GPU (BirdRig.gpu_body): the same loft as BirdRig._loft_neck, each vertex worked out from
// its row and column, the pose's few numbers and the bird's fixed tables -- position, the smoothed normal (as LoftMesh
// sums its triangles' normals), colour and feather coordinates. Included by the body shader (drawing) and by the
// capture shader tests read back (tests/gpu_test_neck.gd).
//
// neck_tab (RGBA32F, 60 wide; written once):
//   y0: the head's neck ring, 60 points (head space, from the mean of every third)
//   y1: their colours      y2: their feather coordinates (uv, uv2)      y3: the trunk's front ring, 20 points (unscaled,
//   from its centre)       y4: its feather coordinates (uv, uv2; 21, the seam again)
//   y5: the head ring's u run on round the ring (x), and what one lap adds (y, in x = 0)
//   y6 + row: the body's colour carried up the neck, per row (mesh order) and column
//   y16: the trunk ring's way on forward (20, unit)    y17: its normals
//   y18: the head ring's way up into the head (60, head space, unit)    y19: its normals
//   y20 + row: the head's colours carried down the neck, per row (mesh order) and head ring point
uniform sampler2D neck_tab : filter_nearest, repeat_disable;
uniform vec3 neck_ca;      // the trunk's ring centre (scaled)
uniform vec3 neck_p1;      // the centreline's two control points
uniform vec3 neck_p2;
uniform vec3 neck_cb;      // the head ring's centre
uniform mat3 neck_hb;      // the head's basis
uniform float neck_st;     // the trunk's scale (fluff, breath)
uniform int neck_r;        // the pairing: column j meets head point (r +- 3 j) mod 60
uniform int neck_rev;
uniform float neck_ub_off; // the head's u, unwrapped to run on from the trunk's
uniform float neck_flip;   // the normals' sign (LoftMesh._flip)
uniform vec4 neck_k;       // BirdRig.NECK_OUT, NECK_IN, NECK_FULL, NECK_PACK

const int NK_ROWS = 10;
const int NK_AROUND = 20;
const int NK_HEAD = 60;

int nk_mod(int a, int n) {
	int r = a - (a / n) * n;
	return r < 0 ? r + n : r;
}

int nk_lin(int j) {   // the head point column j meets, not wrapped
	return neck_r + (neck_rev != 0 ? -3 * j : 3 * j);
}

float nk_u(int i) {   // BirdRig._neck_u: row i (mesh order) along the neck, 0 the trunk .. 1 the head
	float t = float(NK_ROWS - 1 - i) / float(NK_ROWS - 1);
	return t - neck_k.w * sin(6.28318530718 * t) / 6.28318530718;
}

// Each lengthwise line its own cubic, leaving the trunk along its surface and entering the head along its (BirdRig._loft_neck).
vec3 nk_pos(int i, int j) {
	int jj = nk_mod(j, NK_AROUND);
	int m = nk_mod(nk_lin(jj), NK_HEAD);
	float u = nk_u(i);
	float v = 1.0 - u;
	vec3 c = neck_ca * v * v * v + neck_p1 * 3.0 * v * v * u + neck_p2 * 3.0 * v * u * u + neck_cb * u * u * u;
	float s = smoothstep(0.0, 1.0, u);
	float dl = distance(neck_ca, neck_cb);
	vec3 tb = normalize(neck_cb - neck_p2);
	float w1 = 3.0 * v * v * u * neck_k.x * dl;
	float w2 = 3.0 * v * u * u * neck_k.y * dl;
	float bump = 64.0 * pow(u * v, 3.0);
	vec3 oa = texelFetch(neck_tab, ivec2(jj, 3), 0).xyz * neck_st;
	vec3 ob = neck_hb * texelFetch(neck_tab, ivec2(m, 0), 0).xyz;
	vec3 ta = texelFetch(neck_tab, ivec2(jj, 16), 0).xyz;
	vec3 tbj = normalize(neck_hb * texelFetch(neck_tab, ivec2(m, 18), 0).xyz) - tb;
	return c + (oa + (ob - oa) * s) * (1.0 + neck_k.z * bump) + (ta - vec3(0.0, 0.0, -1.0)) * w1 - tbj * w2;
}

// LoftMesh.normals: every triangle's unit normal summed at its corners (quads a b / c d: triangles a c b, b c d), over
// the four quads round the vertex -- its 3 x 3 neighbours, each placed once.
vec3 nk_normal(int i, int j) {
	if (i == 0) {   // the head ring: the head's own normals (LoftMesh.pin_first)
		return normalize(neck_hb * texelFetch(neck_tab, ivec2(nk_mod(nk_lin(nk_mod(j, NK_AROUND)), NK_HEAD), 19), 0).xyz);
	}
	if (i == NK_ROWS - 1) {   // the trunk ring: the trunk's (pin_last)
		return texelFetch(neck_tab, ivec2(nk_mod(j, NK_AROUND), 17), 0).xyz;
	}
	vec3 g[9];
	for (int di = -1; di <= 1; di++) {
		for (int dj = -1; dj <= 1; dj++) {
			int qi = clamp(i + di, 0, NK_ROWS - 1);
			g[(di + 1) * 3 + dj + 1] = nk_pos(qi, j + dj);
		}
	}
	vec3 acc = vec3(0.0);
	for (int di = -1; di <= 0; di++) {
		int qi = i + di;
		if (qi < 0 || qi > NK_ROWS - 2) {
			continue;
		}
		for (int dj = -1; dj <= 0; dj++) {
			vec3 a = g[(di + 1) * 3 + dj + 1];
			vec3 b = g[(di + 1) * 3 + dj + 2];
			vec3 c = g[(di + 2) * 3 + dj + 1];
			vec3 d = g[(di + 2) * 3 + dj + 2];
			vec3 f1 = cross(c - a, b - a);
			vec3 f2 = cross(c - b, d - b);
			f1 = dot(f1, f1) > 1e-24 ? normalize(f1) : vec3(0.0);
			f2 = dot(f2, f2) > 1e-24 ? normalize(f2) : vec3(0.0);
			if (di == 0 && dj == 0) {
				acc += f1;               // this vertex is a
			} else if (di == 0) {
				acc += f1 + f2;          // b
			} else if (dj == 0) {
				acc += f1 + f2;          // c
			} else {
				acc += f2;               // d
			}
		}
	}
	acc *= neck_flip;
	return dot(acc, acc) > 1e-30 ? normalize(acc) : vec3(0.0, 1.0, 0.0);
}

// Vertex (row i, column j: 0 .. 20, the last the seam) of the neck.
void neck_vertex(int i, int j, out vec3 pos, out vec3 nrm, out vec4 col, out vec2 uv, out vec2 uv2) {
	int jj = nk_mod(j, NK_AROUND);
	pos = nk_pos(i, jj);
	nrm = nk_normal(i, jj);
	float u = nk_u(i);
	float s = smoothstep(0.0, 1.0, u);
	int m = nk_mod(nk_lin(jj), NK_HEAD);
	vec4 c_body = texelFetch(neck_tab, ivec2(jj, 6 + i), 0);
	col = c_body + (texelFetch(neck_tab, ivec2(m, 20 + i), 0) - c_body) * smoothstep(0.2, 0.9, u);   // (BirdRig._head_share)
	vec4 ta = texelFetch(neck_tab, ivec2(j, 4), 0);
	vec4 hb = texelFetch(neck_tab, ivec2(m, 2), 0);
	int q = nk_lin(j);
	int lap = (q - nk_mod(q, NK_HEAD)) / NK_HEAD;
	vec2 ub = vec2(texelFetch(neck_tab, ivec2(nk_mod(q, NK_HEAD), 5), 0).x + float(lap) * texelFetch(neck_tab, ivec2(0, 5), 0).y + neck_ub_off, hb.y);
	uv = ta.xy + (ub - ta.xy) * s;
	uv2 = ta.zw + (hb.zw - ta.zw) * s;
}
