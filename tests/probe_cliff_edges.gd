extends TestCase
## The escarpment's structure, exactly, from its model (Escarpment): for tools/cliff_edges.py to draw as a front
## elevation (along the cliff x height) and a top view (along the cliff x out from the middle), and to measure.
##   Godot --path . --headless -- --run-test probe_cliff_edges --out <json> [--seed 7]
## Writes: the sampling; a depth image of the wall seen from the front (how far back the face stands, m, at each
## (arc, z)); the ground's height seen from above (at each (arc, r)); and the structure as lines -- each bed's foot,
## each joint (the bed it cuts, its arc), the lips (a bed's foot jutting past the top of the bed under it), the ledges,
## the skyline, the clefts.

const STEP := 0.25   ## m: the images' sampling


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var seed_arg := Boot.arg_value(args, "--seed")
	var layout := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	var esc := layout.rock
	esc.height(0.0, 0.0)   # (lays the beds down)
	var half := Escarpment.HALF * esc.foot
	var arcs := []
	var a := -half
	while a <= half:
		arcs.append(a)
		a += STEP
	var z_max := Escarpment.SKYLINE.z + 2.0
	var nz := int(z_max / STEP) + 1
	var r_lo := esc.foot - Escarpment.SCREE - 2.0
	var nrr := int((Escarpment.PLATEAU + 45.0 + Escarpment.SCREE) / STEP)
	var front := PackedFloat32Array()   # (row-major: z rows, arc columns; NaN where there's no wall)
	var plan := PackedFloat32Array()    # (r rows, arc columns)
	var feet := []
	var skyline := []
	var lips := []
	var ledges := []
	var clefts := []
	var r0s := []   # (each column's foot radius: the front image is m back from it)
	front.resize(nz * arcs.size())
	plan.resize(nrr * arcs.size())
	for ci in arcs.size():
		var arc: float = arcs[ci]
		var theta := esc.at + arc / esc.foot
		var col := esc.column(theta)
		r0s.append(col[1] if not col.is_empty() else esc.foot)
		if col.is_empty():
			for zi in nz:
				front[zi * arcs.size() + ci] = NAN
			for ri in nrr:
				plan[ri * arcs.size() + ci] = 0.0
			continue
		var rows := int(col[4])
		var r0: float = col[1]
		var top: float = col[3]
		skyline.append([arc, top])
		if esc.gully(arc) > 0.5:
			clefts.append(arc)
		# The front: the face's radius at each height (the rows, between them linearly), as m back from r0.
		for zi in nz:
			var z := zi * STEP
			var v := NAN
			if z <= top:
				for j in rows - 1:
					var z0: float = col[5 + j * 2]
					var z1: float = col[5 + (j + 1) * 2]
					if z >= z0 and z <= z1 and z1 > z0:
						v = lerpf(col[6 + j * 2], col[6 + (j + 1) * 2], (z - z0) / (z1 - z0)) - r0
						break
			front[zi * arcs.size() + ci] = v
		for ri in nrr:
			plan[ri * arcs.size() + ci] = esc.height_in(col, r_lo + ri * STEP)
		# Each bed's foot (its lowest row), where it's below the top; a lip where it juts past the top of the bed under it.
		var per := Escarpment.ROW_F.size()
		for b in rows / per:
			var j := b * per
			var zf: float = col[5 + j * 2]
			if zf <= 0.01 or zf >= top - 0.01:
				continue
			feet.append([b, arc, zf, col[6 + j * 2] - r0])
			if j > 0 and col[6 + j * 2] < col[6 + (j - 1) * 2] - 0.3:
				lips.append([b, arc, zf, col[6 + (j - 1) * 2] - col[6 + j * 2]])
		for l in esc.ledges(col):
			ledges.append([arc, l[2], float(l[0]) - r0, float(l[1]) - r0])
	# The joints: each bed's, where the bed shows (its foot below the top somewhere near), with the heights it spans.
	var joints := []
	for b in esc._joints.size():
		for ja in esc._joints[b]:
			if ja < -half or ja > half:
				continue
			var col := esc.column(esc.at + ja / esc.foot)
			if col.is_empty():
				continue
			var per := Escarpment.ROW_F.size()
			var z0: float = col[5 + (b * per) * 2]
			var z1: float = col[5 + (b * per + per - 1) * 2]
			if z1 - z0 > 0.05:
				joints.append([b, ja, z0, z1])
	var data := {
		"step": STEP, "arcs": arcs.size(), "arc0": -half, "nz": nz, "nr": nrr, "r0": r_lo - esc.foot,
		"front": Array(front), "plan": Array(plan), "beds": Array(esc._beds), "hard": Array(esc._hard),
		"feet": feet, "joints": joints, "lips": lips, "ledges": ledges, "skyline": skyline, "clefts": clefts, "r0s": r0s, "foot": esc.foot,
	}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("cliff edges: %d columns, %d joints, %d lip samples, %d ledge samples -> %s" % [arcs.size(), joints.size(), lips.size(), ledges.size(), out])
	finish()
