extends TestCase
## The arm wings lofted on the GPU (BirdRig.gpu_body) are the rig's own lofts: the shader's vertices
## (arm_place.gdshaderinc, the file the body shader draws with) are read back and compared with BirdRig._loft_arm's,
## both wings, vertex by vertex -- position, smoothed normal (the closed wrist end too), colour and feather coordinates,
## the loop's read off the trunk where it lies -- for every species, spread, half-folded, flapped up and down, twisted,
## swept, the hand lifted, fluffed and breathing. A GPU test: runs windowed.
## (The wrist end, the last ring, closes the loft inside the hand's piece: its chord and thickness are nothing, so it
## is a straight segment and its triangles slivers whose normals are whatever the rounding makes them, here as in the
## rig. There it is held to the rig's positions, and its normals to being normals.)

const ROWS := 16   # BirdRig.ROOT_ROWS + ARM_STATIONS + 2
const COLS := 17   # ARM_AROUND + 1
const CAPTURE := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
#include "res://scripts/bird/arm_place.gdshaderinc"
// One float a pixel (x: position, normal, colour, uv, uv2 -- 14; y: side x 272 + row x 17 + column), split hi + lo.
void fragment() {
	ivec2 px = ivec2(FRAGCOORD.xy);
	int side = px.y / 272;
	int v = px.y - side * 272;
	vec3 pos;
	vec3 nrm;
	vec4 col;
	vec2 uv;
	vec2 uv2;
	arm_vertex(side, v / 17, v - (v / 17) * 17, pos, nrm, col, uv, uv2);
	float vals[14] = float[14](pos.x, pos.y, pos.z, nrm.x, nrm.y, nrm.z, col.r, col.g, col.b, col.a, uv.x, uv.y, uv2.x, uv2.y);
	float x = vals[px.x];
	float hi = uintBitsToFloat(floatBitsToUint(x) & 0xFFFFE000u);
	COLOR = vec4(hi, (x - hi) * 2048.0, 0.0, 1.0);
}
"""
const PARAMS := ["body_tab", "arm_pose", "body_rings", "body_nz", "body_around"]
const POSES := [   # fold, flap (deg), twist (deg), sweep (deg), hand_lift (deg), fluff, breath
	[0.0, 5.0, 0.0, 0.0, 0.0, 1.0, 0.0],
	[0.3, 40.0, 8.0, 10.0, 20.0, 1.0, 0.6],
	[0.6, -30.0, -6.0, -8.0, 0.0, 1.1, -0.7],
	[0.85, 10.0, 0.0, 0.0, 35.0, 1.15, 1.0],
]


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	BirdRig.gpu_body = true
	var vp := SubViewport.new()
	vp.use_hdr_2d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(14, 2 * ROWS * COLS)
	add_child(vp)
	var rect := ColorRect.new()
	rect.size = Vector2(vp.size)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CAPTURE
	mat.shader = sh
	rect.material = mat
	vp.add_child(rect)
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(rig)
		rig.build(p)
		check(rig.gpu_arm, p.id + ": the arm wings lofted on the GPU")
		for k in POSES.size():
			var q: Array = POSES[k]
			rig.fold = q[0]
			rig.flap = deg_to_rad(q[1])
			rig.twist = deg_to_rad(q[2])
			rig.sweep = q[3]
			rig.hand_lift = q[4]
			rig.fluff = q[5]
			rig.breath = q[6]
			rig._cpu_arm = true   # (the rig's own lofts too, built in full this pose, to compare with)
			rig._arm_built = [{}, {}]
			rig.apply_pose()
			rig._cpu_arm = false
			for n in PARAMS:
				mat.set_shader_parameter(n, rig.body_texture_material.get_shader_parameter(n))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			for side in 2:
				var lm: LoftMesh = rig._arm_loft[side]
				check(lm.positions.size() == ROWS * COLS, "%s pose %d side %d: the rig lofted it (%d vertices)" % [p.id, k, side, lm.positions.size()])
				if lm.positions.size() != ROWS * COLS:
					continue
				var arr := lm.mesh.surface_get_arrays(0)
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var uv2s: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
				var worst := [0.0, 0.0, 0.0, 0.0, 0.0]
				var at := ["", "", "", "", ""]
				for vi in ROWS * COLS:
					var g := PackedFloat32Array()
					for x in 14:
						var c := img.get_pixel(x, side * ROWS * COLS + vi)
						g.append(c.r + c.g / 2048.0)
					var cc := lm.colors_built[vi]
					var e := [Vector3(g[0], g[1], g[2]).distance_to(lm.positions[vi]),
						Vector3(g[3], g[4], g[5]).distance_to(lm.normals_now[vi]),
						maxf(maxf(absf(g[6] - cc.r), absf(g[7] - cc.g)), maxf(absf(g[8] - cc.b), absf(g[9] - cc.a))),
						maxf(Vector2(g[10], g[11]).distance_to(uvs[vi]) / maxf(1.0, uvs[vi].length()), Vector2(g[12], g[13]).distance_to(uv2s[vi]) / maxf(1.0, uv2s[vi].length()))]
					if vi / COLS == ROWS - 1:   # (the wrist end: its normals only unit)
						e.append(absf(Vector3(g[3], g[4], g[5]).length() - 1.0))
						e[1] = 0.0
					else:
						e.append(0.0)
					for m in 5:
						if e[m] > worst[m]:
							worst[m] = e[m]
							at[m] = "row %d col %d" % [vi / COLS, vi % COLS]

				var tag := "%s pose %d side %d" % [p.id, k, side]
				print("%s: position %.7f m (%s), normal %.6f (%s), colour %.6f (%s), coordinates %.7f (%s)" % [tag, worst[0], at[0], worst[1], at[1], worst[2], at[2], worst[3], at[3]])
				check(worst[4] < 1e-4, "%s: the wrist end's normals are unit vectors (off by %.6f)" % [tag, worst[4]])
				check(worst[0] < 1e-5, "%s: every vertex where the rig puts it (%.7f m, %s)" % [tag, worst[0], at[0]])
				check(worst[1] < 5e-4, "%s: its normal as the rig smooths it (%.6f, %s)" % [tag, worst[1], at[1]])
				check(worst[2] < 1e-5, "%s: its colour (%.6f, %s)" % [tag, worst[2], at[2]])
				check(worst[3] < 1e-5, "%s: its feather coordinates (%.7f relative, %s)" % [tag, worst[3], at[3]])
		rig.queue_free()
	BirdRig.gpu_body = false
	finish()
