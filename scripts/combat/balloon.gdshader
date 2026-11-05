// A target balloon's envelope and fins (TargetBalloon): weathered doped canvas sewn in gores and panels (each panel
// its own tone, the seams stitched and raised), sun-faded on top and grimy underneath, the rigging band along each
// lower flank, the range's roundel on each side, bullet holes and the burning edge. Attributes (TargetBalloon._upload):
//   UV       (m along the envelope from its nose, gores round it: 0 .. 1)
//   CUSTOM0  (rest-space position xyz (the envelope as built, taut), piece: 0 envelope, 1 fin)
// Holes and the burn are given in rest space, so they stay where they were made however the envelope sags, crumples
// or falls.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 canvas : source_color = vec3(0.58, 0.53, 0.4);
uniform vec3 canvas_dark : source_color = vec3(0.4, 0.36, 0.26);
uniform vec3 faded : source_color = vec3(0.68, 0.65, 0.55);     // the sun-bleached crown
uniform vec3 grime : source_color = vec3(0.3, 0.25, 0.17);      // the belly: oil and earth off the winch party's hands
uniform vec3 inside : source_color = vec3(0.09, 0.075, 0.055);   // the rubberised lining, seen through a hole
uniform vec3 char_col : source_color = vec3(0.04, 0.035, 0.03);
uniform vec3 paint_ring : source_color = vec3(0.66, 0.48, 0.15);   // (the outposts' roundel: planks.gdshader)
uniform vec3 paint_blue : source_color = vec3(0.07, 0.13, 0.4);
uniform float roundel_z = -0.2;      // rest space: the roundel's middle along the envelope, its radius
uniform float roundel_r = 0.075;
uniform float gores = 16.0;
uniform float panel = 0.1;           // m between the panels' seams round the envelope
uniform float radius = 0.22;         // the envelope's widest
uniform vec4 holes[24];              // rest-space centre, radius
uniform int hole_n = 0;
uniform vec4 burn = vec4(0.0, 0.0, 0.0, -1.0);   // rest-space centre, how far the fire has run (< 0: none)
uniform float flicker = 0.0;         // (the embers' glow, by time)
uniform float smoulder = 0.0;        // 0 .. 1: a wreck's embers still glowing in the char

varying vec3 rest;
varying float piece;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// A line `w` m wide at distance `d` (m), antialiased: thinner than a pixel, it fades by how much of the pixel it covers.
float line(float d, float w) {
	float px = max(fwidth(d), 1e-5);
	float ww = max(w, px);
	return (1.0 - smoothstep(ww * 0.5 - px * 0.5, ww * 0.5 + px * 0.5, d)) * (w / ww);
}

void vertex() {
	rest = CUSTOM0.xyz;
	piece = CUSTOM0.w;
}

void fragment() {
	float m = vnoise(rest * 7.0) * 0.6 + vnoise(rest * 23.0) * 0.4;
	float rr = max(length(rest.xy), 0.01);
	float ang = atan(rest.y, rest.x);
	// Each panel cut from its own bolt and weathered its own way: a little lighter or darker, warmer or greyer.
	// (the panels laid brickwise: each gore's joins staggered from its neighbours')
	float gore = floor(UV.y * gores);
	float stagger = hash(vec3(gore, 5.0, 1.0));
	vec2 cell = piece < 0.5 ? vec2(gore, floor(UV.x / panel + stagger)) : vec2(40.0 + floor(UV.y * 2.0), floor(UV.x / (panel * 0.7)));
	float pn = hash(vec3(cell, piece * 7.0 + 3.0));
	vec3 c = mix(canvas_dark, canvas, 0.74 + 0.18 * m + 0.22 * (pn - 0.5));
	c *= vec3(1.0 + 0.07 * (pn - 0.5), 1.0, 1.0 - 0.08 * (pn - 0.5));
	// Faded where the sun's on it; grimy underneath; rain streaks running down the flanks.
	float up = rest.y / radius;
	c = mix(c, faded * (0.92 + 0.12 * m), 0.4 * smoothstep(0.2, 0.95, up));
	float streak = vnoise(vec3(rest.x * 70.0, rest.y * 2.5, rest.z * 70.0)) * 0.7 + vnoise(rest * 31.0) * 0.3;
	c *= 1.0 - 0.14 * smoothstep(0.5, 0.85, streak) * smoothstep(0.75, -0.2, up);
	c = mix(c, grime, (0.35 + 0.25 * vnoise(rest * 13.0)) * smoothstep(-0.35, -0.85, up));
	// Seams: a stitched double row along each gore and round each panel join; a narrower one down a fin.
	float seam = 0.0;
	float ridge = 0.0;
	if (piece < 0.5) {
		float g = fract(UV.y * gores);
		float gd = min(g, 1.0 - g) * 6.2832 * rr / gores;
		float pz = fract(UV.x / panel + stagger);
		float pd = min(pz, 1.0 - pz) * panel;
		seam = max(line(gd, 0.003), 0.7 * line(pd, 0.0025));
		ridge = max(1.0 - smoothstep(0.0, 0.0025, gd), 0.8 * (1.0 - smoothstep(0.0, 0.002, pd)));
		// The rigging band along each lower flank, its patches where the lines are made fast.
		float band = min(abs(ang - (-1.5708 + 0.68)), abs(ang - (-1.5708 - 0.68))) * rr;
		float b = line(band, 0.012);
		c = mix(c, canvas_dark * 0.75, 0.55 * b);
		ridge = max(ridge, b);
	} else {
		float pz = fract(UV.x / (panel * 0.7));
		float pd = min(pz, 1.0 - pz) * panel * 0.7;
		seam = 0.8 * line(pd, 0.0025);
		ridge = 0.8 * (1.0 - smoothstep(0.0, 0.002, pd));
	}
	c = mix(c, canvas_dark * 0.75, 0.42 * seam);
	// The roundel on each flank.
	if (piece < 0.5 && abs(rest.x) > radius * 0.3) {
		float rd = length(vec2(rest.z - roundel_z, rest.y)) / roundel_r;
		if (rd < 1.03) {
			float aaw = fwidth(rd) * 1.2;
			vec3 pc = paint_ring;
			pc = mix(pc, paint_blue, 1.0 - smoothstep(0.86 - aaw, 0.86 + aaw, rd));
			pc = mix(pc, paint_ring, 1.0 - smoothstep(0.42 - aaw, 0.42 + aaw, rd));
			pc *= 0.82 + 0.25 * m;
			// (faded and flaking like the rest of it, the seams' stitches through the paint)
			float cover = (1.0 - smoothstep(1.0 - aaw, 1.0 + aaw, rd)) * (0.86 + 0.1 * vnoise(rest * 130.0 + 4.0));
			cover *= 1.0 - 0.6 * seam;
			c = mix(c, pc, cover);
		}
	}
	if (!FRONT_FACING) {
		c = inside * (0.8 + 0.3 * m);
		if (burn.w > 0.0) {
			c = mix(c, char_col, 0.85);   // (the fire's soot all over the lining)
		}
	}
	// Bullet holes: ragged, frayed threads round the edge, a brown scorch beyond.
	float scorch = 0.0;
	float fray = 0.0;
	for (int i = 0; i < hole_n; i++) {
		float d = length(rest - holes[i].xyz);
		float r = holes[i].w * (0.7 + 0.6 * vnoise(rest * 300.0 + float(i) * 7.0));
		if (d < r) {
			discard;
		}
		fray = max(fray, 1.0 - smoothstep(r, r * 1.5, d));
		vec3 off = rest - holes[i].xyz;
		float ds = length(off - vec3(0.0, 0.0, clamp(off.z, 0.0, r * 5.0)));   // (the soot smeared aft by the air over it)
		scorch = max(scorch, (1.0 - smoothstep(r, r * 3.2, ds)) * (0.6 + 0.4 * vnoise(rest * 150.0)));
	}
	c = mix(c, vec3(0.2, 0.13, 0.08), 0.7 * scorch);
	c = mix(c, mix(vec3(0.1, 0.08, 0.06), canvas * 1.1, smoothstep(0.55, 0.75, vnoise(rest * 700.0))), 0.8 * fray);
	// The fire: inside its reach the canvas is gone but for charred rags and the seams; at the edge it glows; just
	// ahead of it the dope browns and blackens.
	vec3 glow = vec3(0.0);
	if (burn.w > 0.0) {
		float d = length(rest - burn.xyz) + (vnoise(rest * 9.0) - 0.5) * 0.14 + (vnoise(rest * 45.0) - 0.5) * 0.03;
		float e = burn.w - d;
		if (e > 0.03) {
			float keep = max(seam, smoothstep(0.52, 0.58, vnoise(rest * vec3(6.0, 6.0, 18.0))));
			if (keep < 0.5) {
				discard;
			}
			c = char_col * (0.8 + 0.4 * m);
			// Embers left in the char, dying as the wreck smoulders.
			float em = smoothstep(0.78, 0.92, vnoise(rest * 90.0 + vec3(flicker * 0.3)));
			glow += vec3(1.0, 0.3, 0.05) * em * (smoulder * 1.6 + 0.6 * (1.0 - smoothstep(0.03, 0.25, e)));
		} else if (e > 0.0) {
			c = char_col;
			float t = 1.0 - e / 0.03;
			glow = mix(vec3(1.0, 0.25, 0.03), vec3(1.0, 0.65, 0.22), t) * (4.0 + 2.0 * flicker) * (0.6 + 0.4 * vnoise(rest * 80.0 + flicker));
		} else {
			float h = 1.0 - smoothstep(0.0, 0.1, -e);
			c = mix(c, mix(vec3(0.33, 0.19, 0.08), char_col, h), smoothstep(0.0, 1.0, h * 1.2));
		}
	}
	// The weave's tooth, and the seams standing proud (a bump from the screen-space slope of their height).
	// (and each gore bellying out a little between its seams)
	float lobe = piece < 0.5 ? sin(3.14159 * fract(UV.y * gores)) * 0.0015 : 0.0;
	float h = ridge * 0.0006 + lobe + (vnoise(rest * 900.0) - 0.5) * 0.00004;
	h *= FRONT_FACING ? 1.0 : 0.0;   // (the lining inside is smooth)
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL);
	vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad + NORMAL * 1e-12);
	ALBEDO = c;
	ROUGHNESS = FRONT_FACING ? 0.82 - 0.1 * m : 0.95;
	SPECULAR = 0.3;
	EMISSION = glow;
}
