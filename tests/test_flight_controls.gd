extends TestCase
## Stick authority: pull trades speed for height, push trades height for speed (and tucks the wings),
## bank turns, pulling in a bank tightens the turn, and the bank never passes the limit.

const DT := 1.0 / 60.0


## Fly for `secs`; returns how far the heading turned (accumulated per tick, so full circles count).
func fly(m: FlightModel, stick: Vector2, secs: float) -> float:
	var inp := FlightInput.new(stick)
	var turned := 0.0
	for i in int(secs * 60.0):
		var h := m.heading()
		m.step(DT, inp)
		turned += wrapf(m.heading() - h, -PI, PI)
	return turned


func settled(p: BirdProfile) -> FlightModel:
	var m := FlightModel.new(p)
	m.launch(Vector3(0, 300, 0), Vector3.FORWARD, p.v_best)
	fly(m, Vector2.ZERO, 8.0)
	return m


func setup() -> void:
	for p in BirdProfile.all():
		# Pull: the path points up within a second, at a speed cost, and height is gained.
		var m := settled(p)
		var v0 := m.speed
		var y0 := m.position.y
		fly(m, Vector2(0, 0.6), 0.8)
		check(m.path_angle > 0.0, "%s pull climbs (path %.1f deg)" % [p.id, rad_to_deg(m.path_angle)])
		check(m.speed < v0, p.id + " pull costs speed")
		check(not m.stalled, p.id + " a 0.6 pull doesn't stall")
		check(m.position.y > y0, p.id + " pull gains height")

		# Push: speed builds well past best glide, path steepens, wings tuck at full push.
		m = settled(p)
		v0 = m.speed
		fly(m, Vector2(0, -1.0), 3.0)
		check(m.speed > v0 * 1.5, "%s push gains speed (%.1f -> %.1f)" % [p.id, v0, m.speed])
		check(m.fold > 0.9, p.id + " full push tucks the wings")
		check(m.wing_area_eff < p.wing_area * 0.6, p.id + " tuck shrinks the wing")

		# Full bank holds at the limit.
		m = settled(p)
		fly(m, Vector2(1.0, 0.0), 1.0)
		near(rad_to_deg(m.bank), p.max_bank_deg, 0.01, p.id + " bank stops at the limit")
		# A 40-degree bank turns right; bank-and-yank turns tighter.
		var sx := 40.0 / p.max_bank_deg
		m = settled(p)
		var turned_bank := fly(m, Vector2(sx, 0.0), 1.5)
		check(turned_bank > 0.3, "%s right bank turns right (%.2f rad)" % [p.id, turned_bank])
		var m2 := settled(p)
		fly(m2, Vector2(sx, 0.0), 0.3)
		var turned_yank := fly(m2, Vector2(sx, 0.6), 0.25)
		check(m2.load_factor > 1.4, "%s yank pulls g (%.2f)" % [p.id, m2.load_factor])   # (before speed bleeds off)
		turned_yank += fly(m2, Vector2(sx, 0.6), 0.95) + turned_bank * 0.3 / 1.5
		check(turned_yank > turned_bank * 1.2, "%s yank tightens the turn (%.2f vs %.2f rad)" % [p.id, turned_yank, turned_bank])
		# Left mirrors right.
		var m3 := settled(p)
		near(fly(m3, Vector2(-sx, 0.0), 1.5), -turned_bank, 0.02, p.id + " left mirrors right")
		# Letting go levels the wings and returns to the glide.
		fly(m3, Vector2.ZERO, 10.0)
		near(m3.bank, 0.0, 1e-4, p.id + " neutral levels the wings")
		near(rad_to_deg(m3.path_angle), -rad_to_deg(p.glide_angle), 0.5, p.id + " back on the glide slope")

	# Turn rate in a steady bank is the lift's sideways share: omega = n g sin(phi) / (V cos(gamma)).
	var c := BirdProfile.crow()
	var mt := settled(c)
	var phi := deg_to_rad(45.0)
	var stick_x := 45.0 / c.max_bank_deg
	fly(mt, Vector2(stick_x, 0.0), 1.0)
	var omega := fly(mt, Vector2(stick_x, 0.0), 1.0)
	var expected := mt.load_factor * BirdProfile.G * sin(phi) / (mt.speed * cos(mt.path_angle))
	near(omega, expected, expected * 0.1, "turn rate matches the lift's sideways share")
	finish()
