extends TestCase
## Diagnostic: the outposts on the oaks against the oaks' own wood as drawn (TreeData.limbs, the trunk): for each, how
## deep the limbs run into the deck, the hangar and the space a bird stands in over the deck (HEADROOM), and how
## much limb is inside each (past the deck's bolted strip, Pinewood.DECK_BOLT, and outside the trunk as drawn); then a sheet of renders, a row per oak outpost (out in front of the rail, from the side,
## from above). `--bark`: instead a sheet of bark close-ups, the oak's trunk and a big limb beside a pine's trunk and
## a veteran's limb, at the same distance. Windowed:
##   .\probe.ps1 probe_oak_outpost --out <png> [--seed 7] [--bark] [--grow: Pinewood.grow, not the baked map]

const CELL := Vector2i(640, 400)
const HEADROOM := 0.6   ## m over the deck a bird and rider stand in


func _init() -> void:
	timeout_sec = 180.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var seed_arg := Boot.arg_value(args, "--seed")
	get_window().size = Vector2i(1280, 800)
	var layout: ArenaLayout = (Pinewood.grow if args.has("--grow") else Pinewood.generate).call(int(seed_arg) if seed_arg != "" else 7)
	var rows := []
	for o: ArenaLayout.OutpostData in layout.outposts:
		var t: ArenaLayout.TreeData = layout.trees[o.tree_id]
		if t.kind != ArenaLayout.Kind.BROADLEAF:
			continue
		var side := o.out.cross(Vector3.UP).normalized()
		# (past the strip it's bolted on by, Pinewood.DECK_BOLT: wood there is the trunk and the stems' feet it's fixed to)
		var bolt := o.out * Pinewood.DECK_BOLT * 0.5
		var deck := _box(o.centre + Vector3.DOWN * o.thickness * 0.5 + bolt, side, o.out, Vector3(o.width, o.thickness, o.depth - Pinewood.DECK_BOLT))
		var head := _box(o.centre + Vector3.UP * HEADROOM * 0.5 + bolt, side, o.out, Vector3(o.width, HEADROOM, o.depth - Pinewood.DECK_BOLT))
		var hx := ArenaLayout.hangar_x(o)
		var hz := ArenaLayout.hangar_z(o)
		# (the hangar at its deck x along `side`, as ArenaBuilder._outpost draws it)
		var hc := o.centre + side * hx + o.out * hz + Vector3.UP * ArenaLayout.HANGAR_SIZE.y * 0.5
		var hangar := _box(hc, side, o.out, ArenaLayout.HANGAR_SIZE)
		var c := Vector3(t.base.x, 0.0, t.base.y)
		print("OAK %d outpost %d: deck at %.2f m (fork %.2f, bole top %.2f), out %s, %.2f m from the trunk's axis to the deck's middle" % [
			t.id, o.id, o.centre.y - ArenaLayout.GROUND_Y, t.crown_base, t.stem, _deg(o.out), Vector2(o.centre.x - c.x, o.centre.z - c.z).length()])
		for part in [["deck", deck], ["hangar", hangar], ["headroom", head]]:
			var hits := _limbs_in(t, part[1])
			var worst := 0.0
			var inside := 0.0
			for h in hits:
				worst = maxf(worst, h[1])
				inside += h[2]
			print("  %-8s %d limbs in it, deepest %.2f m, %.1f m of limb inside" % [part[0], hits.size(), worst, inside])
			for h in hits:
				print("    limb %d (radius %.2f m where it leaves, from %.1f m up): %.2f m deep, %.2f m inside" % [h[0], t.limbs[h[0]][1][0], (t.limbs[h[0]][0] as PackedVector3Array)[0].y, h[1], h[2]])
		rows.append([o, t])
	var root := Node3D.new()
	add_child(root)
	ForestLight.setup(root)
	var arena := ArenaBuilder.new()
	root.add_child(arena)
	arena.build(layout)
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.02
	cam.far = 600.0
	root.add_child(cam)
	cam.current = true
	var views := []
	if args.has("--bark"):
		var oak: ArenaLayout.TreeData = rows[0][1]
		var pine: ArenaLayout.TreeData = null
		var vet: ArenaLayout.TreeData = null
		for t in layout.trees:
			if t.kind == ArenaLayout.Kind.PINE and t.form == "" and (pine == null or Vector2(t.base).distance_to(oak.base) < Vector2(pine.base).distance_to(oak.base)):
				pine = t
			if t.form == "veteran" and (vet == null or Vector2(t.base).distance_to(oak.base) < Vector2(vet.base).distance_to(oak.base)):
				vet = t
		var oc := Vector3(oak.base.x, ArenaLayout.GROUND_Y, oak.base.y)
		var pc := Vector3(pine.base.x, ArenaLayout.GROUND_Y, pine.base.y)
		# The oak's thickest limb out of the fork, looked at a metre out along it.
		var lb: Array = oak.limbs[0]
		for l in oak.limbs:
			if float(l[1][0]) > float(lb[1][0]):
				lb = l
		var lp: PackedVector3Array = lb[0]
		var at_l := lp[lp.size() / 2]
		var along := (lp[lp.size() / 2 + 1] - lp[lp.size() / 2 - 1]).normalized()
		var across := along.cross(Vector3.UP).normalized()
		var vl := Vector3(vet.base.x, ArenaLayout.GROUND_Y, vet.base.y)
		var vlimb: Array = []
		for l in vet.limbs:
			if l[2] == "limb" and (vlimb.is_empty() or float(l[1][0]) > float(vlimb[1][0])):
				vlimb = l
		var vp: PackedVector3Array = vlimb[0]
		var vat := vp[vp.size() / 2]
		var vacross := (vp[vp.size() - 1] - vp[0]).normalized().cross(Vector3.UP).normalized()
		views = [
			["oak trunk, 3 m off", oc + Vector3(3.0 + oak.radius, 2.0, 0.0), oc + Vector3(0, 2.0, 0)],
			["pine trunk, 3 m off", pc + Vector3(3.0 + pine.radius, 2.0, 0.0), pc + Vector3(0, 2.0, 0)],
			["oak trunk, 8 m off", oc + Vector3(8.0, 3.0, 0.0), oc + Vector3(0, 3.0, 0)],
			["oak limb, 2 m off", at_l + across * 2.0 + Vector3.UP * 0.3, at_l],
			["veteran pine limb, 1 m off", vat + vacross * 1.0 + Vector3.UP * 0.2, vat],
			["oak fork, 4 m off", oc + Vector3(4.0, oak.crown_base + 0.5, 1.5), oc + Vector3(0, oak.crown_base, 0)],
		]
		# The joins: the first limb grown's first fork (its first piece's tip, where the next piece and a side limb
		# leave), and where it leaves the trunk, from below.
		var p1: PackedVector3Array = oak.limbs[0][0]
		var joint := p1[p1.size() - 1]
		var p1_dir := (joint - p1[0]).normalized()
		var p1_side := p1_dir.cross(Vector3.UP).normalized()
		var exit := oc + Vector3.UP * p1[0].y + Vector3(p1_dir.x, 0.0, p1_dir.z).normalized() * oak.radius
		views.append(["a limb's first fork, 2.5 m off", joint + p1_side * 2.5 + Vector3.UP * 0.6, joint])
		views.append(["where it leaves the trunk, from below", exit + p1_side * 2.2 + Vector3.DOWN * 1.2, exit + Vector3.UP * 0.3])
		views.append(["the fork from above, 3 m", oc + Vector3(1.0, oak.crown_base + 3.5, 1.0), oc + Vector3(0, oak.crown_base, 0)])
	else:
		for r in rows:
			var o: ArenaLayout.OutpostData = r[0]
			var side := o.out.cross(Vector3.UP).normalized()
			views.append(["oak %d outpost: in front" % r[1].id, o.centre + o.out * 4.0 + Vector3.UP * 1.0 + side * 0.8, o.centre + Vector3.UP * 0.3])
			views.append(["from the side", o.centre + side * 3.2 + o.out * 0.8 + Vector3.UP * 0.6, o.centre - o.out * 0.2 + Vector3.UP * 0.3])
			views.append(["from above", o.centre + o.out * 1.6 + Vector3.UP * 3.5 + side * 0.4, o.centre])
	var cols := 3
	var n_rows := ceili(views.size() / float(cols))
	var sheet := Image.create(CELL.x * cols, CELL.y * n_rows, false, Image.FORMAT_RGB8)
	for i in views.size():
		var v: Array = views[i]
		cam.look_at_from_position(v[1], v[2], Vector3.UP)
		await frames(40 if i == 0 else 14)
		await RenderingServer.frame_post_draw
		var shot := get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGB8)
		shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
		print("view %d: %s" % [i, v[0]])
	if out != "":
		sheet.save_png(out)
		print("sheet: ", out)
	finish()


## A box: centre, its x along `side`, z along `out`, size (x, y, z).
func _box(centre: Vector3, side: Vector3, out_dir: Vector3, size: Vector3) -> Dictionary:
	return {"c": centre, "x": side, "z": out_dir, "half": size * 0.5}


## How far `p` is outside box `b` (negative inside).
func _box_dist(b: Dictionary, p: Vector3) -> float:
	var d: Vector3 = p - (b.c as Vector3)
	var q: Vector3 = Vector3(absf(d.dot(b.x)), absf(d.y), absf(d.dot(b.z))) - (b.half as Vector3)
	var outside := Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length()
	return outside + minf(maxf(q.x, maxf(q.y, q.z)), 0.0)


## [limb index, deepest (m into the box past the limb's surface), length of limb axis within its radius of the box]
## for each of `t`'s drawn limbs that reaches into box `b`.
func _limbs_in(t: ArenaLayout.TreeData, b: Dictionary) -> Array:
	var hits := []
	for li in t.limbs.size():
		var pts: PackedVector3Array = t.limbs[li][0]
		var radii: PackedFloat32Array = t.limbs[li][1]
		var worst := 0.0
		var inside := 0.0
		for i in pts.size() - 1:
			var seg := pts[i].distance_to(pts[i + 1])
			var n := maxi(1, ceili(seg / 0.05))
			for k in n:
				var u := (k + 0.5) / n
				var q := pts[i].lerp(pts[i + 1], u)
				var r := lerpf(radii[i], radii[i + 1], u)
				if Vector2(q.x - t.base.x, q.z - t.base.y).length() + r < Pinewood._bole_r(t, q.y):
					continue   # (hidden inside the trunk as drawn)
				var d := _box_dist(b, q) - r
				if d < 0.0:
					worst = maxf(worst, -d)
					inside += seg / n
		if worst > 0.0:
			hits.append([li, worst, inside])
	return hits


func _deg(v: Vector3) -> String:
	return "%.0f deg" % rad_to_deg(atan2(v.x, v.z))
