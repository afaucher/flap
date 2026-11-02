class_name FlightAudio
extends Node
## Procedural flight sound, driven only by a bird's telemetry (set_state):
##   WIND: noise through a low-pass whose cutoff and level rise with airspeed; it flutters (amplitude
##     wobble) below the stall and a thin whistle joins in a dive.
##   WHOOSH: crossing a speed band (SpeedBands) sweeps a band-passed noise burst -- rising when speeding up,
##     falling when slowing -- centred on a pitch of its own for each band, so each crossing is recognisable:
##     the low one is "slow enough to catch", the middle one is best glide.
##   THUMP: each wingbeat, a short low thump.
## Synthesis is in render() (pure, testable headless); _process feeds it to an AudioStreamGenerator.

const RATE := 22050.0
const WHOOSH_LEN := 0.45
const THUMP_LEN := 0.12

var volume := 0.8
var band := -1
var events: Array = []          ## [band_from, band_to] per crossing (tests, debug)

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
# Targets from telemetry, and smoothed values used per sample.
var _speed_ratio := 0.0         ## speed / (2.5 v_best), 0..~1
var _stalled := false
var _dive := 0.0
var _cut := 300.0
var _gain := 0.0
var _flaps := -1
# Filter states.
var _w_low := 0.0
var _w_band := 0.0
var _h_low := 0.0
var _h_band := 0.0
var _t := 0.0
# Transients.
var _whoosh_t := 1e9
var _whoosh_from := 400.0
var _whoosh_to := 1200.0
var _thump_t := 1e9


func _ready() -> void:
	_rng.seed = 12345
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	# Headless (tests) there is nothing to hear, and the dummy audio driver never releases a started
	# generator playback (reported as a leak at exit). Tests drive render() directly.
	if DisplayServer.get_name() == "headless":
		return
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


## Feed a Bird.telemetry() snapshot (once a frame).
func set_state(t: Dictionary) -> void:
	var flying: bool = t.state == Bird.State.FLYING
	var speed: float = t.speed if flying else 0.0
	var v_best: float = t.v_best
	_speed_ratio = speed / (2.5 * v_best)
	_stalled = flying and (t.stalled or speed < t.v_stall)
	_dive = clampf((speed - v_best * 1.8) / v_best, 0.0, 1.0)
	var c := SpeedBands.cuts(t.v_stall, t.grab_speed, v_best)
	var nb := SpeedBands.band(speed, c, band) if flying else -1
	if band >= 0 and nb >= 0 and nb != band:
		_start_whoosh(band, nb)
		events.append([band, nb])
	band = nb
	var fc: int = t.flap_count
	if _flaps >= 0 and fc > _flaps:
		_thump_t = 0.0
	_flaps = fc


func _start_whoosh(from: int, to: int) -> void:
	var centre := 260.0 * pow(1.45, maxi(from, to))
	if to > from:
		_whoosh_from = centre * 0.5
		_whoosh_to = centre * 1.6
	else:
		_whoosh_from = centre * 1.6
		_whoosh_to = centre * 0.5
	_whoosh_t = 0.0


func _process(_dt: float) -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n > 0:
		_playback.push_buffer(render(n))


## Synthesize `n` stereo frames from the current state.
func render(n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(n)
	var target_cut := 220.0 + 2600.0 * pow(clampf(_speed_ratio, 0.0, 1.2), 1.3)
	var target_gain := (0.015 + 0.45 * pow(clampf(_speed_ratio, 0.0, 1.2), 2.0)) * volume
	var dt := 1.0 / RATE
	for i in n:
		_t += dt
		_cut += (target_cut - _cut) * 0.002
		_gain += (target_gain - _gain) * 0.002
		var noise := _rng.randf() * 2.0 - 1.0
		# Wind: 2-pole state-variable low-pass.
		var f := 2.0 * sin(PI * minf(_cut, 6000.0) / RATE)
		_w_low += f * _w_band
		var high := noise - _w_low - 0.7 * _w_band
		_w_band += f * high
		var s := _w_low * _gain
		if _stalled:
			s *= 0.6 + 0.4 * sin(TAU * 9.0 * _t)   # flutter
		if _dive > 0.0:
			s += sin(TAU * (900.0 + 900.0 * _dive) * _t) * 0.025 * _dive * volume
		# Whoosh: band-pass noise sweeping across the band's pitch.
		if _whoosh_t < WHOOSH_LEN:
			var u := _whoosh_t / WHOOSH_LEN
			var fw := lerpf(_whoosh_from, _whoosh_to, u)
			var g := 2.0 * sin(PI * fw / RATE)
			_h_low += g * _h_band
			var hh := noise - _h_low - 0.25 * _h_band
			_h_band += g * hh
			var env := minf(1.0, u * 10.0) * pow(1.0 - u, 1.5)
			s += _h_band * env * 0.35 * volume
			_whoosh_t += dt
		# Thump: a low decaying sine with a little noise.
		if _thump_t < THUMP_LEN:
			var e := 1.0 - _thump_t / THUMP_LEN
			s += (sin(TAU * 85.0 * _thump_t) + noise * 0.25) * e * e * 0.18 * volume
			_thump_t += dt
		s = clampf(s, -1.0, 1.0)
		out[i] = Vector2(s, s)
	return out
