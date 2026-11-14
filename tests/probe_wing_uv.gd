extends TestCase
## How the contour-feather chart lies on the arm wing's surface (test_wing_chart measures it; this prints it): per
## band of the loft, root to wrist, the stretch half and 90 % of its area lie under (the tile's scale along its most
## stretched direction over its least, 1 = even; the trunk's own is about 1.5), its median density (tiles per metre over
## the trunk's beside the shoulder: below 1, the feathers drawn bigger), which way the tile is stretched (u: along the
## arm, v: across the chord), and the drawn chord against the chart's. The left wing, or `--side 1`.
## `--bird <id>`, `--pose <name>` (glide), `--arm-chart-old` (BirdRig.arm_chart_even off).

const Chart := preload("res://tests/test_wing_chart.gd")


func setup() -> void:
	Plumage.level = 6
	var args := OS.get_cmdline_user_args()
	var only := Boot.arg_value(args, "--bird") if args.has("--bird") else ""
	var pose := Boot.arg_value(args, "--pose") if args.has("--pose") else "glide"
	BirdRig.arm_chart_even = not args.has("--arm-chart-old")
	for p in BirdProfile.all():
		if only != "" and p.id != only:
			continue
		var rig := BirdRig.new()
		add_child(rig)
		rig.build(p)
		RigPoses.apply(rig, pose, 0.0)
		rig.apply_pose()
		var sh: Vector3 = rig._trunk.transform.affine_inverse() * (rig.wing_joints[0][0] as Vector3)
		var trunk := Chart.trunk_stats(rig, sh)
		print("%s (%s): trunk by the shoulder: density %.1f tiles/m, stretch %.2f (tile %.3f m)" % [p.id, pose, trunk.x, trunk.y, rig._tile])
		for b: Dictionary in Chart.measure(rig, int(Boot.arg_value(args, "--side")) if args.has("--side") else 0):
			print("  %-12s chord %3.0f mm, chart %3.0f mm   stretch median %5.2f, 90%% %6.2f   density %.2f   stretched along %s" % [
				b.label, b.chord * 1000.0, b.chart * 1000.0, b.stretch, b.stretch90, b.density, "v" if b.along_v else "u"])
		rig.queue_free()
	BirdRig.arm_chart_even = true
	finish()
