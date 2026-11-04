extends TestCase
## The pine wood's floor (FloorField, ArenaBuilder._ground, _grass; forest_floor.gdshader), as built:
##   - the field: mounds a hand high on the litter, none in the moss hollows, the dirt or the openings; moss and dirt
##     their shares of the floor;
##   - drawn and solid the same: the fine mesh shows the field's heights, the collision heightmap holds them, and a ray
##     down meets the floor at ArenaLayout.ground; the big plane draws only round the fine mesh, no gap;
##   - a crow settling onto the top of a mound stands on it (not in it), and on the floor between them too;
##   - a round coming down onto a mound bursts on its surface;
##   - grass thick in the openings, thin under the trees.


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var layout := Pinewood.generate(7)
	var ff := layout.floor_field
	check(ff != null, "the pine wood has a floor field")
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# The field: where the mounds are and how high, the shares of moss and dirt (inside the wood).
	var top := Vector2.ZERO
	var top_h := 0.0
	var on_moss := 0.0
	var moss := 0
	var dirt := 0
	var cells := 0
	for j in range(0, ff.n, 2):
		for i in range(0, ff.n, 2):
			var p := ff.origin + Vector2(i, j) * FloorField.RES
			if p.length() > layout.boundary - 5.0:
				continue
			var k := (j * ff.n + i) * 4
			var h := ff.data[k]
			cells += 1
			if ff.data[k + 1] > 0.0:
				moss += 1
				on_moss = maxf(on_moss, h)
			elif ff.data[k + 2] > 0.0:
				dirt += 1
			if h > top_h and ff.data[k + 3] == 0.0:
				top_h = h
				top = p
	print("FLOOR mounds up to %.2f m (at %s); moss %.0f %% of the floor (the highest mound on it %.3f m), dirt %.0f %%" % [top_h, top, 100.0 * moss / cells, on_moss, 100.0 * dirt / cells])
	check(top_h > FloorField.MOUND_H * 0.7 and top_h <= FloorField.MOUND_H + 0.001, "mounds a hand high (%.2f m)" % top_h)
	check(on_moss < 0.04, "none in the moss hollows (%.3f m)" % on_moss)
	check(absf(float(moss) / cells - FloorField.MOSS_SHARE) < 0.06 and dirt > 0, "moss about its share (%.0f %%), dirt too" % (100.0 * moss / cells))
	var in_open := 0.0
	for o in layout.openings:
		in_open = maxf(in_open, layout.ground(o.centre.x, o.centre.y))
	check(in_open < 0.01, "flat in the openings (%.3f m)" % in_open)
	# Drawn and solid the same.
	var ground: Node = arena.get_node("Ground")
	var fine := ground.get_node_or_null("FloorMounds") as MeshInstance3D
	check(fine != null, "a fine floor mesh under the wood")
	if fine != null:
		var fm := fine.material_override as ShaderMaterial
		var step := (fine.mesh as PlaneMesh).size.x / float((fine.mesh as PlaneMesh).subdivide_width + 1)
		check(float(fm.get_shader_parameter("displace")) > 0.0 and step <= FloorField.RES, "fine enough to draw the field's mounds, and drawing them (%.2f m)" % step)
		var tex := fm.get_shader_parameter("field") as ImageTexture
		check(tex != null and tex.get_width() == ff.n, "drawn from the field itself")
		var plane: MeshInstance3D = null
		for c in ground.get_children():
			if c is MeshInstance3D and c != fine:
				plane = c
		var hv = (plane.material_override as ShaderMaterial).get_shader_parameter("hole_r")
		var hole := float(hv) if hv != null else 0.0   # (unset: the plane draws everywhere)
		check(hole <= ff.size * 0.5 and hole > ff.fade_r, "the big plane draws only round it, no gap (hole %.1f, mesh %.1f, mounds gone by %.1f)" % [hole, ff.size * 0.5, ff.fade_r])
	var space := arena.get_world_3d().direct_space_state
	var worst := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 200:
		var p := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (layout.boundary - 5.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 3.0, p.y), Vector3(p.x, -1.0, p.y), ArenaBuilder.WORLD_LAYER))
		if hit.is_empty() or not (hit.collider as Node).is_in_group("ground"):
			continue
		worst = maxf(worst, absf(hit.position.y - (ArenaLayout.GROUND_Y + layout.ground(p.x, p.y))))
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(top.x, 3.0, top.y), Vector3(top.x, -1.0, top.y), ArenaBuilder.WORLD_LAYER))
	print("FLOOR solid: a ray down meets the floor within %.3f m of ground() (200 points); on the highest mound at %.3f m" % [worst, down.get("position", Vector3.ZERO).y])
	check(worst < 0.03, "the floor is solid where it's drawn (within %.3f m)" % worst)
	check(not down.is_empty() and absf(down.position.y - top_h) < 0.03, "the mounds are solid")
	# A crow settling onto the highest mound, and onto flat floor in an opening.
	for spot in [[top, "the highest mound"], [layout.openings[1].centre, "the glade"]]:
		var at: Vector2 = spot[0]
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.crow(), layout, ScriptedInput.new())
		b.rig.visible = false
		b.fly_from(Vector3(at.x, ArenaLayout.GROUND_Y + layout.ground(at.x, at.y) + 0.6, at.y), Vector3(0.0, -0.9, 0.3).normalized(), 1.0)
		await get_tree().physics_frame
		# (what the bird's flight takes for its height over the floor: the ground effect, settling; over the mound, from it)
		var over := b.global_position.y - (ArenaLayout.GROUND_Y + layout.ground(b.global_position.x, b.global_position.z))
		check(absf(b.model.ground_height - (over - b._radius)) < 0.03, "over %s the bird knows its height above the floor (%.2f m, it's %.2f)" % [spot[1], b.model.ground_height, over - b._radius])
		for f in 120:
			await get_tree().physics_frame
			if b.state == Bird.State.GROUNDED:
				break
		var t: Dictionary = b.telemetry()
		var g := ArenaLayout.GROUND_Y + layout.ground(b.global_position.x, b.global_position.z)
		print("FLOOR a crow settling on %s: %s, stands at %.3f m, the floor there %.3f m (stand height %.3f)" % [spot[1], Bird.State.keys()[b.state], b.stand_y, g, float(t.stand_height)])
		eq(b.state, Bird.State.GROUNDED, "a crow settling on %s stands" % spot[1])
		check(absf(b.stand_y - g) < 0.04 and float(t.stand_height) < 0.1, "on it, not in it (%.3f v %.3f m)" % [b.stand_y, g])
		b.queue_free()
	# A round coming down onto the mound bursts on its surface.
	var burst := _drop_round(layout, top)
	print("FLOOR a round dropped onto the mound bursts at %.3f m (the mound %.3f m)" % [burst.y, top_h])
	check(absf(burst.y - top_h) < 0.08, "a round bursts on the mound's surface (%.3f v %.3f m)" % [burst.y, top_h])
	# Grass: per square metre, in the openings against under the trees.
	var grass: MultiMeshInstance3D = null
	for c in arena.get_children():
		if c is MultiMeshInstance3D and c.name == "Batch_grass":
			grass = c
	check(grass != null, "grass is drawn")
	if grass != null:
		var inside := 0
		var outside := 0
		var off := 0.0
		for i in grass.multimesh.instance_count:
			var o := grass.multimesh.get_instance_transform(i).origin
			off = maxf(off, absf(o.y - ArenaLayout.GROUND_Y - layout.ground(o.x, o.z)))
			if Pinewood.in_opening(layout, Vector2(o.x, o.z)):
				inside += 1
			else:
				outside += 1
		var open_area := 0.0
		for o in layout.openings:
			open_area += PI * float(o.r) * float(o.r)
		var wood_area := PI * layout.boundary * layout.boundary - open_area
		var d_in := inside / open_area
		var d_out := outside / wood_area
		print("FLOOR grass: %.2f a square metre in the openings, %.3f under the trees; the farthest off the floor %.3f m" % [d_in, d_out, off])
		check(d_in > 2.0 and d_in > d_out * 15.0, "thick in the openings, thin under the trees (%.2f v %.3f)" % [d_in, d_out])
		check(off < 0.01, "and on the floor, mounds and all (%.3f m off)" % off)
	arena.queue_free()
	finish()


## Where a round falling straight down onto (x, z) bursts (Projectile.step against the layout, no birds).
func _drop_round(layout: ArenaLayout, at: Vector2) -> Vector3:
	var p := Projectile.launch(Projectile.Kind.ROCKET, Vector3(at.x, ArenaLayout.GROUND_Y + 2.0, at.y), Vector3.ZERO, Vector3.DOWN, null)
	for i in 200:
		var r: Dictionary = p.step(1.0 / 60.0, layout, [])
		if r.has("burst"):
			return r.burst
	return p.pos
