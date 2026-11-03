extends TestCase
## GPU feather placement (BirdRig.gpu_feathers) places every feather where the rig's own maths does: the shader's
## placement (feather_place.gdshaderinc, the same file the feather shader draws with) is read back from the GPU and
## compared, feather by feather, with BirdRig's -- every species; spread, half-folded with the hand lifted and the
## alula out, folded; flapped, twisted, swept, the primaries slotted; the tail fanned, pitched and twisted; feathers
## lost, and the coverts over them ruffled. A knocked-out feather's copy (feather_copy) is where the rig puts it.
## Their angles change with the fold and the slot each pose; their definitions are written once.
## A GPU test: runs windowed (.\test_runner.ps1 -Gpu), since the headless renderer runs no shaders.

const CAPTURE := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
#include "res://scripts/bird/feather_place.gdshaderinc"
// Each feather's frame, one float a pixel (x: column * 3 + row, then the base; y: the feather's slot), split hi + lo
// so a half-float target carries it at about float precision.
void fragment() {
	ivec2 px = ivec2(FRAGCOORD.xy);
	mat4 fx = feather_place(px.y);
	float v = fx[px.x / 3][px.x % 3];
	float hi = uintBitsToFloat(floatBitsToUint(v) & 0xFFFFE000u);
	COLOR = vec4(hi, (v - hi) * 2048.0, 0.0, 1.0);
}
"""

const POSES := [
	# fold, hand_lift, alula, flap (deg), twist (deg), sweep (deg), tail spread, tail pitch, tail twist, slot
	[0.0, 0.0, 0.0, 5.0, 0.0, 0.0, 0.2, 0.0, 0.0, 0.0],
	[0.62, 35.0, 0.8, -20.0, 6.0, 12.0, 0.9, 0.3, 0.15, 0.7],
	[1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -0.2, 0.0, 0.0],
	[0.3, 10.0, 0.4, 40.0, -8.0, -9.0, 0.5, 0.1, -0.3, 0.4],
]


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	BirdRig.gpu_feathers = true
	var vp := SubViewport.new()
	vp.use_hdr_2d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var rect := ColorRect.new()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CAPTURE
	mat.shader = sh
	rect.material = mat
	vp.add_child(rect)
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # (posed by hand, as Bird's rig is: drawn as posed)
		add_child(rig)
		rig.build(p)
		check(rig.gpu_place, p.id + ": placed on the GPU")
		var w := rig._defs_tex.get_width()
		vp.size = Vector2i(12, w)
		rect.size = Vector2(12, w)
		mat.set_shader_parameter("defs", rig._defs_tex)
		mat.set_shader_parameter("pose", rig._pose_tex)
		# The definitions are written once: folding and slotting the wing changes only the pose.
		rig.apply_pose()
		var writes := rig.gpu_defs_writes
		for q in [[0.3, 0.2], [0.7, 0.9], [1.0, 0.0]]:
			rig.fold = q[0]
			rig.slot = q[1]
			rig.apply_pose()
		eq(rig.gpu_defs_writes, writes, p.id + ": folding and slotting don't rewrite the feathers' definitions")
		for k in POSES.size():
			var q: Array = POSES[k]
			rig.fold = q[0]
			rig.hand_lift = q[1]
			rig.alula = q[2]
			rig.flap = deg_to_rad(q[3])
			rig.twist = deg_to_rad(q[4])
			rig.sweep = q[5]
			rig.tail_spread = q[6]
			rig.tail_pitch = q[7]
			rig.tail_twist = q[8]
			rig.slot = q[9]
			rig.lost = {} if k < 2 else {BirdRig.feather_key(0, WingShape.Kind.PRIMARY, 3): true, BirdRig.feather_key(1, WingShape.Kind.SECONDARY, 4): true, 3005: true}
			rig._cpu_feathers = true   # (the rig's own placement as well, to compare with)
			rig.apply_pose()
			rig._cpu_feathers = false
			check(rig.feather_xforms.size() > 50, "%s pose %d: the rig placed its feathers too (%d)" % [p.id, k, rig.feather_xforms.size()])
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var worst := 0.0
			var worst_at := ""
			var shrunk := 0
			for n in rig.feather_xforms.size():
				var want: Transform3D = rig.feather_xforms[n]
				var slot := rig.feather_slots[n]
				var got := _read(img, slot)
				var e := maxf(maxf(got.origin.distance_to(want.origin), got.basis.x.distance_to(want.basis.x)), maxf(got.basis.y.distance_to(want.basis.y), got.basis.z.distance_to(want.basis.z)))
				if e > worst:
					worst = e
					worst_at = "kind %d key %d" % [rig.feather_kinds[n], rig.feather_keys[n]]
				if rig.lost.has(rig.feather_keys[n]) and got.basis.z.length() < 1e-4:
					shrunk += 1
			print("%s pose %d: worst %.8f m (%s)" % [p.id, k, worst, worst_at])
			check(worst < 2e-5, "%s pose %d: every feather where the rig puts it (worst %.7f m, %s)" % [p.id, k, worst, worst_at])
			eq(shrunk, rig.lost.size(), "%s pose %d: lost feathers shrunk to nothing" % [p.id, k])
			if k >= 2:
				var ruffled := 0
				var defs := rig._defs_tex.get_image()
				for x in defs.get_width():
					var r := defs.get_pixel(x, 2).g
					if r != 0.0 and absf(r) < 0.5:
						ruffled += 1
				check(ruffled >= 2, "%s pose %d: the coverts over the lost feathers ruffled on the GPU (%d)" % [p.id, k, ruffled])
			# A knocked-out feather's copy, from a pose placed only on the GPU: where the rig puts that feather.
			var ck := BirdRig.feather_key(1, WingShape.Kind.PRIMARY, 6)
			var want_copy: Transform3D = rig.global_transform * rig.feather_xforms[rig.feather_keys.find(ck)]
			rig.apply_pose()
			check(rig.feather_xforms.is_empty(), "%s pose %d: a GPU pose places nothing here" % [p.id, k])
			var cp := rig.feather_copy(ck)
			check(cp != null and cp.transform.origin.distance_to(want_copy.origin) < 1e-6 and cp.transform.basis.z.distance_to(want_copy.basis.z) < 1e-6,
				"%s pose %d: a knocked-out feather's copy where the rig puts it" % [p.id, k])
			if cp != null:
				cp.free()
		rig.queue_free()
	BirdRig.gpu_feathers = false
	finish()


func _read(img: Image, slot: int) -> Transform3D:
	var v := PackedFloat32Array()
	for x in 12:
		var c := img.get_pixel(x, slot)
		v.append(c.r + c.g / 2048.0)
	return Transform3D(Basis(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8])), Vector3(v[9], v[10], v[11]))
