extends SceneTree
## Bake the feather textures (FeatherAtlas) into assets/feathers/*.png. Run after changing FeatherAtlas:
##   & $godot --path . --headless --script res://tools/bake_feathers.gd
## then import (.\test_runner.ps1 does) so the PNGs get their mipmaps.


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FeatherAtlas.ATLAS_PATH.get_base_dir()))
	var atlas := FeatherAtlas.bake_atlas()
	var err := atlas.save_png(FeatherAtlas.ATLAS_PATH)
	print("atlas: %s (%d)" % [FeatherAtlas.ATLAS_PATH, err])
	var body := FeatherAtlas.bake_body()
	err = body.save_png(FeatherAtlas.BODY_PATH)
	print("body: %s (%d)" % [FeatherAtlas.BODY_PATH, err])
	print("baked in %d ms" % (Time.get_ticks_msec() - t0))
	quit()
