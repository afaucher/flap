extends TestCase
## Diagnostic: how long the pine wood takes to grow (Pinewood.generate) and to build (ArenaBuilder.build), and
## how much it draws.

func setup() -> void:
	var t0 := Time.get_ticks_msec()
	var a := Pinewood.generate(7)
	var t1 := Time.get_ticks_msec()
	var b := ArenaBuilder.new()
	add_child(b)
	b.build(a)
	var t2 := Time.get_ticks_msec()
	var verts := 0
	var tris := 0
	var meshes := 0
	for c in b.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh and String(c.name).begins_with("Wood_"):
			var m := (c as MeshInstance3D).mesh as ArrayMesh
			meshes += 1
			verts += m.surface_get_array_len(0)
			tris += m.surface_get_array_index_len(0) / 3
	print("BUILD generate %d ms, build %d ms; wood: %d meshes, %d verts, %d tris; %d perches" % [t1 - t0, t2 - t1, meshes, verts, tris, a.perches.size()])
	finish()
