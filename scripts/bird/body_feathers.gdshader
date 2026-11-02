// Body feathers (Plumage level 6; docs/research/feather_texture_study.md): the body's plumage colours (vertex
// colours, sRGB) under a repeating tile of small overlapping contour feathers (FeatherAtlas body tile: R shade,
// G shaft, B spot field, A edge distance), tips toward the tail. Matte, as the plain body.
// PROTOTYPE: the body mesh has no UVs yet, so the tile is projected from the mesh's own space:
//   mode 0, the trunk: round the body's long axis (rig Z) -- along = z, around = |angle from the spine| x radius,
//           so the pattern mirrors at the spine and keel (bilateral, like real feather tracts) with no seam;
//   mode 1, the head sphere: polar coordinates round `axis` (head space), whose poles are the forehead above
//           the bill and the underside where the neck joins (both mostly hidden): rows run back over the crown;
//   mode 2, the arm wing's loft (re-lofted every pose in rig space): a plane frame that moves with the wing,
//           set by the rig each pose -- x along the span (`axis`), y aft (`axis_v`, the feathers' tips), so
//           the forewing's small coverts don't slide as the wing flaps; `axis_n` (its normal) tells top from under.
// The neck (re-lofted every pose, in rig space) uses mode 0 too: it carries on the trunk's pattern, but its
// feathers slide as the head moves. The body mesh should carry these coordinates as UVs instead (the study
// lists what it must provide).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D scales : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int mode = 0;
uniform vec3 origin;                 // a point on the axis (mesh space)
uniform vec3 axis = vec3(0.0, -0.6, 1.0);   // mode 1: from the front pole to the back one; mode 2: along the span
uniform vec3 axis_v = vec3(0.0, 0.0, 1.0);  // mode 2: aft
uniform vec3 axis_n = vec3(0.0, 1.0, 0.0);  // mode 2: the wing's upper normal
uniform float feather = 0.02;        // m: one tile (4 feathers across, 8 rows) along and around
uniform float radius = 1.0;          // mode 1: the sphere's radius (m)
uniform vec3 spot_tint = vec3(0.5);  // the spot's colour as a multiple of the body colour
uniform float spot_back = 0.0;       // spot amount on the back .. on the belly
uniform float spot_belly = 0.0;
uniform float spot_size = 0.5;
uniform vec3 fringe_col = vec3(1.0); // pale feather edges (sRGB), mixed in by fringe_amt
uniform float fringe_amt = 0.0;
uniform float fringe_w = 0.35;
uniform float strength = 1.0;
uniform float belly_strength = 1.0;   // (a share of `strength` on the belly, where the keel's mirror line shows)

varying vec3 pos;
varying float face;

void vertex() {
	pos = VERTEX;
	face = dot(NORMAL, axis_n);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 st;
	float up;   // 1 on the back .. -1 on the belly
	float fade = 1.0;
	if (mode == 1) {
		vec3 a = normalize(axis);
		vec3 d = normalize(pos);
		float polar = acos(clamp(-dot(d, a), -1.0, 1.0));   // 0 at the forehead
		vec3 side = vec3(1.0, 0.0, 0.0);
		vec3 top = normalize(cross(a, side));
		float az = atan(dot(d, side), dot(d, top));
		st = vec2(abs(az) * sin(polar), polar) * radius;
		up = d.y;
		fade = 1.0 - smoothstep(0.7, 0.9, polar / PI);   // (the rows crowd into rings round the back pole)
	} else if (mode == 2) {
		vec3 p = pos - origin;
		st = vec2(dot(p, axis), dot(p, axis_v));
		up = face;
	} else {
		vec2 p = pos.xy - origin.xy;
		float az = atan(p.x, p.y);
		st = vec2(abs(az) * length(p), pos.z);
		up = cos(az);
	}
	vec4 t = texture(scales, st / feather);
	vec3 c = COLOR.rgb;
	float k = strength * fade * mix(belly_strength, 1.0, smoothstep(-0.3, 0.3, up));
	float spot_amt = mix(spot_belly, spot_back, smoothstep(-0.3, 0.3, up));
	c = mix(c, c * spot_tint, smoothstep(0.88 - spot_size * 0.7, 1.0 - spot_size * 0.7, t.b) * spot_amt * k);
	c = mix(c, mix(c, fringe_col, fringe_amt), (1.0 - smoothstep(fringe_w * 0.4, fringe_w, t.a)) * k);
	c = mix(c, c * 0.8, t.g * k);
	ALBEDO = to_linear(c) * mix(1.0, t.r * 1.1, k);
	ROUGHNESS = 0.95;
	SPECULAR = 0.35;
}
