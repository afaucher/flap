// The pine wood's floor, in world metres: needle litter (the photoscan, warm and dry) heaped in low mounds; moss in
// the hollows between them (cushions of green, soft and lumpy, its own relief -- no needles drawn through it); bare
// dirt in patches (dark, gritty, flat); and in the openings -- the clearing, the glade, the gaps (`openings`) -- a
// short sward, greener, no mounds. Each patch's edge is ragged but sharp enough to read from the air. The mounds are
// real height where the mesh is fine enough (`displace`: the floor mesh under the wood, ArenaBuilder._ground); the
// big plane round it draws only past `hole_r`. The fine detail fades with distance so it doesn't shimmer.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 litter : source_color = vec3(0.27, 0.22, 0.16);
uniform vec3 litter_hi : source_color = vec3(0.4, 0.33, 0.24);
uniform vec3 moss : source_color = vec3(0.17, 0.27, 0.06);
uniform vec3 moss_hi : source_color = vec3(0.34, 0.42, 0.1);
uniform vec3 earth : source_color = vec3(0.15, 0.11, 0.08);
uniform vec3 sward : source_color = vec3(0.26, 0.3, 0.1);
// The photoscan of pine-needle litter (assets/LICENSES.md), when given: the base, at `scan_tile` m, sampled at two
// scales and rotations blended by noise so its 2 m repeat doesn't show from the air.
uniform bool use_scan = false;
uniform sampler2D scan_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scan_tile = 2.0;
uniform vec3 scan_tint : source_color = vec3(1.0);
// The patches: how much of the floor is moss (the hollows) and bare dirt.
uniform float moss_amount = 0.5;
uniform float dirt_amount = 0.5;
// The mounds: their height (m), drawn as height where this mesh is fine (0 on the big plane); none past fade_r.
uniform float displace = 0.0;
uniform float mound_h = 0.22;
uniform float fade_r = 95.0;
uniform float hole_r = 0.0;   // (the big plane: nothing drawn inside this, where the fine mesh is)
// The openings: xy centre, z radius, w its edge's phase (Pinewood.edge's wobble); the first `opening_count`.
uniform vec4 openings[16];
uniform int opening_count = 0;

varying vec2 wxz;
varying float v_mound;

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

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + 1.7;
		a *= 0.5;
	}
	return s;
}

float fbm3(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + 1.7;
		a *= 0.5;
	}
	return s / 0.875;
}

// How far inside an opening p is: 1 well in, 0 outside (the edge ragged as Pinewood.edge draws it, 3 m soft).
float open_mask(vec2 p) {
	float m = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= opening_count) {
			break;
		}
		vec4 o = openings[i];
		vec2 d = p - o.xy;
		float a = atan(d.y, d.x);
		float r = o.z * (1.0 + 0.14 * sin(3.0 * a + o.w) + 0.08 * sin(5.0 * a + o.w * 2.3));   // (as Pinewood.edge)
		m = max(m, 1.0 - smoothstep(r - 3.0, r + 1.0, length(d)));
	}
	return m;
}

// The patches at p: x moss (in the hollows), y bare dirt, z the sward of the openings; the litter is what's left.
vec3 patches(vec2 p) {
	float big = fbm3(p * 0.07);
	float mid = fbm3(p * 0.33 + 3.0);
	float edge = (vnoise(p * 2.3 + 11.0) - 0.5) * 0.06;   // (a ragged edge, not a blur)
	float lo = 0.7 - moss_amount * 0.12;   // (0.5: about a fifth of the floor)
	float moss_m = smoothstep(lo, lo + 0.04, big * 0.6 + mid * 0.45 + edge);
	float dlo = 0.7 - dirt_amount * 0.1;
	float dirt_m = smoothstep(dlo, dlo + 0.04, fbm3(p * 0.19 + 9.0) + edge) * (1.0 - moss_m);
	float op = open_mask(p);
	return vec3(moss_m * (1.0 - op), dirt_m * (1.0 - op), op);
}

// The mounds' height at p (m): on the litter only, low and broad, a little steeper at their edges.
float mound(vec2 p, vec3 pt) {
	float lit = (1.0 - pt.x) * (1.0 - pt.y * 0.8) * (1.0 - pt.z);
	float h = smoothstep(0.25, 0.75, fbm3(p * 0.42 + 17.0)) * 0.75 + fbm3(p * 1.3 + 5.0) * 0.25;
	return mound_h * h * lit * (1.0 - smoothstep(fade_r - 12.0, fade_r, length(p)));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wxz = wp.xz;
	v_mound = 0.0;
	if (displace > 0.0) {
		float e = 0.25;
		float h = mound(wxz, patches(wxz)) * displace;
		float hx = mound(wxz + vec2(e, 0.0), patches(wxz + vec2(e, 0.0))) * displace;
		float hz = mound(wxz + vec2(0.0, e), patches(wxz + vec2(0.0, e))) * displace;
		VERTEX.y += h;
		v_mound = h;
		NORMAL = normalize(vec3(-(hx - h) / e, 1.0, -(hz - h) / e));
		TANGENT = normalize(vec3(1.0, (hx - h) / e, 0.0));
		BINORMAL = normalize(cross(NORMAL, TANGENT));
	}
}

void fragment() {
	vec2 p = wxz;
	if (hole_r > 0.0 && length(p) < hole_r) {
		discard;
	}
	float fp = length(fwidth(p));
	float keep = 1.0 - smoothstep(0.004, 0.03, fp);   // (fine detail, faded with distance)
	vec3 pt = patches(p);
	float moss_m = pt.x;
	float dirt_m = pt.y;
	float open_m = pt.z;
	float big = fbm(p * 0.08);
	// The litter: the scan (or a painted brown), a little lighter on the mounds' tops.
	vec3 col = mix(litter, litter_hi, smoothstep(0.3, 0.8, fbm(p * 0.6 + 3.0)));
	vec3 nrm = vec3(0.5, 0.5, 1.0);
	float rough = 0.9;
	if (use_scan) {
		vec2 u1 = p / scan_tile;
		vec2 u2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p / (scan_tile * 1.37) + 0.37;
		float w = smoothstep(0.35, 0.65, fbm(p * 0.15 + 11.0));
		col = mix(texture(scan_albedo, u1).rgb, texture(scan_albedo, u2).rgb, w) * scan_tint * (0.85 + 0.3 * big);
		nrm = mix(texture(scan_normal, u1).rgb, texture(scan_normal, u2).rgb, w);
		rough = mix(texture(scan_arm, u1).g, texture(scan_arm, u2).g, w);
	}
	col *= 1.0 + v_mound * 0.9;
	// Moss: lumpy cushions of uneven size, their own green, yellower on their crowns, darker between them.
	float cush = fbm3(p * 4.5 + 7.0) * 0.7 + fbm3(p * 13.0 + 2.0) * 0.3;
	float dome = smoothstep(0.35, 0.75, cush);
	float tone = fbm3(p * 1.7 + 4.0);
	vec3 mcol = mix(moss, moss_hi, tone * 0.6 + dome * 0.4);
	mcol *= mix(1.0, 0.6 + 0.5 * dome + 0.3 * vnoise(p * 70.0), keep);
	// (needles fallen on the moss near its edges)
	float rim = smoothstep(0.0, 0.5, moss_m) * (1.0 - smoothstep(0.5, 1.0, moss_m));
	mcol = mix(mcol, col, rim * 0.6);
	// Dirt: dark earth, grit and a few pale stones.
	float grit = hash12(floor(p * 45.0));
	vec3 dcol = earth * (0.85 + 0.3 * fbm3(p * 3.0)) * mix(1.0, 0.75 + 0.5 * grit, keep);
	dcol = mix(dcol, vec3(0.35, 0.32, 0.27), step(0.985, hash12(floor(p * 9.0) + 2.0)) * keep * 0.8);
	// The sward: short grass, green and straw, in the openings.
	float blades = vnoise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * vec2(60.0, 9.0));
	vec3 scol = mix(sward, sward * vec3(1.35, 1.25, 0.9), fbm3(p * 0.5 + 21.0)) * mix(1.0, 0.75 + 0.5 * blades, keep);
	col = mix(col, mcol, moss_m);
	col = mix(col, dcol, dirt_m);
	col = mix(col, scol, open_m);
	ALBEDO = col;
	ROUGHNESS = mix(mix(mix(rough, 0.8, moss_m), 0.97, dirt_m), 0.9, open_m);
	SPECULAR = 0.25;
	// Relief: the scan's on the litter; the moss its cushions; the dirt its grit; the sward nearly flat.
	float e = 0.02;
	float hmx = fbm3((p + vec2(e, 0.0)) * 4.5 + 7.0) * 0.7 + fbm3((p + vec2(e, 0.0)) * 13.0 + 2.0) * 0.3;
	float hmz = fbm3((p + vec2(0.0, e)) * 4.5 + 7.0) * 0.7 + fbm3((p + vec2(0.0, e)) * 13.0 + 2.0) * 0.3;
	vec3 mn = normalize(vec3((cush - hmx) / e * 0.06, (cush - hmz) / e * 0.06, 1.0)) * 0.5 + 0.5;
	nrm = mix(nrm, mix(vec3(0.5, 0.5, 1.0), mn, keep), moss_m);
	nrm = mix(nrm, vec3(0.5 + (grit - 0.5) * 0.2 * keep, 0.5, 1.0), dirt_m);
	nrm = mix(nrm, vec3(0.5, 0.5 + (blades - 0.5) * 0.25 * keep, 1.0), open_m);
	NORMAL_MAP = nrm;
}
