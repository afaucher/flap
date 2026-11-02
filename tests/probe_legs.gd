extends TestCase
## Diagnostic (run by name): the detailed legs' trunk loop on the perched hawk -- each loop point's colour against
## the drawn trunk's nearest vertex there.


func setup() -> void:
	LegRig.enabled = true
	var rig := BirdRig.new()
	add_child(rig)
	rig.build(BirdProfile.by_id("hawk"))
	RigPoses.apply(rig, "folded", 0.0)
	var ta: Array = (rig._trunk.mesh as ArrayMesh).surface_get_arrays(0)
	var tv: PackedVector3Array = ta[Mesh.ARRAY_VERTEX]
	var tc: PackedColorArray = ta[Mesh.ARRAY_COLOR]
	var w := tv.size() / rig.body.trunk_z.size()
	print("trunk verts %d, rings %d -> %d per ring" % [tv.size(), rig.body.trunk_z.size(), w])
	for i in 2:
		var fa: Array = (rig.legs.feather_mi[i].mesh as ArrayMesh).surface_get_arrays(0)
		var fv: PackedVector3Array = fa[Mesh.ARRAY_VERTEX]
		var fc: PackedColorArray = fa[Mesh.ARRAY_COLOR]
		for j in LegRig.AROUND:
			var best := 0
			for k in tv.size():
				if tv[k].distance_squared_to(fv[j]) < tv[best].distance_squared_to(fv[j]):
					best = k
			print("leg %d loop %d: %s  nearest trunk vertex %d (ring %d, col %d) %s  dist %.4f  at %s" % [i, j, fc[j], best, best / w, best % w, tc[best], tv[best].distance_to(fv[j]), fv[j]])
	finish()
