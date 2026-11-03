extends TestCase
## The legs' feather tubes built on the GPU (BirdRig.gpu_body) are LegRig's own build: the shader's vertices
## (trouser_place.gdshaderinc, the file the body shader draws with) are read back and compared with _build_feathers's
## build of the same pose, vertex by vertex -- position (the loop and fillet scaled with the trunk, as its bone scales
## them), normal, colour and feather coordinates -- every species, both legs, perched, flaring, reaching and tucked
## part way, fluffed and breathing: the loop on the shell, the fillet, the rings with no fold at the ankle, the skirt
## and the hem as the skin draws it, the owl's tube to the pad. A GPU test: runs windowed.

const COLS := 13   # LegRig.AROUND + 1
const ROWS := 14   # FILLET_W.size() + T_MAXT
const PER_LEG := ROWS * COLS
const CAPTURE := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
#include "res://scripts/bird/trouser_place.gdshaderinc"
// One float a pixel (x: position, normal, colour, uv, uv2 -- 14; y: leg x 182 + row x 13 + column), split hi + lo.
void fragment() {
	ivec2 px = ivec2(FRAGCOORD.xy);
	int leg = px.y / 182;
	int v = px.y - leg * 182;
	vec3 pos;
	vec3 nrm;
	vec4 col;
	vec2 uv;
	vec2 uv2;
	trouser_vertex(leg, v / 13, v - (v / 13) * 13, pos, nrm, col, uv, uv2);
	float vals[14] = float[14](pos.x, pos.y, pos.z, nrm.x, nrm.y, nrm.z, col.r, col.g, col.b, col.a, uv.x, uv.y, uv2.x, uv2.y);
	float x = vals[px.x];
	float hi = uintBitsToFloat(floatBitsToUint(x) & 0xFFFFE000u);
	COLOR = vec4(hi, (x - hi) * 2048.0, 0.0, 1.0);
}
"""
const PARAMS := ["leg_pose", "leg_static", "trunk_w", "leg_l", "body_tab", "body_rings", "body_nz", "body_around"]
const POSES := [   # RigPoses pose ("": the rig as built, its feet at its middle: the ankles tucked in), legs' reach (-1:
	# as the pose has it), fluff, breath
	["", -1.0, 1.0, 0.0],
	["folded", -1.0, 1.0, 0.0],
	["folded", -1.0, 1.12, 0.8],
	["flare", -1.0, 1.0, -0.6],
	["flare", 0.6, 1.0, 0.0],
	["flare", 0.3, 1.05, 0.4],
	["glide", -1.0, 1.0, 0.0],
	["glide", 0.15, 1.0, 1.0],
]


func _init() -> void:
	timeout_sec = 180.0


func setup() -> void:
	BirdRig.gpu_body = true
	var vp := SubViewport.new()
	vp.use_hdr_2d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(14, 2 * PER_LEG)
	add_child(vp)
	var rect := ColorRect.new()
	rect.size = Vector2(vp.size)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CAPTURE
	mat.shader = sh
	rect.material = mat
	vp.add_child(rect)
	var exits := {}
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(rig)
		rig.build(p)
		check(rig.legs != null and rig.legs.gpu, p.id + ": the trousers built on the GPU")
		for k in POSES.size():
			var q: Array = POSES[k]
			if q[0] != "":
				RigPoses.apply(rig, q[0], 0.0)
			if float(q[1]) >= 0.0:
				rig.leg_reach = PackedFloat32Array([q[1], q[1]])
			rig.fluff = q[2]
			rig.breath = q[3]
			rig.legs.cpu_trousers = true   # (LegRig's own build of this pose too, to compare with)
			rig.apply_pose()
			rig.legs.cpu_trousers = false
			for n in PARAMS:
				mat.set_shader_parameter(n, rig.body_texture_material.get_shader_parameter(n))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var st := rig.fluff * (1.0 + 0.012 * rig.breath)
			for leg in 2:
				var tag := "%s %s reach %.2f side %d" % [p.id, q[0], rig.leg_reach[leg], leg]
				exits[rig.legs.exit_on[leg]] = true
				if rig.legs.exit_on[leg] == "":
					check(not rig.legs.feather_mi[leg].visible, tag + ": no trousers when the leg doesn't leave the body")
					continue
				var arr := (rig.legs.cpu_mesh[leg] as ArrayMesh).surface_get_arrays(0)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var uv2s: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
				var cols: PackedColorArray = rig.legs.cpu_colors[leg]
				# (the faces the same way round: culled from behind, a tube wound the other way shows its inside)
				var ci: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				var gi: PackedInt32Array = (rig.legs.feather_mi[leg].mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_INDEX]
				eq([gi[0], gi[1], gi[2]], [ci[0], ci[1], ci[2]], tag + ": its faces wound as LegRig winds them")
				var worst := [0.0, 0.0, 0.0, 0.0]
				var at := ["", "", "", ""]
				for vi in v.size():
					var row := vi / COLS
					var g := PackedFloat32Array()
					for x in 14:
						var c := img.get_pixel(x, leg * PER_LEG + vi)
						g.append(c.r + c.g / 2048.0)
					var want := v[vi]
					if row < LegRig.FILLET_W.size():   # (drawn: the loop and fillet scaled with the trunk)
						var ws := smoothstep(0.0, 1.0, float(LegRig.FILLET_W[row]))
						want *= (1.0 - ws) * st + ws
					var cc := cols[vi]
					var e := [Vector3(g[0], g[1], g[2]).distance_to(want),
						Vector3(g[3], g[4], g[5]).distance_to(nrm[vi]),
						maxf(maxf(absf(g[6] - cc.r), absf(g[7] - cc.g)), maxf(absf(g[8] - cc.b), absf(g[9] - cc.a))),
						maxf(Vector2(g[10], g[11]).distance_to(uvs[vi]) / maxf(1.0, uvs[vi].length()), Vector2(g[12], g[13]).distance_to(uv2s[vi]) / maxf(1.0, uv2s[vi].length()))]
					for m in 4:
						if e[m] > worst[m]:
							worst[m] = e[m]
							at[m] = "row %d col %d" % [row, vi % COLS]
				print("%s (exit %s, %d rows): position %.7f m (%s), normal %.6f (%s), colour %.6f (%s), coordinates %.7f (%s)" % [tag, rig.legs.exit_on[leg], v.size() / COLS, worst[0], at[0], worst[1], at[1], worst[2], at[2], worst[3], at[3]])
				check(worst[0] < 2e-5, "%s: every vertex where LegRig builds it (%.7f m, %s)" % [tag, worst[0], at[0]])
				check(worst[1] < 2e-3, "%s: its normal (%.6f, %s)" % [tag, worst[1], at[1]])
				check(worst[2] < 1e-4, "%s: its colour (%.6f, %s)" % [tag, worst[2], at[2]])
				check(worst[3] < 1e-4, "%s: its feather coordinates (%.7f relative, %s)" % [tag, worst[3], at[3]])
		rig.queue_free()
	check(exits.has("tibia") and exits.has("tarsus"), "the tibia and the tarsus leaving the body were tried (%s)" % str(exits.keys()))
	BirdRig.gpu_body = false
	print("exits seen: ", exits.keys())
	finish()
