// The escarpment (EdgeBuilder._rock) and its blocks: limestone in world metres. With use_scan, a photoscan (assets/
// LICENSES.md: the cliff's marble_cliff_05, the blocks' rock_boulder_dry) laid on triplanar -- colour, normal, AO and
// roughness -- at two scales blended by noise so its repeat doesn't show, toned down and cooled into the wood's
// range; over it, as on the procedural rock: bedding planes in thin darker bands, water stains streaking down the
// steep faces, lichen, the vertical joints, cracks, and grass and heather on whatever faces up; and low down, where
// the ground lies gentle, the scree's own scan (gray_rocks) seen from above.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;   // (both sides: the wall seen side-on where the ring curves away)

uniform float strata = 1.0;   // the bedding bands and joints (0 for the blocks, which lie any way up)
uniform float bump = 0.6;     // the procedural bump (without a scan)
uniform float veg_amount = 1.0;
uniform float fracture = 0.0;          // how strongly the surface breaks into facets (the cliff's and the blocks': 1)
uniform float fracture_size = 0.8;     // m across a facet
uniform vec2 cut_sector = vec2(0.0, 0.0);   // (the wall's sector: its middle angle, and how far either side it's cut)
uniform bool cut_steep = false;   // the height field under the wall: its steep parts not drawn (the wall's sheet is)   // how much grass and heather grows on what faces up

uniform bool use_scan = false;
uniform sampler2D scan_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scan_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scan_tile = 6.0;              // m one repeat of the scan covers (at the finer of its two scales)
uniform vec3 scan_tint : source_color = vec3(0.42, 0.44, 0.49);
uniform float scan_normal_depth = 1.0;

uniform bool use_ground = false;            // the scree's scan on the gentle ground low down
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ground_tile = 1.8;
uniform vec3 ground_tint : source_color = vec3(0.5, 0.52, 0.56);
uniform float ground_y = 0.0;
uniform float scree_top = 6.0;              // m above the ground: below it, gentle ground is scree

varying vec3 wp;
varying vec3 wn;
varying vec3 tint;   // (each block's own shade: the instance colour; white on the cliff's mesh)

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise3(p);
		p = p * 2.02 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s / 0.97;
}

// Voronoi in 3D: (distance to the nearest cell point, to the second nearest, the nearest cell's id).
vec3 voronoi3(vec3 p) {
	vec3 c = floor(p);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = c + vec3(float(x), float(y), float(z));
				vec3 o = g + vec3(hash13(g), hash13(g + 17.1), hash13(g + 41.7));
				float d = length(p - o);
				if (d < f1) {
					f2 = f1;
					f1 = d;
					id = hash13(g + 3.3);
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return vec3(f1, f2, id);
}

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z);
}

vec3 tri_rgb(sampler2D t, vec3 p, vec3 w, float tile) {
	return texture(t, p.zy / tile).rgb * w.x + texture(t, p.xz / tile).rgb * w.y + texture(t, p.xy / tile).rgb * w.z;
}

// A tangent-space normal map on triplanar, as a world normal (the "whiteout" blend).
vec3 tri_normal(sampler2D t, vec3 p, vec3 n, vec3 w, float tile, float depth) {
	vec3 tx = (texture(t, p.zy / tile).rgb * 2.0 - 1.0) * vec3(depth, depth, 1.0);
	vec3 ty = (texture(t, p.xz / tile).rgb * 2.0 - 1.0) * vec3(depth, depth, 1.0);
	vec3 tz = (texture(t, p.xy / tile).rgb * 2.0 - 1.0) * vec3(depth, depth, 1.0);
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb;
}

void fragment() {
	vec3 n = normalize(wn);
	if (cut_steep) {   // (by the triangle's own slope, not the smoothed normal: no slivers of a step left standing)
		vec3 face_n = normalize(cross(dFdx(wp), dFdy(wp)));
		float off = abs(mod(atan(wp.x, wp.z) - cut_sector.x + 3.14159265, 6.2831853) - 3.14159265);
		if (abs(face_n.y) < 0.6 && off < cut_sector.y) {   // (only where the wall's sheet stands in front)
			discard;
		}
	}
	float big = fbm3(wp * 0.07);
	float mid = fbm3(wp * 0.45 + 5.0);
	float fine = fbm3(wp * 3.1 + 11.0);
	vec3 col;
	vec3 nw = n;
	float rough = 0.9;
	float ao = 1.0;
	float steep = 1.0 - smoothstep(0.35, 0.7, n.y);
	if (use_scan) {
		vec3 w = tri_weights(n);
		float mixk = smoothstep(0.35, 0.65, fbm3(wp * 0.05 + 7.0));   // (the two scales, blended by noise)
		col = mix(tri_rgb(scan_albedo, wp, w, scan_tile), tri_rgb(scan_albedo, wp + 13.7, w, scan_tile * 2.7), mixk);
		col = mix(vec3(dot(col, vec3(0.33))), col, 0.6) * scan_tint;   // (some of its warmth taken out: Dales grey)
		vec3 arm = mix(tri_rgb(scan_arm, wp, w, scan_tile), tri_rgb(scan_arm, wp + 13.7, w, scan_tile * 2.7), mixk);
		ao = arm.r;
		rough = arm.g;
		nw = tri_normal(scan_normal, wp, n, w, scan_tile, scan_normal_depth);
		col *= 0.85 + 0.3 * big;
	} else {
		// (albedo in the wood's own range -- its litter is about 0.15 -- and cooler than neutral: under the golden
		// sun it reads as the concept's grey)
		col = mix(vec3(0.1, 0.112, 0.135), vec3(0.23, 0.25, 0.285), smoothstep(0.25, 0.8, big * 0.6 + mid * 0.5));
		col = mix(col, vec3(0.24, 0.225, 0.2), smoothstep(0.55, 0.8, fbm3(wp * 0.12 + 21.0)) * 0.4);   // warmer patches
		col *= 0.88 + 0.24 * fine;
	}
	float k = use_scan ? 0.7 : 1.0;   // (the scan has its own detail: the painted marks lighter on it)
	// Fracture facets: cells a little under a metre across, each a plane turned its own way, dark cracks between
	// them where the cells meet, and the facets' own light and dark.
	float crack = 1.0;
	if (fracture > 0.0) {
		vec3 v = voronoi3(wp / fracture_size);
		vec3 tilt = vec3(hash13(vec3(v.z * 71.0, 1.0, 2.0)), hash13(vec3(v.z * 37.0, 5.0, 3.0)), hash13(vec3(v.z * 13.0, 7.0, 9.0))) * 2.0 - 1.0;
		nw = normalize(nw + (tilt - n * dot(tilt, n)) * 0.28 * fracture);
		crack = smoothstep(0.0, 0.05, v.y - v.x);
		col *= mix(0.72, 1.0, mix(1.0, crack, fracture)) * (0.94 + 0.12 * v.z * fracture);
		v = voronoi3(wp / (fracture_size * 0.33) + 7.0);   // (and finer chips)
		col *= mix(1.0, 0.9 + 0.1 * smoothstep(0.0, 0.05, v.y - v.x), fracture);
	}
	// Bedding: thin darker bands, wavering.
	float bed = sin(wp.y * 1.6 + big * 7.0);
	col *= 1.0 - 0.16 * k * smoothstep(0.82, 0.98, bed) * strata;
	// Water stains down the steep faces.
	float streak = fbm3(vec3((wp.x + wp.z) * 0.9, wp.y * 0.05, (wp.x - wp.z) * 0.9));
	col = mix(col, col * 0.45, steep * smoothstep(0.5, 0.75, streak) * 0.6 * k);
	// Lichen.
	float li = fbm3(wp * 1.4 + 31.0);
	col = mix(col, vec3(0.3, 0.27, 0.16), smoothstep(0.68, 0.8, li) * 0.4 * k);
	col = mix(col, vec3(0.06, 0.06, 0.055), smoothstep(0.72, 0.85, fbm3(wp * 2.3 + 41.0)) * 0.3 * k);
	// Vertical joints between the blocks (along the cliff: its angle round the ring, in metres).
	float arc = atan(wp.x, wp.z) * length(wp.xz);
	float jt = fract(arc / 1.9 + fbm3(wp * vec3(0.3, 0.08, 0.3)) * 0.8);
	col *= 1.0 - 0.5 * k * (1.0 - smoothstep(0.0, 0.03, min(jt, 1.0 - jt))) * steep * strata;
	// Cracks.
	float cr = abs(fbm3(wp * vec3(0.5, 0.25, 0.5) + 51.0) - 0.5);
	col *= 1.0 - 0.45 * k * (1.0 - smoothstep(0.0, 0.025, cr)) * steep;
	// Low down, gentle ground: the scree's own scan.
	float scree = 0.0;
	if (use_ground) {
		scree = (1.0 - smoothstep(scree_top - 1.5, scree_top, wp.y - ground_y)) * smoothstep(0.5, 0.75, n.y);
		vec2 gu = wp.xz / ground_tile;
		// (and earth between, in patches: the talus is soil and rubble as much as stone)
		float soil = smoothstep(0.35, 0.55, fbm3(wp * 0.09 + 13.0)) * 0.9;
		vec3 ground = mix(texture(ground_albedo, gu).rgb * ground_tint, vec3(0.2, 0.15, 0.1) * (0.8 + 0.4 * fine), soil);
		col = mix(col, ground, scree);
		vec3 gn = texture(ground_normal, gu).rgb * 2.0 - 1.0;
		nw = normalize(mix(nw, normalize(vec3(gn.x, gn.z, gn.y) + n * 0.5), scree));   // (seen from above: x, z across, y up)
		rough = mix(rough, 0.92, scree);
	}
	// Grass and heather on what faces up (not on the scree).
	float veg = smoothstep(0.62, 0.85, n.y) * smoothstep(0.2, 0.5, mid + 0.25) * (1.0 - scree) * veg_amount;
	vec3 green = mix(vec3(0.1, 0.13, 0.05), vec3(0.13, 0.08, 0.09), smoothstep(0.45, 0.65, fbm3(wp * 0.3 + 61.0)));
	col = mix(col, green * (0.8 + 0.3 * fine), veg);
	ALBEDO = col * tint;
	ROUGHNESS = mix(rough, 0.95, veg);
	AO = mix(ao, 1.0, veg);
	AO_LIGHT_AFFECT = 0.3;
	SPECULAR = 0.3;
	if (use_scan) {
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(nw, n, veg * 0.6)), 0.0)).xyz);
		if (!FRONT_FACING) {
			NORMAL = -NORMAL;
		}
	} else {
		// Bump from the same noise (surface gradient).
		float hgt = mid * 0.25 + fine * 0.06 + (1.0 - smoothstep(0.0, 0.025, cr)) * -0.05;
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float dhx = dFdx(hgt);
		float dhy = dFdy(hgt);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad * bump);
	}
}
