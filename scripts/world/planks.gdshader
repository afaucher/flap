// Weathered timber and its ironwork for the outposts (TimberMesh's pieces, and ArenaBuilder._plank_mesh's planks).
// Every vertex carries its piece's own frame (TimberMesh): (across, along, through) in metres from the piece's
// middle, its half size, kind, seed, pith and scan board. Each face finds its normal in that frame, so:
//  - long faces (the grain along them) take the weathered-planks photoscan at its true scale -- one scan board
//    per board, the top and each edge from a different part of it (an edge maps by the through-board
//    coordinate), a face wider than a board laid as several with a groove between, a round piece's scan
//    wrapped round it -- greyed by the weather where the sky reaches;
//  - end faces (the grain coming out of them) draw end grain: growth rings round the pith (off the board for a
//    sawn plank, so they read as arcs; inside a squared beam; on the axis of a round rail), dark latewood,
//    radial checks, faint saw marks, coloured from the board's own scan, relief by a derivative bump (an end
//    face has no useful tangent frame);
//  - iron (bolts, washers, plates: dark, rusting), brass and olive paint (the ammo boxes), the dark inside of
//    the hangar, and rope (coiled round the rail).
// A roundel can be painted (flag PAINTED): weathered, chipped along the grain, the grain and board gaps
// showing through. Nail heads where the planks cross the bearers (`nail_at`, along the plank).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D scan_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scan_tile = 2.0;           // m the scan covers
uniform vec3 scan_tint : source_color = vec3(1.0);
uniform vec3 beam_tint : source_color = vec3(0.8, 0.74, 0.68);   // the squared beams: heavier, darker timber
uniform float weather = 0.55;            // 0 fresh .. 1 grey all over (the sky-facing faces most)
uniform vec3 silver : source_color = vec3(0.6, 0.58, 0.54);
uniform float end_dark = 0.82;           // end grain drinks the rain: darker than the face
uniform vec2 nail_at = vec2(9.0, 9.0);   // along the plank (m from its middle): where it crosses the bearers
uniform bool nails = false;
uniform vec3 roundel_c = vec3(0.0);      // model space: the roundel's centre, its axis, radius
uniform vec3 roundel_n = vec3(1.0, 0.0, 0.0);
uniform float roundel_r = 0.13;
uniform vec3 paint_ring : source_color = vec3(0.66, 0.48, 0.15);
uniform vec3 paint_blue : source_color = vec3(0.1, 0.16, 0.42);
uniform vec3 crate_paint : source_color = vec3(0.42, 0.34, 0.13);

// The scan's boards: nine across, the first gap at u = SCAN_GAP0, one board every SCAN_PITCH; its two rows of
// nails at v = 0.293 and 0.70 (stepped over: our nails are where our bearers are).
const float SCAN_GAP0 = 0.0605;
const float SCAN_PITCH = 0.1113;
const float BOARD_USE = 0.205;           // m of a scan board clear of its gaps (one board: 0.223 m)

const int K_BOARD = 0;
const int K_ROUND = 1;
const int K_BEAM = 2;
const int K_IRON = 3;
const int K_DARK = 4;
const int K_BRASS = 5;
const int K_PAINT = 6;
const int K_ROPE = 7;

varying vec3 lp;          // the piece's frame: (across, along, through), m
varying vec3 mp;          // model space
varying vec3 mn;          // model-space normal
varying flat vec4 c0;
varying flat vec4 c1;
varying flat float seed;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void vertex() {
	lp = vec3(UV.x, UV.y, UV2.x);
	mp = VERTEX;
	mn = NORMAL;
	c0 = CUSTOM0;
	c1 = CUSTOM1;
	vec3 o = NODE_POSITION_WORLD;
	seed = fract(UV2.y + hash12(o.xz * 3.1 + o.y));
}

// A bumped normal from a height h (m) over the surface, by its screen derivatives (Mikkelsen 2010).
vec3 bump(vec3 n, vec3 dpx, vec3 dpy, float h) {
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 g = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - g);
}

void fragment() {
	int kind = int(c0.w + 0.5);
	vec3 H = c0.xyz;
	vec3 L = lp;
	float s = seed;
	vec3 N = normalize(NORMAL);
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	bool round_piece = kind == K_ROUND || kind == K_ROPE;
	// The face's own normal in the piece's frame (flat faces: from the frame's derivatives, outward).
	vec3 nl = cross(dFdx(L), dFdy(L));
	nl = nl / max(length(nl), 1e-12);
	if (dot(nl, L) < 0.0) {
		nl = -nl;
	}
	if (round_piece && abs(nl.y) < 0.6) {
		nl = normalize(vec3(L.x, 0.0, L.z));
	}
	bool end_face = abs(nl.y) > 0.6;
	float up = clamp(normalize(mn).y, 0.0, 1.0);
	vec3 col = vec3(0.5);
	float rough = 0.85;
	float metal = 0.0;
	float spec = 0.35;
	vec3 nrm = N;
	if (kind == K_DARK) {
		col = vec3(0.004, 0.003, 0.0025);
		rough = 1.0;
		spec = 0.1;
	} else if (kind == K_IRON || kind == K_BRASS) {
		float n1 = vnoise(L.xy * 900.0 + L.z * 700.0 + s * 37.0);
		float n2 = vnoise(L.xy * 180.0 + L.z * 150.0 + s * 11.0);
		if (kind == K_IRON) {
			float rust = smoothstep(0.45, 0.85, n2 * 0.7 + n1 * 0.3);
			col = mix(vec3(0.018, 0.016, 0.014), vec3(0.15, 0.05, 0.015), rust * 0.8);
			col = mix(col, vec3(0.06, 0.058, 0.055), smoothstep(0.75, 0.95, n1) * 0.5);   // (bright worn spots)
			metal = mix(0.35, 0.05, rust);
			rough = mix(0.55, 0.9, rust);
		} else {
			float tarnish = smoothstep(0.3, 0.9, n2);
			col = mix(vec3(0.42, 0.27, 0.06), vec3(0.13, 0.1, 0.035), tarnish * 0.7);
			metal = 0.75;
			rough = mix(0.28, 0.6, tarnish);
		}
		spec = 0.5;
		nrm = bump(N, dpx, dpy, (n1 - 0.5) * 0.00015);
	} else if (kind == K_ROPE) {
		// Rope wound round the rail: coils one rope across, each twisted from three strands, fibres along them.
		float th = atan(L.z, L.x);
		float rr = length(L.xz);
		float coil = L.y / 0.011 + th / (2.0 * PI);
		float cf = fract(coil);
		float hump = sin(PI * cf);
		float strand = fract(cf * 2.0 + th * 3.0 / PI);
		float sh = sin(PI * strand);
		float fibre = vnoise(vec2(coil * 6.0, th * rr * 900.0 + s * 9.0));
		col = vec3(0.21, 0.13, 0.055) * (0.45 + 0.45 * hump + 0.2 * sh) * (0.75 + 0.5 * fibre);
		col = mix(col, vec3(lum(col)) * vec3(1.1, 1.0, 0.85), weather * 0.3 * up);
		rough = 0.95;
		spec = 0.2;
		float aa = 1.0 - smoothstep(0.3, 0.8, fwidth(coil));
		nrm = bump(N, dpx, dpy, (hump * 0.0018 + sh * 0.0005) * aa);
	} else if (end_face) {
		// End grain: rings round the pith, in the face's section (across, through).
		vec2 q = vec2(L.x, L.z);
		vec2 P = round_piece ? vec2(0.0) : c1.xy;
		vec2 d = q - P;
		float r = length(d);
		float th = atan(d.y, d.x);
		float rs = mix(0.0024, 0.0042, hash12(vec2(s, 3.7)));    // ring spacing, m (pine: a few mm)
		float wob = 0.0016 * (vnoise(vec2(th * 4.0 + s * 20.0, r * 25.0)) - 0.5) + 0.006 * r * (vnoise(vec2(th * 1.5 + s * 7.0, 2.0)) - 0.5);
		float rings = (r + wob) / rs;
		rings += 0.7 * (vnoise(vec2(rings * 0.3, s * 11.0)) - 0.5);   // (the years: some rings wide, some tight)
		float f = fract(rings);
		float late = smoothstep(0.58, 0.78, f) * (1.0 - smoothstep(0.9, 1.0, f));
		float aa = 1.0 - smoothstep(0.35, 0.9, fwidth(rings));
		late *= aa;
		float board = c1.z >= 0.0 ? c1.z : floor(s * 9.0);
		vec3 base = textureLod(scan_albedo, vec2(SCAN_GAP0 + (board + 0.5) * SCAN_PITCH, 0.5 + s * 0.3), 7.0).rgb * scan_tint;
		if (kind == K_BEAM) {
			base *= beam_tint;
		}
		base = mix(base, vec3(lum(base)) * vec3(1.08, 1.0, 0.9), 0.25) * end_dark;
		vec3 ew = base * vec3(1.22, 1.14, 1.04);
		vec3 lw = base * vec3(0.52, 0.46, 0.4);
		col = mix(ew, lw, late * (kind == K_BOARD ? 0.65 : 0.75));
		// The heart of a round or boxed-heart piece: darker heartwood, paler sapwood outside.
		float rmax = round_piece ? H.x : length(H.xz);
		if (kind != K_BOARD) {
			col *= mix(0.86, 1.06, smoothstep(0.45, 0.8, r / rmax));
		}
		col *= 0.88 + 0.24 * vnoise(q * 1400.0 + s * 5.0);
		// Radial checks: a few thin cracks out from the pith (from the surface in, on a board).
		float chk = 0.0;
		for (int i = 0; i < 3; i++) {
			float a = hash12(vec2(s * 13.0, float(i) * 7.1)) * 2.0 * PI;
			vec2 dir = vec2(cos(a), sin(a));
			float al = dot(d, dir);
			float off = abs(dot(d, vec2(-dir.y, dir.x)) + 0.0006 * sin(al * 300.0 + float(i)));
			float r0 = kind == K_BOARD ? length(P) - 0.2 * length(H.xz) : 0.004;
			float r1 = kind == K_BOARD ? length(P) + 0.3 * length(H.xz) : rmax * mix(0.4, 0.95, hash12(vec2(s, float(i))));
			float t = clamp((al - r0) / max(r1 - r0, 1e-4), 0.0, 1.0);
			float wdt = 0.0009 * (1.0 - t) + 0.0002;
			float on = step(r0, al) * step(al, r1) * step(0.35 + 0.3 * float(i), hash12(vec2(s * 5.0, float(i) + 0.5)) + 0.35);
			chk = max(chk, (1.0 - smoothstep(wdt * 0.4, wdt, off)) * on);
		}
		col = mix(col, base * 0.18, chk * 0.9);
		// Saw marks: faint parallel kerfs, slightly curved (a big circular blade).
		float sa = hash12(vec2(s, 9.1)) * PI;
		vec2 sd = vec2(cos(sa), sin(sa));
		float kerf = sin((dot(q, sd) + dot(q, q) * 0.6) * 2.0 * PI / 0.0021 + vnoise(q * 80.0) * 2.0);
		float kaa = 1.0 - smoothstep(0.3, 0.8, fwidth(dot(q, sd) / 0.0021));
		col *= 1.0 + 0.05 * kerf * kaa;
		// Weathered: greyer where the sky reaches, and paler at the face's own edge (sun-bleached arris).
		float grey = clamp(weather * (0.3 + 0.4 * up) + (s - 0.5) * 0.2, 0.0, 1.0);
		col = mix(col, vec3(lum(col)) * silver / max(lum(silver), 0.01) * 1.05, grey * 0.45);
		float edge = round_piece ? smoothstep(H.x * 0.86, H.x, r) : max(smoothstep(H.x - 0.006, H.x, abs(L.x)), smoothstep(H.z - 0.004, H.z, abs(L.z)));
		col = mix(col, col * 1.25 + 0.02, edge * 0.5);
		rough = 0.92;
		spec = 0.25;
		float h = (late - 0.5) * 0.00025 - chk * 0.0012 + kerf * kaa * 0.00003;
		nrm = bump(N, dpx, dpy, h);
	} else {
		// Long faces: the scan, at its true scale, the grain along the piece.
		float c;
		float cw;
		float fid;
		if (round_piece) {
			float rr = length(L.xz);
			float arc = atan(L.z, L.x) * rr;
			float per = BOARD_USE * 0.9;
			c = abs(fract(arc / (2.0 * per) + 0.5) - 0.5) * 2.0 * per - per * 0.5;   // (a triangle wave: no seam)
			cw = per * 0.5;
			fid = 0.0;
		} else if (abs(nl.z) >= abs(nl.x)) {
			c = L.x;
			cw = H.x;
			fid = nl.z > 0.0 ? 0.0 : 3.0;
		} else {
			c = L.z;
			cw = H.z;
			fid = nl.x > 0.0 ? 5.0 : 7.0;
		}
		// A face wider than one scan board is laid as several, side by side.
		float nb = max(1.0, ceil(2.0 * cw / BOARD_USE - 0.001));
		float sw = 2.0 * cw / nb;
		float x = c + cw;
		float sub = clamp(floor(x / sw), 0.0, nb - 1.0);
		float cc = x - (sub + 0.5) * sw;
		float seam = abs(x - floor(x / sw + 0.5) * sw);
		float groove = nb > 1.0 && x > sw * 0.5 && x < 2.0 * cw - sw * 0.5 ? 1.0 - smoothstep(0.0012, 0.0028, seam) : 0.0;
		float board = c1.z >= 0.0 ? c1.z : floor(s * 9.0);
		float oseed = hash12(vec2(s * 17.0, fid + sub * 3.0));
		board = mod(board + fid + sub * 4.0, 9.0);
		float m = oseed > 0.5 ? -1.0 : 1.0;                       // (the board turned over)
		float vdir = hash12(vec2(oseed, 4.0)) > 0.5 ? -1.0 : 1.0;  // (and end for end)
		float slack = max(0.0, 0.2825 - H.y / scan_tile);
		vec2 f = vec2(cc * m, L.y * vdir);
		vec2 uv = vec2(SCAN_GAP0 + (board + 0.5) * SCAN_PITCH, 0.9965 + (hash12(vec2(oseed, 8.0)) - 0.5) * 2.0 * slack) + f / scan_tile;
		vec2 gx = dFdx(f) / scan_tile;
		vec2 gy = dFdy(f) / scan_tile;
		float vv = fract(uv.y);
		uv.y += (abs(vv - 0.293) < 0.012 || abs(vv - 0.7) < 0.012) ? 0.03 : 0.0;
		vec3 alb = textureGrad(scan_albedo, uv, gx, gy).rgb * scan_tint;
		vec3 sn = textureGrad(scan_normal, uv, gx, gy).rgb;
		rough = textureGrad(scan_arm, uv, gx, gy).g;
		if (kind == K_BEAM) {
			alb *= beam_tint;
		}
		// The weather: silver-grey where the sky reaches, streaked along the grain.
		float wst = vnoise(vec2(L.y * 3.0, c * 60.0 + s * 17.0));
		float grey = clamp(weather * (0.5 + 0.6 * wst) * (0.45 + 0.55 * up) + (s - 0.5) * 0.3, 0.0, 1.0);
		col = mix(alb, vec3(lum(alb)) * silver / max(lum(silver), 0.01) * 1.12, grey * 0.7);
		// Worn arrises: the bevels pale where hands and feet and sun have been.
		float arris = smoothstep(0.3, 0.45, min(abs(nl.x), abs(nl.z))) * (round_piece ? 0.0 : 1.0);
		col = mix(col, col * 1.3 + 0.015, arris * 0.6);
		col = mix(col, col * 0.15, groove);
		// The tangent frame of the scan on this face, from the derivatives (no mesh tangents needed).
		vec3 dp2perp = cross(dpy, N);
		vec3 dp1perp = cross(N, dpx);
		vec2 dfx = dFdx(f);
		vec2 dfy = dFdy(f);
		vec3 T = dp2perp * dfx.x + dp1perp * dfy.x;
		vec3 B = dp2perp * dfx.y + dp1perp * dfy.y;
		float im = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-20));
		T *= im;
		B *= im;
		vec2 nxy = sn.xy * 2.0 - 1.0;
		nxy.x *= m;
		nxy.y *= vdir;
		vec3 nt = vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
		nrm = normalize(T * nt.x - B * nt.y + N * nt.z);
		if (groove > 0.0) {
			nrm = bump(nrm, dpx, dpy, -groove * 0.002);
		}
		// Nail heads where a plank crosses a bearer: two at each, on its top.
		if (nails && nl.z > 0.8) {
			float nail = 0.0;
			for (int e = 0; e < 2; e++) {
				for (int k = -1; k <= 1; k += 2) {
					vec2 np = vec2(float(k) * H.x * 0.55 + (hash12(vec2(s, float(e * 2 + k))) - 0.5) * 0.012, nail_at[e] + (hash12(vec2(s * 3.0, float(e * 2 + k))) - 0.5) * 0.01);
					float dn = length(L.xy - np);
					nail = max(nail, 1.0 - smoothstep(0.0038, 0.0048, dn));
					col *= 1.0 - 0.35 * (1.0 - smoothstep(0.004, 0.011, dn));   // (the rust and dirt round it)
				}
			}
			vec3 iron = mix(vec3(0.09, 0.085, 0.08), vec3(0.3, 0.16, 0.08), vnoise(L.xy * 1500.0) * 0.6);
			col = mix(col, iron, nail);
			metal = nail * 0.5;
			rough = mix(rough, 0.6, nail);
		}
		// Olive paint on the ammo boxes, worn through at the edges and in chips.
		if (kind == K_PAINT) {
			float chips = smoothstep(0.72, 0.8, vnoise(L.xy * vec2(90.0, 25.0) + s * 30.0) * 0.75 + vnoise(L.xy * 500.0) * 0.25);
			float near_edge = max(smoothstep(H.x - 0.006, H.x, abs(L.x)), max(smoothstep(H.y - 0.006, H.y, abs(L.y)), smoothstep(H.z - 0.006, H.z, abs(L.z))));
			vec3 pc = crate_paint * (0.75 + 0.5 * lum(alb) / 0.3) * (0.9 + 0.2 * wst);
			col = mix(pc, alb, max(chips, near_edge * 0.6));
			rough = mix(0.55, rough, chips);
			nrm = normalize(mix(N, nrm, 0.35 + 0.65 * chips));
		}
		// The roundel, painted on the boards: rings, faded, chipped along the grain, the grain showing through.
		if ((int(c1.w + 0.5) & 1) == 1 && dot(normalize(mn), roundel_n) > 0.7) {
			vec3 rel = mp - roundel_c;
			float rr = length(rel - dot(rel, roundel_n) * roundel_n) / roundel_r;
			if (rr < 1.03) {
				float aaw = fwidth(rr) * 1.2;
				vec3 pc = paint_ring;
				pc = mix(pc, paint_blue, 1.0 - smoothstep(0.86 - aaw, 0.86 + aaw, rr));
				pc = mix(pc, paint_ring, 1.0 - smoothstep(0.42 - aaw, 0.42 + aaw, rr));
				float cover = 1.0 - smoothstep(1.0 - aaw, 1.0 + aaw, rr);
				float wl = lum(alb) / 0.3;
				pc *= 0.72 + 0.32 * wl;                                       // (the grain through thin paint)
				pc = mix(pc, vec3(lum(pc)) * 1.2 + 0.03, 0.1 + 0.12 * wst);  // (faded, chalky)
				float peel = vnoise(vec2(L.y * 14.0, c * 170.0) + s * 9.0) * 0.7 + vnoise(L.xy * 400.0) * 0.3;
				float chip = smoothstep(0.66, 0.72, peel + 0.25 * smoothstep(cw - 0.012, cw, abs(c)));
				cover *= 1.0 - chip;
				col = mix(col, pc, cover * 0.92);
				rough = mix(rough, 0.7, cover);
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	NORMAL = nrm;
}
