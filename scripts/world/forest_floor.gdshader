// The pine wood's floor, in world metres: needle litter (the photoscan, warm and dry) heaped in low mounds; moss in
// the hollows between them (cushions of green, soft and lumpy, its own relief -- no needles drawn through it); bare
// dirt in patches (dark, gritty, flat); and in the openings -- the clearing, the glade, the gaps -- a short sward,
// greener, no mounds. Where and how high all comes from the floor's field (`field`: FloorField, the same data the
// collision and ArenaLayout.ground read); the shader adds each patch's ragged fine edge and the close detail. The
// mounds are drawn as height on the fine mesh under the wood (`displace`, ArenaBuilder._ground); the big plane round
// it is a ring with a real hole (ArenaBuilder.floor_ring: no discard here, which would cost every pixel of the floor
// its early depth test). The fine detail fades with distance so it doesn't shimmer.
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
// Past the wood's edge the litter gives way to heath (EdgeBuilder; heath.gdshaderinc), from heath_from to heath_to
// m out from the middle, raggedly.
uniform bool heath_on = false;
uniform float heath_from = 84.0;
uniform float heath_to = 98.0;

#include "res://scripts/world/heath.gdshaderinc"

// The moss's photoscan (forest_leaves_02, assets/LICENSES.md: moss cushions with twigs and fallen leaves), when given:
// at `moss_tile` m, two scales and rotations blended by noise, toned greener by `moss_tint`.
uniform bool use_moss_scan = false;
uniform sampler2D moss_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float moss_tile = 3.0;
uniform vec3 moss_tint : source_color = vec3(0.62, 0.85, 0.42);

// The floor's field (FloorField.image): r the mounds' height, g moss, b dirt (each -1..1 about its edge), a the openings.
uniform sampler2D field : filter_linear, repeat_disable;
uniform vec2 field_origin = vec2(0.0);
uniform float field_size = 1.0;
uniform float field_res = 0.5;
uniform bool use_field = false;
uniform float displace = 0.0;

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

// The field at p: x height, y moss, z dirt, w open (zero off it).
vec4 field_at(vec2 p) {
	if (!use_field) {
		return vec4(0.0, -1.0, -1.0, 0.0);
	}
	vec2 uv = (p - field_origin) / field_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec4(0.0, -1.0, -1.0, 0.0);
	}
	// (texel centres sit on the grid's points)
	float n = field_size / field_res + 1.0;
	return textureLod(field, (uv * (n - 1.0) + 0.5) / n, 0.0);
}

// The patches at p: x moss, y dirt, z the sward of the openings (the field's signals, their edges ragged in fine).
vec3 patches(vec2 p) {
	vec4 f = field_at(p);
	float edge = (vnoise(p * 2.3 + 11.0) - 0.5) * 0.9 + (vnoise(p * 7.0 + 3.0) - 0.5) * 0.3;
	float moss_m = smoothstep(-0.12, 0.12, f.y + edge);
	float dirt_m = smoothstep(-0.12, 0.12, f.z + edge) * (1.0 - moss_m);
	float op = f.w;
	return vec3(moss_m * (1.0 - op), dirt_m * (1.0 - op), op);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wxz = wp.xz;
	v_mound = 0.0;
	if (displace > 0.0) {
		float e = field_res;
		float h = field_at(wxz).x;
		float hx = field_at(wxz + vec2(e, 0.0)).x - field_at(wxz - vec2(e, 0.0)).x;
		float hz = field_at(wxz + vec2(0.0, e)).x - field_at(wxz - vec2(0.0, e)).x;
		VERTEX.y += h * displace;
		v_mound = h;
		NORMAL = normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
		TANGENT = normalize(vec3(1.0, hx / (2.0 * e), 0.0));
		BINORMAL = normalize(cross(NORMAL, TANGENT));
	}
}

void fragment() {
	vec2 p = wxz;
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
	// Each layer below is worked out only where it shows (its share over 0): mixed in at 0 it leaves the floor as it
	// was, so skipping it changes nothing drawn and saves most pixels most of the work. (The moss scan's samples take
	// their gradients from outside the branch: a branch that differs across a pixel quad can't give texture() its own.)
	float rough_out = rough;
	// Moss: lumpy cushions of uneven size, their own green, yellower on their crowns, darker between them.
	vec2 m1 = p / moss_tile + 0.21;
	vec2 m2 = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * p / (moss_tile * 1.31) + 0.63;
	vec2 m1x = dFdx(m1);
	vec2 m1y = dFdy(m1);
	vec2 m2x = dFdx(m2);
	vec2 m2y = dFdy(m2);
	if (moss_m > 0.0) {
		float tone = fbm3(p * 1.7 + 4.0);
		vec3 mcol;
		vec3 mn;
		float mscan_r = 0.85;
		if (use_moss_scan) {
			float mw = smoothstep(0.35, 0.65, fbm3(p * 0.21 + 31.0));
			vec3 sc = mix(textureGrad(moss_albedo, m1, m1x, m1y).rgb, textureGrad(moss_albedo, m2, m2x, m2y).rgb, mw);
			float lum = dot(sc, vec3(0.3, 0.59, 0.11));
			sc = mix(vec3(lum), sc, 1.25) * moss_tint;   // (more colour, greener: it reads as moss under the warm sun)
			mcol = sc * (0.8 + 0.4 * tone);
			mn = mix(textureGrad(moss_normal, m1, m1x, m1y).rgb, textureGrad(moss_normal, m2, m2x, m2y).rgb, mw);
			mscan_r = mix(textureGrad(moss_arm, m1, m1x, m1y).g, textureGrad(moss_arm, m2, m2x, m2y).g, mw);
		} else {
			float cush = fbm3(p * 4.5 + 7.0) * 0.7 + fbm3(p * 13.0 + 2.0) * 0.3;
			float dome = smoothstep(0.35, 0.75, cush);
			mcol = mix(moss, moss_hi, tone * 0.6 + dome * 0.4);
			mcol *= mix(1.0, 0.6 + 0.5 * dome + 0.3 * vnoise(p * 70.0), keep);
			// (its relief: the cushions' slope)
			float e = 0.02;
			float hmx = fbm3((p + vec2(e, 0.0)) * 4.5 + 7.0) * 0.7 + fbm3((p + vec2(e, 0.0)) * 13.0 + 2.0) * 0.3;
			float hmz = fbm3((p + vec2(0.0, e)) * 4.5 + 7.0) * 0.7 + fbm3((p + vec2(0.0, e)) * 13.0 + 2.0) * 0.3;
			mn = mix(vec3(0.5, 0.5, 1.0), normalize(vec3((cush - hmx) / e * 0.06, (cush - hmz) / e * 0.06, 1.0)) * 0.5 + 0.5, keep);
		}
		// (needles fallen on the moss near its edges)
		float rim = smoothstep(0.0, 0.5, moss_m) * (1.0 - smoothstep(0.5, 1.0, moss_m));
		mcol = mix(mcol, col, rim * 0.6);
		col = mix(col, mcol, moss_m);
		rough_out = mix(rough_out, mscan_r, moss_m);
		nrm = mix(nrm, mn, moss_m);
	}
	// Dirt: dark earth, grit and a few pale stones.
	if (dirt_m > 0.0) {
		float grit = hash12(floor(p * 45.0));
		vec3 dcol = earth * (0.85 + 0.3 * fbm3(p * 3.0)) * mix(1.0, 0.75 + 0.5 * grit, keep);
		// (a few small stones: round, of different sizes, a jittered point a cell, earthy greys, not white)
		vec2 sc = floor(p * 6.0);
		vec2 so = (vec2(hash12(sc + 2.0), hash12(sc + 9.0)) * 0.6 + 0.2) / 6.0;
		float srad = (0.012 + 0.03 * hash12(sc + 5.0)) * step(0.93, hash12(sc + 13.0));
		float stone = 1.0 - smoothstep(srad * 0.6, srad, length(p - sc / 6.0 - so));
		vec3 stone_col = vec3(0.2, 0.18, 0.15) * (0.8 + 0.4 * hash12(sc + 17.0));
		dcol = mix(dcol, stone_col, stone * keep);
		col = mix(col, dcol, dirt_m);
		rough_out = mix(rough_out, 0.97, dirt_m);
		nrm = mix(nrm, vec3(0.5 + (grit - 0.5) * 0.2 * keep, 0.5, 1.0), dirt_m);
	}
	// The sward: short grass, green and straw, in the openings.
	if (open_m > 0.0) {
		float blades = vnoise(mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * vec2(60.0, 9.0));
		vec3 scol = mix(sward, sward * vec3(1.35, 1.25, 0.9), fbm3(p * 0.5 + 21.0)) * mix(1.0, 0.75 + 0.5 * blades, keep);
		col = mix(col, scol, open_m);
		rough_out = mix(rough_out, 0.9, open_m);
		nrm = mix(nrm, vec3(0.5, 0.5 + (blades - 0.5) * 0.25 * keep, 1.0), open_m);
	}
	// Past the wood's edge the floor gives way to heath (heath.gdshaderinc), along a ragged line.
	float heath_k = 0.0;
	if (heath_on) {
		heath_k = smoothstep(heath_from, heath_to, length(p) + (big - 0.5) * 16.0 + (fbm(p * 0.3 + 6.0) - 0.5) * 4.0);
		if (heath_k > 0.0) {
			col = mix(col, heath_albedo(p), heath_k);
		}
	}
	ALBEDO = col;
	ROUGHNESS = mix(rough_out, 0.95, heath_k);
	SPECULAR = 0.25;
	// Relief: the scan's on the litter; the moss its cushions (above); the dirt its grit; the sward nearly flat.
	NORMAL_MAP = mix(nrm, vec3(0.5, 0.5, 1.0), heath_k * 0.7);
}
