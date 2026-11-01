class_name SpeedBands
extends RefCounted
## The speed bands a bird's airspeed falls into, cut at the speeds that matter for flying it:
##   0 STALL  below stall speed
##   1 CATCH  stall .. catch speed: slow enough to catch a perch
##   2 SLOW   catch .. best glide
##   3 GLIDE  best glide .. 1.5x (cruise)
##   4 FAST   1.5x .. 2.2x best glide
##   5 DIVE   above 2.2x best glide
## Crossing a cut plays a whoosh (FlightAudio) and the HUD names the band, so speed can be dialled in by ear.
## Hysteresis (HYST of each cut) keeps a speed sitting on a cut from chattering between bands.

const NAMES: Array[String] = ["STALL", "CATCH", "SLOW", "GLIDE", "FAST", "DIVE"]
const HYST := 0.03


static func cuts(v_stall: float, v_catch: float, v_best: float) -> PackedFloat32Array:
	return PackedFloat32Array([v_stall, v_catch, v_best, v_best * 1.5, v_best * 2.2])


## The band for `speed`, given the band it was in (`prev`, -1 for none): it only moves past a cut once the
## speed is HYST beyond it.
static func band(speed: float, c: PackedFloat32Array, prev := -1) -> int:
	var raw := 0
	for cut in c:
		if speed >= cut:
			raw += 1
	if prev < 0 or raw == prev:
		return raw
	if raw > prev:
		# Climbing: each cut above prev must be cleared by the margin.
		var b := prev
		while b < raw and speed >= c[b] * (1.0 + HYST):
			b += 1
		return b
	var d := prev
	while d > raw and speed < c[d - 1] * (1.0 - HYST):
		d -= 1
	return d
