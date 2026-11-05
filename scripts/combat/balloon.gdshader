// A target balloon's envelope and fins (TargetBalloon): doped canvas sewn in gores, the range's roundel on each
// side, bullet holes and the burning edge. Attributes (TargetBalloon._upload):
//   UV       (m along the envelope from its nose, gores round it: 0 .. 1)
//   CUSTOM0  (rest-space position xyz (the envelope as built, taut), piece: 0 envelope, 1 fin)
// Holes and the burn are given in rest space, so they stay where they were made however the envelope sags, crumples
// or falls.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 canvas : source_color = vec3(0.76, 0.71, 0.56);
uniform vec3 canvas_dark : source_color = vec3(0.47, 0.43, 0.33);
uniform vec3 inside : source_color = vec3(0.2, 0.17, 0.12);    // the rubberised lining, seen through a hole
uniform vec3 char_col : source_color = vec3(0.05, 0.04, 0.035);
uniform vec3 paint_ring : source_color = vec3(0.66, 0.48, 0.15);   // (the outposts' roundel: planks.gdshader)
uniform vec3 paint_blue : source_color = vec3(0.07, 0.13, 0.4);
uniform float roundel_z = -0.2;      // rest space: the roundel's middle along the envelope, its radius
uniform float roundel_r = 0.075;
uniform float gores = 16.0;
uniform float panel = 0.07;          // m between the panels' seams round the envelope
uniform float radius = 0.22;         // the envelope's widest
uniform vec4 holes[24];              // rest-space centre, radius
uniform int hole_n = 0;
uniform vec4 burn = vec4(0.0, 0.0, 0.0, -1.0);   // rest-space centre, how far the fire has run (< 0: none)
uniform float flicker = 0.0;         // (the embers' glow, by time)
uniform float wet = 0.0;             // 0 .. 1: limp, it shows its wrinkles darker

varying vec3 rest;
varying float piece;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	rest = CUSTOM0.xyz;
	piece = CUSTOM0.w;
}

void fragment() {
	vec3 c = canvas;
	float m = vnoise(rest * 7.0) * 0.6 + vnoise(rest * 23.0) * 0.4;
	c = mix(canvas_dark, canvas, 0.78 + 0.22 * m);
	// Rain streaks run down from the crown; grime on the belly where it's handled on the winch.
	float streak = vnoise(vec3(rest.x * 60.0, rest.y * 3.0, rest.z * 60.0));
	c *= 1.0 - 0.12 * smoothstep(0.55, 0.9, streak) * smoothstep(-0.05, 0.15, rest.y);
	c = mix(c, canvas_dark * 0.7, 0.25 * smoothstep(-0.1, -0.2, rest.y) * vnoise(rest * 11.0));
	// Seams: the gores' along it, the panels' round it (a darker stitched line, a small ridge).
	float seam = 0.0;
	if (piece < 0.5) {
		float g = fract(UV.y * gores);
		float rr = max(length(rest.xy), 0.01);
		float gd = min(g, 1.0 - g) * 6.2832 * rr / gores;
		seam = max(seam, 1.0 - smoothstep(0.0008, 0.0018, gd));
		float pz = fract(UV.x / panel);
		float pd = min(pz, 1.0 - pz) * panel;
		seam = max(seam, 0.6 * (1.0 - smoothstep(0.0006, 0.0014, pd)));
	} else {
		float pz = fract(UV.x / (panel * 0.8));
		seam = 1.0 - smoothstep(0.001, 0.0022, min(pz, 1.0 - pz) * panel * 0.8);
	}
	float seam_far = smoothstep(0.004, 0.0015, fwidth(UV.x));   // (fades out where a seam is under a pixel: no graph paper)
	c = mix(c, canvas_dark * 0.85, 0.4 * seam * seam_far);
	// The roundel on each flank.
	if (piece < 0.5 && abs(rest.x) > radius * 0.35) {
		float rr = length(vec2(rest.z - roundel_z, rest.y)) / roundel_r;
		if (rr < 1.03) {
			float aaw = fwidth(rr) * 1.2;
			vec3 pc = paint_ring;
			pc = mix(pc, paint_blue, 1.0 - smoothstep(0.86 - aaw, 0.86 + aaw, rr));
			pc = mix(pc, paint_ring, 1.0 - smoothstep(0.42 - aaw, 0.42 + aaw, rr));
			pc *= 0.85 + 0.2 * m;
			float cover = (1.0 - smoothstep(1.0 - aaw, 1.0 + aaw, rr)) * mix(0.95, 0.8, vnoise(rest * 40.0));
			c = mix(c, pc, cover);
		}
	}
	if (!FRONT_FACING) {
		c = inside * (0.8 + 0.3 * m);
	}
	// Bullet holes: ragged, a scorched ring round each.
	float scorch = 0.0;
	for (int i = 0; i < hole_n; i++) {
		float d = length(rest - holes[i].xyz);
		float r = holes[i].w * (0.75 + 0.5 * vnoise(rest * 260.0 + float(i) * 7.0));
		if (d < r) {
			discard;
		}
		scorch = max(scorch, 1.0 - smoothstep(r, r * 2.4, d));
	}
	c = mix(c, char_col, 0.8 * scorch);
	// The fire: inside its reach the canvas is gone but for charred strips along the seams; at the edge it glows;
	// just ahead of it the dope browns and blackens.
	vec3 glow = vec3(0.0);
	if (burn.w > 0.0) {
		float d = length(rest - burn.xyz) + (vnoise(rest * 9.0) - 0.5) * 0.14 + (vnoise(rest * 45.0) - 0.5) * 0.03;
		float e = burn.w - d;
		if (e > 0.035) {
			float keep = max(seam, smoothstep(0.55, 0.62, vnoise(rest * vec3(6.0, 6.0, 18.0))));   // (charred rags and the seams)
			if (keep < 0.5) {
				discard;
			}
			c = char_col;
		} else if (e > 0.0) {
			c = char_col;
			float t = 1.0 - e / 0.035;
			glow = mix(vec3(1.0, 0.25, 0.03), vec3(1.0, 0.65, 0.2), t) * (3.0 + 2.0 * flicker) * (0.6 + 0.4 * vnoise(rest * 80.0 + flicker));
		} else {
			float h = 1.0 - smoothstep(0.0, 0.09, -e);
			c = mix(c, mix(vec3(0.35, 0.2, 0.08), char_col, h), smoothstep(0.0, 1.0, h * 1.2));
		}
	}
	ALBEDO = c;
	ROUGHNESS = 0.62 - 0.12 * m;
	SPECULAR = 0.35;
	EMISSION = glow;
}
