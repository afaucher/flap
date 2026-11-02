extends TestCase
## Plumage (docs/research/plumage_coloring.md): countershading (back darker than belly where the species
## has it), two-tone feathers (the Red-tail's red tail above, buff below), the underwing's leading-edge bar and
## wrist comma, darker wingtip fingers, head marks, and marks along the feather in the strip (the hawk's dark
## primary tips, the tail's subterminal band). Level 0 is the old single tint.


func setup() -> void:
	Plumage.level = 5
	for id in ["owl", "hawk", "falcon"]:
		check(Plumage.body(id, 0.4, 1.0, 0.0).get_luminance() < Plumage.body(id, 0.4, -1.0, 0.0).get_luminance(), id + " back darker than belly")
	near(Plumage.body("crow", 0.4, 1.0, 0.0).get_luminance(), Plumage.body("crow", 0.4, -1.0, 0.0).get_luminance(), 0.03, "crow black all over")
	var tail: Array = Plumage.base("hawk", "tail")
	check(tail[0].r > tail[0].g * 1.5 and tail[1].get_luminance() > tail[0].get_luminance(), "red-tail: brick red above, paler buff below")
	check(Plumage.limb("hawk", 1, 0.1, 0.5, true).get_luminance() < Plumage.limb("hawk", 1, 0.8, 0.5, true).get_luminance(), "hawk patagial bar darker than the under-coverts behind it")
	check(Plumage.limb("hawk", 3, 0.1, 0.5, true).get_luminance() < 0.25, "hawk dark wrist comma")
	check(Plumage.finger("hawk", 10)[0] < 0.8 and Plumage.finger("hawk", 5)[0] == 1.0, "outer primaries darker, inner ones not")
	var eye := Vector3(0.75, 0.25, -0.55).normalized()
	check(Plumage.head("falcon", Vector3(0, 1, 0), eye).get_luminance() < 0.2 and Plumage.head("falcon", Vector3(0, -0.8, -0.6).normalized(), eye).get_luminance() > 0.7, "falcon: dark hood, white throat")
	check(Plumage.head("falcon", Vector3(eye.x * 0.9, eye.y - 0.35, eye.z).normalized(), eye).get_luminance() < 0.25, "falcon moustache below the eye")
	check(Plumage.head("sparrow", Vector3(0, -0.8, -0.6).normalized(), eye).get_luminance() < 0.15, "sparrow black bib")
	check(Plumage.hex(Plumage.spec("owl").head.disc[0]).get_luminance() > 0.8, "owl pale facial disc")
	var prim: PackedColorArray = Plumage.row("hawk", "primary", true)
	check(prim[Plumage.STRIP - 2].get_luminance() < prim[Plumage.STRIP / 2].get_luminance() * 0.5, "hawk primaries dark-tipped below")
	var band: PackedColorArray = Plumage.row("hawk", "tail", false)
	var at := func(t: float) -> Color: return band[int(t * Plumage.STRIP)]
	check(at.call(0.88).get_luminance() < at.call(0.5).get_luminance() and at.call(0.97).get_luminance() > at.call(0.88).get_luminance(), "red-tail: dark subterminal band, pale tip")
	var tex := Plumage.strip("hawk")
	eq(tex.get_height(), Plumage.GROUPS.size() * 2, "a strip row per group and face")
	Plumage.level = 2
	near(Plumage.finger("hawk", 10)[0], 1.0, 1e-6, "no finger darkening before level 3")
	check(Plumage.head("sparrow", Vector3(0, -0.8, -0.6).normalized(), eye).get_luminance() > 0.3, "no head marks before level 4")
	Plumage.level = 5
	finish()
