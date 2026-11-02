extends TestCase
## BuildVersion.resolve: the HUD's and the bird lab's build stamp (see scripts/ui/build_version.gd); and the HUD
## and the lab show it.


func setup() -> void:
	eq(BuildVersion.resolve(true, "2026-10-17.143005\n", false), "2026-10-17.143005", "export: trailing newline stripped")
	eq(BuildVersion.resolve(true, String.chr(0xFEFF) + "2026-10-17.143005\r\n", false), "2026-10-17.143005", "BOM stripped")
	eq(BuildVersion.resolve(false, "", false), BuildVersion.UNKNOWN, "missing file")
	eq(BuildVersion.resolve(true, "  \n", false), BuildVersion.UNKNOWN, "blank file")
	eq(BuildVersion.resolve(true, "2026-10-17.143005", true), "dev (2026-10-17.143005)", "a source run never passes as a build")
	eq(BuildVersion.resolve(false, "", true), "dev (unversioned)", "source run, no file")
	check(BuildVersion.text().begins_with("dev ("), "tests run from source: " + BuildVersion.text())
	var label := BuildVersion.make_label()
	check(label.text.contains(BuildVersion.text()), "label shows the stamp")
	eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "label never eats clicks")
	label.free()
	var hud := FlightHud.new()
	add_child(hud)
	await frames(1)
	var hl := hud.get_node_or_null("BuildVersion") as Label
	check(hl != null and hl.text.contains(BuildVersion.text()), "the flight HUD shows the build stamp")
	hud.queue_free()
	var lab: Node = load("res://scenes/bird_lab.tscn").instantiate()
	add_child(lab)
	await frames(3)
	var ll := lab.find_child("BuildVersion", true, false) as Label
	check(ll != null and ll.text.contains(BuildVersion.text()), "the bird lab shows the build stamp")
	lab.queue_free()
	await frames(1)
	finish()
