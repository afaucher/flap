extends TestCase
## The neck lofted on the GPU (BirdRig.gpu_body) is the rig's own loft: the shader's vertices (neck_place.gdshaderinc,
## the file the body shader draws with) are read back and compared with BirdRig._loft_neck's, vertex by vertex --
## position, smoothed normal, colour, feather coordinates -- for every species, the head turned and tipped every way
## (the rings paired differently), the bird fluffed and breathing. A GPU test: runs windowed.

const CAPTURE := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
#include "res://scripts/bird/neck_place.gdshaderinc"
// One float a pixel (x: position, normal, colour, uv, uv2 -- 14; y: the vertex), split hi + lo.
void fragment() {
	ivec2 px = ivec2(FRAGCOORD.xy);
	vec3 pos;
	vec3 nrm;
	vec4 col;
	vec2 uv;
	vec2 uv2;
	neck_vertex(px.y / 21, px.y - (px.y / 21) * 21, pos, nrm, col, uv, uv2);
	float vals[14] = float[14](pos.x, pos.y, pos.z, nrm.x, nrm.y, nrm.z, col.r, col.g, col.b, col.a, uv.x, uv.y, uv2.x, uv2.y);
	float v = vals[px.x];
	float hi = uintBitsToFloat(floatBitsToUint(v) & 0xFFFFE000u);
	COLOR = vec4(hi, (v - hi) * 2048.0, 0.0, 1.0);
}
"""
const PARAMS := ["neck_tab", "neck_ca", "neck_p1", "neck_p2", "neck_cb", "neck_hb", "neck_st", "neck_r", "neck_rev", "neck_ub_off", "neck_flip"]
const LOOKS := [   # look direction (yaw deg, pitch deg), fluff, breath
	[0.0, 0.0, 1.0, 0.0],
	[70.0, 20.0, 1.0, 0.5],
	[-80.0, -30.0, 1.12, -0.8],
	[150.0, 10.0, 1.0, 1.0],
	[-160.0, 45.0, 1.05, 0.0],
]


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	BirdRig.gpu_body = true
	var vp := SubViewport.new()
	vp.use_hdr_2d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(14, BirdRig.NECK_ROWS * 21)
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
		check(rig.gpu_neck, p.id + ": the neck lofted on the GPU")
		var pairings := {}
		for k in LOOKS.size():
			var q: Array = LOOKS[k]
			var yaw := deg_to_rad(q[0])
			var pitch := deg_to_rad(q[1])
			rig.look_dir = Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
			rig.fluff = q[2]
			rig.breath = q[3]
			rig._cpu_neck = true   # (the rig's own loft too, to compare with)
			rig.apply_pose()
			rig._cpu_neck = false
			for n in PARAMS:
				mat.set_shader_parameter(n, rig.body_texture_material.get_shader_parameter(n))
			pairings[rig.body_texture_material.get_shader_parameter("neck_r")] = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var lm: LoftMesh = rig._neck_loft
			var arr := lm.mesh.surface_get_arrays(0)
			var cols := lm.colors_built
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var uv2s: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
			var worst := [0.0, 0.0, 0.0, 0.0]
			for vi in lm.positions.size():
				var g := PackedFloat32Array()
				for x in 14:
					var c := img.get_pixel(x, vi)
					g.append(c.r + c.g / 2048.0)
				worst[0] = maxf(worst[0], Vector3(g[0], g[1], g[2]).distance_to(lm.positions[vi]))
				worst[1] = maxf(worst[1], Vector3(g[3], g[4], g[5]).distance_to(lm.normals_now[vi]))
				var cc := cols[vi]
				worst[2] = maxf(worst[2], maxf(maxf(absf(g[6] - cc.r), absf(g[7] - cc.g)), maxf(absf(g[8] - cc.b), absf(g[9] - cc.a))))
				worst[3] = maxf(worst[3], maxf(Vector2(g[10], g[11]).distance_to(uvs[vi]) / maxf(1.0, uvs[vi].length()), Vector2(g[12], g[13]).distance_to(uv2s[vi]) / maxf(1.0, uv2s[vi].length())))
			var tag := "%s look %d" % [p.id, k]
			print("%s: position %.7f m, normal %.6f, colour %.6f, coordinates %.7f" % [tag, worst[0], worst[1], worst[2], worst[3]])
			check(worst[0] < 1e-5, "%s: every vertex where the rig puts it (%.7f m)" % [tag, worst[0]])
			check(worst[1] < 2e-4, "%s: its normal as the rig smooths it (%.6f)" % [tag, worst[1]])
			check(worst[2] < 1e-5, "%s: its colour (%.6f)" % [tag, worst[2]])
			check(worst[3] < 1e-5, "%s: its feather coordinates (%.6f relative)" % [tag, worst[3]])
		check(pairings.size() >= 3, "%s: the head turned far enough to pair the rings differently (%d pairings)" % [p.id, pairings.size()])
		rig.queue_free()
	BirdRig.gpu_body = false
	finish()
