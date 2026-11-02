extends TestCase
## Diagnostic: sightlines in the pine wood by height -- how far you see level before wood (and leaves) block
## the view: median, 25th percentile, share that reach 40 m (the seeker's lock range).

const HEIGHTS := [3.0, 8.0, 13.0, 18.0, 22.0, 26.0, 30.0, 36.0]


func _init() -> void:
	timeout_sec = 300.0


func setup() -> void:
	for dens in [1.0, 0.5, 0.25]:
		Pinewood.crown_density = dens
		var a := Pinewood.generate(7)
		var r := Pinewood.sightlines(a, HEIGHTS, 160, 40.0, true)
		print("SIGHT crowns %.2f: wood and leaves" % dens)
		for h in HEIGHTS:
			print("SIGHT   %4.0f m: median %4.1f m, 25%% %4.1f m, %3.0f%% reach 40 m" % [h, r[h][0], r[h][1], r[h][2] * 100.0])
	Pinewood.crown_density = 0.5
	finish()
