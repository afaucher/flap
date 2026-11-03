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
uniform sampler2D scan_disp : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
// The grain in relief (as the bark's fissures are): the scan's normals deepened, and its height (raised latewood
// ridges, eroded grooves between) bumped in, with fine ridges of its own along the grain; the ridges worn smoother
// than the grooves, so a raking sun runs highlights along the grain and the grooves stay dark.
uniform float normal_depth = 2.6;
uniform float grain_depth = 0.008;       // m from the grooves to the ridges' tops
uniform float ridge_gloss = 0.55;        // the ridges' roughness, as a share of the scan's
uniform float scan_tile = 2.0;           // m the scan covers
uniform vec3 scan_tint : source_color = vec3(1.0);
uniform vec3 beam_tint : source_color = vec3(0.8, 0.74, 0.68);   // the squared beams: heavier, darker timber
uniform float weather = 0.55;            // 0 fresh .. 1 grey all over (the sky-facing faces most)
uniform vec3 silver : source_color = vec3(0.7, 0.6, 0.48);
uniform float end_dark = 0.82;           // end grain drinks the rain: darker than the face
uniform vec2 nail_at = vec2(9.0, 9.0);   // along the plank (m from its middle): where it crosses the bearers
uniform bool nails = false;
uniform vec3 roundel_c = vec3(0.0);      // model space: the roundel's centre, its axis, radius
uniform vec3 roundel_n = vec3(1.0, 0.0, 0.0);
uniform float roundel_r = 0.13;
uniform vec3 paint_ring : source_color = vec3(0.66, 0.48, 0.15);
uniform vec3 paint_blue : source_color = vec3(0.07, 0.13, 0.4);
uniform vec3 crate_paint : source_color = vec3(0.68, 0.53, 0.2);

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
const int K_CLOTH = 8;

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
	bool wood = kind == K_BOARD || kind == K_BEAM || kind == K_ROUND;
	float up = clamp(normalize(mn).y, 0.0, 1.0);
	vec3 col = vec3(0.5);
	float rough = 0.85;
	float metal = 0.0;
	float spec = 0.35;
	float ao = 1.0;
	int flags = int(c1.w + 0.5);
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
		col = vec3(0.22, 0.15, 0.08) * (0.45 + 0.45 * hump + 0.2 * sh) * (0.75 + 0.5 * fibre);
		col = mix(col, vec3(lum(col)) * vec3(1.1, 1.0, 0.85), weather * 0.3 * up);
		rough = 0.95;
		spec = 0.2;
		float aa = 1.0 - smoothstep(0.3, 0.8, fwidth(coil));
		nrm = bump(N, dpx, dpy, (hump * 0.0018 + sh * 0.0005) * aa);
	} else if (kind == K_CLOTH) {
		// Cloth: a windsock's red and white bands (tail to mouth), a pennant halved orange and white; faded, dirty.
		vec3 red = vec3(0.42, 0.05, 0.03);
		vec3 white = vec3(0.6, 0.56, 0.48);
		float u = (L.y + H.y) / max(2.0 * H.y, 1e-4);
		float band;
		if (int(c1.z + 0.5) == 0) {
			float b5 = u * 2.5;
			band = smoothstep(0.5 - fwidth(b5), 0.5 + fwidth(b5), abs(fract(b5) - 0.5) * 2.0);
			col = mix(red, white, band);
		} else {
			band = smoothstep(-fwidth(L.x), fwidth(L.x), L.x);
			col = mix(white, vec3(0.55, 0.22, 0.03), band);
		}
		col *= 0.82 + 0.3 * vnoise(L.xy * 260.0 + s * 9.0);
		rough = 0.95;
		spec = 0.2;
	} else if (end_face && wood) {
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
			float wdt = 0.0007 * (1.0 - t) + 0.00015;
			float on = step(r0, al) * step(al, r1) * step(0.35 + 0.3 * float(i), hash12(vec2(s * 5.0, float(i) + 0.5)) + 0.35);
			chk = max(chk, (1.0 - smoothstep(wdt * 0.4, wdt, off)) * on);
		}
		col = mix(col, base * 0.25, chk * 0.85);
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
		float al = L.y;   // (along the scan's boards)
		if (round_piece) {
			float rr = length(L.xz);
			float arc = atan(L.z, L.x) * rr;
			float per = BOARD_USE * 0.9;
			c = abs(fract(arc / (2.0 * per) + 0.5) - 0.5) * 2.0 * per - per * 0.5;   // (a triangle wave: no seam)
			cw = per * 0.5;
			fid = 0.0;
		} else if (end_face) {   // (the ends of a painted box: no end grain under the paint)
			c = L.x;
			cw = H.x;
			fid = 2.0;
			al = L.z;
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
		vec2 f = vec2(cc * m, al * vdir);
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
		float wst = vnoise(vec2(al * 3.0, c * 60.0 + s * 17.0));
		float grey = clamp(weather * (0.5 + 0.6 * wst) * (0.45 + 0.55 * up) + (s - 0.5) * 0.3, 0.0, 1.0);
		col = mix(alb, vec3(lum(alb)) * silver / max(lum(silver), 0.01) * 1.15, grey * 0.5);
		// Sunlit old timber: warmer and more contrasty than the scan -- the weathered face pale, the grain's dark
		// lines and the cracks deep (contrast about a mid grey, then a little more colour).
		col *= clamp(pow(max(lum(col), 1e-3) / 0.16, 0.4), 0.55, 1.3);
		col = max(mix(vec3(lum(col)), col, 1.15), vec3(0.0));
		// Worn arrises: the bevels pale where hands and feet and sun have been.
		float arris = smoothstep(0.3, 0.45, min(abs(nl.x), abs(nl.z))) * (round_piece ? 0.0 : 1.0);
		col = mix(col, col * 1.3 + 0.015, arris * 0.6);
		col = mix(col, col * 0.15, groove);
		// A board laid edge to edge with others: its edges are down in the gaps, in shadow, darker toward the bottom.
		if ((flags & 4) == 4 && abs(nl.x) > 0.85) {
			float hgt = clamp((L.z + H.z) / max(2.0 * H.z, 1e-4), 0.0, 1.0);
			col *= mix(0.12, 0.45, hgt);
			ao = mix(0.15, 0.55, hgt);
		}
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
		vec2 nxy = (sn.xy * 2.0 - 1.0) * normal_depth;
		nxy.x *= m;
		nxy.y *= vdir;
		vec3 nt = normalize(vec3(nxy, 1.0));
		nrm = normalize(T * nt.x - B * nt.y + N * nt.z);
		// The grain's relief: the scan's height, and fine ridges along the grain (they fade out with distance, where
		// a pixel spans several: no shimmer).
		float hd = textureGrad(scan_disp, uv, gx, gy).r;
		float fine = 1.0 - smoothstep(0.3, 1.0, fwidth(cc) * 220.0);
		float wav = vnoise(vec2(cc * 35.0 + s * 7.0, al * 1.5)) * 3.0 + vnoise(vec2(cc * 90.0, al * 6.0));   // (rings wander)
		float rid = smoothstep(0.35, 0.85, vnoise(vec2(cc * 220.0 + wav + s * 13.0, al * 2.0))) * vnoise(vec2(cc * 40.0, al * 0.8 + s * 3.0));
		float hg = mix(hd, hd * 0.85 + rid * 0.15, fine);
		nrm = bump(nrm, dpx, dpy, (hg - 0.5) * grain_depth);
		float ridge = smoothstep(0.5, 0.8, hg);
		rough = mix(min(rough * 1.08, 1.0), rough * ridge_gloss, ridge);
		ao *= mix(0.4, 1.0, smoothstep(0.15, 0.6, hd));
		col *= mix(0.72, 1.06, smoothstep(0.2, 0.75, hg));   // (dirt and shade down in the grooves, the ridges sun-bleached)
		spec = 0.5;
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
			rough = mix(0.42, rough, chips);
			metal = mix(0.5, 0.0, chips);   // (painted sheet over the box: a little of the metal's sheen)
			nrm = normalize(mix(N, nrm, 0.35 + 0.65 * chips));
			// Stencilled marks on the panels of the front and back: two lines of blocky lettering, worn.
			if ((flags & 2) == 2 && abs(nl.z) > 0.8) {
				vec2 q = vec2(L.y, L.x);   // (along the box, up it)
				float line = q.y > 0.004 && q.y < 0.016 ? 1.0 : (q.y > -0.014 && q.y < -0.004 ? 2.0 : 0.0);
				float gw = line == 1.0 ? 0.0085 : 0.0065;
				float x0 = line == 1.0 ? -0.042 : -0.03;
				float g = floor((q.x - x0) / gw);
				float gx = (q.x - x0) / gw - g;
				float gy = line == 1.0 ? (q.y - 0.004) / 0.012 : (q.y + 0.014) / 0.01;
				float ng = line == 1.0 ? 10.0 : 9.0;
				float on = 0.0;
				if (line > 0.0 && g >= 0.0 && g < ng && gx < 0.72 && hash12(vec2(g, line * 7.0 + s)) > 0.12) {
					vec2 cell = floor(vec2(gx / 0.72 * 3.0, gy * 5.0));
					on = step(0.42, hash12(cell + vec2(g * 3.1, line * 11.0) + floor(s * 4.0)));
				}
				on *= 1.0 - smoothstep(0.55, 0.75, vnoise(q * 700.0 + s * 13.0));   // (worn)
				col = mix(col, vec3(0.05, 0.04, 0.025), on * 0.85);
			}
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
				pc *= 0.74 + 0.3 * wl;                                        // (the grain through thin paint)
				// Faded evenly by the sun, softly patchy, thinner where it's faded most; a few small chips, and
				// worn off along the boards' arrises.
				float fade = vnoise(L.xy * vec2(8.0, 6.0) + s * 5.0) * 0.6 + vnoise(L.xy * 26.0 + 3.0) * 0.4;
				pc = mix(pc, vec3(lum(pc)) * 1.15 + 0.04, 0.1 + 0.22 * smoothstep(0.3, 0.85, fade));
				cover *= mix(0.95, 0.72, smoothstep(0.35, 0.9, fade));
				float chip = smoothstep(0.8, 0.84, vnoise(L.xy * 110.0 + s * 21.0) * 0.8 + vnoise(L.xy * 520.0) * 0.2);
				chip = max(chip, smoothstep(cw - 0.004, cw, abs(c)) * 0.8);
				cover *= 1.0 - chip;
				col = mix(col, pc, cover);
				rough = mix(rough, 0.7, cover);
			}
		}
	}
	ALBEDO = col;
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	NORMAL = nrm;
}
