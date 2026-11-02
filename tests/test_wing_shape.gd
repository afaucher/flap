extends TestCase
## Every species' drawn wing is the flight model's wing: the spread tip reaches span / 2 and the planform
## (both wings + body strip) has the profile's wing area, so the drawn aspect ratio matches too. Folding
## shrinks it, and the species keep their characteristic shapes.


func setup() -> void:
	var shapes := {}
	for p in BirdProfile.all():
		var w := WingShape.for_profile(p)
		shapes[p.id] = w
		var area := w.drawn_area()
		var ar := p.span * p.span / area
		print("%s: half-span %.3f (model %.3f), area %.4f (model %.4f), AR %.2f (model %.2f), scale %.2f chord %.2f" % [p.id, w.drawn_half_span(), w.half_span(), area, p.wing_area, ar, p.aspect_ratio, w.scale, w.chord])
		near(w.drawn_half_span(), w.half_span(), w.half_span() * 0.01, p.id + " tip reaches span / 2")
		near(area, p.wing_area, p.wing_area * 0.03, p.id + " drawn area is the model's")
		near(ar, p.aspect_ratio, p.aspect_ratio * 0.04, p.id + " drawn aspect ratio is the model's")
		# Folded: the wing packs up against the body.
		var folded := 0.0
		for q in w.outline(1.0):
			folded = maxf(folded, q.x)
		check(folded < w.half_span() * 0.45, "%s folds in (%.2f of %.2f m)" % [p.id, folded, w.half_span()])
		# Bone lengths are fixed through the fold.
		var l := w.bone_lengths()
		for fold in [0.0, 0.5, 1.0]:
			var j := w.joints(fold)
			near(j[0].distance_to(j[1]), l[0], 1e-5, "humerus length")
			near(j[1].distance_to(j[2]), l[1], 1e-5, "forearm length")
			near(j[2].distance_to(j[3]), l[2], 1e-5, "hand length")
		# Primary lengths: longest where the species says, all positive.
		var best := 0
		for i in range(1, 11):
			check(w.primary_shape(i) > 0.0, "positive primary")
			if best == 0 or w.primary_shape(i) > w.primary_shape(best):
				best = i
		eq(best, WingShape.DATA[p.id].longest, p.id + " longest primary")
	# Character: the falcon has the shortest arm relative to its hand; the hawk the longest.
	var ratio := func(id: String) -> float: return (shapes[id].arm[0] + shapes[id].arm[1]) / shapes[id].arm[2]
	check(ratio.call("falcon") < ratio.call("crow") and ratio.call("crow") < ratio.call("hawk"), "arm:hand falcon < crow < hawk")
	check(shapes["hawk"].slots == 5 and shapes["falcon"].slots == 0, "hawk slotted, falcon not")
	finish()
