shader_type canvas_item;
render_mode unshaded, blend_disabled;
// A sitting bird's deepest feather tip inside what it sits on (BirdRig._posture's rule, on the GPU: LeanProbe). One
// pixel a bird: every feather placed as the feather shader places it (feather_place.gdshaderinc), its tip taken to the
// world and measured against the surface; the deepest plus the margin, split hi + lo (about float precision in a
// half-float target).
#include "res://scripts/bird/feather_place.gdshaderinc"

uniform mat4 rig_xf;       // the rig's global transform
uniform int slots = 0;     // feathers in `defs`
uniform int srf_kind = 0;  // 0 branch (a, b, radius), 1 disc (centre a, radius), 2 ground (centre a)
uniform vec3 srf_a;
uniform vec3 srf_b;
uniform float srf_r;
uniform float margin;

// BirdRig._depth: how far p is inside the surface (+ inside, - clear of it).
float fp_depth(vec3 p) {
	if (srf_kind == 0) {
		vec3 ab = srf_b - srf_a;
		float s = clamp(dot(p - srf_a, ab) / max(dot(ab, ab), 1e-8), -0.2, 1.2);
		return srf_r - distance(p, srf_a + ab * s);
	}
	if (srf_kind == 1) {
		if (length(p.xz - srf_a.xz) > srf_r) {
			return -1e30;
		}
		return srf_a.y - p.y;
	}
	return srf_a.y - p.y;
}

void fragment() {
	float worst = -1e30;
	for (int k = 0; k < slots; k++) {
		mat4 fx = feather_place(k);
		vec3 tip = (rig_xf * vec4(fx[3].xyz + fx[2].xyz, 1.0)).xyz;
		worst = max(worst, fp_depth(tip) + margin);
	}
	worst = max(worst, -1000.0);   // (nothing under it: far clear, and finite in a half float)
	float hi = uintBitsToFloat(floatBitsToUint(worst) & 0xFFFFE000u);
	COLOR = vec4(hi, (worst - hi) * 2048.0, 0.0, 1.0);
}
