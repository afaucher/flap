extends SceneTree
## Diagnostic: the feather chart where the neck meets the trunk and the head (BirdRig "Feather coordinates"):
## for each neck line, the trunk end's u and the head end's u (as a share of each ring's girth), and v at both
## ends. A twist shows as the shares drifting apart round the ring.
##   & $godot --path . --headless --script res://tests/probe_feather_chart.gd


func _initialize() -> void:
	Plumage.level = 6
	for id in ["hawk", "owl", "sparrow"]:
		var rig := BirdRig.new()
		root.add_child(rig)
		rig.build(BirdProfile.by_id(id))
		rig.apply_pose()
		var ua: PackedVector2Array = rig.body.trunk_uv[0]
		var pa: float = (rig.body.trunk_uv2[0] as PackedVector2Array)[0].x
		print("%s  trunk girth %.2f tiles, head ring girth %.2f" % [id, pa, (rig._hb_uv2[0] as Vector2).x])
		for j in BirdRig.TRUNK_AROUND:
			var hq := j * 3
			print("  j %2d  trunk u %+.3f (share %+.3f) v %.2f   head[%2d] u %+.3f (share %+.3f) v %.2f" % [j, ua[j].x, ua[j].x / pa, ua[j].y, hq, (rig._hb_uv[hq] as Vector2).x, (rig._hb_uv[hq] as Vector2).x / (rig._hb_uv2[hq] as Vector2).x, (rig._hb_uv[hq] as Vector2).y])
		var tz: PackedFloat32Array = rig.body.trunk_z
		for i in [10, 20]:
			var a: PackedVector2Array = rig.body.trunk_uv[i]
			var b: PackedVector2Array = rig.body.trunk_uv[i + 1]
			print("  ring %d: dz %.4f m, dv (spine) %.3f tiles -> %.4f m per tile (tile %.4f m, size %.2f), girth %.2f tiles" % [i, tz[i + 1] - tz[i], b[5].y - a[5].y, (tz[i + 1] - tz[i]) / (b[5].y - a[5].y), rig._tile, rig._size_trunk(tz[i]), (rig.body.trunk_uv2[i] as PackedVector2Array)[0].x])
		rig.free()
	quit()
