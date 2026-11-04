extends TestCase
## The escarpment from straight above, exactly, from its model: the ground's height (Escarpment.height, the envelope:
## the highest rock at each spot, the talus, the plateau) on a world grid, for tools/cliff_plan.py to draw as a plan
## (hillshade, contours) -- the whole wrap, and the middle close up. And, per column, where the wall's face stands at
## each height (its rows), to draw the face's lines in plan.
##   Godot --path . --headless -- --run-test probe_cliff_plan --out <dir> [--seed 7]
## Writes <dir>/plan_wide.bin and plan_mid.bin (float32 heights, row-major, north up) and plan.json (their grids, the
## sector, the boundary, the reach, the face lines).


func _init() -> void:
	timeout_sec = 600.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out := Boot.arg_value(args, "--out")
	var seed_arg := Boot.arg_value(args, "--seed")
	Pinewood.cliff = true   # (the escarpment is what this measures)
	var layout := Pinewood.generate(int(seed_arg) if seed_arg != "" else 7)
	var esc := layout.rock
	var meta := {"boundary": layout.boundary, "at": esc.at, "half": Escarpment.HALF, "foot": esc.foot, "grids": {}}
	var mid := Vector2(sin(esc.at), cos(esc.at)) * esc.foot
	for g in [["wide", Vector2.ZERO, 440.0, 1.0], ["mid", mid, 60.0, 0.15]]:
		var c: Vector2 = g[1]
		var half: float = g[2]
		var step: float = g[3]
		var n := int(half * 2.0 / step)
		var buf := PackedFloat32Array()
		buf.resize(n * n)
		for j in n:
			var z := c.y + half - (j + 0.5) * step   # (row 0: the far north, +z... as seen from above, +z up the image)
			for i in n:
				var x := c.x - half + (i + 0.5) * step
				buf[j * n + i] = esc.height(x, z)
		var f := FileAccess.open(out.path_join("plan_%s.bin" % g[0]), FileAccess.WRITE)
		f.store_buffer(buf.to_byte_array())
		f.close()
		meta.grids[g[0]] = {"cx": c.x, "cz": c.y, "half": half, "step": step, "n": n}
	# The face's lines: for each column across the sector (every 0.5 m at the foot), where the wall stands at each
	# height from 2 m to the top in 4 m steps (the face's plan at that height), and its foot and top edges.
	var lines := {"foot": [], "top": [], "toe": [], "reach": []}
	var levels := []
	for k in 12:
		levels.append(2.0 + 4.0 * k)
		lines["z%d" % (2 + 4 * k)] = []
	var nth := int(Escarpment.HALF * 2.0 * esc.foot / 0.5)
	for t in nth + 1:
		var theta := esc.at - Escarpment.HALF + Escarpment.HALF * 2.0 * t / nth
		var col := esc.column(theta)
		var d := Vector2(sin(theta), cos(theta))
		lines.reach.append([d.x * esc.reach(theta, layout.boundary), d.y * esc.reach(theta, layout.boundary)])
		if col.is_empty():
			continue
		var rows := int(col[4])
		lines.foot.append([d.x * col[6], d.y * col[6]])
		lines.top.append([d.x * esc.top_start(col), d.y * esc.top_start(col)])
		var tw := esc.talus(col)
		lines.toe.append([d.x * (col[6] - tw.x), d.y * (col[6] - tw.x)])
		for lv in levels:
			if lv > col[3]:
				continue
			for j in rows - 1:   # (where the face crosses this height: the first row pair spanning it)
				var z0: float = col[5 + j * 2]
				var z1: float = col[5 + (j + 1) * 2]
				if z0 <= lv and z1 > lv:
					var r := lerpf(col[6 + j * 2], col[6 + (j + 1) * 2], (lv - z0) / (z1 - z0))
					lines["z%d" % int(lv)].append([d.x * r, d.y * r, theta])
					break
	meta.lines = lines
	var f := FileAccess.open(out.path_join("plan.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	print("cliff plan -> %s" % out)
	finish()
