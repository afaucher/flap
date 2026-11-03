extends TestCase
## The outposts' timber as drawn (planks.gdshader on ArenaBuilder._outpost's pieces): square-on orthographic close-ups
## read back from the GPU and measured.
##  - End grain: a flat-sawn plank's sawn end, a bearer's end and the landing rail's end show growth rings (light
##    and dark bands crossing the face: up the plank's end, both ways across the beam's and the rail's) -- not
##    the scan smeared into streaks running one way, as an end face once was.
##  - A hangar wall shows its boards: the grain varying across every part of it, the dark gaps between the
##    boards; a face wider than a scan board is laid as several boards with grooves, not one stretched.
##  - The grain runs along a brace (as along a plank): the picture varies less along the piece than across it,
##    the piece turned either way on screen.
##  - A plank's top is one scan board, no gap line down its middle.
## A GPU test: runs windowed (.\test_runner.ps1 -Gpu), since the headless renderer runs no shaders.

const PX := 160

var vp: SubViewport
var cam: Camera3D
var sun: DirectionalLight3D
var _shots := 0


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.5, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	sun = DirectionalLight3D.new()
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.005
	cam.far = 3.0
	vp.add_child(cam)
	cam.current = true
	var b := ArenaBuilder.new()
	b.layout = ArenaLayout.new()
	b.layout.style = "pinewood"
	b.layout.seed = 7
	vp.add_child(b)
	var o := ArenaLayout.OutpostData.new()
	o.centre = Vector3(0, 1, 0)
	o.out = Vector3.BACK
	b._outpost(o)
	var fm: MeshInstance3D = b.get_node("Outpost0_Frame")
	var pieces := {}
	for p in fm.get_meta("pieces"):
		if not pieces.has(p.name):
			pieces[p.name] = []
		pieces[p.name].append(p)
	var world := func(p: Dictionary) -> Transform3D:
		return fm.global_transform * (p.xform as Transform3D)

	# End grain: the flat-sawn planks' ends (by their pith, which the mesh carries), at the rail's edge.
	var flat := 0
	for i in ArenaBuilder.PLANKS:
		var pl: MeshInstance3D = b.get_node("Outpost0_Plank%d" % i)
		var c1: PackedFloat32Array = pl.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM1]
		var pith := Vector2(c1[0], c1[1])
		if absf(pith.y) < 0.04 or absf(pith.x) > absf(pith.y):
			continue
		flat += 1
		var box := pl.mesh.get_aabb()
		var gt := pl.global_transform
		var end_c := gt * Vector3(box.get_center().x, box.get_center().y, box.position.z)
		var img := await _shot(end_c, (gt.basis * Vector3(0, 0, -1)).normalized(), Vector3.UP, 0.03)
		var st := _stats(img, Rect2i(8, 8, PX - 16, PX - 16))
		var rings := _rings(_profile(img, true), 8)
		print("plank %d end: %d rings up it, variation up %.3f across %.3f" % [i, rings, st.gy, st.gx])
		check(rings >= 4, "plank %d: its sawn end shows growth rings (%d up the end)" % [i, rings])
		check(st.gy > 0.4 * st.gx, "plank %d: its end isn't streaked (variation up %.3f, across %.3f)" % [i, st.gy, st.gx])
	check(flat >= 3, "flat-sawn planks to look at (%d)" % flat)
	# A bearer's end and the rail's end: rings round a pith inside the section, crossing the face both ways.
	for name in ["bearer_out", "rail"]:
		var p: Dictionary = pieces[name][0]
		var xf: Transform3D = world.call(p)
		var ax := xf.basis.y.normalized()
		var end_c := xf.origin + ax * (p.size as Vector3).y * 0.5
		var size := minf((p.size as Vector3).x, (p.size as Vector3).z) * 0.7
		var img := await _shot(end_c, ax, Vector3.UP, size)
		var up_r := _rings(_profile(img, true), 4)
		var across_r := _rings(_profile(img, false), 4)
		print("%s end: rings %d up, %d across" % [name, up_r, across_r])
		check(up_r >= 4 and across_r >= 4, "%s: its end shows rings both ways across it (%d up, %d across)" % [name, up_r, across_r])

	# The hangar's back wall: boards with gaps, the grain varying across all of it.
	var back: Array = pieces["hangar_board_nz_0"]
	var bxf: Transform3D = world.call(back[0])
	var n_out := bxf.basis.z.normalized()
	var wall_c := Vector3.ZERO
	for k in 4:
		wall_c += (world.call(pieces["hangar_board_nz_%d" % k][0]) as Transform3D).origin
	wall_c /= 4.0
	wall_c += n_out * 0.008
	var wimg := await _shot(Vector3(wall_c.x, 1.0 + 0.235, wall_c.z), n_out, Vector3.UP, 0.42)
	var band := Rect2i(int(PX * 0.1), int(PX * 0.5 - 0.115 / 0.42 * PX), int(PX * 0.8), int(0.23 / 0.42 * PX))
	_boards(wimg, band, "the hangar's back wall", 3)

	# A face wider than a scan board (0.5 m): laid as several boards, grooves between, nothing stretched.
	var tm := TimberMesh.new()
	tm.box("wide", Transform3D(Basis(), Vector3.ZERO), Vector3(0.5, 0.6, 0.04), TimberMesh.Kind.BOARD, 0.3)
	var wide := MeshInstance3D.new()
	wide.mesh = tm.commit()
	wide.material_override = fm.material_override
	wide.position = Vector3(0, 4, 0)
	vp.add_child(wide)
	var wi := await _shot(wide.global_position + Vector3(0, 0, 0.02), Vector3.BACK, Vector3.UP, 0.48)
	_boards(wi, Rect2i(4, 4, PX - 8, PX - 8), "a 0.5 m face", 2)
	wide.queue_free()

	# The grain along the pieces: a brace and a plank's top, each turned both ways on screen.
	var brace: Dictionary = pieces["brace_l"][0]
	var pxf: Transform3D = world.call(brace)
	var sz: Vector3 = brace.size
	var axes := [pxf.basis.x.normalized(), pxf.basis.y.normalized(), pxf.basis.z.normalized()]
	var long_i := 0
	for k in 3:
		if sz[k] > sz[long_i]:
			long_i = k
	var long_dir: Vector3 = axes[long_i]
	var face_i := (long_i + 1) % 3
	var face_n: Vector3 = axes[face_i]
	var face_c := pxf.origin + face_n * sz[face_i] * 0.5
	var bw_px := int(sz[3 - long_i - face_i] * 0.6 / 0.3 * PX)
	_grain_along(await _shot(face_c, face_n, long_dir, 0.3), true, bw_px, "the brace", 0.1)
	_grain_along(await _shot(face_c, face_n, face_n.cross(long_dir), 0.3), false, bw_px, "the brace, turned", 0.1)
	# Every plank's top, toward the rail (clear of the boxes): on none does the grain run across (a board of the scan
	# here and there is blotchy -- a knot -- and alike both ways), and along them clearly on the whole deck.
	var lead := 0.0
	for i in ArenaBuilder.PLANKS:
		var pl: MeshInstance3D = b.get_node("Outpost0_Plank%d" % i)
		var box := pl.mesh.get_aabb()
		var gt := pl.global_transform
		var top_c := gt * Vector3(box.get_center().x, box.end.y, -0.28)
		var along := (gt.basis * Vector3(0, 0, 1)).normalized()
		var pw_px := int(box.size.x * 0.6 / 0.24 * PX)
		lead += _grain_along(await _shot(top_c, Vector3.UP, along, 0.24, 0.03), true, pw_px, "plank %d's top" % i, -0.1)
		lead += _grain_along(await _shot(top_c, Vector3.UP, along.cross(Vector3.UP), 0.24, 0.03), false, pw_px, "plank %d's top, turned" % i, -0.1)
	lead /= ArenaBuilder.PLANKS * 2
	check(lead > 0.12, "the planks' grain runs along them (more alike along by %.2f on average)" % lead)
	# Every plank's top: one scan board, no dark gap line down its middle.
	for i in ArenaBuilder.PLANKS:
		var pl: MeshInstance3D = b.get_node("Outpost0_Plank%d" % i)
		var box := pl.mesh.get_aabb()
		var gt := pl.global_transform
		var top_c := gt * Vector3(box.get_center().x, box.end.y, -0.28)
		var along := (gt.basis * Vector3(0, 0, 1)).normalized()
		var size := box.size.x * 1.0
		var img := await _shot(top_c, Vector3.UP, along, size, 0.03)
		var cols := _profile(img, false, PX / 2 - 1)   # (luminance across the plank, averaged along it)
		var inner := cols.slice(int(PX * 0.22), int(PX * 0.78))
		var med := _median(inner)
		var lo: float = inner.min()
		check(lo > med * 0.62, "plank %d: no gap line down its middle (darkest %.3f, median %.3f)" % [i, lo, med])
	finish()


## Square-on orthographic picture of the surface at `c` facing `n`, `up` up the screen, `size` m tall.
func _shot(c: Vector3, n: Vector3, up: Vector3, size: float, dist := 0.25) -> Image:
	cam.size = size
	cam.global_position = c + n * dist
	cam.look_at(c, up)
	var right := n.cross(up).normalized()
	sun.global_basis = Basis.looking_at((-n + up * 0.35 + right * 0.25).normalized(), up)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if OS.has_environment("TIMBER_SHOTS"):   # (to look at what was measured)
		_shots += 1
		img.save_png(OS.get_environment("TIMBER_SHOTS").path_join("shot_%02d.png" % _shots))
	return img


func _lum(img: Image, x: int, y: int) -> float:
	return img.get_pixel(x, y).get_luminance()


## Mean |change| over 2 px across (gx) and up (gy) the screen, relative to the mean luminance.
func _stats(img: Image, r: Rect2i) -> Dictionary:
	var gx := 0.0
	var gy := 0.0
	var m := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y - 2):
		for x in range(r.position.x, r.end.x - 2):
			var l := _lum(img, x, y)
			gx += absf(_lum(img, x + 2, y) - l)
			gy += absf(_lum(img, x, y + 2) - l)
			m += l
			n += 1
	m = maxf(m / n, 1e-4)
	return {"gx": gx / n / m, "gy": gy / n / m, "mean": m}


## Luminance along the screen's middle: up it (`vertical`: averaged over 5 columns) or across (5 rows); `band`
## widens the average.
func _profile(img: Image, vertical: bool, band := 2) -> Array:
	var out := []
	for i in PX:
		var s := 0.0
		for k in range(-band, band + 1):
			s += _lum(img, PX / 2 + k, i) if vertical else _lum(img, i, PX / 2 + k)
		out.append(s / (band * 2 + 1))
	return out


## Light / dark bands along a profile: crossings of its local mean (a moving average +- w px) with hysteresis.
func _rings(p: Array, w: int) -> int:
	var state := 0
	var flips := 0
	var h := 0.006
	for i in range(w + 4, p.size() - w - 4):
		var m := 0.0
		for k in range(-w, w + 1):
			m += p[i + k]
		m /= w * 2 + 1
		var q: float = p[i] - m
		if q > h and state != 1:
			if state != 0:
				flips += 1
			state = 1
		elif q < -h and state != -1:
			if state != 0:
				flips += 1
			state = -1
	return flips / 2


func _median(a: Array) -> float:
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]


## Boards side by side, the grain up the screen: in every quarter across, the picture varies across the grain
## (nothing smeared sideways), and `gaps` or more dark lines between boards.
func _boards(img: Image, r: Rect2i, what: String, gaps: int) -> void:
	var qw := r.size.x / 4
	for k in 4:
		var st := _stats(img, Rect2i(r.position.x + k * qw, r.position.y, qw, r.size.y))
		check(st.gx > 0.02 and st.gx > 0.25 * st.gy, "%s: its quarter %d isn't smeared (variation across %.3f, up %.3f)" % [what, k, st.gx, st.gy])
	var cols := []
	for x in range(r.position.x, r.end.x):
		var s := 0.0
		for y in range(r.position.y, r.end.y):
			s += _lum(img, x, y)
		cols.append(s / r.size.y)
	var med := _median(cols)
	var dark := 0
	var was := false
	for v in cols:
		var d: bool = v < med * 0.72
		if d and not was:
			dark += 1
		was = d
	print("%s: %d dark lines between boards" % [what, dark])
	check(dark >= gaps, "%s: boards with gaps between (%d dark lines)" % [what, dark])


## The grain along the piece, up the screen (`up`) or across it, in the piece's middle (`width_px` across it): the
## picture stays alike a few mm along the grain and changes a few mm across it -- the correlation of each pixel
## with its neighbour `d` px away is the higher along.
func _grain_along(img: Image, up: bool, width_px: int, what: String, margin: float) -> float:
	var half := maxi(width_px / 2, 4)
	var r := Rect2i(PX / 2 - half, 8, half * 2, PX - 16) if up else Rect2i(8, PX / 2 - half, PX - 16, half * 2)
	var d := 4
	var c_up := _corr(img, r, Vector2i(0, d))
	var c_across := _corr(img, r, Vector2i(d, 0))
	var along: float = c_up if up else c_across
	var across: float = c_across if up else c_up
	print("%s: alike %d px along %.2f, across %.2f" % [what, d, along, across])
	check(along > across + margin, "%s: the grain runs along it (alike %d px along: %.2f, across: %.2f)" % [what, d, along, across])
	return along - across


## Pearson correlation of the luminance in r with itself shifted by `o`.
func _corr(img: Image, r: Rect2i, o: Vector2i) -> float:
	var sa := 0.0
	var sb := 0.0
	var saa := 0.0
	var sbb := 0.0
	var sab := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y - o.y):
		for x in range(r.position.x, r.end.x - o.x):
			var a := _lum(img, x, y)
			var b := _lum(img, x + o.x, y + o.y)
			sa += a
			sb += b
			saa += a * a
			sbb += b * b
			sab += a * b
			n += 1
	var cov := sab / n - (sa / n) * (sb / n)
	var va := saa / n - (sa / n) * (sa / n)
	var vb := sbb / n - (sb / n) * (sb / n)
	return cov / maxf(sqrt(va * vb), 1e-9)
