extends "res://tests/test_tack.gd"
## Diagnostic: test_tack's fit checks for every species at a range of rider heights; prints what fails where,
## to find how big a rider each bird can carry.
##   .\test_runner.ps1 probe_rider_scale

const HEIGHTS := [0.075, 0.085, 0.09, 0.095, 0.105, 0.115]
var _fails := []


func _init() -> void:
	timeout_sec = 600.0


func check(cond: bool, msg: String = "") -> bool:
	if not cond:
		_fails.append(msg)
	return true


func eq(a, b, msg: String = "") -> bool:
	if a != b:
		_fails.append("%s (%s != %s)" % [msg, str(a), str(b)])
	return true


func setup() -> void:
	for id in BirdProfile.IDS:
		for h in HEIGHTS:
			Tack.rider_height = h
			_fails.clear()
			var rig := BirdRig.new()
			add_child(rig)
			rig.build(BirdProfile.by_id(id))
			var tack := Tack.fit(rig)
			_fit(id, rig, tack)
			for pose in ["glide", "folded"]:
				RigPoses.apply(rig, pose, 0.0)
				tack.sitting = pose == "folded"
				tack.update(0.0)
				_rider(id, pose, rig, tack)
				_head(id, pose, rig, tack)
				_footing(id, pose, tack)
				_scarf(id, pose, rig, tack)
			_wings(id, rig, tack)
			_launcher(id, rig, tack)
			print("SCALE %-8s %.3f  %d fails" % [id, h, _fails.size()])
			var seen := {}
			for f in _fails:
				var key: String = String(f).substr(0, 70)
				if not seen.has(key):
					seen[key] = true
					print("      ", f)
				if seen.size() >= 8:
					break
			rig.queue_free()
			await frames(1)
	Tack.rider_height = Tack.RIDER_HEIGHT
	finish()
