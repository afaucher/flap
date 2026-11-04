shader_type spatial;
// A thermal's motes (AirFx): seed fluff and dust catching the sun, drawn as points of light -- a small hot core
// that adds light, its true size close by; far off it stays a couple of pixels across, fainter, so the column
// reads as a glitter, never a snowfall. Each glints as it turns.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float size_m = 0.035;       // the quad's true size (AirFx.MOTE_SIZE)
uniform float min_px = 2.0;         // never drawn smaller than this on screen
uniform vec3 glint : source_color = vec3(1.0, 0.93, 0.76);
uniform float energy = 6.0;

varying float dim;
varying float twinkle;
varying float sharp;

void vertex() {
	// Face the camera (as BILLBOARD_PARTICLES), grown to min_px when it would be smaller.
	mat4 face = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	float d = max(-(VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).z, 0.01);
	float px = 2.0 * d / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);   // one pixel across at this distance, m
	float k = max(1.0, min_px * px / (size_m * s));
	MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(vec4(s * k, 0, 0, 0), vec4(0, s * k, 0, 0), vec4(0, 0, s * k, 0), vec4(0, 0, 0, 1));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	sharp = mix(1.0, 7.0, clamp((size_m * s * k / px - min_px) / 6.0, 0.0, 1.0));   // (a soft core when a few pixels: the pixels hit its middle)
	dim = 1.0 / k;   // (fainter far off, but not by the whole area it spreads over: a glint still shows at 60 m)
	float phase = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453) * 6.2832;
	twinkle = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TIME * (1.5 + fract(phase) * 2.0) + phase), 3.0);
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float core = exp(-r * r * sharp);
	ALBEDO = glint * energy;
	ALPHA = core * COLOR.a * dim * twinkle;
}
