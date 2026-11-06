extends SceneTree
## Diagnostic: each species' bill and head in profile, as the rig builds them (head space, metres: -Z the bill, +Y
## up), for charting against the traced reference photos (tools/beak_profiles.py). Writes JSON: per species the head
## radius and skull, the bill's two mandibles (every vertex [x, y, z, colour: r across the bill, g which surface]
## and their triangles), the head's surface, the eye's centre and radius, the culmen's base (Face.bill_base) and the
## bill's pitch.
##   & $godot --path . --headless --script res://tests/probe_beak_profile.gd -- --out <json>
##   python tools/beak_profiles.py <json> <out.jpg>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "user://beak_profiles.json"
	var i := args.find("--out")
	if i >= 0 and i + 1 < args.size():
		out = args[i + 1]
	var all := {}
	for p in BirdProfile.all():
		var rig := BirdRig.new()
		root.add_child(rig)
		rig.build(p)
		rig.look_dir = Vector3.FORWARD
		rig.apply_pose()
		var hr: float = rig.body.head_r
		var d := {"hr": hr, "skull": [rig.body.skull.x, rig.body.skull.y, rig.body.skull.z]}
		for part in ["BeakUpper", "Jaw/BeakLower"]:
			var mi := rig._head.get_node(part) as MeshInstance3D
			var xf := _in_head(rig, mi)   # (the lower mandible sits on the jaw pivot)
			var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
			var pts := []
			var vs := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var cs := arr[Mesh.ARRAY_COLOR] as PackedColorArray
			for k in vs.size():
				var v := xf * vs[k]
				pts.append([v.x, v.y, v.z, cs[k].to_html(false)])
			d[part.get_file()] = pts
			d[part.get_file() + "_tris"] = Array(arr[Mesh.ARRAY_INDEX] as PackedInt32Array)
		# the head surface's vertices (its outline in profile is taken in Python)
		var hm := rig._head.get_node("HeadSurface") as MeshInstance3D
		var hx := _in_head(rig, hm)
		var hv := []
		var ha := (hm.mesh as ArrayMesh).surface_get_arrays(0)
		d["head_tris"] = Array(ha[Mesh.ARRAY_INDEX] as PackedInt32Array) if ha[Mesh.ARRAY_INDEX] != null else []
		for v in ha[Mesh.ARRAY_VERTEX]:
			var q := hx * (v as Vector3)
			hv.append([q.x, q.y, q.z])
		d["head"] = hv
		var eye: Node3D = rig._head.find_child("EyeR", true, false)
		var ep := _in_head(rig, eye).origin
		d["eye"] = [ep.x, ep.y, ep.z, float(Face.spec(p.id).eye.r) * hr]
		var bb := Face.bill_base(p.id, hr, rig.body.skull)
		d["base"] = [bb.x, bb.y, bb.z]
		d["pitch"] = float(Face.spec(p.id).beak.pitch)
		all[p.id] = d
		rig.free()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(all))
	f.close()
	print("wrote ", out)
	quit()


## A node's transform in its head's space (the scene isn't in the tree yet: no global transforms).
func _in_head(rig: BirdRig, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != rig._head:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t
