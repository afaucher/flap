extends TestCase
## Beyond the pine wood's boundary (EdgeBuilder, Escarpment; docs/design/arena_edge.md), as built and drawn:
##   - nothing of it inside the playable circle (the rock, its boulders, the heath's tufts and heather, the far pines),
##     so it changes no flying in the wood;
##   - the escarpment stands well above the wood in the middle of its sector and comes down to the heath at both ends
##     (left and right), its tiers leaving level ledges between steep faces, its faces lit with the sun across them,
##     drawn facing out (not inside out) and solid: a ray toward it hits the rock, one toward the heath hits nothing;
##   - its perches: on the stones and the ledges as built (the rock's collision right under each), many low down and
##     fewer the higher they stand, none on the top; inside the soft wall, which in its sector stands out by the
##     cliff (a bird flying out toward it isn't turned back, one flying out over the heath is); and the AI can plan
##     its way in to the low ones; its clearance queries see the rock;
##   - out past the plateau the hills run on round the ring without a step;
##   - the heath's cover is thick by the fence and thins away from it, and none grows on the rock;
##   - the fence's two strands run from post to post, sagging between them.

const BANDS := [0.0, 5.0, 14.0, 22.0, 30.0, 999.0]   ## perch heights, m: stones, the tiers' ledges, the top


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	var layout := Pinewood.generate(7)
	check(not layout.escarpment.is_empty() and layout.rock != null, "the pine wood has an escarpment")
	eq(Pinewood.generate(7).escarpment.at, layout.escarpment.at, "same seed, same escarpment")
	var arena := ArenaBuilder.new()
	add_child(arena)
	arena.build(layout)
	var edge := arena.edge
	await get_tree().physics_frame
	await get_tree().physics_frame
	_outside(layout, edge)
	_rock(layout, edge)
	_perches(layout, edge)
	await _wall(layout, edge)
	_hills(edge)
	_heath(layout, edge)
	_fence(layout, edge)
	arena.queue_free()
	finish()


func _r(p: Vector3) -> float:
	return Vector2(p.x, p.z).length()


func _outside(layout: ArenaLayout, edge: EdgeBuilder) -> void:
	var b := layout.boundary
	var closest := INF
	for v in (edge.rock.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.y - ArenaLayout.GROUND_Y > 0.02:
			closest = minf(closest, _r(v))
	print("EDGE the rock's nearest raised point: %.1f m out (boundary %.0f)" % [closest, b])
	check(closest >= b + 2.0, "no rock within 2 m of the boundary (nearest %.1f m)" % closest)
	for pair in [["boulders", b + 1.0], ["tufts", b], ["heather", b], ["ledge_heather", b + 2.0], ["ledge_pines", b + 5.0], ["far_pines", 140.0]]:
		var at: PackedVector3Array = edge.placed[pair[0]]
		var near := INF
		for p in at:
			near = minf(near, _r(p))
		check(at.size() > 0 and near >= float(pair[1]), "no %s inside %.0f m (%d of them, nearest %.1f)" % [pair[0], pair[1], at.size(), near])


func _rock(layout: ArenaLayout, edge: EdgeBuilder) -> void:
	var esc := edge.esc
	var arrays := (edge.rock.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tallest_tree := 0.0
	for t in layout.trees:
		tallest_tree = maxf(tallest_tree, t.height)
	# Height across the sector, from the mesh: the middle third, and each end's last twentieth.
	var mid := 0.0
	var left := 0.0
	var right := 0.0
	for v in verts:
		var u := esc.off(atan2(v.x, v.z)) / Escarpment.HALF
		var h := v.y - ArenaLayout.GROUND_Y
		if absf(u) < 0.33:
			mid = maxf(mid, h)
		elif u < -0.95:
			left = maxf(left, h)
		elif u > 0.95:
			right = maxf(right, h)
	print("EDGE rock: %.1f m tall in the middle (the tallest tree %.1f), %.1f and %.1f m at its ends" % [mid, tallest_tree, left, right])
	check(mid > tallest_tree + 5.0, "the escarpment stands well above the wood (%.1f m, trees to %.1f)" % [mid, tallest_tree])
	check(left < 1.0 and right < 1.0, "and comes down to the heath at both ends (%.1f, %.1f m)" % [left, right])
	# Ledges: up the middle column of the mesh, runs of level ground between steep rises, at several heights.
	var nr := 0
	while nr < verts.size() - 1 and _r(verts[nr + 1]) > _r(verts[nr]):
		nr += 1
	nr += 1
	var c0 := (verts.size() / nr / 2) * nr   # (the middle column's first point)
	var ledges := []
	var level_run := 0.0
	var steep_seen := false
	for j in nr - 1:
		var a := verts[c0 + j]
		var b := verts[c0 + j + 1]
		var run := _r(b) - _r(a)
		var rise := b.y - a.y
		if rise > run * 2.0:
			steep_seen = true
			level_run = 0.0
		elif absf(rise) < run * 0.35 and steep_seen:
			level_run += run
			if level_run >= 0.8:
				ledges.append(snappedf(a.y - ArenaLayout.GROUND_Y, 0.1))
				steep_seen = false
	print("EDGE ledges up the middle at: %s m" % [ledges])
	check(ledges.size() >= 3, "the tiers leave level ledges between steep faces (%d up the middle)" % ledges.size())
	# The faces: the sun across them (lit, not head on), and drawn facing out: a height field faces up everywhere, and
	# Godot's front faces wind clockwise seen from the front, so each triangle's edges' cross product points down.
	var to_sun := (Basis.from_euler(Vector3(deg_to_rad(-ForestLight.SUN_ELEVATION), deg_to_rad(ForestLight.SUN_AZIMUTH), 0.0)) * Vector3.BACK).normalized()
	var sun_h := Vector2(to_sun.x, to_sun.z).normalized()
	var face := Vector2.ZERO
	var front := 0
	var back := 0
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var g := (verts[idx[t + 1]] - a).cross(verts[idx[t + 2]] - a)
		if g.length() < 1e-6:
			continue
		if g.y < 0.0:
			front += 1
		else:
			back += 1
		var n := (normals[idx[t]] + normals[idx[t + 1]] + normals[idx[t + 2]]).normalized()
		if n.y < 0.5:
			face += Vector2(n.x, n.z).normalized() * g.length()
	var lit := rad_to_deg(face.normalized().angle_to(sun_h))
	print("EDGE the faces turn %.0f deg from the sun; %d triangles drawn facing out, %d inside out" % [absf(lit), front, back])
	check(absf(lit) > 25.0 and absf(lit) < 75.0, "the sun falls across the faces, not head on nor behind (%.0f deg)" % absf(lit))
	check(back == 0, "every triangle of the rock faces out (%d inside out)" % back)
	# Solid: a ray from the posts toward the cliff's middle hits it; one toward the heath, nothing.
	var space := edge.get_world_3d().direct_space_state
	var dir := Vector3(sin(esc.at), 0.0, cos(esc.at))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(dir * (layout.boundary + 0.5) + Vector3.UP * 12.0, dir * (esc.foot + 60.0) + Vector3.UP * 12.0))
	check(not hit.is_empty() and hit.collider == edge.rock_body, "a ray toward the escarpment hits the rock")
	if not hit.is_empty():
		print("EDGE the rock stops a ray %.1f m out" % _r(hit.position))
		# The AI sees it too: not clear inside the rock, clear a few metres in front of where the ray met it.
		var into: Vector3 = hit.position + dir * 1.0
		var before: Vector3 = hit.position - dir * 3.0
		check(not layout.clear_by(into, 0.3) and layout.clear_by(before, 0.3), "the AI's clearance sees the rock (in it: blocked; 3 m short: clear)")
		check(not layout.segment_clear(before, into + dir * 3.0, 0.3) and layout.segment_clear(before - dir * 2.0, before, 0.3), "and a flight into it isn't clear, one short of it is")
	var away := -dir
	var miss := space.intersect_ray(PhysicsRayQueryParameters3D.create(away * (layout.boundary + 0.5) + Vector3.UP * 12.0, away * 400.0 + Vector3.UP * 12.0))
	check(miss.is_empty(), "one toward the heath hits nothing")


## The rock's perches: standing on it as built, more low down and fewer higher, none on top; reachable inside the
## soft wall; and the AI can plan its way in to the low ones.
func _perches(layout: ArenaLayout, edge: EdgeBuilder) -> void:
	var space := edge.get_world_3d().direct_space_state
	var counts := []
	counts.resize(BANDS.size() - 1)
	counts.fill(0)
	var floating := 0
	var walled := 0
	var mine := []
	var top := edge.esc.mean_top()
	var on_top := 0
	for p in layout.perches:
		if p.tree_id != layout.rock_tree:
			continue
		mine.append(p)
		var h: float = p.position.y - ArenaLayout.GROUND_Y
		for i in BANDS.size() - 1:
			if h >= BANDS[i] and h < BANDS[i + 1]:
				counts[i] += 1
		if h > top - 3.0:
			on_top += 1
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(p.position + Vector3.UP * 2.0, p.position - Vector3.UP * 2.0))
		if down.is_empty() or down.collider != edge.rock_body or absf(down.position.y - p.position.y) > 0.25:
			floating += 1
			print("EDGE perch %d at %s: the rock under it at %s" % [p.id, p.position, down.get("position", "none")])
		if _r(p.position) > layout.reach(Vector2(p.position.x, p.position.z)) - 4.0:
			walled += 1
	print("EDGE rock perches by height %s m: %s; %d near the top; %d not on the rock; %d at the soft wall" % [BANDS, counts, on_top, floating, walled])
	check(mine.size() >= 15, "the rock has perches (%d)" % mine.size())
	check(counts[0] >= 4 and counts[1] >= 6, "plenty down low, on the stones and the lowest ledges (%d, %d)" % [counts[0], counts[1]])
	var falling := true   # (from the lowest ledges up: each band fewer than the one below, or none)
	for i in range(2, counts.size()):
		if counts[i] > 0 and counts[i] >= counts[i - 1]:
			falling = false
	check(falling and counts[1] > counts[3] * 2, "fewer the higher they stand (%s)" % [counts])
	check(on_top == 0, "none on the top (%d)" % on_top)
	check(floating == 0, "each on the rock as built (%d not)" % floating)
	check(walled == 0, "each well inside the soft wall (%d at it)" % walled)
	# The AI: from over the wood, routes in to the lowest perches.
	var planner := FlightPlanner.new(layout)
	var profile := BirdProfile.by_id("crow")
	mine.sort_custom(func(a, b): return a.position.y < b.position.y)
	var routed := 0
	var tried := 0
	for p in mine.slice(0, 8):
		var from: Vector3 = Vector3(p.position.x, 0.0, p.position.z).normalized() * 55.0 + Vector3.UP * 14.0
		tried += 1
		if not planner.plan_to_perch(from, p, profile).is_empty():
			routed += 1
	print("EDGE the AI plans its way in to %d of the %d lowest rock perches" % [routed, tried])
	check(routed >= tried - 1, "the AI can plan its way in to the low perches (%d of %d)" % [routed, tried])


## Gliding out from just past the posts at 15 m: toward the cliff's middle the soft wall leaves the bird be (it
## flies on out over the scree), over the heath it turns it back.
func _wall(layout: ArenaLayout, edge: EdgeBuilder) -> void:
	var out := {}
	for side in ["cliff", "heath"]:
		var ang := edge.esc.at + (0.0 if side == "cliff" else PI)
		var dir := Vector3(sin(ang), 0.0, cos(ang))
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.crow(), layout, ScriptedInput.new())
		b.rig.visible = false
		b.fly_from(dir * (layout.boundary + 1.0) + Vector3.UP * 15.0, dir, b.profile.v_best * 1.2)
		var far := 0.0
		for i in 90:
			await get_tree().physics_frame
			far = maxf(far, _r(b.global_position))
		out[side] = far
		b.queue_free()
	print("EDGE gliding out from the posts for 1.5 s: toward the cliff to %.1f m out, over the heath to %.1f m (boundary %.0f)" % [out.cliff, out.heath, layout.boundary])
	check(out.cliff > layout.boundary + 9.0, "toward the cliff the soft wall lets a bird fly on out (%.1f m)" % out.cliff)
	check(out.heath < layout.boundary + 7.5, "over the heath it turns it back (%.1f m)" % out.heath)


## Past the plateau the hills run on round the ring: no steps between neighbouring columns out there.
func _hills(edge: EdgeBuilder) -> void:
	var verts: PackedVector3Array = (edge.hills.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nr := 0
	while nr < verts.size() - 1 and _r(verts[nr + 1]) > _r(verts[nr]):
		nr += 1
	nr += 1
	var nt := verts.size() / nr
	var worst := 0.0
	for i in nt - 1:
		for j in nr:
			var r := _r(verts[i * nr + j])
			if r < 200.0:
				continue
			worst = maxf(worst, absf(verts[i * nr + j].y - verts[(i + 1) * nr + j].y) / (r * TAU / (nt - 1)))
	print("EDGE the hills' steepest step round the ring past 200 m: %.2f (rise over run)" % worst)
	check(worst < 2.0, "the hills run on round the ring without a step (steepest %.2f)" % worst)


func _heath(layout: ArenaLayout, edge: EdgeBuilder) -> void:
	var near := 0
	var far := 0
	var on_rock := 0
	for p in (edge.placed["tufts"] as PackedVector3Array) + (edge.placed["heather"] as PackedVector3Array):
		var r := _r(p)
		if r < layout.boundary + 15.0:
			near += 1
		elif r > EdgeBuilder.HILLS_FROM - 15.0 and r < EdgeBuilder.HILLS_FROM:
			far += 1
		if edge.esc.height(p.x, p.z) > 0.1:
			on_rock += 1
	print("EDGE heath cover: %d in the 15 m by the fence, %d in the 15 m before the hills, %d on the rock" % [near, far, on_rock])
	check(far > 0 and near > far * 2, "the heath's cover is thick by the fence and thins away from it (%d v %d)" % [near, far])
	check(on_rock == 0, "none grows on the rock (%d)" % on_rock)


func _fence(layout: ArenaLayout, edge: EdgeBuilder) -> void:
	var verts: PackedVector3Array = (edge.wires.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var posts := []
	for t in layout.trees:
		if t.kind == ArenaLayout.Kind.POST:
			posts.append(t)
	var tied := 0
	for t in posts:
		var ok := true
		for y in EdgeBuilder.WIRES:
			var at := Vector3(t.base.x, ArenaLayout.GROUND_Y + y, t.base.y)
			var best := INF
			for v in verts:
				best = minf(best, v.distance_to(at))
			ok = ok and best < EdgeBuilder.WIRE_R * 2.0
		tied += 1 if ok else 0
	var lowest := INF
	for v in verts:
		if absf(v.y - ArenaLayout.GROUND_Y - EdgeBuilder.WIRES[0]) < 0.5:
			lowest = minf(lowest, v.y - ArenaLayout.GROUND_Y)
	print("EDGE fence: %d of %d posts have both strands tied on; the low strand sags to %.2f m (strung at %.2f)" % [tied, posts.size(), lowest, EdgeBuilder.WIRES[0]])
	check(tied >= posts.size() - 2, "the strands run from post to post (%d of %d)" % [tied, posts.size()])
	check(lowest < EdgeBuilder.WIRES[0] - EdgeBuilder.WIRE_SAG * 0.7, "and sag between them (%.2f m)" % lowest)
