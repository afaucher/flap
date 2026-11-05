class_name RaceView
extends Node3D
## The course drawn, placeholder style (the gate designs come later): each window as a thin frame, a banner bar over
## the post and trunk gates, red and white bands on their posts and trunks, a ring for each hoop on its ropes (a
## span hoop's rope strung between its trunks), the start perch marked. Visual only: the posts' wood is the layout's
## (RaceCourse.apply), the frames and ropes have no collision. set_next() colours them: the next gate bright, the one
## after it softer, those passed green, the rest pale, the finish black and white.

const NEXT := Color(1.0, 0.45, 0.1)
const AFTER := Color(1.0, 0.75, 0.45)
const LATER := Color(0.92, 0.9, 0.85)
const PASSED := Color(0.35, 0.8, 0.4)
const FINISH := Color(0.08, 0.08, 0.08)
const ROPE := Color(0.55, 0.45, 0.3)
const BAND := Color(0.75, 0.12, 0.08)
const BAR := 0.05   ## m: the frame's thickness

var course: RaceCourse
var _mats: Array[StandardMaterial3D] = []   ## each gate's frame


func build(c: RaceCourse) -> void:
	course = c
	var rope := _mat(ROPE, false)
	var band := _mat(BAND, false)
	var white := _mat(Color(0.95, 0.95, 0.92), false)
	for g in c.gates:
		var m := _mat(LATER, true)
		_mats.append(m)
		var root := Node3D.new()
		add_child(root)
		var basis := Basis(g.right(), Vector3.UP, -g.normal)   # (local x along the window, -z the way through)
		if g.kind == "hoop":
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = g.half_w - BAR
			torus.outer_radius = g.half_w + BAR
			torus.rings = 48
			ring.mesh = torus
			ring.material_override = m
			ring.transform = Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5), g.centre)   # (the torus lies flat: stood up across the way through)
			root.add_child(ring)
		else:
			var w := g.half_w
			var h := g.half_h
			for e in [[Vector3(-w, -h, 0), Vector3(w, -h, 0)], [Vector3(-w, h, 0), Vector3(w, h, 0)], [Vector3(-w, -h, 0), Vector3(-w, h, 0)], [Vector3(w, -h, 0), Vector3(w, h, 0)]]:
				root.add_child(_bar(g.centre + basis * (e[0] as Vector3), g.centre + basis * (e[1] as Vector3), BAR, m))
			for i in g.poles.size():   # (bands on the posts or trunks beside the window)
				for k in 3:
					var y := g.centre.y - g.half_h + g.half_h * (0.33 + k * 0.67)
					var c3 := Vector3(g.poles[i].x, y, g.poles[i].y)
					var bm := MeshInstance3D.new()
					var cyl := CylinderMesh.new()
					cyl.top_radius = g.pole_r[i] + 0.02
					cyl.bottom_radius = g.pole_r[i] + 0.03
					cyl.height = 0.35
					bm.mesh = cyl
					bm.material_override = band if k % 2 == 0 else white
					bm.position = c3
					root.add_child(bm)
		for r in g.ropes():
			root.add_child(_bar(r[0], r[1], 0.015 if g.kind == "hoop" else 0.04, rope if g.kind == "hoop" else m))
	var st := MeshInstance3D.new()   # (the start: a disc over the rail)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	st.mesh = disc
	st.material_override = _mat(NEXT, true)
	st.position = c.start.position + Vector3.UP * 0.6
	add_child(st)
	set_next(0)


## Colour the gates for a run whose next gate is `next`.
func set_next(next: int) -> void:
	for k in _mats.size():
		var c := LATER
		if k < next:
			c = PASSED
		elif k == next:
			c = NEXT
		elif k == next + 1:
			c = AFTER
		if course.gates[k].finish and k >= next:
			c = FINISH if k > next else NEXT.lerp(FINISH, 0.4)
		_mats[k].albedo_color = c
		_mats[k].emission = c * (0.9 if k == next else 0.25)


func _bar(a: Vector3, b: Vector3, r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 6
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = m
	var d := (b - a).normalized()
	var x := d.cross(Vector3.FORWARD if absf(d.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, d, x.cross(d)), (a + b) * 0.5)
	return mi


static func _mat(c: Color, glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if glow:
		m.emission_enabled = true
		m.emission = c * 0.25
	return m
