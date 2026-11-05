extends TestCase
## Diagnostic: how birds hit wood -- every bonk's speed, speed into the surface and angle of approach (0 skimming
## along it .. 90 square on), and which side of the bird took it (belly, back, flank, chest), in three settings:
##   flock    the AI flock (AIPilot) in the pine wood, 90 s;
##   straight unguided birds glided straight through the pine wood from random points, headings and speeds (a
##            stand-in for a player who doesn't steer round the trees): the first hit of each;
##   match    a 3 v 3 of combat-AI birds (pilot), 120 s.
## BONK_MODE=flock|straight|match (default all). Headless: .\probe.ps1 probe_bonk_angles -Headless

const GLANCE_INTO := 3.0     ## m/s: the proposed glance's limit into the surface
const GLANCE_DEG := 35.0     ## deg: and of approach angle

var stats := {}


func _init() -> void:
	timeout_sec = 900.0


func setup() -> void:
	var mode := OS.get_environment("BONK_MODE")
	var all := []
	for m in ["flock", "straight", "match"]:
		if mode == "" or mode == m:
			stats = {"ticks": 0, "braces": 0, "glances": 0, "braced_glances": 0, "missed": 0}
			Perf.on = true
			Perf._acc.clear()
			var rows: Array = await call("_" + m)
			_report(m, rows)
			print("  braces %d (%d ended in a glance, %d touched nothing: a false alarm), glances %d in all; %.1f bird-minutes; brace check %.1f us per bird-tick" % [
				stats.braces, stats.braced_glances, stats.missed, stats.glances, stats.ticks / 3600.0, float(Perf._acc.get("bird.brace", 0)) / maxf(stats.ticks, 1)])
			for k2 in ["bird.brace", "x.brace.dist", "x.brace.touch"]:
				print("  PERF %s %.1f us per bird-tick" % [k2, float(Perf._acc.get(k2, 0)) / maxf(stats.ticks, 1)])
			Perf.on = false
			all += rows
	if mode == "":
		_report("all", all)
	finish()


## Watch `birds` for `ticks` physics ticks (`step` awaits one), recording each bonk against the velocity and body
## frame of the tick before. `first_only`: stop watching a bird after its first.
func _watch(birds: Array, ticks: int, step: Callable, first_only := false) -> Array:
	var rows := []
	var prev := {}
	var done := {}
	for b: Bird in birds:
		b.bonked.connect(func(n: Vector3, into: float):
			if done.has(b) or not prev.has(b):
				return
			var p: Array = prev[b]
			var v: Vector3 = p[0]
			var basis: Basis = p[1]
			var spd := v.length()
			var deg := rad_to_deg(asin(clampf(into / maxf(spd, 1e-3), 0.0, 1.0)))
			# (the side that took it: the contact normal points from the wood to the bird, so the bird's own side
			# facing the wood is -n)
			var l := basis.inverse() * -n
			var side := "flank"
			if l.y < -0.6: side = "belly"
			elif l.y > 0.6: side = "back"
			elif l.z < -0.6: side = "chest"
			elif l.z > 0.6: side = "rear"
			rows.append({"id": b.profile.id, "speed": spd, "into": into, "deg": deg, "side": side, "y": b.global_position.y})
			if first_only:
				done[b] = true)
	var pend := {}   # bird -> sim s its brace began, until it touches
	var last := {}
	stats.ticks += ticks * birds.size()
	for f in ticks:
		for b: Bird in birds:
			if is_instance_valid(b):
				prev[b] = [b.model.velocity, b.global_basis]
		await step.call()
		var now := f / 60.0
		for b: Bird in birds:
			if not is_instance_valid(b) or done.has(b):
				continue
			var was: Array = last.get(b, [0, 0, 0])
			if b.braces > int(was[0]):
				stats.braces += 1
				pend[b] = now
			if b.glances > int(was[1]):
				stats.glances += 1
				if pend.has(b):
					stats.braced_glances += 1
					pend.erase(b)
			if b.bonks > int(was[2]):
				pend.erase(b)
			if pend.has(b) and now - float(pend[b]) > Bird.REFLEX_AHEAD + 0.15:
				stats.missed += 1
				pend.erase(b)
			last[b] = [b.braces, b.glances, b.bonks]
		if first_only and done.size() == birds.size():
			break
	return rows


func _flock() -> Array:
	var layout := Pinewood.generate(7)
	var arena := ArenaBuilder.new()
	arena.looks = false
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var birds := []
	for i in BirdProfile.IDS.size():
		var b := Bird.new()
		add_child(b)
		b.setup(BirdProfile.by_id(BirdProfile.IDS[i]), layout, AIPilot.new(layout, 1000 + i))
		b.arena = arena
		b.rig.visible = false
		b.perch_at(layout.perches[(i * 53 + 5) % layout.perches.size()])
		birds.append(b)
	var rows := await _watch(birds, 90 * 60, func(): await get_tree().physics_frame)
	for b in birds:
		b.queue_free()
	arena.queue_free()
	await frames(2)
	return rows


func _straight() -> Array:
	var layout := Pinewood.generate(7)
	var arena := ArenaBuilder.new()
	arena.looks = false
	add_child(arena)
	arena.build(layout)
	await frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rows := []
	for round in 12:
		var birds := []
		for id in BirdProfile.IDS:
			var b := Bird.new()
			add_child(b)
			b.setup(BirdProfile.by_id(id), layout, null)
			b.arena = arena
			b.rig.visible = false
			var r := layout.reach(Vector2.ZERO) * 0.6 * sqrt(rng.randf())
			var a := rng.randf() * TAU
			var h := rng.randf() * TAU
			var at := Vector3(cos(a) * r, rng.randf_range(2.0, 12.0), sin(a) * r)
			b.fly_from(at, Vector3(cos(h), 0.0, sin(h)), b.profile.v_best * rng.randf_range(0.6, 1.4))
			birds.append(b)
		rows += await _watch(birds, 6 * 60, func(): await get_tree().physics_frame, true)
		for b in birds:
			b.queue_free()
		await frames(1)
	arena.queue_free()
	await frames(2)
	return rows


func _match() -> Array:
	var layout := Pinewood.generate(7)
	var a := CombatWorld.far_base(layout, Vector3(60, 0, 0))
	var b := CombatWorld.far_base(layout, a.position)
	var d := Duel.new()
	add_child(d)
	d.setup(layout, {0: a, 1: b})
	await frames(1)
	for team in [0, 1]:
		var base: Perch = d.world.bases[team]
		var other: Perch = d.world.bases[1 - team]
		var toward := Vector3(other.position.x - base.position.x, 0.0, other.position.z - base.position.z).normalized()
		var across := Vector3(-toward.z, 0.0, toward.x)
		for i in 3:
			var at := base.position + toward * 12.0 + across * (float(i) - 1.0) * 6.0 + Vector3.UP * (6.0 + 2.0 * i)
			d.add_ai(["crow", "sparrow", "hawk"][i], team, at, toward, CombatSkill.preset("pilot"), 20 + team * 10 + i)
	var birds := d.entries.map(func(e): return e.bird)
	var rows := await _watch(birds, 120 * 60, func(): await d.step())
	d.cleanup()
	d.queue_free()
	await frames(2)
	return rows


func _report(name: String, rows: Array) -> void:
	var n := rows.size()
	print("== %s: %d bonks" % [name, n])
	if n == 0:
		return
	var bins := [10.0, 20.0, 35.0, 50.0, 70.0, 90.1]
	var by_deg := []
	by_deg.resize(bins.size())
	by_deg.fill(0)
	var into_bins := [1.5, 2.0, 3.0, 4.5, 6.0, 1e9]
	var by_into := []
	by_into.resize(into_bins.size())
	by_into.fill(0)
	var sides := {}
	var glance := 0
	var lost_glance := 0.0
	for r: Dictionary in rows:
		for i in bins.size():
			if r.deg < bins[i]:
				by_deg[i] += 1
				break
		for i in into_bins.size():
			if r.into < into_bins[i]:
				by_into[i] += 1
				break
		sides[r.side] = int(sides.get(r.side, 0)) + 1
		if r.into < GLANCE_INTO and r.deg < GLANCE_DEG and r.side != "back":
			glance += 1
			lost_glance += r.speed * 0.4   # (what the old bonk cost: it kept 60% of the speed)
	var line := "  angle (deg):"
	var lo := 0.0
	for i in bins.size():
		line += "  %.0f-%.0f %d" % [lo, minf(bins[i], 90.0), by_deg[i]]
		lo = bins[i]
	print(line)
	line = "  into (m/s):"
	lo = 1.0
	for i in into_bins.size():
		line += "  %s %d" % ["%.1f-%.1f" % [lo, into_bins[i]] if into_bins[i] < 1e8 else ">%.1f" % lo, by_into[i]]
		lo = into_bins[i]
	print(line)
	print("  side: %s" % sides)
	var mean_spd := 0.0
	var mean_into := 0.0
	for r: Dictionary in rows:
		mean_spd += r.speed / n
		mean_into += r.into / n
	print("  mean speed %.1f m/s, mean into %.1f m/s" % [mean_spd, mean_into])
	print("  would glance (into < %.0f m/s, under %.0f deg, not on the back): %d of %d (%.0f%%), which the old bonk cost %.1f m/s each on average" % [GLANCE_INTO, GLANCE_DEG, glance, n, 100.0 * glance / n, lost_glance / maxf(glance, 1)])
	if OS.get_environment("BONK_ROWS") != "":
		for r: Dictionary in rows:
			print("  ROW %-7s v %4.1f into %4.1f deg %4.1f %-5s y %.1f" % [r.id, r.speed, r.into, r.deg, r.side, r.y])
