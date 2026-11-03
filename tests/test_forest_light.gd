extends TestCase
## The pine wood's looks (ForestLight.LOOKS): each one sets what it declares on the drawn light (the sun, the sky,
## the environment, and its tone curve when it has one); stepping through them (F6) and back to the afternoon
## leaves every property as the afternoon had it -- nothing of one look leaks into the next.


func setup() -> void:
	var host := Node3D.new()
	add_child(host)
	ForestLight.look = "afternoon"
	var sun := ForestLight.setup(host)
	var we: WorldEnvironment = null
	for c in host.get_children():
		if c is WorldEnvironment:
			we = c
	var objs := {"env": we.environment, "sky": we.environment.sky.sky_material, "sun": sun}
	var keys := []   # every property any look sets: [object, property]
	for l in ForestLight.LOOKS:
		for key in (ForestLight.LOOKS[l] as Dictionary):
			if key != "curve":
				keys.append([key.get_slice(".", 0), key.get_slice(".", 1).get_slice(":", 0)])
	var before := {}
	for k in keys:
		before[k] = objs[k[0]].get(k[1])
	check(we.environment.adjustment_color_correction == null, "the afternoon has no tone curve")
	eq(ForestLight.LOOKS.keys()[0], "afternoon", "the afternoon comes first")
	for i in ForestLight.LOOKS.size() - 1:
		var name := ForestLight.next_look(host)
		var l: Dictionary = ForestLight.LOOKS[name]
		eq(name, ForestLight.LOOKS.keys()[i + 1], "F6 steps to the next look")
		for key in l:
			if key == "curve":
				var t := we.environment.adjustment_color_correction as GradientTexture1D
				check(t != null and t.gradient.colors.size() == (l.curve as Array).size(), "%s: its tone curve is on" % name)
				continue
			var o: Object = objs[key.get_slice(".", 0)]
			var prop: String = key.get_slice(".", 1)
			var got = o.get(prop.get_slice(":", 0))
			if prop.contains(":"):
				got = (got as Vector3)["xyz".find(prop.get_slice(":", 1))]
			check(_same(got, l[key]), "%s sets %s (%s, wants %s)" % [name, key, str(got), str(l[key])])
		if not l.has("curve"):
			check(we.environment.adjustment_color_correction == null, "%s: no curve left from the last look" % name)
	eq(ForestLight.next_look(host), "afternoon", "and round to the afternoon")
	for k in keys:
		check(_same(objs[k[0]].get(k[1]), before[k]), "back to the afternoon's %s.%s" % k)
	check(we.environment.adjustment_color_correction == null, "the afternoon's (no) curve back")
	finish()


static func _same(a, b) -> bool:
	if a is Color:
		return (a as Color).is_equal_approx(b)
	if a is Vector3:
		return (a as Vector3).is_equal_approx(b)
	if a is float or b is float:
		return is_equal_approx(float(a), float(b))
	return a == b
