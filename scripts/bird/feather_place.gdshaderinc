// Each flight and tail feather's placement on the GPU (BirdRig.gpu_feathers): the same maths as BirdRig.apply_pose's
// feather loop, from the wing's joints this pose (`pose`, written each pose) and each feather's own definition
// (`defs`, written when the feather set changes). Included by the feather shader (drawing) and by the capture shader
// tests read back (tests/gpu_test_feathers.gd), so there is one copy.
//
// defs (RGBA32F, x = the feather's slot: plain feathers first, then the slotted primaries):
//   y0: bone, t, rel (deg; its term at no fold and slot), kind      y1: length, width, layer (m), index
//   y2: side, lost (1) or a ruffled covert's twist (rad, signed; BirdRig._ruffle), rel's terms in fold and in slot x (1 - fold)
//   (tail feathers, kind 6: y0.y its place across the fan, y1.z the tuck over its inner neighbour (m), y2.w the
//   base's sideways offset (m))
// pose (RGBA32F; rows 0, 1 the wings, row 2 the tail):
//   wing: 0 shoulder, ik_w | 1 elbow, panel | 2 wrist, side sign | 3 hand, alula | 4 arm normal, fold |
//         5 hand normal, sweep | 6 fold_y, unit | 7 folded dir, thumb | 8-10 the wing plane's basis (8.w: slot) |
//         11 bone angles (deg)
//   tail: 0 tail base, fan | 1-3 its basis | 4 its normal
uniform sampler2D defs : filter_nearest, repeat_disable;
uniform sampler2D pose : filter_nearest, repeat_disable;

const int K_ALULA = 3;
const int K_LESSER = 5;
const int B_FOREARM = 1;
const int B_HAND = 2;
const float FOLD_STEP_G = 0.00015;
const float TAIL_W = 0.2;

vec4 fp_pose(int r, int k) {
	return texelFetch(pose, ivec2(k, r), 0);
}

// Vector3.slerp: turn a toward b by w of the angle between them (lengths interpolated); straight lerp if parallel.
vec3 fp_slerp(vec3 a, vec3 b, float w) {
	float la = dot(a, a);
	float lb = dot(b, b);
	if (la == 0.0 || lb == 0.0) {
		return mix(a, b, w);
	}
	vec3 ax = cross(a, b);
	float al = dot(ax, ax);
	if (al == 0.0) {
		return mix(a, b, w);
	}
	ax /= sqrt(al);
	float sa = sqrt(la);
	float rl = mix(sa, sqrt(lb), w);
	float ang = atan(sqrt(al), dot(a, b)) * w;
	vec3 r = a * cos(ang) + cross(ax, a) * sin(ang) + ax * dot(ax, a) * (1.0 - cos(ang));
	return r * (rl / sa);
}

// The feather's frame: columns x (width), y (arch), z (length), and its base.
mat4 fp_xform(vec3 base, vec3 d, vec3 n, float len, float wid, float arch) {
	vec3 z = normalize(d);
	vec3 x = normalize(cross(n, z));
	vec3 y = normalize(cross(z, x));
	return mat4(vec4(x * wid, 0.0), vec4(y * len * arch, 0.0), vec4(z * len, 0.0), vec4(base, 1.0));
}

mat4 feather_place(int slot) {
	vec4 d0 = texelFetch(defs, ivec2(slot, 0), 0);
	vec4 d1 = texelFetch(defs, ivec2(slot, 1), 0);
	vec4 d2 = texelFetch(defs, ivec2(slot, 2), 0);
	mat4 xf;
	if (int(d0.w + 0.5) == 6) {   // a tail feather
		vec4 t0 = fp_pose(2, 0);
		mat3 tb = mat3(fp_pose(2, 1).xyz, fp_pose(2, 2).xyz, fp_pose(2, 3).xyz);
		vec3 tn = fp_pose(2, 4).xyz;
		float u = d0.y;
		vec3 d = tb * vec3(sin(u * t0.w * 0.5), 0.0, cos(u * t0.w * 0.5));
		vec3 base = t0.xyz + vec3(d2.w, 0.0, 0.0) + tn * d1.z;
		xf = fp_xform(base, d, tn, d1.x, d1.y, 1.0);
	} else {
		int i = int(d2.x + 0.5);
		vec4 p0 = fp_pose(i, 0);
		vec4 p1 = fp_pose(i, 1);
		vec4 p2 = fp_pose(i, 2);
		vec4 p3 = fp_pose(i, 3);
		vec4 p4 = fp_pose(i, 4);
		vec4 p5 = fp_pose(i, 5);
		vec3 fold_y = fp_pose(i, 6).xyz;
		vec4 p7 = fp_pose(i, 7);
		float ik_w = p0.w;
		float s = p2.w;
		float alula = p3.w;
		float fold = p4.w;
		vec3 arm_n = p4.xyz;
		vec3 hand_n = p5.xyz;
		int bone = int(d0.x + 0.5);
		int kind = int(d0.w + 0.5);
		float t = d0.y;
		float fi = d1.w;
		vec3 a = bone == 0 ? p0.xyz : (bone == 1 ? p1.xyz : p2.xyz);
		vec3 b = bone == 0 ? p1.xyz : (bone == 1 ? p2.xyz : p3.xyz);
		vec3 n = bone == B_HAND ? hand_n : arm_n;
		vec3 u = normalize(b - a);
		if (bone == B_HAND && kind != K_ALULA) {
			n = fp_slerp(hand_n, arm_n, 0.5 * (1.0 - smoothstep(1.0, 4.0, fi)));
		} else if (bone == B_FOREARM) {
			n = fp_slerp(arm_n, hand_n, 0.5 * smoothstep(0.7, 1.0, t));
		}
		n = normalize(n - u * dot(u, n));
		vec3 aft = normalize(cross(u, n) * s);
		float rel_deg = d0.z + d2.z * fold + d2.w * fp_pose(i, 8).w * (1.0 - fold);
		float rel = radians(rel_deg);
		if (kind == K_ALULA) {
			rel -= radians(25.0) * alula;
		}
		vec3 d = normalize(u * cos(rel) + aft * sin(rel));
		if (ik_w > 0.0) {
			if (bone != B_HAND) {   // (BirdRig._fk_feather_dir)
				vec3 ang = fp_pose(i, 11).xyz;
				float bone_deg = bone == 0 ? ang.x : (bone == 1 ? ang.y : ang.z);
				float r = radians(bone_deg + rel_deg - p5.w);
				mat3 wp = mat3(fp_pose(i, 8).xyz, fp_pose(i, 9).xyz, fp_pose(i, 10).xyz);
				vec3 fk = normalize(wp * vec3(s * cos(r), 0.0, sin(r)));
				d = normalize(fp_slerp(d, fk, ik_w));
			}
			d = normalize(fp_slerp(d, p7.xyz, ik_w * ik_w));
			n = normalize(fp_slerp(n, fold_y, ik_w));
		}
		vec3 root = mix(a, b, t);
		root += fold_y * ((p1.w - dot(root, fold_y)) * ik_w);
		vec3 base = root + n * d1.z;
		if (kind == K_ALULA) {
			float unit = fp_pose(i, 6).w;
			base = root + n * mix(p7.w * 0.45 + (0.0025 + 2.0 * FOLD_STEP_G * fi) * unit, d1.z, ik_w);
			d = normalize(d + n * 0.35 * alula);
		}
		if (d2.y != 0.0 && abs(d2.y) < 0.5) {   // a covert over a lost flight feather: stands up and twists
			float tw = d2.y * 0.5;   // (Vector3.rotated about n)
			d = normalize(d + n * tan(abs(d2.y)));
			d = d * cos(tw) + cross(n, d) * sin(tw) + n * dot(n, d) * (1.0 - cos(tw));
		}
		float sz = 1.0;
		if (kind == K_LESSER && bone != B_HAND) {
			sz = max(smoothstep(0.3, 0.9, fold), 0.001);
		}
		xf = fp_xform(base, d, n, d1.x * sz, d1.y * sz, max(1.0 - ik_w, 0.02));
	}
	if (d2.y > 0.5) {   // lost: shrunk to nothing at its root (BirdRig._gone)
		xf[0] *= 1e-4;
		xf[1] *= 1e-4;
		xf[2] *= 1e-4;
	}
	return xf;
}
