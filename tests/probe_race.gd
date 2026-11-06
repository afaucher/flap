extends TestCase
## Diagnostic: a race course and how the birds fly it.
##   .\probe.ps1 -Headless probe_race [--seed 7] [--course <n>] [--out <dir>] [--skills recruit,pilot,ace]
##                                    [--birds crow,owl,hawk,falcon,sparrow] [--seconds 150] [--no-trials]
##                                    [--plan-for <birds>] (the birds the course is planned for: RaceCourse.Envelope)
## Prints the course gate by gate (kind, height, leg, climb, the turn at the gate before, the tightest radius a smooth
## line needs) against each bird's turning circle (at cruise: AIPilot.cruise_turn_radius; at its tightest: 1.2 x its
## stall speed at its bank limit), then races every bird at every skill (RaceTrial, all at once: they don't collide)
## and prints each one's time, misses, go-arounds and touches of wood. Writes <out>/race_course.svg: the course from
## above over the wood, with each skill's crow (or the first bird) flown over it, and its height profile.

var out_dir := "user://race"


func _init() -> void:
	timeout_sec = 900.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var arena_seed := int(Boot.arg_value(args, "--seed")) if Boot.arg_value(args, "--seed") != "" else 7
	var course_seed := int(Boot.arg_value(args, "--course")) if Boot.arg_value(args, "--course") != "" else arena_seed
	if Boot.arg_value(args, "--out") != "":
		out_dir = Boot.arg_value(args, "--out")
	var skills := (Boot.arg_value(args, "--skills") if Boot.arg_value(args, "--skills") != "" else "recruit,pilot,ace").split(",")
	var birds := (Boot.arg_value(args, "--birds") if Boot.arg_value(args, "--birds") != "" else ",".join(BirdProfile.IDS)).split(",")
	var seconds := float(Boot.arg_value(args, "--seconds")) if Boot.arg_value(args, "--seconds") != "" else 150.0
	var pilot_seed := int(Boot.arg_value(args, "--pilot-seed")) if Boot.arg_value(args, "--pilot-seed") != "" else 100   # (the first racer's; the next +1 ...)

	var layout := Pinewood.generate(arena_seed)
	RaceCourse.debug = true
	var plan_for := (Boot.arg_value(args, "--plan-for") if Boot.arg_value(args, "--plan-for") != "" else ",".join(BirdProfile.IDS)).split(",")
	var course := RaceCourse.generate(layout, course_seed, Array(plan_for), Boot.arg_value(args, "--style"))
	print("RACE planned for %s: turning circle %.1f m, half span %.2f m, way in %.1f m, way out %.1f m, level run-in %.1f m" % [",".join(plan_for), course.envelope.turn_r, course.envelope.half_span, course.envelope.entry(), course.envelope.exit(), course.envelope.dive_run()])
	print("RACE arena %d course %d: %d gates, %.0f m, built in %.0f ms; start perch %d at (%.1f, %.1f, %.1f)" % [arena_seed, course_seed,
		course.gates.size(), course.length(), course.build_ms, course.start.id, course.start.position.x, course.start.position.y, course.start.position.z])
	var probs := course.problems()
	print("RACE candidates: %d (%d checked); options turned away: %s" % [course._pool.size(), course._valid.size(), course.why])
	print("RACE rules: ", "all kept" if probs.is_empty() else "; ".join(probs))
	_table(course)
	if not args.has("--no-trials"):
		var trial := RaceTrial.new()
		add_child(trial)
		trial.setup(layout, course)
		var i := 0
		for s in skills:
			for id in birds:
				trial.add_ai(id, s, pilot_seed + i)
				i += 1
		var t0 := Time.get_ticks_msec()
		var trace := Boot.arg_value(args, "--trace")   # (<skill>,<bird>: its flight, every 0.25 s, near the gate it's on)
		if trace != "":
			var e0: Dictionary = trial.entries.filter(func(x): return x.skill + "," + x.bird.profile.id == trace)[0]
			for f in int(seconds * 60.0):
				await trial.step()
				if f % 15 == 0:
					var b: Bird = e0.bird
					var pl: RacePilot = e0.pilot
					var r: RaceRun = e0.run
					if r.finished() or pl.dnf:
						break
					if r.home():   # (on the way home: how it's getting on with the rail)
						var d := b.global_position - course.start.position
						print("HOME t=%5.2f dist=%5.1f dy=%+5.1f v=%4.1f state=%d mode=%d target=%s route=%d wp=%d reason=%s avoid=%.1f" % [r.clock, d.length(), d.y, b.model.speed,
							b.state, pl.guide.mode, "rail" if pl.guide.target == course.start else str(pl.guide.target), pl.guide.route.size(), pl.guide.wp, pl.guide.debug_reason, pl.guide.avoiding])
						continue
					var g := course.gates[r.next]
					var o := b.global_position - g.centre
					print("TRACE t=%5.2f next=%d along=%+6.1f lat=%+5.1f dy=%+5.1f v=%4.1f path=%+4.0f bank=%+4.0f around=%s avoid=%.1f aim=(%+.1f %+.1f %+.1f) st=%d" % [r.clock, r.next,
						o.dot(g.normal), o.dot(g.right()), o.y, b.model.speed, rad_to_deg(b.model.path_angle), rad_to_deg(b.model.bank), pl._around, pl.guide.avoiding,
						(pl._aim - g.centre).dot(g.normal), (pl._aim - g.centre).dot(g.right()), pl._aim.y - g.centre.y, b.state])
		await trial.run(seconds)
		print("RACE trials: %d birds, %.1f s wall" % [trial.entries.size(), (Time.get_ticks_msec() - t0) / 1000.0])
		_results(trial, course)
		_svg(course, layout, trial)
	else:
		_svg(course, layout, null)
	finish()


func _table(course: RaceCourse) -> void:
	print("RACE  #  kind        height  leg m  climb  turn   radius  marked")
	for lg in course.legs():
		print("RACE %2d  %-10s %5.1f  %5.1f  %+5.0f  %+5.0f  %6.1f  %s" % [lg.gate, lg.kind, lg.height, lg.plan, lg.climb, lg.turn, lg.radius, "yes" if lg.marked else ""])
	var kinds := {}
	var left := 0
	var right := 0
	var wound := 0.0
	var lo := INF
	var hi := -INF
	for lg in course.legs():
		kinds[lg.kind] = int(kinds.get(lg.kind, 0)) + 1
		left += 1 if lg.turn > 15.0 else 0
		right += 1 if lg.turn < -15.0 else 0
		wound += lg.turn
		lo = minf(lo, lg.height)
		hi = maxf(hi, lg.height)
	print("RACE shape: %s; turns %d left, %d right, %+.0f deg in all; windows %.1f-%.1f m up" % [kinds, left, right, wound, lo, hi])
	print("RACE turning circles (m): cruise (v* at 85% bank) / tightest (1.2 v_stall at the bank limit)")
	var line := "RACE   gate radius  "
	for id in BirdProfile.IDS:
		var p := BirdProfile.by_id(id)
		line += "  %s %.1f/%.1f" % [id, AIPilot.cruise_turn_radius(p), _tightest(p)]
	print(line)
	for lg in course.legs():
		var row := "RACE  %2d  %6.1f  " % [lg.gate, lg.radius]
		for id in BirdProfile.IDS:
			var p := BirdProfile.by_id(id)
			var r: float = lg.radius
			row += "  %-14s" % ("ok" if r >= AIPilot.cruise_turn_radius(p) else ("slow down" if r >= _tightest(p) else "too tight"))
		print(row)


static func _tightest(p: BirdProfile) -> float:
	var v := p.v_stall * 1.2
	return v * v / (BirdProfile.G * tan(deg_to_rad(p.max_bank_deg)))


func _results(trial: RaceTrial, course: RaceCourse) -> void:
	print("RACE  skill    bird      time    gates  misses  arounds  bonks  glances  wings  dnf")
	for r in trial.results():
		print("RACE  %-8s %-8s %6s  %2d/%d   %3d     %3d     %3d    %3d     %3d    %s" % [r.skill, r.id, ("%.1f" % r.time) if r.time < INF else "-",
			r.gates, course.gates.size(), r.misses, r.go_arounds, r.bonks, r.glances, r.wing_strikes, "DNF" if r.dnf else ""])
	print("RACE splits (s at each gate):")
	for r in trial.results():
		var s := PackedStringArray()
		for x in r.splits:
			s.append("%.1f" % x)
		print("RACE  %-8s %-8s %s%s" % [r.skill, r.id, " ".join(s), ("  missed at " + str(r.missed_at)) if not r.missed_at.is_empty() else ""])


## The course from above (and its height profile under it), the wood behind, each skill's first bird flown over it.
func _svg(course: RaceCourse, layout: ArenaLayout, trial: RaceTrial) -> void:
	var px := 5.0
	var half := layout.boundary + 4.0
	var w := half * 2.0 * px
	var prof_h := 260.0
	var s := PackedStringArray()
	s.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="sans-serif" font-size="13">' % [w, w + prof_h + 40])
	s.append('<rect width="100%" height="100%" fill="#f2efe6"/>')
	var at := func(p: Vector3) -> Vector2: return Vector2(p.x + half, p.z + half) * px
	s.append('<circle cx="%.0f" cy="%.0f" r="%.0f" fill="none" stroke="#999"/>' % [half * px, half * px, layout.boundary * px])
	for o in layout.openings:
		var pts := PackedStringArray()
		for k in 72:
			var q: Vector2 = o.centre + Vector2.from_angle(TAU * k / 72.0) * Pinewood.edge(o, o.centre + Vector2.from_angle(TAU * k / 72.0))
			var v: Vector2 = at.call(Vector3(q.x, 0.0, q.y))
			pts.append("%.0f,%.0f" % [v.x, v.y])
		s.append('<polygon points="%s" fill="#fbf3d0" stroke="#e0c060"/>' % " ".join(pts))
	for t in layout.trees:
		var v: Vector2 = at.call(Vector3(t.base.x, 0.0, t.base.y))
		match t.kind:
			ArenaLayout.Kind.PINE:
				s.append('<circle cx="%.0f" cy="%.0f" r="%.0f" fill="#c9d8c4"/>' % [v.x, v.y, 2.5 * px if t.form == "" else (1.2 if t.form == "pole" else 4.5) * px])
				s.append('<circle cx="%.0f" cy="%.0f" r="%.1f" fill="#24502a"/>' % [v.x, v.y, maxf(1.5, t.radius * px)])
			ArenaLayout.Kind.BROADLEAF:
				s.append('<circle cx="%.0f" cy="%.0f" r="%.0f" fill="#e2d4b8"/>' % [v.x, v.y, 9.0 * px])
				s.append('<circle cx="%.0f" cy="%.0f" r="%.1f" fill="#6b4520"/>' % [v.x, v.y, t.radius * px])
			ArenaLayout.Kind.POST:
				s.append('<circle cx="%.0f" cy="%.0f" r="2.5" fill="#c03020"/>' % [v.x, v.y])
	var colors := {"recruit": "#d08020", "pilot": "#2060c0", "ace": "#a020a0"}
	if trial != null:
		var shown := {}
		for e in trial.entries:
			if shown.has(e.skill) or (e.bird.profile.id != "crow" and trial.entries.any(func(x): return x.skill == e.skill and x.bird.profile.id == "crow")):
				continue
			shown[e.skill] = true
			var pts := PackedStringArray()
			for p in e.track:
				var v: Vector2 = at.call(p)
				pts.append("%.0f,%.0f" % [v.x, v.y])
			s.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="1.6" opacity="0.8"/>' % [" ".join(pts), colors.get(e.skill, "#333")])
	# Legs, coloured by the height they end at.
	var lo := INF
	var hi := -INF
	for g in course.gates:
		lo = minf(lo, g.centre.y)
		hi = maxf(hi, g.centre.y)
	for k in course.gates.size():   # (each leg's planned line: the smooth curve, or its route through the wood)
		var pts := []
		for p in course.flown_line(course.gates, k):
			var v: Vector2 = at.call(p)
			pts.append("%.0f,%.0f" % [v.x, v.y])
		s.append('<polyline points="%s" fill="none" stroke="#202020" stroke-width="1.2" stroke-dasharray="6,4"/>' % " ".join(pts))
	if not course.gates.is_empty():   # (home: the last gate to the rail's run-in, then in to the rail)
		var hp := [course.gates[-1].centre, course.home_in(), course.start.position]
		for j in 2:
			var a: Vector2 = at.call(hp[j])
			var b: Vector2 = at.call(hp[j + 1])
			s.append('<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="#e07800" stroke-width="2.5" stroke-dasharray="6,4"/>' % [a.x, a.y, b.x, b.y])
	var ks := {"post": "#c03020", "trunk": "#1a7a3a", "hoop": "#2050c0"}
	for k in course.gates.size():
		var g := course.gates[k]
		var c: Vector2 = at.call(g.centre)
		var r := g.right() * g.half_w
		var a: Vector2 = at.call(g.centre + r)
		var b: Vector2 = at.call(g.centre - r)
		var col: String = "#000000" if k == course.gates.size() - 1 else ks[g.kind]
		s.append('<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="%s" stroke-width="5"/>' % [a.x, a.y, b.x, b.y, col])
		var tip: Vector2 = at.call(g.centre + g.normal * 4.0)
		s.append('<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="%s" stroke-width="2"/>' % [c.x, c.y, tip.x, tip.y, col])
		s.append('<text x="%.0f" y="%.0f" fill="%s" font-weight="bold">%d%s %.0fm</text>' % [c.x + 8, c.y - 8, col, k + 1, " L" if k == course.gates.size() - 1 else ("*" if g.marked else ""), g.centre.y])
	var st: Vector2 = at.call(course.start.position)
	s.append('<rect x="%.0f" y="%.0f" width="12" height="12" fill="#000"/><text x="%.0f" y="%.0f">start %.0fm</text>' % [st.x - 6, st.y - 6, st.x + 10, st.y + 4, course.start.position.y])
	s.append('<text x="10" y="20">post (red), trunk (green), hoop (blue), last (black, then home to the rail); * needs course markers. Flown: recruit (orange), pilot (blue), ace (purple)</text>')
	# Height profile: distance along the course against height, each gate's window as a bar.
	var y0 := w + 20.0
	var total := course.length()
	var sx := (w - 60.0) / maxf(total, 1.0)
	var sy := (prof_h - 30.0) / maxf(hi + 4.0, 10.0)
	var base_y := y0 + prof_h - 10.0
	s.append('<line x1="40" y1="%.0f" x2="%.0f" y2="%.0f" stroke="#7a6a50" stroke-width="2"/>' % [base_y, w - 20.0, base_y])
	var dist := 0.0
	var prev := course.start.position
	var pts := PackedStringArray(["%.0f,%.0f" % [40.0, base_y - prev.y * sy]])
	for k in course.gates.size():
		var g := course.gates[k]
		dist += prev.distance_to(g.centre)
		var x := 40.0 + dist * sx
		pts.append("%.0f,%.0f" % [x, base_y - g.centre.y * sy])
		s.append('<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" stroke="%s" stroke-width="6"/>' % [x, base_y - (g.centre.y - g.half_h) * sy, x, base_y - (g.centre.y + g.half_h) * sy, "#000" if k == course.gates.size() - 1 else ks[g.kind]])
		s.append('<text x="%.0f" y="%.0f">%d</text>' % [x - 4, base_y - (g.centre.y + g.half_h) * sy - 6, k + 1])
		prev = g.centre
	s.append('<polyline points="%s" fill="none" stroke="#202020" stroke-dasharray="6,4"/>' % " ".join(pts))
	s.append('<text x="40" y="%.0f">height (m) along the course (%.0f m); 0-%.0f m</text>' % [y0 + 4, total, hi + 4.0])
	s.append('</svg>')
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := ProjectSettings.globalize_path(out_dir.path_join("race_course.svg"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(s))
	f.close()
	var img := Image.new()   # (and as a PNG, to look at anywhere)
	if img.load_svg_from_string("
".join(s)) == OK:
		img.save_png(path.get_basename() + ".png")
	print("RACE map: ", path, " (and .png)")
