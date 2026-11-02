extends SceneTree
## Bake the feather textures (FeatherAtlas) into assets/feathers/*.png, and stamp them with the baker's MD5.
## Run after changing FeatherAtlas:
##   & $godot --path . --headless --script res://tools/bake_feathers.gd
## then import (.\test_runner.ps1 does) so the PNGs get their mipmaps.


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FeatherAtlas.ATLAS_PATH.get_base_dir()))
	var atlas := FeatherAtlas.bake_atlas()
	print("atlas: %d, %d" % [atlas[0].save_png(FeatherAtlas.ATLAS_PATH), atlas[1].save_png(FeatherAtlas.ATLAS_N_PATH)])
	var body := FeatherAtlas.bake_body()
	print("body: %d, %d" % [body[0].save_png(FeatherAtlas.BODY_PATH), body[1].save_png(FeatherAtlas.BODY_N_PATH)])
	var f := FileAccess.open(FeatherAtlas.STAMP_PATH, FileAccess.WRITE)
	f.store_string(FeatherAtlas.source_md5())
	f.close()
	print("baked in %d ms" % (Time.get_ticks_msec() - t0))
	quit()
