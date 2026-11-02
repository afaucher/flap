extends SceneTree
## Bake the feather textures (FeatherAtlas) into assets/feathers/*.png and the leg scales (ScaleTile) into
## assets/legs/*.png, and stamp each set with its baker's MD5. Run after changing FeatherAtlas or ScaleTile:
##   & $godot --path . --headless --script res://tools/bake_feathers.gd [-- --feathers | --scales]
## (one set only), then import (.\test_runner.ps1 does) so the PNGs get their mipmaps.


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if not args.has("--scales"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FeatherAtlas.ATLAS_PATH.get_base_dir()))
		var atlas := FeatherAtlas.bake_atlas()
		print("atlas: %d, %d" % [atlas[0].save_png(FeatherAtlas.ATLAS_PATH), atlas[1].save_png(FeatherAtlas.ATLAS_N_PATH)])
		var body := FeatherAtlas.bake_body()
		print("body: %d, %d" % [body[0].save_png(FeatherAtlas.BODY_PATH), body[1].save_png(FeatherAtlas.BODY_N_PATH)])
		_stamp(FeatherAtlas.STAMP_PATH, FeatherAtlas.source_md5())
	if not args.has("--feathers"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ScaleTile.SCALES_PATH.get_base_dir()))
		var scales := ScaleTile.bake()
		print("scales: %d, %d" % [scales[0].save_png(ScaleTile.SCALES_PATH), scales[1].save_png(ScaleTile.NORMALS_PATH)])
		_stamp(ScaleTile.STAMP_PATH, ScaleTile.source_md5())
	print("baked in %d ms" % (Time.get_ticks_msec() - t0))
	quit()


func _stamp(path: String, md5: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(md5)
	f.close()
