extends TestCase
## Diagnostic: paints the foliage card textures (FoliageTex), times them, saves them as PNGs to $FOLIAGE_OUT
## (or the user data folder) on a dark background and alone.


func setup() -> void:
	var out := OS.get_environment("FOLIAGE_OUT")
	if out == "":
		out = OS.get_user_data_dir()
	for kind in ["needles", "oak", "fern"]:
		var t0 := Time.get_ticks_msec()
		var tex := FoliageTex.get_tex(kind)
		print("FOLIAGE %s %d ms" % [kind, Time.get_ticks_msec() - t0])
		tex.get_image().save_png(out.path_join("foliage_%s.png" % kind))
	finish()
