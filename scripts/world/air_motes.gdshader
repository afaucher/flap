shader_type spatial;
// A thermal's motes (AirFx): seed fluff and dust, seen only where it catches the sun -- a small core that adds light,
// lit by the sun through the canopy's shadows (all but gone in the shade) and scattering forward (it flares looking
// into the light, dims with the sun behind you). Its true size close by, a little long and turned any way; far off
// a couple of pixels across, fainter, so the column reads as a glitter, never a snowfall. Each glints as it turns.
render_mode blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float size_m = 0.035;       // the quad's true size (AirFx.MOTE_SIZE)
uniform float min_px = 2.0;         // never drawn smaller than this on screen
uniform vec3 glint : source_color = vec3(1.0, 0.93, 0.76);
uniform float energy = 1.2;         // the sun's light it sends on (times the forward scatter)
uniform float scatter_g = 0.35;     // Henyey-Greenstein: 0 the same every way, toward 1 all forward
uniform float shade = 0.03;         // what's left of it in the shade
uniform vec2 fade_far = vec2(40.0, 75.0);   // m: gone by the far blur (ForestLight.FAR_BLUR_FROM 45 m), which spreads
                                              // a bright speck into a pale bokeh blot

varying float dim;
varying float twinkle;
varying float sharp;

void vertex() {
	float h = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	float h2 = fract(h * 91.7);
	// Face the camera (as BILLBOARD_PARTICLES), grown to min_px when it would be smaller.
	mat4 face = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	float d = max(-(VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).z, 0.01);
	float px = 2.0 * d / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);   // one pixel across at this distance, m
	float k = max(1.0, min_px * px / (size_m * s));
	float big = clamp((size_m * s * k / px - min_px) / 6.0, 0.0, 1.0);   // 0 at a couple of pixels, 1 from 8 up
	sharp = mix(1.0, 7.0, big);   // (a soft core when a few pixels: the pixels hit its middle)
	// A little long (a seed's plume, a fleck), turned any way: only where it's big enough to show.
	float a = mix(1.0, 1.0 + h2 * 0.8, big);
	float t = h * 6.2832;
	VERTEX.xy = mat2(vec2(cos(t), sin(t)), vec2(-sin(t), cos(t))) * (VERTEX.xy * vec2(sqrt(a), 1.0 / sqrt(a)));
	MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(vec4(s * k, 0, 0, 0), vec4(0, s * k, 0, 0), vec4(0, 0, s * k, 0), vec4(0, 0, 0, 1));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	dim = (1.0 - smoothstep(fade_far.x, fade_far.y, d)) / k;   // (fainter far off, not by the whole area it spreads over)
	twinkle = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TIME * (1.5 + h2 * 2.0) + t), 3.0);
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float core = exp(-r * r * sharp) * (1.0 - smoothstep(0.75, 1.0, r));   // (nothing at the quad's edge)
	ALBEDO = glint;
	AO = 0.0;                // (no sky light on it: it shows by the sun alone)
	AO_LIGHT_AFFECT = 0.0;
	EMISSION = glint * shade;
	ALPHA = core * COLOR.a * dim * twinkle;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// Forward scatter: brightest where the view runs on toward the sun.
		float c = dot(-VIEW, LIGHT);
		float g = scatter_g;
		float hg = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * c, 1.5);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * hg * energy;
	}
}
