class_name SoundDsp
extends RefCounted
## Offline sound building blocks for SoundRecipes (docs/design/audio_plan.md): mono float samples in [-1, 1] at RATE.
## Loading and processing recordings (ported from ..\cast tools/sfx_proto/sfx_rec.gd), synthesis (noise, tones, the
## note lists of ..\squirrel-racer's bird calls), and writing 16-bit WAVs. Pure and deterministic: noise comes from the
## RandomNumberGenerator the caller passes, so a bake always makes the same files.

const RATE := 44100


static func n_of(sec: float) -> int:
	return int(sec * RATE)


static func silence(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n_of(sec))
	return b


# ---------------------------------------------------------------- recordings

## Mono samples at RATE from a WAV (8/16/24/32-bit PCM or 32-bit float), any channel count and rate.
static func load_wav(path: String) -> PackedFloat32Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SoundDsp: could not open " + path)
		return PackedFloat32Array()
	f.seek(12)
	var fmt := 1
	var channels := 1
	var rate := RATE
	var bits := 16
	var out := PackedFloat32Array()
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		var next := f.get_position() + size + (size & 1)
		if id == "fmt ":
			fmt = f.get_16()
			channels = f.get_16()
			rate = f.get_32()
			f.get_32()
			f.get_16()
			bits = f.get_16()
			if fmt == 0xFFFE and size >= 40:   # WAVE_FORMAT_EXTENSIBLE: the real format is the subformat's first word
				f.get_16()
				f.get_16()
				f.get_32()
				fmt = f.get_16()
		elif id == "data":
			var pcm := f.get_buffer(size)
			var bps := bits / 8
			var frames := size / (bps * channels)
			out.resize(frames)
			for i in frames:
				var acc := 0.0
				for c in channels:
					var o := (i * channels + c) * bps
					var v := 0.0
					if fmt == 3 and bits == 32:
						v = pcm.decode_float(o)
					elif bits == 16:
						v = pcm.decode_s16(o) / 32768.0
					elif bits == 24:
						var x := pcm[o] | (pcm[o + 1] << 8) | (pcm[o + 2] << 16)
						if x & 0x800000:
							x -= 0x1000000
						v = x / 8388608.0
					elif bits == 32:
						v = pcm.decode_s32(o) / 2147483648.0
					elif bits == 8:
						v = (pcm[o] - 128) / 128.0
					acc += v
				out[i] = acc / channels
		f.seek(next)
	return resample(out, float(rate) / RATE) if rate != RATE else out


# ---------------------------------------------------------------- processing (all return new arrays)

## Plays `s` at `speed` (2.0 = an octave up and half as long). Linear interpolation; also converts sample rates.
static func resample(s: PackedFloat32Array, speed: float) -> PackedFloat32Array:
	var n := int(s.size() / speed)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var x := i * speed
		var j := int(x)
		var fr := x - j
		var a := s[mini(j, s.size() - 1)]
		var b := s[mini(j + 1, s.size() - 1)]
		out[i] = a + (b - a) * fr
	return out


static func pitch(s: PackedFloat32Array, semitones: float) -> PackedFloat32Array:
	return resample(s, pow(2.0, semitones / 12.0))


## Seconds `from`..`to` (to < 0 = the end).
static func cut(s: PackedFloat32Array, from: float, to: float = -1.0) -> PackedFloat32Array:
	var a := clampi(int(from * RATE), 0, s.size())
	var b := s.size() if to < 0.0 else clampi(int(to * RATE), a, s.size())
	return s.slice(a, b)


## The first moment after `after` s that the level jumps: a 5 ms window `db` above the 50 ms before it.
static func onset(s: PackedFloat32Array, after: float = 0.0, db: float = 15.0) -> float:
	var w := n_of(0.005)
	var prev := 1e-9
	var i := n_of(after)
	while i + w < s.size():
		var e := 0.0
		for j in w:
			e += s[i + j] * s[i + j]
		e /= w
		if e > prev * db_to_linear(db) and e > 1e-6:
			return float(i) / RATE
		prev = prev * 0.9 + e * 0.1
		i += w
	return -1.0


## The separate events in a recording (scratches, taps): [start, end] s for each stretch whose 10 ms level is within
## `below` dB of the loudest window, padded by `pre` before and `post` after, at least `min_len` s long; stretches
## closer than `join` s are one event.
static func events(s: PackedFloat32Array, below := 25.0, pre := 0.015, post := 0.08, min_len := 0.06,
		join := 0.06) -> Array:
	var w := n_of(0.01)
	var lv := PackedFloat32Array()
	var top := 0.0
	for i in range(0, s.size() - w, w):
		var e := 0.0
		for j in w:
			e += s[i + j] * s[i + j]
		lv.append(sqrt(e / w))
		top = maxf(top, lv[-1])
	var th := top * db_to_linear(-below)
	var out := []
	var a := -1
	var last := -1
	for k in lv.size():
		if lv[k] >= th:
			if a < 0 or (k - last) * 0.01 > join:
				if a >= 0:
					out.append([a, last])
				a = k
			last = k
	if a >= 0:
		out.append([a, last])
	var secs := []
	for ev: Array in out:
		var t0 := maxf(0.0, ev[0] * 0.01 - pre)
		var t1 := minf(s.size() / float(RATE), (ev[1] + 1) * 0.01 + post)
		if t1 - t0 >= min_len:
			secs.append([t0, t1])
	return secs


## Quietens the hiss between the loud parts: a downward expander, full gain within `range_db` of the sound's loudest
## 10 ms, falling to silence `range_db + knee` below it.
static func gate(s: PackedFloat32Array, range_db := 30.0, knee := 12.0) -> PackedFloat32Array:
	var out := s.duplicate()
	var env := 0.0
	var top := 0.0
	var a := exp(-1.0 / (0.002 * RATE))
	var r := exp(-1.0 / (0.03 * RATE))
	var envs := PackedFloat32Array()
	envs.resize(s.size())
	for i in s.size():
		var x := absf(s[i])
		env = (a if x > env else r) * env + (1.0 - (a if x > env else r)) * x
		envs[i] = env
		top = maxf(top, env)
	for i in s.size():
		var d := linear_to_db(maxf(envs[i], 1e-9) / maxf(top, 1e-9)) + range_db
		out[i] *= clampf(1.0 + d / knee, 0.0, 1.0)
	return out


static func fade(s: PackedFloat32Array, fade_in: float, fade_out: float, curve: float = 1.0) -> PackedFloat32Array:
	var out := s.duplicate()
	var ni := mini(n_of(fade_in), out.size())
	for i in ni:
		out[i] *= pow(float(i) / ni, curve)
	var no := mini(n_of(fade_out), out.size())
	for i in no:
		out[out.size() - 1 - i] *= pow(float(i) / no, curve)
	return out


static func gain(s: PackedFloat32Array, db: float) -> PackedFloat32Array:
	var out := s.duplicate()
	var g := db_to_linear(db)
	for i in out.size():
		out[i] *= g
	return out


## Multiplies by env(k), k = 0..1 across the sound.
static func shape(s: PackedFloat32Array, env: Callable) -> PackedFloat32Array:
	var out := s.duplicate()
	for i in out.size():
		out[i] *= float(env.call(float(i) / out.size()))
	return out


## Two-pole (12 dB/oct) filters, `passes` times in series for a steeper slope.
static func lowpass(s: PackedFloat32Array, hz: float, passes: int = 1) -> PackedFloat32Array:
	return svf(s, func(_k: float) -> float: return hz, 0.707, 0, passes)


static func highpass(s: PackedFloat32Array, hz: float, passes: int = 1) -> PackedFloat32Array:
	return svf(s, func(_k: float) -> float: return hz, 0.707, 2, passes)


static func bandpass(s: PackedFloat32Array, hz: float, q: float = 1.0) -> PackedFloat32Array:
	return svf(s, func(_k: float) -> float: return hz, q, 1, 1)


## Cytomic/Simper trapezoidal state-variable filter (stable to Nyquist). `hz` is a Callable(k: 0..1 across the sound)
## so a cutoff can sweep. mode: 0 low-pass, 1 band-pass (unity peak), 2 high-pass.
static func svf(s: PackedFloat32Array, hz: Callable, q: float, mode: int, passes: int = 1) -> PackedFloat32Array:
	var cur := s
	var k := 1.0 / q
	for p in passes:
		var out := PackedFloat32Array()
		out.resize(cur.size())
		var ic1 := 0.0
		var ic2 := 0.0
		var g := 0.0
		for i in cur.size():
			if i % 32 == 0:
				g = tan(PI * clampf(float(hz.call(float(i) / cur.size())), 10.0, RATE * 0.45) / RATE)
			var a1 := 1.0 / (1.0 + g * (g + k))
			var a2 := g * a1
			var a3 := g * a2
			var v0 := cur[i]
			var v3 := v0 - ic2
			var v1 := a1 * ic1 + a2 * v3
			var v2 := ic2 + a2 * ic1 + a3 * v3
			ic1 = 2.0 * v1 - ic1
			ic2 = 2.0 * v2 - ic2
			out[i] = v2 if mode == 0 else (v1 * k if mode == 1 else v0 - k * v1 - v2)
		cur = out
	return cur


## Mixes `layer` into `base` at `at` seconds (extends base if needed), scaled by `db`.
static func mix(base: PackedFloat32Array, layer: PackedFloat32Array, at: float = 0.0, db: float = 0.0) -> PackedFloat32Array:
	var out := base.duplicate()
	var i0 := n_of(at)
	if i0 + layer.size() > out.size():
		out.resize(i0 + layer.size())   # (new samples are zero)
	var g := db_to_linear(db)
	for i in layer.size():
		out[i0 + i] += layer[i] * g
	return out


static func peak(s: PackedFloat32Array) -> float:
	var m := 0.0
	for v in s:
		m = maxf(m, absf(v))
	return m


## Root-mean-square level in t0..t1 s (t1 < 0: the end).
static func rms(s: PackedFloat32Array, t0: float = 0.0, t1: float = -1.0) -> float:
	var x := cut(s, t0, t1)
	if x.is_empty():
		return 0.0
	var e := 0.0
	for v in x:
		e += v * v
	return sqrt(e / x.size())


## Scales to a peak in dBFS, with a 4 ms fade at the end so nothing clicks.
static func normalize(s: PackedFloat32Array, peak_db: float = -1.0) -> PackedFloat32Array:
	return fade(gain(s, peak_db - linear_to_db(maxf(peak(s), 1e-6))), 0.0, 0.004)


## A seamless loop of `sec` s from a sound at least `sec + xfade` long: its tail cross-faded into its head.
static func make_loop(s: PackedFloat32Array, sec: float, xfade: float) -> PackedFloat32Array:
	var n := n_of(sec)
	var x := n_of(xfade)
	var out := s.slice(0, n)
	for i in x:
		var k := float(i) / x
		out[i] = out[i] * sqrt(k) + s[n + i] * sqrt(1.0 - k)
	return out


# ---------------------------------------------------------------- synthesis

static func white(rng: RandomNumberGenerator, sec: float) -> PackedFloat32Array:
	var b := silence(sec)
	for i in b.size():
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


## Pink noise (Paul Kellet's filter, as squirrel racer's amb_noise), about the level of white noise.
static func pink(rng: RandomNumberGenerator, sec: float) -> PackedFloat32Array:
	var b := silence(sec)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var b3 := 0.0
	var b4 := 0.0
	var b5 := 0.0
	var b6 := 0.0
	for i in b.size():
		var w := rng.randf_range(-1.0, 1.0)
		b0 = 0.99886 * b0 + w * 0.0555179
		b1 = 0.99332 * b1 + w * 0.0750759
		b2 = 0.969 * b2 + w * 0.153852
		b3 = 0.8665 * b3 + w * 0.3104856
		b4 = 0.55 * b4 + w * 0.5329522
		b5 = -0.7616 * b5 - w * 0.016898
		b[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.2
		b6 = w * 0.115926
	return b


## A tone of `sec` s whose frequency is freq.call(k: 0..1) Hz. wave: "sine", "triangle", "square", "saw".
static func tone(sec: float, freq: Callable, wave := "sine") -> PackedFloat32Array:
	var b := silence(sec)
	var ph := 0.0
	for i in b.size():
		ph = fmod(ph + float(freq.call(float(i) / b.size())) / RATE, 1.0)
		match wave:
			"triangle":
				b[i] = 1.0 - 4.0 * absf(ph - 0.5)
			"square":
				b[i] = 1.0 if ph < 0.5 else -1.0
			"saw":
				b[i] = 2.0 * ph - 1.0
			_:
				b[i] = sin(TAU * ph)
	return b


## An exponential sweep f0 -> f1 across the sound, for tone() and svf().
static func sweep(f0: float, f1: float) -> Callable:
	return func(k: float) -> float: return f0 * pow(f1 / f0, k)


## A hit envelope: linear attack `a` s, then exponential decay with time constant `tau` s.
static func hit(s: PackedFloat32Array, a: float, tau: float) -> PackedFloat32Array:
	var out := s.duplicate()
	for i in out.size():
		var t := float(i) / RATE
		out[i] *= t / a if t < a else exp(-(t - a) / tau)
	return out


## A burst of noise through a band-pass sweeping f0 -> f1 (q), with a hit envelope.
static func noise_hit(rng: RandomNumberGenerator, sec: float, f0: float, f1: float, q: float, a: float,
		tau: float) -> PackedFloat32Array:
	return hit(svf(white(rng, sec), sweep(f0, f1), q, 1), a, tau)


## A struck object: decaying partials at `freqs` Hz (each its own level and time constant) -- clinks, knocks, chimes.
static func modal(sec: float, freqs: Array, levels: Array, taus: Array) -> PackedFloat32Array:
	var b := silence(sec)
	for m in freqs.size():
		var w := TAU * float(freqs[m]) / RATE
		var l: float = levels[m]
		var tau: float = taus[m]
		for i in b.size():
			b[i] += sin(w * i) * l * exp(-float(i) / (tau * RATE)) * minf(1.0, i / 40.0)
	return b


## A note list, as ..\squirrel-racer's bird calls (index.html playCall): [t, f0, f1, length, wave, level, am, q].
## Each note sweeps f0 -> f1 exponentially, rises in 12 ms (or 30 % of it), holds to 70 % and dies away; "noise" is
## band-passed noise (q, default 6) on the same sweep; `am` (Hz) adds a 50 % amplitude flutter.
static func notes(rng: RandomNumberGenerator, list: Array) -> PackedFloat32Array:
	var end := 0.0
	for nt: Array in list:
		end = maxf(end, float(nt[0]) + float(nt[3]))
	var out := silence(end + 0.05)
	for nt: Array in list:
		var t0: float = nt[0]
		var d: float = nt[3]
		var w: String = nt[4]
		var v: float = nt[5]
		var am: float = nt[6] if nt.size() > 6 else 0.0
		var q: float = nt[7] if nt.size() > 7 and float(nt[7]) > 0.0 else 6.0
		var src := svf(white(rng, d), sweep(nt[1], nt[2]), q, 1) if w == "noise" else tone(d, sweep(nt[1], nt[2]),
				"saw" if w == "sawtooth" else w)
		var att := minf(0.012, d * 0.3)
		for i in src.size():
			var t := float(i) / RATE
			var e := t / att if t < att else (1.0 if t < d * 0.7 else pow(0.0001, (t - d * 0.7) / (d * 0.3)))
			if am > 0.0:
				e *= 0.5 + 0.5 * sin(TAU * am * t)
			src[i] *= e * v * 0.5
		out = mix(out, src, t0)
	return out


## squirrel racer's rep(n, dt, f): the notes of f(t) for t = 0, dt, 2 dt ...
static func rep(n: int, dt: float, f: Callable) -> Array:
	var a := []
	for i in n:
		a.append_array(f.call(i * dt))
	return a


## A call's take: pitch shifted about +-5 % and tempo +-7 %, every note wavering +-1.5 % (squirrel racer: "no two songs
## alike").
static func vary(rng: RandomNumberGenerator, list: Array) -> Array:
	var p := 1.0 + rng.randf_range(-0.05, 0.05)
	var k := 1.0 + rng.randf_range(-0.07, 0.07)
	var out := []
	for nt: Array in list:
		var c := nt.duplicate()
		var j := p * (1.0 + rng.randf_range(-0.015, 0.015))
		c[0] = float(c[0]) * k
		c[3] = float(c[3]) * (1.0 + (k - 1.0) * 0.5)
		c[1] = float(c[1]) * j
		c[2] = float(c[2]) * j
		c[5] = float(c[5]) * rng.randf_range(0.85, 1.15)
		out.append(c)
	return out


# ---------------------------------------------------------------- output

## A 16-bit mono WAV of `s` (loop: loops whole).
static func to_wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w
