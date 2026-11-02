// Down and loose barbs at the body's outline (Plumage level 6; docs/research/feather_texture_study.md, "Down at
// the outline"). Shells: the body's own meshes drawn again a few millimetres out along their normals (next_pass
// on the body-feather material, one material per shell), each showing only scattered strands -- fewer and thinner
// further out -- and only where the surface is seen edge-on. Face-on they would blur the feather texture; at the
// silhouette they break the clean outline into a soft fringe, as the loose barb tips and down of a real bird do.
// The strands run along the feathers' flow (the body's feather chart: UV in tiles, v along the flow).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float height = 0.004;    // m: the outermost shell's distance off the surface
uniform float layer = 1.0;       // this shell (1 .. layers)
uniform float layers = 2.0;
uniform float density = 30.0;    // strand columns per tile across the flow
uniform float strand_len = 0.6;  // a strand's length, share of its cell along the flow
uniform float grazing = 0.5;     // shown where |N.V| is below this: the outline
uniform float transmit = 0.6;    // light through the fringe from a sun behind
uniform float paler = 0.12;      // down is paler than the vane surface

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	VERTEX += NORMAL * height * layer / layers;
}

void fragment() {
	float h = layer / layers;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = 1.0 - smoothstep(grazing * 0.35, grazing, facing);
	// A strand per cell: its column, a random offset, length and lean; fewer survive in the outer shells.
	vec2 g = vec2(UV.x * density, UV.y * density * 0.3);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float r1 = hash12(cell);
	float r2 = hash12(cell + 17.3);
	float r3 = hash12(cell + 41.7);
	float alive = step(h * 0.5, r1);
	float x0 = 0.2 + 0.6 * r2 + (f.y - 0.5) * (r3 - 0.5) * 0.6;   // (a slight lean)
	float along = f.y / (strand_len * (0.6 + 0.8 * r3));
	float w = 0.24 * (1.0 - 0.5 * h) * (1.0 - clamp(along, 0.0, 1.0) * 0.7);   // tapering to the tip
	float strand = alive * step(abs(f.x - x0), w) * step(along, 1.0);
	float k = COLOR.a;   // (the texture strength: none where the chart has none)
	if (strand * rim * k < 0.5) {
		discard;
	}
	vec3 c = to_linear(COLOR.rgb) * (1.0 + paler);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.3;
	BACKLIGHT = c * transmit;
}
