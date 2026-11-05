extends TestCase
## Standalone cliff erosion, chipping & mass-wasting laboratory.
##
## Combines:
##   1. Continuous 3D Multi-Tier Bedrock & Watertight Bench Architecture (`z_rock(x, y)`):
##      - Defines the 5 macro tectonic zones of `concept_cliff_ortho.png` (left stepped tiers, left-center
##        leaning monolith over a dark basal cave, center recessed bay, center-right wide bench with heaped
##        earth mound, and right fluted headwall), deep master shadow clefts, and watertight bench shelves
##   2. Zone-Specific Macro Monolith, Pillar & Buttress Architecture (`_spawn_geological_crag_architecture`):
##      - Right Fluted Headwall (`x = +20..+78, y = 17..36 m`): tall 15..19 m vertical columnar pillars
##        spanning the full upper headwall height (no horizontal brick courses!)
##      - Left-Center Leaning Monolith (`x = -29..-7.8, y = 4.2..20.0 m`): massive 11..15 m right-leaning
##        monolith slabs jutting over a dark basal cave, capped by a stony-earth & boulder shoulder at y = 20..22 m
##      - Center Recessed Bay (`x = -7.5..+20.5, y = 17.8..34 m`): broad recessed slabs above the wide bench
##      - Lower Pier Wall (`x = -6.5..+56, y = 2.5..13.8 m`): massive rock piers strictly capped below y = 13.8 m
##        so the wide center-right stony-earth bench (`y = 14.0..18.0 m`) sits in full, unobstructed view!
##      - Left Stepped Crags (`x = -80..-29`): 3 distinct crag tiers separated by the two left benches
##   3. Gullied Base Talus Cones & Natural Foreground Valley Floor (`_build_base_talus`)
##   4. Multi-scale Clumped Rockfall Fans, Bench-Lip Cap Slabs, and Valley Boulders (`_spawn_sorted_boulders`)
##
## Run windowed:
##   Godot --path . -- --run-test probe_cliff_lab --out-dir test_logs/cliff_lab

const EDGE_BUILDER_SCRIPT := preload("res://scripts/world/edge_builder.gd")
const SPAN_X := 164.0
const CLIFF_H := 38.0
const ORTHO_SIZE := 44.5


func _init() -> void:
	timeout_sec = 120.0


func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := Boot.arg_value(args, "--out-dir")
	if out_dir == "":
		out_dir = "test_logs/cliff_lab"
	DirAccess.make_dir_recursive_absolute(out_dir)

	get_window().size = Vector2i(1536, 512)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var root := Node3D.new()
	add_child(root)

	ForestLight.look = "clear"
	ForestLight.setup(root)
	for c in root.get_children():
		if c is WorldEnvironment:
			var we := c as WorldEnvironment
			we.environment.volumetric_fog_enabled = false
			we.environment.fog_enabled = false
			we.environment.background_mode = Environment.BG_COLOR
			we.environment.background_color = Color(0.86, 0.89, 0.93)
			we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			we.environment.ambient_light_color = Color(0.67, 0.72, 0.79)
			we.environment.ambient_light_energy = 0.82
			if we.camera_attributes is CameraAttributesPractical:
				(we.camera_attributes as CameraAttributesPractical).dof_blur_far_enabled = false
		elif c is DirectionalLight3D:
			var sun := c as DirectionalLight3D
			sun.rotation_degrees = Vector3(-38.0, -36.0, 0.0)
			sun.light_energy = 2.45
			sun.shadow_enabled = true

	var t0 := Time.get_ticks_msec()
	var lab := _build_eroded_cliff(77)
	root.add_child(lab.node)
	print("Eroded cliff built in %d ms (wall tris: %d, crags: %d, boulders: %d)" % [
		Time.get_ticks_msec() - t0, int(lab.wall_tris), int(lab.crag_count), int(lab.boulder_count)
	])

	var cam := Camera3D.new()
	cam.near = 1.0
	cam.far = 600.0
	root.add_child(cam)
	cam.current = true

	var set_ortho := func() -> void:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = ORTHO_SIZE
		cam.look_at_from_position(
			Vector3(0.0, 23.0, 120.0),
			Vector3(0.0, 16.8, 0.0),
			Vector3.UP
		)

	var set_3quarter := func() -> void:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 46.0
		cam.look_at_from_position(
			Vector3(-52.0, 23.0, 62.0),
			Vector3(6.0, 14.5, -1.0),
			Vector3.UP
		)

	var snap := func(fname: String, n_frames: int) -> void:
		await frames(n_frames)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var p := out_dir.path_join(fname)
		img.save_png(p)
		print("saved: ", p)

	# ---------------------------------------------------------------------------------------------
	# CHECKPOINT 1: Pure Chipped Bedrock (Beds + Conjugate Joints + Retreat Tiers, NO Deposition)
	# ---------------------------------------------------------------------------------------------
	_apply_checkpoint1_materials(lab)
	set_ortho.call()
	await snap.call("checkpoint1_bedrock_clay_ortho.png", 35)
	set_3quarter.call()
	await snap.call("checkpoint1_bedrock_clay_3quarter.png", 20)

	# ---------------------------------------------------------------------------------------------
	# CHECKPOINT 2: Mass-Wasting Deposition (Talus Cones at Angle of Repose + Benches + Boulders)
	# ---------------------------------------------------------------------------------------------
	_apply_checkpoint2_materials(lab)
	set_ortho.call()
	await snap.call("checkpoint2_deposition_clay_ortho.png", 25)
	# Also save as `lab_clay_ortho.png` for continuity
	var img_cp2 := get_viewport().get_texture().get_image()
	img_cp2.convert(Image.FORMAT_RGB8)
	img_cp2.save_png(out_dir.path_join("lab_clay_ortho.png"))
	set_3quarter.call()
	await snap.call("checkpoint2_deposition_clay_3quarter.png", 20)

	# ---------------------------------------------------------------------------------------------
	# CHECKPOINT 3: Surface Weathering & Materiality Driven by the Erosion State
	# ---------------------------------------------------------------------------------------------
	_apply_lit_materials(lab)
	set_ortho.call()
	await snap.call("checkpoint3_weathered_lit_ortho.png", 25)
	var img_cp3 := get_viewport().get_texture().get_image()
	img_cp3.convert(Image.FORMAT_RGB8)
	img_cp3.save_png(out_dir.path_join("lab_lit_ortho.png"))
	set_3quarter.call()
	await snap.call("checkpoint3_weathered_lit_3quarter.png", 25)
	var img_cp3_3q := get_viewport().get_texture().get_image()
	img_cp3_3q.convert(Image.FORMAT_RGB8)
	img_cp3_3q.save_png(out_dir.path_join("lab_lit_3quarter.png"))

	# ---------------------------------------------------------------------------------------------
	# STUDY 1: Incipient Surface Cracks (3D Recessed V-Cleft Fissures inside Intact Facets)
	#   1. `study1_incipient_cracks_closeup.png`: Close-up on the leaning monolith & central crags
	#      showing true 3D recessed V-groove fissures (chamfered lips, steep 83 deg inner walls,
	#      deep cavity root, pre-detachment hinged slip, arrested tips, and T-junction branches).
	#   2. `study1_crack_geometry_comparison.png`: 3-panel side-by-side comparison of the exact same
	#      3D cracked blocks under:
	#        (A) Clay WITHOUT directional shadow maps (`shadow_enabled = false`)
	#        (B) Clay WITH directional self-shadowing (`shadow_enabled = true`)
	#        (C) Full Weathered Limestone (`rock.gdshader`) WITH self-shadowing (`shadow_enabled = true`)
	# ---------------------------------------------------------------------------------------------
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 32.0
	cam.look_at_from_position(
		Vector3(-11.0, 16.8, 39.0),
		Vector3(3.0, 15.8, 1.5),
		Vector3.UP
	)
	await snap.call("study1_incipient_cracks_closeup.png", 25)

	# Render the 3-panel A/B/C self-shadow & materiality comparison (`1536x768`, 3 x `512x768`)
	var sun_ref: DirectionalLight3D = null
	for c in root.get_children():
		if c is DirectionalLight3D:
			sun_ref = c as DirectionalLight3D
			break
	if sun_ref != null:
		var orig_bias := sun_ref.shadow_bias
		sun_ref.shadow_bias = 0.015
		get_window().size = Vector2i(512, 768)
		await frames(2)
		cam.fov = 28.0
		cam.look_at_from_position(
			Vector3(-12.5, 15.8, 32.5),
			Vector3(-5.5, 14.8, 2.5),
			Vector3.UP
		)
		var comp_img := Image.create(1536, 768, false, Image.FORMAT_RGB8)

		# Panel A: Clay WITHOUT shadow map (`shadow_enabled = false`)
		_apply_checkpoint2_materials(lab)
		sun_ref.shadow_enabled = false
		await frames(20)
		await RenderingServer.frame_post_draw
		var img_a := get_viewport().get_texture().get_image()
		img_a.convert(Image.FORMAT_RGB8)
		comp_img.blit_rect(img_a, Rect2i(0, 0, 512, 768), Vector2i(0, 0))

		# Panel B: Clay WITH directional self-shadowing (`shadow_enabled = true`)
		sun_ref.shadow_enabled = true
		await frames(20)
		await RenderingServer.frame_post_draw
		var img_b := get_viewport().get_texture().get_image()
		img_b.convert(Image.FORMAT_RGB8)
		comp_img.blit_rect(img_b, Rect2i(0, 0, 512, 768), Vector2i(512, 0))

		# Panel C: Full Weathered Limestone (`rock.gdshader`) WITH self-shadowing (`shadow_enabled = true`)
		_apply_lit_materials(lab)
		await frames(20)
		await RenderingServer.frame_post_draw
		var img_c := get_viewport().get_texture().get_image()
		img_c.convert(Image.FORMAT_RGB8)
		comp_img.blit_rect(img_c, Rect2i(0, 0, 512, 768), Vector2i(1024, 0))

		var comp_path := out_dir.path_join("study1_crack_geometry_comparison.png")
		comp_img.save_png(comp_path)
		print("saved: ", comp_path)
		sun_ref.shadow_bias = orig_bias
		get_window().size = Vector2i(1536, 512)
		await frames(2)

	# ---------------------------------------------------------------------------------------------
	# STUDY 2: Cliff-Top Caprock Pavement & Ragged Rim + End Taper into Normal Land
	# ---------------------------------------------------------------------------------------------
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 48.0
	cam.look_at_from_position(
		Vector3(-34.0, 44.0, 46.0),
		Vector3(-12.0, 22.0, -8.0),
		Vector3.UP
	)
	await snap.call("study2_rim_pavement_and_taper.png", 25)

	# ---------------------------------------------------------------------------------------------
	# STUDY 3: Varied Lift Heights (3 m / 9 m / 18 m / 36 m) & Arena Micro-Outcrops
	# ---------------------------------------------------------------------------------------------
	(lab.node as Node3D).visible = false
	get_window().size = Vector2i(1536, 768)
	await frames(2)
	var lifts_node := _build_lift_scale_study()
	root.add_child(lifts_node)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 56.0
	cam.look_at_from_position(
		Vector3(1.0, 21.0, 110.0),
		Vector3(1.0, 14.5, 0.0),
		Vector3.UP
	)
	await snap.call("study3_lift_scales_ortho.png", 25)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 52.0
	cam.look_at_from_position(
		Vector3(-54.0, 29.0, 74.0),
		Vector3(2.0, 12.0, -2.0),
		Vector3.UP
	)
	await snap.call("study3_lift_scales_3quarter.png", 25)
	lifts_node.visible = false

	# ---------------------------------------------------------------------------------------------
	# STUDY 4: Macro Landform Topologies Around the Forest Arena (Full Geological Erosion Detail!)
	#   0: Crescent Amphitheatre / Cirque
	#   1: Box Gorge / Narrowing Defile
	#   2: Karst Sinkhole / Collapsed Dolina
	#   3: Stepped Karst Bench & Internal Outcrop Spurs
	# ---------------------------------------------------------------------------------------------
	var forma_names := ["amphitheatre", "gorge", "sinkhole", "stepped_spurs"]
	for fi in 4:
		var fn: String = forma_names[fi]
		var f_node := _build_macro_formation(fi)
		root.add_child(f_node)
		# Top-Down Orthographic Plan View (`1280x1280`)
		get_window().size = Vector2i(1280, 1280)
		await frames(2)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 285.0
		cam.look_at_from_position(
			Vector3(0.0, 260.0, 0.01),
			Vector3(0.0, 0.0, 0.0),
			Vector3.FORWARD
		)
		await snap.call("study4_plan_%s.png" % fn, 25)
		# Bird's-Eye Perspective View (`1536x864`, close enough to read the full eroded cliff & benches!)
		get_window().size = Vector2i(1536, 864)
		await frames(2)
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 50.0
		if fi == 1:
			cam.look_at_from_position(
				Vector3(16.0, 33.0, 96.0),
				Vector3(-2.0, 13.5, -32.0),
				Vector3.UP
			)
		elif fi == 3:
			cam.look_at_from_position(
				Vector3(-46.0, 33.0, 74.0),
				Vector3(8.0, 11.5, -32.0),
				Vector3.UP
			)
		else:
			cam.look_at_from_position(
				Vector3(-44.0, 33.0, 68.0),
				Vector3(12.0, 14.0, -46.0),
				Vector3.UP
			)
		await snap.call("study4_bird_%s.png" % fn, 25)
		f_node.queue_free()

	# ---------------------------------------------------------------------------------------------
	# STUDY 5: The Surrounding Karst Landscape & Ground-Protruding Rocks
	#   1. `study5_protruding_types_catalog.png`: Side-by-side field guide of the 4 natural ways
	#      bedrock and ancient rockfall protrude from the forest floor & heath:
	#        (A) Emergent Dip-Slope Rib ("Whaleback" / Cuesta Ledge)
	#        (B) Sub-Soil Karst Pavement Knoll (Flush Clints & Grike Fissures)
	#        (C) Earth-Fast Founder Boulders (Half-Buried Ancient Erratics with Soil Collars)
	#        (D) Dry Karst Wash Gully (Stepped Bedrock Banks + Water-Sorted Cobble Bed)
	#   2. `study5_landscape_context_3quarter.png`: Wide bird's-eye view across the surrounding
	#      heath and forest clearing showing how these protruding rock features tie the ground
	#      plane structurally to the main escarpment.
	#   3. `study5_landscape_ground_level.png`: Low flight-level perspective (`y ~ 7 m`) weaving
	#      between pine trunks over emergent bedrock ribs, karst knolls, and founder boulders.
	# ---------------------------------------------------------------------------------------------
	get_window().size = Vector2i(1536, 768)
	await frames(2)
	var cat_node := _build_protruding_rock_catalog()
	root.add_child(cat_node)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 46.0
	cam.look_at_from_position(
		Vector3(0.0, 19.0, 47.0),
		Vector3(0.0, 2.0, -1.0),
		Vector3.UP
	)
	await snap.call("study5_protruding_types_catalog.png", 25)
	cat_node.queue_free()

	get_window().size = Vector2i(1280, 768)
	await frames(2)
	(lab.node as Node3D).visible = true
	var surr_node := _build_surrounding_landscape_study()
	root.add_child(surr_node)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 50.0
	cam.look_at_from_position(
		Vector3(-38.0, 25.0, 94.0),
		Vector3(4.0, 8.0, 18.0),
		Vector3.UP
	)
	await snap.call("study5_landscape_context_3quarter.png", 25)

	cam.fov = 50.0
	cam.look_at_from_position(
		Vector3(-16.0, 6.8, 76.0),
		Vector3(6.0, 5.2, 20.0),
		Vector3.UP
	)
	await snap.call("study5_landscape_ground_level.png", 25)
	surr_node.queue_free()

	# ---------------------------------------------------------------------------------------------
	# STUDY 6: Ecological Plant & Tree Distribution by Rooting Soil Depth & Disturbance
	#   1. `study6_rooting_depth_zones_ortho.png`: Diagnostic rooting-soil depth & rockfall
	#      disturbance habitat map on the 150 m escarpment:
	#        - Bone/Grey (`soil < 2 cm`): Bare vertical/overhanging rock & active boulder chutes
	#        - Ochre/Gold (`soil = 5..25 cm`): Horizontal marl parting seams & narrow crevices (ferns/grass)
	#        - Olive/Sage (`soil = 25..75 cm`): Narrow ledges, rim grikes & talus fringe (woody shrubs)
	#        - Deep Green (`soil > 0.8..2.0 m`): Wide mid-cliff structural bench, deep cleft pockets,
	#          set-back plateau soil, and inter-cone valley soil (where trees can root!)
	#   2. `study6_ecological_plant_distribution_ortho.png`: Full lit ortho elevation with all 4
	#      plant guilds (crevice ferns along bedding seams, woody shrubs on narrow ledges & talus
	#      margins, stunted rock-pines in mid-cliff bench/cleft pockets & set back from rim clints,
	#      and tall Scots pines in deep valley soil parting around active talus cones).
	#   3. `study6_ecological_closeup_3quarter.png`: 3/4 oblique close-up showing how trees cluster
	#      in deep rooting pockets while shrubs and crevice ferns trace the shallower rock seams.
	# ---------------------------------------------------------------------------------------------
	get_window().size = Vector2i(1536, 768)
	await frames(2)
	(lab.node as Node3D).visible = true
	_apply_rooting_depth_diagnostic_materials(lab)
	set_ortho.call()
	await snap.call("study6_rooting_depth_zones_ortho.png", 25)

	_apply_lit_materials(lab)
	var veg_node := _build_ecological_vegetation_study(lab)
	root.add_child(veg_node)
	set_ortho.call()
	await snap.call("study6_ecological_plant_distribution_ortho.png", 25)

	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 44.0
	cam.look_at_from_position(
		Vector3(-40.0, 28.5, 56.0),
		Vector3(2.0, 12.5, 4.0),
		Vector3.UP
	)
	await snap.call("study6_ecological_closeup_3quarter.png", 25)
	veg_node.queue_free()

	finish()


# --- Stratified Bed & Tectonic Joint Tables -------------------------------------------------

var _beds_y := PackedFloat32Array()      # bed bottom heights
var _beds_hard := PackedFloat32Array()   # 0..1 competence of each bed
var _joint_sets := []                    # 1D tectonic joint tables per scale & tier

const MASTER_JOINTS := [
	Vector3(-56.0, 0.08, 2.8),
	Vector3(-41.0, -0.10, 3.2),
	Vector3(-29.0, 0.18, 3.6),
	Vector3(-7.5, -0.05, 5.6),   # deep vertical shadow cleft on right edge of monolith!
	Vector3(5.5, 0.10, 3.4),
	Vector3(21.0, -0.06, 4.8),   # master cleft bounding right fluted headwall!
	Vector3(34.0, 0.08, 4.0),
	Vector3(47.0, -0.10, 3.6),
	Vector3(60.0, 0.06, 3.0),
]


func _init_geology() -> void:
	var raw_beds := [
		[4.2, 0.94],
		[0.65, 0.16],  # basal undercut parting at y ~ 2.7 m
		[5.6, 0.96],   # massive lower reef bed (y ~ 3.3..8.9 m)
		[0.75, 0.18],  # parting at y ~ 8.9 m
		[5.5, 0.97],   # massive bench-forming caprock (y ~ 9.7..15.2 m)
		[0.85, 0.12],  # mid-cliff recessive horizon at y ~ 15.2..16.0 m
		[5.6, 0.95],   # mid-upper bed (y ~ 16.0..21.6 m)
		[0.70, 0.20],  # parting at y ~ 21.6 m
		[5.6, 0.96],   # upper massive bed (y ~ 22.3..27.9 m)
		[0.75, 0.15],  # upper bench parting at y ~ 27.9..28.7 m
		[5.8, 0.97],   # massive upper headwall bed (y ~ 28.7..34.5 m)
		[0.65, 0.22],  # parting at y ~ 34.5 m
		[5.8, 0.96],   # top rim caprock (y ~ 35.1..40.9 m)
	]
	_beds_y.clear()
	_beds_hard.clear()
	var y := -1.5
	for b in raw_beds:
		_beds_y.append(y)
		_beds_hard.append(float(b[1]))
		y += float(b[0])
	_beds_y.append(y)

	_joint_sets.clear()
	var widths := [14.5, 6.8, 3.2]
	var amps := [2.6, 1.25, 0.40]
	var tilts := [0.26, 0.22, 0.14]
	var bevels := [1.35, 0.85, 0.55]

	for si in 3:
		var w: float = widths[si]
		var nx := ceili((SPAN_X + 80.0) / w) + 6
		var ny := 16
		var table := PackedFloat32Array()
		table.resize(nx * ny * 8)
		for i in nx * ny:
			var id := float(i) * 1.61803 + float(si) * 917.3
			var sgn := 1.0 if _hash(id + 2.1) < 0.5 else -1.0
			table[i * 8 + 0] = 0.22 + 0.56 * _hash(id + 0.1)
			table[i * 8 + 1] = (_hash(id + 0.7) * 2.0 - 1.0) * 0.15
			table[i * 8 + 2] = _hash(id + 1.3) * 2.0 - 1.0
			table[i * 8 + 3] = sgn * lerpf(0.20, 0.78, _hash(id + 2.9))
			table[i * 8 + 4] = (_hash(id + 3.7) * 2.0 - 1.0) * 0.22
			var pm := _hash(id + 4.9)
			table[i * 8 + 5] = 1.0 if pm > 0.64 else (-1.0 if pm < 0.22 else 0.0)
			table[i * 8 + 6] = (_hash(id + 6.1) - 0.5) * 1.2
			table[i * 8 + 7] = _hash(id + 7.3) * 2.0 - 1.0
		_joint_sets.append({
			"w": w,
			"amp": amps[si],
			"tilt": tilts[si],
			"bevel": bevels[si],
			"nx": nx,
			"ny": ny,
			"table": table
		})


func _sample_joint_blocks(x: float, y: float, y_mid: float, row_id: int, layer: int) -> Vector4:
	var d: Dictionary = _joint_sets[layer]
	var w: float = float(d.w)
	var amp: float = float(d.amp)
	var tilt_scale: float = float(d.tilt)
	var bevel: float = float(d.bevel)
	var nx: int = int(d.nx)
	var ny: int = int(d.ny)
	var t: PackedFloat32Array = d.table

	var u := (x + SPAN_X * 0.5 + 40.0) / w
	var cu := floori(u)
	var ry := posmod(row_id, ny)
	var dy_m := y - y_mid

	var wav := 0.14 * sin(y * 0.28 + float(layer) * 2.1)
	var best_cell := cu
	for ix in range(cu - 1, cu + 3):
		var wx := posmod(ix, nx)
		var o := (wx * ny + ry) * 8
		var j_u := float(ix) + t[o + 0] + (t[o + 1] * dy_m + wav) / w
		if u >= j_u:
			best_cell = ix

	var wx_L := posmod(best_cell, nx)
	var wx_R := posmod(best_cell + 1, nx)
	var wx_prev := posmod(best_cell - 1, nx)
	var o_L := (wx_L * ny + ry) * 8
	var o_R := (wx_R * ny + ry) * 8
	var o_prev := (wx_prev * ny + ry) * 8

	var u_L := float(best_cell) + t[o_L + 0] + (t[o_L + 1] * dy_m + wav) / w
	var u_R := float(best_cell + 1) + t[o_R + 0] + (t[o_R + 1] * dy_m + wav) / w
	var span_m := maxf(1.0, (u_R - u_L) * w)
	var x_in_block := (u - u_L) * w - span_m * 0.5
	var frac := clampf((u - u_L) / maxf(0.05, u_R - u_L), 0.0, 1.0)

	var z_cur := _eval_block_plane(t, o_L, x_in_block, dy_m, span_m, amp, tilt_scale)
	var z_prev := _eval_block_plane(t, o_prev, x_in_block + span_m, dy_m, span_m, amp, tilt_scale)
	var z_next := _eval_block_plane(t, o_R, x_in_block - span_m, dy_m, span_m, amp, tilt_scale)

	var dist_L_m := (u - u_L) * w
	var dist_R_m := (u_R - u) * w
	var dist_joint_m := minf(dist_L_m, dist_R_m)

	var z_blended := z_cur
	if dist_L_m < bevel:
		var k := smoothstep(0.0, bevel, dist_L_m)
		z_blended = lerpf(0.5 * (z_prev + z_cur), z_cur, k)
	elif dist_R_m < bevel:
		var k := smoothstep(0.0, bevel, dist_R_m)
		z_blended = lerpf(0.5 * (z_next + z_cur), z_cur, k)

	var groove := (1.0 - smoothstep(0.0, bevel * 0.9, dist_joint_m)) * amp * 0.44
	var weld := (1.0 if absf(t[o_L + 7]) > 0.32 else 0.0) * smoothstep(0.12, 0.88, sin(frac * PI))
	var fault_cur := t[o_L + 7] * 2.0
	var fault_prev := t[o_prev + 7] * 2.0
	var fault_y := lerpf(0.5 * (fault_prev + fault_cur), fault_cur, smoothstep(0.0, bevel * 1.6, dist_L_m))
	return Vector4(z_blended, groove, weld, fault_y)


func _eval_block_plane(
	t: PackedFloat32Array,
	o: int,
	x_rel: float,
	dy_m: float,
	span_m: float,
	amp: float,
	tilt_scale: float
) -> float:
	var z_step := amp * t[o + 2] * 0.55
	var plane_tilt := (t[o + 3] * x_rel + t[o + 4] * dy_m) * tilt_scale
	var prow_mode := t[o + 5]
	var prow := 0.0
	if prow_mode > 0.5:
		var ridge_x := t[o + 6] * span_m * 0.18
		prow = maxf(0.0, (span_m * 0.45 - absf(x_rel - ridge_x))) * tilt_scale * 0.80
	elif prow_mode < -0.5:
		prow = -maxf(0.0, (span_m * 0.42 - absf(x_rel))) * tilt_scale * 0.75
	return z_step + plane_tilt + prow


func _bench_layout(x: float, y: float) -> Vector3:
	var fault := -1.4 * smoothstep(-10.5, -6.0, x) + 0.9 * smoothstep(18.5, 24.0, x)
	var step_wave := 0.65 * sin(x * 0.08 + 0.5) + 0.35 * cos(x * 0.19 - 0.3)
	var y_macro := y - (0.02 * x + fault + step_wave)

	var center_bay := smoothstep(-9.5, -5.5, x) * (1.0 - smoothstep(19.0, 25.0, x))
	var right_bench := smoothstep(-8.5, -3.5, x) * (1.0 - smoothstep(46.0, 56.0, x))
	var left_terraces := 1.0 - smoothstep(-32.0, -25.0, x)

	var left_spur_mod := clampf(0.55 + 0.55 * sin(x * 0.16 + 1.1), 0.15, 1.0)
	var right_mod := clampf(0.85 + 0.25 * sin(x * 0.12 - 0.5), 0.55, 1.15)

	var mid_retreat_dist := 12.2 * center_bay + 8.4 * (right_bench * (1.0 - center_bay * 0.48)) * right_mod + 6.0 * left_terraces * left_spur_mod
	var top_retreat_dist := 6.0 * (1.0 - smoothstep(-34.0, -26.0, x)) * clampf(0.65 + 0.45 * cos(x * 0.14 + 0.7), 0.2, 1.0)
	return Vector3(y_macro, mid_retreat_dist, top_retreat_dist)


func _cleft_depth_at(x: float, y: float) -> float:
	var cleft_depth := 0.0
	for mj in MASTER_JOINTS:
		var mjv: Vector3 = mj
		var jx := mjv.x + (y - 18.0) * mjv.y
		var dist := absf(x - jx)
		if dist < 2.8:
			cleft_depth += mjv.z * pow(1.0 - dist / 2.8, 1.7)
	return cleft_depth


func _z_rock(x: float, y: float) -> float:
	var bl := _bench_layout(x, y)
	var y_macro := bl.x
	var mid_retreat_dist := bl.y
	var top_retreat_dist := bl.z

	var tier_id := 0
	var tier_mid_y := 7.5
	if y_macro > 27.8:
		tier_id = 2
		tier_mid_y = 33.0
	elif y_macro > 15.6:
		tier_id = 1
		tier_mid_y = 21.5

	var jb0 := _sample_joint_blocks(x, y_macro, tier_mid_y, tier_id, 0)
	var y_strat := y_macro + jb0.w

	var nb := _beds_hard.size()
	var b_idx := 0
	for b in nb:
		if y_strat >= _beds_y[b] and y_strat < _beds_y[b + 1]:
			b_idx = b
			break
		elif y_strat >= _beds_y[nb]:
			b_idx = nb - 1
	var hard := _beds_hard[b_idx]
	var b_y0 := _beds_y[b_idx]
	var b_y1 := _beds_y[b_idx + 1]
	var b_mid := 0.5 * (b_y0 + b_y1)
	var b_frac := clampf((y_strat - b_y0) / maxf(0.1, b_y1 - b_y0), 0.0, 1.0)

	var right_bench := smoothstep(-8.5, -3.5, x) * (1.0 - smoothstep(46.0, 56.0, x))
	var left_terraces := 1.0 - smoothstep(-32.0, -25.0, x)

	# Prominent heaped earth mound on the center-right bench (`x = -2..+50, y_macro = 13.4..18.8 m`)
	var bench_mound_h := 3.6 + 1.85 * exp(-pow((x - 14.0) / 15.0, 2.0)) + 1.45 * exp(-pow((x - 36.0) / 12.0, 2.0))
	var above_mid_bench := smoothstep(13.4, 13.4 + bench_mound_h, y_macro)
	var above_top_bench := smoothstep(25.6, 28.8, y_macro)
	var tier_retreat := above_mid_bench * mid_retreat_dist + above_top_bench * top_retreat_dist

	var mid_t := clampf((y_macro - 13.4) / bench_mound_h, 0.0, 1.0)
	var top_t := clampf((y_macro - 25.6) / 3.2, 0.0, 1.0)
	var mid_ramp := sin(mid_t * PI) * clampf((mid_retreat_dist - 1.5) / 4.0, 0.0, 1.0)
	var top_ramp := sin(top_t * PI) * clampf((top_retreat_dist - 1.5) / 3.5, 0.0, 1.0)
	var rock_exposure := 1.0 - 0.82 * maxf(mid_ramp, top_ramp)

	var z_base := 7.2 + 2.2 * right_bench + 1.6 * left_terraces + 1.3 * sin(x * 0.055)

	var diag_left := x + (y - 11.0) * 0.58
	var mono_x := smoothstep(-31.0, -24.5, diag_left) * (1.0 - smoothstep(-9.2, -7.0, x))
	var mono_y := smoothstep(3.2, 5.8, y) * (1.0 - smoothstep(18.5, 22.2, y))
	var mono_prow := maxf(0.0, 1.0 - absf(x - (-17.0)) / 12.5) * 2.8
	var monolith_jut := mono_x * mono_y * (6.4 + mono_prow - maxf(0.0, y - 13.0) * 0.36)
	var mono_cave := smoothstep(-24.0, -19.0, x) * (1.0 - smoothstep(-9.0, -6.5, x)) * sin(clampf((y - 2.2) / 3.4, 0.0, 1.0) * PI) * 4.2

	var cleft_depth := _cleft_depth_at(x, y)

	var jb1 := _sample_joint_blocks(x, y_strat, tier_mid_y, tier_id * 3 + (b_idx / 3), 1)
	var jb2 := _sample_joint_blocks(x, y_strat, b_mid, b_idx, 2)

	var flute_mask := smoothstep(19.0, 25.0, x) * above_mid_bench
	var flutes := flute_mask * (1.25 * cos(x * 0.65 + sin(x * 0.22) * 0.7) + 0.45 * sin(x * 1.45))

	var massive_buttress := maxf(mono_x * mono_y * 0.85, flute_mask * 0.65)
	var weld_factor := (1.0 - 0.85 * maxf(jb0.z, jb1.z)) * (1.0 - massive_buttress)

	var parting_undercut := 0.0
	if hard < 0.35:
		var seam_profile := sin(b_frac * PI)
		var seam_mod := (0.35 + 0.65 * _noise1(x * 0.14 + float(b_idx) * 5.3)) * weld_factor
		parting_undercut = -1.45 * seam_profile * seam_mod
	else:
		var sub_seam := absf(b_frac - 0.52) * 2.0
		if sub_seam < 0.14 and _noise1(x * 0.12 + float(b_idx) * 9.1) > 0.58:
			parting_undercut = -0.42 * (1.0 - sub_seam / 0.14) * weld_factor

	var natural_lean := -0.12 * y

	var rock_detail := (
		(jb0.x - jb0.y)
		+ (jb1.x - jb1.y)
		+ (jb2.x - jb2.y)
		+ flutes
		+ parting_undercut
	) * rock_exposure

	return (
		z_base
		- tier_retreat
		+ monolith_jut
		- mono_cave
		+ natural_lean
		- cleft_depth * rock_exposure
		+ rock_detail
	)


func _skyline_y(x: float) -> float:
	# Smooth end-taper on the far left (`x < -64 m`) and far right (`x > +64 m`) so the cliff steps down
	# naturally into broken karst ledges and grassy heathland at its lateral ends!
	var taper_L := smoothstep(-81.5, -62.0, x)
	var taper_R := 1.0 - smoothstep(62.0, 81.5, x)
	var end_taper := lerpf(0.28, 1.0, taper_L * taper_R)
	var left_rise := 1.6 * (1.0 - smoothstep(-55.0, -15.0, x))
	var bay_dip := 3.6 * smoothstep(-11.0, -5.5, x) * (1.0 - smoothstep(14.0, 22.0, x))
	var crag_steps := (
		0.85 * sin(x * 0.065 + 0.8)
		+ 0.45 * cos(x * 0.16 - 0.4)
		+ 0.22 * sin(x * 0.38 + 1.9)
	)
	return (34.4 + left_rise - bay_dip + crag_steps) * end_taper


# --- Mesh Construction: Bedrock Wall + Zone-Specific 3D Crag Architecture + Benches + Talus --

func _build_eroded_cliff(seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	_init_geology()

	var holder := Node3D.new()
	holder.name = "CliffLab"

	var nx := 360
	var ny := 112
	var wall_verts := PackedVector3Array()
	wall_verts.resize(nx * ny)

	for ix in nx:
		var x := -SPAN_X * 0.5 + SPAN_X * float(ix) / float(nx - 1)
		var sky := _skyline_y(x)
		for iy in ny:
			var fy := float(iy) / float(ny - 1)
			var y := fy * sky
			var z := _z_rock(x, y)
			if y > sky - 1.1:
				z -= (y - (sky - 1.1)) * 1.45
			wall_verts[ix * ny + iy] = Vector3(x, y, z)

	var st_talus := SurfaceTool.new()
	st_talus.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_benches := SurfaceTool.new()
	st_benches.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depo := _build_base_talus(st_talus, wall_verts, nx, ny)
	var spawn_samples: Array = depo.samples

	var st_rock := SurfaceTool.new()
	st_rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_tris := 0

	for ix in nx - 1:
		var sky_col := _skyline_y(wall_verts[ix * ny].x)
		for iy in ny - 1:
			var p00 := wall_verts[ix * ny + iy]
			var p10 := wall_verts[(ix + 1) * ny + iy]
			var p11 := wall_verts[(ix + 1) * ny + iy + 1]
			var p01 := wall_verts[ix * ny + iy + 1]

			if (ix + iy) % 2 == 0:
				_emit_cliff_tri(st_rock, st_benches, spawn_samples, p00, p10, p11, sky_col)
				_emit_cliff_tri(st_rock, st_benches, spawn_samples, p00, p11, p01, sky_col)
			else:
				_emit_cliff_tri(st_rock, st_benches, spawn_samples, p00, p10, p01, sky_col)
				_emit_cliff_tri(st_rock, st_benches, spawn_samples, p10, p11, p01, sky_col)
			wall_tris += 2

	for ix in nx - 1:
		var r0 := wall_verts[ix * ny + (ny - 1)]
		var r1 := wall_verts[(ix + 1) * ny + (ny - 1)]
		var b1 := r1 + Vector3(0.0, -0.35, -3.5)
		var b0 := r0 + Vector3(0.0, -0.35, -3.5)
		_emit_rock_tri(st_rock, r0, r1, b1)
		_emit_rock_tri(st_rock, r0, b1, b0)

	# Build the 30 m deep Karst Caprock Pavement & Grike Plateau behind the ragged cliff rim (`z_rim .. z_rim - 30 m`)
	var nz_plat := 28
	var plat_verts := PackedVector3Array()
	var plat_nrms := PackedVector3Array()
	var plat_cols := PackedColorArray()
	plat_verts.resize(nx * nz_plat)
	plat_nrms.resize(nx * nz_plat)
	plat_cols.resize(nx * nz_plat)
	for ix in nx:
		var rim_v := wall_verts[ix * ny + (ny - 1)]
		var x := rim_v.x
		for iz in nz_plat:
			var u := float(iz) / float(nz_plat - 1)
			var d_back := u * 30.0
			var z := rim_v.z - d_back
			# Grike fissures (dissolved vertical joints in the caprock) + gentle dip slope rising into the back-slope
			var grike_x := absf(fposmod(x * 0.28 + 0.35 * sin(z * 0.18), 1.0) - 0.5) * 2.0
			var grike_z := absf(fposmod(z * 0.32 + 0.25 * cos(x * 0.15), 1.0) - 0.5) * 2.0
			var grike_groove := -0.85 * (1.0 - smoothstep(0.0, 0.16, minf(grike_x, grike_z))) * (1.0 - smoothstep(14.0, 26.0, d_back))
			var swell := 0.85 * sin(x * 0.06 + z * 0.08) + 0.42 * cos(x * 0.14 - z * 0.11)
			var y := rim_v.y - 0.22 + d_back * 0.11 + swell * smoothstep(0.0, 5.0, d_back) + grike_groove
			plat_verts[ix * nz_plat + iz] = Vector3(x, y, z)
			# Bare limestone clints near the rim (`d_back < 12 m`) transitioning to heath soil further back
			var soil_blend := smoothstep(4.5, 16.0, d_back)
			var is_grike := 1.0 if minf(grike_x, grike_z) < 0.18 else 0.0
			var col_plat := Color(0.74, 0.71, 0.67).lerp(Color(0.58, 0.55, 0.49), maxf(soil_blend, is_grike * 0.85))
			plat_cols[ix * nz_plat + iz] = col_plat
	for ix in nx:
		for iz in nz_plat:
			var dx := plat_verts[mini(ix + 1, nx - 1) * nz_plat + iz] - plat_verts[maxi(ix - 1, 0) * nz_plat + iz]
			var dz_v := plat_verts[ix * nz_plat + maxi(iz - 1, 0)] - plat_verts[ix * nz_plat + mini(iz + 1, nz_plat - 1)]
			var n := dz_v.cross(dx).normalized()
			plat_nrms[ix * nz_plat + iz] = n if n.y >= 0.0 else -n
			if iz > 0 and iz < 14 and ix % 3 == 0 and iz % 2 == 0:
				spawn_samples.append({
					"pos": plat_verts[ix * nz_plat + iz],
					"nrm": plat_nrms[ix * nz_plat + iz],
					"zone": "rim",
					"toe": float(iz) / 14.0
				})
	for ix in nx - 1:
		for iz in nz_plat - 1:
			var q0 := ix * nz_plat + iz
			var q1 := (ix + 1) * nz_plat + iz
			var q2 := q1 + 1
			var q3 := q0 + 1
			for qi in [q0, q2, q1, q0, q3, q2]:
				st_benches.set_color(plat_cols[qi])
				st_benches.set_normal(plat_nrms[qi])
				st_benches.add_vertex(plat_verts[qi])

	# Flat bedrock quarry floor for Checkpoint 1 (before talus deposition)
	var st_floor := SurfaceTool.new()
	st_floor.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fl0 := Vector3(-SPAN_X * 0.52, 0.0, -6.0)
	var fl1 := Vector3(SPAN_X * 0.52, 0.0, -6.0)
	var fl2 := Vector3(SPAN_X * 0.52, -1.8, 56.0)
	var fl3 := Vector3(-SPAN_X * 0.52, -1.8, 56.0)
	_emit_rock_tri(st_floor, fl0, fl2, fl1)
	_emit_rock_tri(st_floor, fl0, fl3, fl2)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "BedrockFloor"
	floor_mi.mesh = st_floor.commit()
	holder.add_child(floor_mi)

	var bedrock_mi := MeshInstance3D.new()
	bedrock_mi.name = "BedrockWall"
	bedrock_mi.mesh = st_rock.commit()
	holder.add_child(bedrock_mi)

	var benches_mi := MeshInstance3D.new()
	benches_mi.name = "BenchShelves"
	benches_mi.mesh = st_benches.commit()
	holder.add_child(benches_mi)

	var talus_mi := MeshInstance3D.new()
	talus_mi.name = "BaseTalusCones"
	talus_mi.mesh = st_talus.commit()
	holder.add_child(talus_mi)

	# 4. Build Zone-Specific 3D Polyhedral Crag Architecture (Monoliths, Tall Fluted Pillars, Pier Blocks)
	var crags := _spawn_geological_crag_architecture(rng)
	holder.add_child(crags.node)

	# 5. Spawn Gravity-Sorted Faceted Boulders & Clumped Rockfall Fans
	var boulders := _spawn_sorted_boulders(rng, spawn_samples)
	holder.add_child(boulders.node)

	return {
		"node": holder,
		"floor": floor_mi,
		"bedrock": bedrock_mi,
		"benches": benches_mi,
		"talus": talus_mi,
		"crags": crags.node,
		"boulders": boulders.node,
		"samples": spawn_samples,
		"plat_verts": plat_verts,
		"plat_nrms": plat_nrms,
		"nx": nx,
		"nz_plat": nz_plat,
		"wall_tris": wall_tris,
		"crag_count": crags.count,
		"boulder_count": boulders.count
	}


func _emit_cliff_tri(
	st_rock: SurfaceTool,
	st_talus: SurfaceTool,
	spawn_samples: Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	sky_col: float
) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.length_squared() < 1e-6:
		return
	var center := (a + b + c) / 3.0
	var bl := _bench_layout(center.x, center.y)
	var y_macro := bl.x
	var bench_mound_h := 3.6 + 1.85 * exp(-pow((center.x - 14.0) / 15.0, 2.0)) + 1.45 * exp(-pow((center.x - 36.0) / 12.0, 2.0))
	var in_mid_band := y_macro > 13.0 and y_macro < (15.0 + bench_mound_h) and bl.y > 1.8
	var in_top_band := y_macro > 25.0 and y_macro < 29.5 and bl.z > 1.8
	var in_mono_cap := center.x > -27.5 and center.x < -8.0 and center.y > 18.8 and center.y < 23.2
	if (in_mid_band or in_top_band or in_mono_cap) and n.y > 0.24 and center.y < sky_col - 1.5:
		var col := Color(0.68, 0.64, 0.59, 1.0)
		for v in [a, c, b]:
			st_talus.set_color(col)
			st_talus.set_normal(n)
			st_talus.add_vertex(v)
		if fposmod(center.x * 3.7 + center.z * 5.3, 1.0) < 0.42:
			spawn_samples.append({
				"pos": center,
				"nrm": n,
				"zone": "bench",
				"toe": 0.5
			})
	else:
		_emit_rock_tri(st_rock, a, b, c)


func _emit_rock_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.length_squared() < 1e-6:
		return
	var center := (a + b + c) / 3.0
	var n_hash := _noise1(center.x * 0.22 + center.y * 0.28)
	var col := Color(0.96, 0.95, 0.93) if n_hash > 0.55 else Color(0.89, 0.90, 0.92)
	if n.y < -0.22:
		col *= 0.66
	elif absf(n.x) > 0.52:
		col *= 0.85
	col.a = 1.0
	for v in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)


## Builds a single-volume, multi-faceted 3D limestone crag polyhedron (NOT split into horizontal brick sub-boxes!)
## with 12 geological fracture planes so massive 8..16 m buttresses, monolith slabs, and vertical pillars have
## broad, clean planar faces, sharp conjugate dihedral arrises, and overhanging lower lips!
func _sculpted_crag_mesh(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8191 + variant * 53
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := Vector3(0.5, 0.5, 0.5)
	var faces := []
	for a in 3:
		for sgn in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[a] = sgn
			var u := Vector3.ZERO
			u[(a + 1) % 3] = half[(a + 1) % 3]
			var v := Vector3.ZERO
			v[(a + 2) % 3] = half[(a + 2) % 3]
			var fc := n * half[a]
			var quad := PackedVector3Array([fc - u - v, fc + u - v, fc + u + v, fc - u + v])
			if (quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(n) < 0.0:
				quad.reverse()
			faces.append(quad)

	# 11 geological fracture cuts:
	#   - 3 broad front dihedral planes (`n.z > 0.85`)
	#   - 4 steep conjugate side joint planes (`|n.x| > 0.65`)
	#   - 4 top/bottom/corner wedge bevels (`|n.y| > 0.55`)
	var cut_normals := [
		Vector3(rng.randf_range(-0.32, 0.32), rng.randf_range(-0.20, 0.16), 1.0).normalized(),
		Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.28, 0.22), 0.90).normalized(),
		Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.42, -0.15), 0.88).normalized(),
		Vector3(rng.randf_range(0.68, 0.95), rng.randf_range(-0.30, 0.30), rng.randf_range(0.15, 0.55)).normalized(),
		Vector3(rng.randf_range(-0.95, -0.68), rng.randf_range(-0.30, 0.30), rng.randf_range(0.15, 0.55)).normalized(),
		Vector3(rng.randf_range(0.55, 0.88), rng.randf_range(-0.48, 0.48), rng.randf_range(-0.25, 0.35)).normalized(),
		Vector3(rng.randf_range(-0.88, -0.55), rng.randf_range(-0.48, 0.48), rng.randf_range(-0.25, 0.35)).normalized(),
		Vector3(rng.randf_range(-0.38, 0.38), rng.randf_range(-0.92, -0.55), rng.randf_range(0.25, 0.65)).normalized(),
		Vector3(rng.randf_range(-0.38, 0.38), rng.randf_range(0.58, 0.92), rng.randf_range(0.20, 0.55)).normalized(),
		Vector3(rng.randf_range(-0.62, 0.62), rng.randf_range(-0.78, -0.42), rng.randf_range(0.35, 0.72)).normalized(),
		Vector3(rng.randf_range(-0.62, 0.62), rng.randf_range(0.42, 0.78), rng.randf_range(0.30, 0.68)).normalized(),
	]
	for cn in cut_normals:
		var n: Vector3 = cn
		var max_d := -1e9
		for f in faces:
			for vert in (f as PackedVector3Array):
				max_d = maxf(max_d, n.dot(vert))
		var cut_depth := rng.randf_range(0.05, 0.19)
		faces = EDGE_BUILDER_SCRIPT._cut(faces, n, max_d - cut_depth)

	for f in faces:
		var poly: PackedVector3Array = f
		if poly.size() < 3:
			continue
		var n := (poly[1] - poly[0]).cross(poly[2] - poly[0]).normalized()
		var f_shade := rng.randf_range(0.95, 1.03)
		if n.y < -0.22:
			f_shade *= 0.68
		elif absf(n.x) > 0.55:
			f_shade *= 0.87
		_emit_facet_with_recessed_cracks(st, poly, n, f_shade, rng, 0, Vector3.ZERO)

	return st.commit()


func _emit_tri_safe(
	st: SurfaceTool,
	v0: Vector3, v1: Vector3, v2: Vector3,
	n0: Vector3, n1: Vector3, n2: Vector3,
	c0: Color, c1: Color, c2: Color,
	ref_out_nrm: Vector3
) -> void:
	var cross_v := (v1 - v0).cross(v2 - v0)
	if cross_v.length_squared() < 1e-10:
		return
	if cross_v.dot(ref_out_nrm) > 0.0:
		for item in [[v0, n0, c0], [v2, n2, c2], [v1, n1, c1]]:
			st.set_color(item[2])
			st.set_normal(item[1])
			st.add_vertex(item[0])
	else:
		for item in [[v0, n0, c0], [v1, n1, c1], [v2, n2, c2]]:
			st.set_color(item[2])
			st.set_normal(item[1])
			st.add_vertex(item[0])


func _emit_flat_facet(st: SurfaceTool, poly: PackedVector3Array, n: Vector3, f_shade: float) -> void:
	if poly.size() < 3:
		return
	var col := Color(f_shade, f_shade, f_shade, 1.0)
	for i in range(1, poly.size() - 1):
		_emit_tri_safe(st, poly[0], poly[i], poly[i + 1], n, n, n, col, col, col, n)


## Carves true 3D recessed V-cleft incipient cracks (pre-detachment tension & conjugate shear fissures)
## INTO a block facet `poly` without splitting the polyhedron into separate blocks or creating external
## faces:
##   1. Splits `poly` along a geological fracture plane `(c_nrm, c_off)` into two strictly convex sub-facets
##      `sub_poly_pos` and `sub_poly_neg`, sliding the lip endpoints strictly along `poly`'s perimeter edges
##      so nothing ever pokes past a bevelled corner;
##   2. Applies a hinged pre-detachment step (`slip`, ~8..20 cm in world space) and micro-tilt (`1.5..3 deg`)
##      to one side of the crack so it casts a real lip shadow when directional shadows are enabled;
##   3. Subdivides the recessed V-groove into 6 jagged cleavage segments with 4 3D wall strips:
##      - positive 48 deg chamfer lip (`L_pos -> T_pos`),
##      - positive 83 deg steep inner wall (`T_pos -> R_mid`, with deep cavity occlusion at `R_mid`),
##      - negative 83 deg opposing inner wall (`R_mid -> T_neg`),
##      - negative 48 deg sun-catching chamfer lip (`T_neg -> L_neg`),
##      supporting both **arrested crack tips** (pinching to zero depth inside the rock face) and recursive
##      **conjugate T-junction branch cracks** (`depth_lvl = 1`).
func _emit_facet_with_recessed_cracks(
	st: SurfaceTool,
	poly: PackedVector3Array,
	n: Vector3,
	f_shade: float,
	rng: RandomNumberGenerator,
	depth_lvl: int,
	prev_c_nrm: Vector3
) -> void:
	if poly.size() < 3:
		return
	if depth_lvl >= 2 or n.z < 0.25:
		_emit_flat_facet(st, poly, n, f_shade)
		return

	var fc := Vector3.ZERO
	for pv in poly:
		fc += pv
	fc /= float(poly.size())

	var up_ref := Vector3.UP if absf(n.y) < 0.90 else Vector3.FORWARD
	var t_u := n.cross(up_ref).normalized()
	var t_v := t_u.cross(n).normalized()

	var u_min := 1e9
	var u_max := -1e9
	var v_min := 1e9
	var v_max := -1e9
	for pv in poly:
		var d := pv - fc
		var u := d.dot(t_u)
		var v := d.dot(t_v)
		u_min = minf(u_min, u)
		u_max = maxf(u_max, u)
		v_min = minf(v_min, v)
		v_max = maxf(v_max, v)
	var u_span := u_max - u_min
	var v_span := v_max - v_min
	var min_span := minf(u_span, v_span)
	var max_span := maxf(u_span, v_span)

	if max_span < (0.20 if depth_lvl == 0 else 0.15) or min_span < (0.11 if depth_lvl == 0 else 0.085):
		_emit_flat_facet(st, poly, n, f_shade)
		return

	var c_nrm := Vector3.ZERO
	if depth_lvl == 0:
		var ang := deg_to_rad(
			rng.randf_range(-32.0, 32.0) if rng.randf() < 0.72
			else rng.randf_range(48.0, 76.0) * (-1.0 if rng.randf() < 0.5 else 1.0)
		)
		c_nrm = (t_u * cos(ang) + t_v * sin(ang)).normalized()
	else:
		var rot_ang := deg_to_rad(rng.randf_range(58.0, 108.0) * (-1.0 if rng.randf() < 0.5 else 1.0))
		c_nrm = prev_c_nrm.rotated(n, rot_ang)
		c_nrm = (c_nrm - n * c_nrm.dot(n)).normalized()

	var c_off := c_nrm.dot(fc) + rng.randf_range(-0.14, 0.14) * min_span
	var n_v := poly.size()
	var sd := PackedFloat32Array()
	sd.resize(n_v)
	var min_sd := 1e9
	var max_sd := -1e9
	for i in n_v:
		var s := c_nrm.dot(poly[i]) - c_off
		sd[i] = s
		min_sd = minf(min_sd, s)
		max_sd = maxf(max_sd, s)

	if min_sd > -0.032 or max_sd < 0.032:
		_emit_flat_facet(st, poly, n, f_shade)
		return

	var i_enter := -1
	var i_exit := -1
	for i in n_v:
		var j := (i + 1) % n_v
		if sd[i] < 0.0 and sd[j] >= 0.0:
			i_enter = i
		elif sd[i] >= 0.0 and sd[j] < 0.0:
			i_exit = i

	if i_enter < 0 or i_exit < 0:
		_emit_flat_facet(st, poly, n, f_shade)
		return

	var j_enter := (i_enter + 1) % n_v
	var j_exit := (i_exit + 1) % n_v
	var t_enter := clampf(-sd[i_enter] / maxf(sd[j_enter] - sd[i_enter], 1e-5), 0.0, 1.0)
	var p_A := poly[i_enter].lerp(poly[j_enter], t_enter)
	var t_exit := clampf(sd[i_exit] / maxf(sd[i_exit] - sd[j_exit], 1e-5), 0.0, 1.0)
	var p_B := poly[i_exit].lerp(poly[j_exit], t_exit)
	var cut_len := p_A.distance_to(p_B)
	if cut_len < 0.09:
		_emit_flat_facet(st, poly, n, f_shade)
		return

	var is_arrested := (rng.randf() < (0.45 if depth_lvl == 0 else 0.78))
	var open_at_A := (rng.randf() < 0.5)
	if depth_lvl > 0 and prev_c_nrm.length_squared() > 0.5:
		# For a secondary T-junction crack, open widest at the end that meets the parent crack!
		open_at_A = absf(prev_c_nrm.dot(p_A - fc)) <= absf(prev_c_nrm.dot(p_B - fc))

	var w_lip_max := rng.randf_range(0.015, 0.025) * (0.76 if depth_lvl > 0 else 1.0)
	var w_A := 0.0 if (is_arrested and not open_at_A) else w_lip_max * (1.0 if is_arrested else rng.randf_range(0.60, 1.0))
	var w_B := 0.0 if (is_arrested and open_at_A) else w_lip_max * (1.0 if is_arrested else rng.randf_range(0.50, 0.95))

	var frac_pos_A := clampf(w_A / maxf(sd[j_enter], 1e-4), 0.0, 0.28) if w_A > 0.0 else 0.0
	var lip_pos_A0 := p_A.lerp(poly[j_enter], frac_pos_A)
	var frac_neg_A := clampf(w_A / maxf(-sd[i_enter], 1e-4), 0.0, 0.28) if w_A > 0.0 else 0.0
	var lip_neg_A := p_A.lerp(poly[i_enter], frac_neg_A)

	var frac_pos_B := clampf(w_B / maxf(sd[i_exit], 1e-4), 0.0, 0.28) if w_B > 0.0 else 0.0
	var lip_pos_B0 := p_B.lerp(poly[i_exit], frac_pos_B)
	var frac_neg_B := clampf(w_B / maxf(-sd[j_exit], 1e-4), 0.0, 0.28) if w_B > 0.0 else 0.0
	var lip_neg_B := p_B.lerp(poly[j_exit], frac_neg_B)

	# Hinged pre-detachment step (`slip_A`, `slip_B`) on the positive sub-facet so one side of the
	# cracked block steps forward by ~10..20 cm and tilts by ~2 deg while staying strictly planar!
	var slip_max := rng.randf_range(0.012, 0.023) * (0.68 if depth_lvl > 0 else 1.0)
	var slip_A := 0.0 if (is_arrested and not open_at_A) else slip_max
	var slip_B := 0.0 if (is_arrested and open_at_A) else (slip_max if is_arrested else slip_max * rng.randf_range(0.38, 0.78))
	var cut_dir := (p_B - p_A) / cut_len
	var tilt_cross := rng.randf_range(-0.024, 0.032)

	var displace_pos := func(v: Vector3) -> Vector3:
		var ht := (v - p_A).dot(cut_dir) / cut_len
		var dz := lerpf(slip_A, slip_B, ht) + maxf(0.0, c_nrm.dot(v - p_A) - w_lip_max) * tilt_cross
		return v + n * dz

	# Build `sub_poly_pos` (`sd >= 0`, displaced by `displace_pos`) and `sub_poly_neg` (`sd <= 0`)
	var sub_poly_pos := PackedVector3Array()
	sub_poly_pos.append(displace_pos.call(lip_pos_A0))
	var idx := j_enter
	while true:
		sub_poly_pos.append(displace_pos.call(poly[idx]))
		if idx == i_exit:
			break
		idx = (idx + 1) % n_v
	sub_poly_pos.append(displace_pos.call(lip_pos_B0))

	var sub_poly_neg := PackedVector3Array()
	sub_poly_neg.append(lip_neg_B)
	idx = j_exit
	while true:
		sub_poly_neg.append(poly[idx])
		if idx == i_enter:
			break
		idx = (idx + 1) % n_v
	sub_poly_neg.append(lip_neg_A)

	var n_pos := (sub_poly_pos[1] - sub_poly_pos[0]).cross(sub_poly_pos[2] - sub_poly_pos[0]).normalized() if sub_poly_pos.size() >= 3 else n
	if n_pos.dot(n) < 0.0:
		n_pos = -n_pos
	var shade_pos := f_shade * rng.randf_range(0.98, 1.03)
	var shade_neg := f_shade * rng.randf_range(0.95, 1.00)
	var col_pos := Color(shade_pos, shade_pos, shade_pos, 1.0)
	var col_neg := Color(shade_neg, shade_neg, shade_neg, 1.0)

	# Emit the two sub-facets (recursing into one of them at `depth_lvl == 0` so a secondary conjugate
	# crack can branch off the primary crack at a T-junction!)
	if depth_lvl == 0 and rng.randf() < 0.78:
		if rng.randf() < 0.55:
			_emit_facet_with_recessed_cracks(st, sub_poly_pos, n_pos, shade_pos, rng, depth_lvl + 1, c_nrm)
			_emit_flat_facet(st, sub_poly_neg, n, shade_neg)
		else:
			_emit_flat_facet(st, sub_poly_pos, n_pos, shade_pos)
			_emit_facet_with_recessed_cracks(st, sub_poly_neg, n, shade_neg, rng, depth_lvl + 1, c_nrm)
	else:
		_emit_flat_facet(st, sub_poly_pos, n_pos, shade_pos)
		_emit_flat_facet(st, sub_poly_neg, n, shade_neg)

	# Build the 6-segment 3D recessed V-groove crack between `lip_pos_A -> lip_pos_B` and `lip_neg_A -> lip_neg_B`
	var lip_pos_A: Vector3 = displace_pos.call(lip_pos_A0)
	var lip_pos_B: Vector3 = displace_pos.call(lip_pos_B0)
	var n_seg := 6
	var d_base := rng.randf_range(0.044, 0.068) * (0.78 if depth_lvl > 0 else 1.0)

	var L_pos_arr := PackedVector3Array()
	var T_pos_arr := PackedVector3Array()
	var R_mid_arr := PackedVector3Array()
	var T_neg_arr := PackedVector3Array()
	var L_neg_arr := PackedVector3Array()
	var env_arr := PackedFloat32Array()

	L_pos_arr.resize(n_seg + 1)
	T_pos_arr.resize(n_seg + 1)
	R_mid_arr.resize(n_seg + 1)
	T_neg_arr.resize(n_seg + 1)
	L_neg_arr.resize(n_seg + 1)
	env_arr.resize(n_seg + 1)

	for k in n_seg + 1:
		var t := float(k) / float(n_seg)
		var l_pos := lip_pos_A.lerp(lip_pos_B, t)
		var l_neg := lip_neg_A.lerp(lip_neg_B, t)
		var m_base := 0.5 * (lip_pos_A0.lerp(lip_pos_B0, t) + l_neg)
		var half_w := maxf(0.0, 0.5 * (lip_pos_A0.lerp(lip_pos_B0, t) - l_neg).dot(c_nrm))
		var dz_here := lerpf(slip_A, slip_B, t)

		var env := 1.0
		if is_arrested and open_at_A:
			env = (1.0 - smoothstep(0.12, 0.74, t)) if t < 0.74 else 0.0
		elif is_arrested and not open_at_A:
			env = smoothstep(0.26, 0.88, t) if t > 0.26 else 0.0
		else:
			env = lerpf(0.68, 1.0, sin(t * PI))

		var jag := rng.randf_range(-0.34, 0.34) * half_w * env if (k > 0 and k < n_seg and env > 0.05) else 0.0
		var d_root := d_base * env * (rng.randf_range(0.86, 1.14) if (k > 0 and k < n_seg) else 0.88)
		var d_throat := 0.26 * d_root
		var w_throat := 0.36 * half_w * env

		L_pos_arr[k] = l_pos
		T_pos_arr[k] = m_base + c_nrm * (jag + w_throat) + n * (0.55 * dz_here - d_throat)
		R_mid_arr[k] = m_base + c_nrm * jag - n * d_root
		T_neg_arr[k] = m_base + c_nrm * (jag - w_throat) - n * d_throat
		L_neg_arr[k] = l_neg
		env_arr[k] = env

	var n_lip_pos_base := (n * 0.64 - c_nrm * 0.77).normalized()
	var n_wall_pos_base := (n * 0.12 - c_nrm * 0.993).normalized()
	var n_wall_neg_base := (n * 0.12 + c_nrm * 0.993).normalized()
	var n_lip_neg_base := (n * 0.64 + c_nrm * 0.77).normalized()
	var col_root_dark := Color(0.05, 0.05, 0.06, 1.0)

	for k in n_seg:
		var e0 := env_arr[k]
		var e1 := env_arr[k + 1]
		var e_mid := 0.5 * (e0 + e1)

		var n_lp0 := n.lerp(n_lip_pos_base, e0).normalized()
		var n_lp1 := n.lerp(n_lip_pos_base, e1).normalized()
		var n_wp0 := n.lerp(n_wall_pos_base, e0).normalized()
		var n_wp1 := n.lerp(n_wall_pos_base, e1).normalized()
		var n_wn0 := n.lerp(n_wall_neg_base, e0).normalized()
		var n_wn1 := n.lerp(n_wall_neg_base, e1).normalized()
		var n_ln0 := n.lerp(n_lip_neg_base, e0).normalized()
		var n_ln1 := n.lerp(n_lip_neg_base, e1).normalized()

		var c_lp0 := col_pos * lerpf(1.0, 0.94, e0)
		var c_lp1 := col_pos * lerpf(1.0, 0.94, e1)
		var c_tp0 := col_pos * lerpf(1.0, 0.44, e0)
		var c_tp1 := col_pos * lerpf(1.0, 0.44, e1)
		var c_rm0 := col_pos.lerp(col_root_dark, e0)
		var c_rm1 := col_pos.lerp(col_root_dark, e1)
		var c_tn0 := col_neg * lerpf(1.0, 0.44, e0)
		var c_tn1 := col_neg * lerpf(1.0, 0.44, e1)
		var c_ln0 := col_neg * lerpf(1.0, 0.94, e0)
		var c_ln1 := col_neg * lerpf(1.0, 0.94, e1)

		# 1. Positive chamfer lip (`L_pos -> T_pos`)
		var ref_lp := n.lerp(n_lip_pos_base, e_mid).normalized()
		_emit_tri_safe(st, L_pos_arr[k], L_pos_arr[k + 1], T_pos_arr[k + 1], n_lp0, n_lp1, n_lp1, c_lp0, c_lp1, c_tp1, ref_lp)
		_emit_tri_safe(st, L_pos_arr[k], T_pos_arr[k + 1], T_pos_arr[k], n_lp0, n_lp1, n_lp0, c_lp0, c_tp1, c_tp0, ref_lp)

		# 2. Positive steep inner cleft wall (`T_pos -> R_mid`)
		if e0 > 0.01 or e1 > 0.01:
			var ref_wp := (n * 0.35 - c_nrm * 0.93).normalized()
			_emit_tri_safe(st, T_pos_arr[k], T_pos_arr[k + 1], R_mid_arr[k + 1], n_wp0, n_wp1, n_wp1, c_tp0, c_tp1, c_rm1, ref_wp)
			_emit_tri_safe(st, T_pos_arr[k], R_mid_arr[k + 1], R_mid_arr[k], n_wp0, n_wp1, n_wp0, c_tp0, c_rm1, c_rm0, ref_wp)

			# 3. Negative steep inner cleft wall (`R_mid -> T_neg`)
			var ref_wn := (n * 0.35 + c_nrm * 0.93).normalized()
			_emit_tri_safe(st, R_mid_arr[k], R_mid_arr[k + 1], T_neg_arr[k + 1], n_wn0, n_wn1, n_wn1, c_rm0, c_rm1, c_tn1, ref_wn)
			_emit_tri_safe(st, R_mid_arr[k], T_neg_arr[k + 1], T_neg_arr[k], n_wn0, n_wn1, n_wn0, c_rm0, c_rm1, c_tn0, ref_wn)

		# 4. Negative chamfer lip (`T_neg -> L_neg`)
		var ref_ln := n.lerp(n_lip_neg_base, e_mid).normalized()
		_emit_tri_safe(st, T_neg_arr[k], T_neg_arr[k + 1], L_neg_arr[k + 1], n_ln0, n_ln1, n_ln1, c_tn0, c_tn1, c_ln1, ref_ln)
		_emit_tri_safe(st, T_neg_arr[k], L_neg_arr[k + 1], L_neg_arr[k], n_ln0, n_ln1, n_ln0, c_tn0, c_ln1, c_ln0, ref_ln)

	# Close the open V-notch ends at `p_A` (`k = 0`) and `p_B` (`k = n_seg`) so side views of the edge are watertight
	if w_A > 0.001 and env_arr[0] > 0.05:
		var c_tpA := col_pos * 0.44
		var c_rmA := col_root_dark
		var c_tnA := col_neg * 0.44
		_emit_tri_safe(st, L_pos_arr[0], T_pos_arr[0], R_mid_arr[0], n, n_wall_pos_base, n, col_pos, c_tpA, c_rmA, n)
		_emit_tri_safe(st, L_pos_arr[0], R_mid_arr[0], L_neg_arr[0], n, n, n, col_pos, c_rmA, col_neg, n)
		_emit_tri_safe(st, R_mid_arr[0], T_neg_arr[0], L_neg_arr[0], n, n_wall_neg_base, n, c_rmA, c_tnA, col_neg, n)
	if w_B > 0.001 and env_arr[n_seg] > 0.05:
		var c_tpB := col_pos * 0.44
		var c_rmB := col_root_dark
		var c_tnB := col_neg * 0.44
		_emit_tri_safe(st, L_pos_arr[n_seg], R_mid_arr[n_seg], T_pos_arr[n_seg], n, n, n_wall_pos_base, col_pos, c_rmB, c_tpB, n)
		_emit_tri_safe(st, L_pos_arr[n_seg], L_neg_arr[n_seg], R_mid_arr[n_seg], n, n, n, col_pos, col_neg, c_rmB, n)
		_emit_tri_safe(st, R_mid_arr[n_seg], L_neg_arr[n_seg], T_neg_arr[n_seg], n, n, n_wall_neg_base, c_rmB, col_neg, c_tnB, n)



## Places zone-specific 3D polyhedral crag blocks (`_spawn_geological_crag_architecture`) that respect the
## open stony-earth benches (`y = 13.8..18.5 m` on center-right, `y = 20..22.5 m` on monolith shoulder,
## `y = 13.5..15.8 m` & `26.0..28.8 m` on left terraces) and use tall 15..19 m vertical pillars on the right
## headwall and 11..15 m leaning slabs on the monolith!
func _spawn_geological_crag_architecture(rng: RandomNumberGenerator) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "CragBlocks"

	var n_shapes := 14
	var shapes := []
	var xforms := []
	var cols := []
	for k in n_shapes:
		shapes.append(_sculpted_crag_mesh(k))
		xforms.append([])
		cols.append([])

	var count_arr := [0]

	# Helper to add a 3D crag block seated at `(x_c, y_bot..y_top)` on the bedrock wall
	var add_crag := func(x_c: float, y_bot: float, y_top: float, w_b: float, d_b: float, roll_deg: float, yaw_deg: float, pitch_deg: float, z_pull: float) -> void:
		var sky_lim := _skyline_y(x_c) + 0.35
		var eff_top := minf(y_top, sky_lim)
		var h_b := eff_top - y_bot
		if h_b < 1.6:
			return
		var adj_bot := maxf(0.2, y_bot)
		var adj_h := eff_top - adj_bot
		if adj_h < 1.5:
			return
		var adj_y := 0.5 * (adj_bot + eff_top)
		var z_face := _z_rock(x_c, adj_y)

		var basis := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), deg_to_rad(roll_deg))).scaled(Vector3(w_b, adj_h, d_b))
		var center := Vector3(x_c, adj_y, z_face - d_b * z_pull)
		var si := rng.randi() % n_shapes
		xforms[si].append(Transform3D(basis, center))
		var c := Color(0.95, 0.95, 0.94).lerp(Color(0.89, 0.90, 0.93), rng.randf()) * rng.randf_range(0.94, 1.04)
		c.a = 1.0
		cols[si].append(c)
		count_arr[0] += 1

	# --- ZONE 1: Left Stepped Crags (`x = -80 .. -29.5`) ---
	# Three distinct rock tiers separated by the two open left benches (`y = 13.4..16.0` and `y = 25.8..28.8`)
	var left_tiers := [
		Vector2(1.8, 7.8),
		Vector2(7.4, 13.4),    # stops at 13.4 m so the lower-left bench (`13.4..16.0`) is open!
		Vector2(16.0, 21.2),
		Vector2(20.8, 25.8),   # stops at 25.8 m so the upper-left bench (`25.8..28.8`) is open!
		Vector2(28.8, 37.5),   # tall upper caprock tier!
	]
	for lt in left_tiers:
		var band: Vector2 = lt
		var x_cur := -79.5
		while x_cur < -29.5:
			var w := rng.randf_range(6.2, 10.5)
			var x_c := minf(-31.5, x_cur + w * 0.5)
			x_cur += w * rng.randf_range(0.86, 0.95)
			if _cleft_depth_at(x_c, 0.5 * (band.x + band.y)) > 2.2:
				continue
			var sky := _skyline_y(x_c)
			var y0 := band.x + rng.randf_range(-0.4, 0.4)
			var y1 := minf(sky + 0.3, band.y + rng.randf_range(-0.4, 0.4))
			if band.y > 35.0:
				y1 = sky + 0.3
			add_crag.call(x_c, y0, y1, w * 1.04, rng.randf_range(4.2, 6.2), rng.randf_range(-5.0, 5.0), rng.randf_range(-12.0, 12.0), rng.randf_range(-5.0, 4.0), 0.24)
			# Add a protruding dihedral wedge block on half of the massive left crags
			if rng.randf() < 0.55:
				var sw := w * rng.randf_range(0.45, 0.72)
				var sy0 := y0 + rng.randf_range(0.0, 1.5)
				var sy1 := minf(y1, sy0 + (y1 - y0) * rng.randf_range(0.55, 0.85))
				add_crag.call(x_c + rng.randf_range(-1.2, 1.2), sy0, sy1, sw, rng.randf_range(3.5, 5.2), rng.randf_range(-8.0, 8.0), rng.randf_range(-16.0, 16.0), rng.randf_range(-7.0, 5.0), 0.12)

	# --- ZONE 2: Left-Center Leaning Monolith (`x = -29.0 .. -8.0, y = 4.2 .. 19.6 m`) ---
	# Built from massive, overlapping right-leaning monolith slabs (`7..11 m` tall) over the basal shadow cave (`y < 4.5 m`),
	# strictly capped at `y = 19.6 m` so the monolith's soil & boulder shoulder (`y = 19.4..22.8 m`) is completely open!
	var mono_slabs := [
		# [x_c, y_bot, y_top, width, depth, roll_deg, yaw_deg]
		[-25.5, 4.8, 12.2, 7.6, 5.8, -17.0, -7.0],
		[-19.5, 4.4, 13.0, 7.8, 6.2, -16.0, 4.0],
		[-14.2, 4.3, 13.5, 7.2, 6.0, -15.0, -6.0],
		[-10.2, 4.5, 13.2, 6.4, 5.6, -13.0, 9.0],
		[-23.5, 11.2, 18.8, 7.5, 5.4, -15.0, 5.0],
		[-17.8, 10.8, 19.4, 7.8, 5.8, -16.0, -5.0],
		[-12.2, 11.0, 19.6, 7.0, 5.5, -14.0, 8.0],
		# Protruding dihedral rib slabs on the face of the monolith
		[-20.8, 6.8, 15.6, 5.8, 5.2, -18.0, -10.0],
		[-15.2, 6.5, 16.2, 6.0, 5.4, -17.0, 9.0],
		[-11.0, 7.2, 15.8, 5.2, 5.0, -14.0, -8.0],
	]
	for ms in mono_slabs:
		var m: Array = ms
		add_crag.call(float(m[0]), float(m[1]), float(m[2]), float(m[3]), float(m[4]), float(m[5]), float(m[6]), -3.5, 0.22)

	# Plus the upper headwall above the monolith's shoulder (`x = -29.0 .. -8.0, y = 22.8 .. sky`):
	var x_m_top := -28.5
	while x_m_top < -8.2:
		var w := rng.randf_range(6.2, 9.2)
		var x_c := minf(-9.5, x_m_top + w * 0.5)
		x_m_top += w * 0.88
		var sky := _skyline_y(x_c)
		add_crag.call(x_c, 22.8, 29.2, w, 5.2, rng.randf_range(-7.0, 4.0), rng.randf_range(-10.0, 10.0), -3.0, 0.22)
		add_crag.call(x_c + rng.randf_range(-0.6, 0.6), 28.6, sky + 0.3, w * 0.96, 5.0, rng.randf_range(-5.0, 5.0), rng.randf_range(-10.0, 10.0), -2.0, 0.22)

	# --- ZONE 3: Lower Pier Wall Below the Wide Center-Right Bench (`x = -6.5 .. +56.0, y = 2.0 .. 13.0 m`) ---
	# Strictly capped at `y_top = 13.0 m` so the wide brown stony-earth & boulder bench (`y = 13.2..18.8 m`) is 100% visible!
	var lower_bands := [Vector2(2.0, 7.8), Vector2(7.4, 13.0)]
	for lb in lower_bands:
		var band: Vector2 = lb
		var x_cur := -6.0
		while x_cur < 56.0:
			var w := rng.randf_range(5.8, 8.8)
			var x_c := x_cur + w * 0.5
			x_cur += w * rng.randf_range(0.88, 0.96)
			if _cleft_depth_at(x_c, 8.0) > 2.2:
				continue
			add_crag.call(x_c, band.x + rng.randf_range(-0.3, 0.3), band.y + rng.randf_range(-0.2, 0.2), w * 1.02, rng.randf_range(4.2, 5.8), rng.randf_range(-3.5, 3.5), rng.randf_range(-10.0, 10.0), rng.randf_range(-4.0, 3.0), 0.24)

	# --- ZONE 4: Center Recessed Bay Headwall (`x = -6.8 .. +20.0, y = 18.8 .. sky`) ---
	# Starts at `y = 18.8 m` (above the wide bench mound!) and uses large 8..10 m tall slabs!
	var bay_bands := [Vector2(18.8, 26.2), Vector2(25.6, 33.8)]
	for bb in bay_bands:
		var band: Vector2 = bb
		var x_cur := -6.5
		while x_cur < 19.8:
			var w := rng.randf_range(6.2, 9.4)
			var x_c := minf(18.5, x_cur + w * 0.5)
			x_cur += w * 0.88
			if _cleft_depth_at(x_c, 25.0) > 2.4:
				continue
			var sky := _skyline_y(x_c)
			var y1 := sky + 0.3 if band.y > 30.0 else band.y + rng.randf_range(-0.4, 0.4)
			add_crag.call(x_c, band.x + rng.randf_range(-0.3, 0.3), y1, w * 1.04, rng.randf_range(4.5, 6.0), rng.randf_range(-4.0, 4.0), rng.randf_range(-11.0, 11.0), rng.randf_range(-4.0, 3.0), 0.24)

	# --- ZONE 5: Right Fluted Columnar Headwall (`x = +21.5 .. +79.5, y = 18.5 .. sky`) ---
	# Tall, unbroken vertical columnar pillars (`height = 12..18 m`!) standing side-by-side above the right bench!
	var x_flute := 22.0
	while x_flute < 79.0:
		var w := rng.randf_range(4.8, 7.6)
		var x_c := x_flute + w * 0.5
		x_flute += w * rng.randf_range(0.86, 0.94)
		if _cleft_depth_at(x_c, 26.0) > 2.3:
			continue
		var sky := _skyline_y(x_c)
		# Above `x = 52`, the mid-bench ends and the fluted pillars extend all the way down to `y = 4.0 m`!
		var y_base := 18.6 if x_c < 51.0 else 4.5
		var mid_split := lerpf(y_base, sky, rng.randf_range(0.45, 0.62))
		# Tall lower-upper pillar pair (each 8..13 m tall, vertical `roll ~ 0`, strong dihedral `yaw`)
		add_crag.call(x_c, y_base + rng.randf_range(-0.4, 0.4), mid_split + 0.8, w * 1.02, rng.randf_range(4.4, 6.2), rng.randf_range(-2.5, 2.5), rng.randf_range(-14.0, 14.0), rng.randf_range(-3.0, 3.0), 0.22)
		add_crag.call(x_c + rng.randf_range(-0.4, 0.4), mid_split - 0.6, sky + 0.35, w * 1.02, rng.randf_range(4.4, 6.2), rng.randf_range(-2.5, 2.5), rng.randf_range(-14.0, 14.0), rng.randf_range(-3.0, 3.0), 0.22)
		# Plus a tall unbroken vertical rib spanning nearly the full pillar height!
		if rng.randf() < 0.65:
			add_crag.call(x_c + rng.randf_range(-0.8, 0.8), y_base + 1.5, sky - 0.5, w * 0.62, rng.randf_range(4.0, 5.6), rng.randf_range(-2.0, 2.0), rng.randf_range(-18.0, 18.0), 0.0, 0.14)

	for k in n_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = shapes[k]
		var xf_arr: Array = xforms[k]
		var col_arr: Array = cols[k]
		mm.instance_count = xf_arr.size()
		for idx_i in xf_arr.size():
			mm.set_instance_transform(idx_i, xf_arr[idx_i])
			mm.set_instance_color(idx_i, col_arr[idx_i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "CragBatch_%d" % k
		mmi.multimesh = mm
		holder.add_child(mmi)

	return {"node": holder, "count": count_arr[0]}


## Builds the gullied, multi-lobed base talus apron + gently sloping foreground valley floor into `st`.
func _build_base_talus(st: SurfaceTool, wall_verts: PackedVector3Array, wall_nx: int, wall_ny: int) -> Dictionary:
	var spawn_samples := []
	var h_apex_arr := PackedFloat32Array()
	var raw_z_wall := PackedFloat32Array()
	var z_start_arr := PackedFloat32Array()
	h_apex_arr.resize(wall_nx)
	raw_z_wall.resize(wall_nx)
	z_start_arr.resize(wall_nx)

	var nz_base := 88
	var z_max := 54.0
	var base_verts := PackedVector3Array()
	var base_nrms := PackedVector3Array()
	var base_cols := PackedColorArray()
	base_verts.resize(wall_nx * nz_base)
	base_nrms.resize(wall_nx * nz_base)
	base_cols.resize(wall_nx * nz_base)

	var repose_tan := tan(deg_to_rad(27.5))

	for ix in wall_nx:
		var x := wall_verts[ix * wall_ny].x
		var lobe_left := 5.4 * exp(-pow((x - (-30.0)) / 9.5, 2.0))
		var lobe_center := 6.8 * exp(-pow((x - (-1.0)) / 16.5, 2.0))
		var lobe_right_1 := 6.8 * exp(-pow((x - 19.5) / 9.5, 2.0))
		var lobe_right_2 := 9.8 * exp(-pow((x - 39.5) / 13.0, 2.0))
		var gully_mod := 0.72 * sin(x * 0.16 + 0.4) + 0.42 * cos(x * 0.37 - 0.7)
		var h_apex := maxf(1.2, 1.6 + lobe_left + lobe_center + lobe_right_1 + lobe_right_2 + gully_mod)
		h_apex_arr[ix] = h_apex

		var iy_apex := clampi(int((h_apex / 37.0) * float(wall_ny - 1)), 0, wall_ny - 1)
		var min_z := wall_verts[ix * wall_ny + iy_apex].z
		for dy in range(-2, 3):
			var jy := clampi(iy_apex + dy, 0, wall_ny - 1)
			min_z = minf(min_z, wall_verts[ix * wall_ny + jy].z)
		raw_z_wall[ix] = min_z

	for ix in wall_nx:
		var sum_z := 0.0
		var sum_w := 0.0
		for dx in range(-18, 19):
			var jx := clampi(ix + dx, 0, wall_nx - 1)
			var w := exp(-pow(float(dx) / 9.5, 2.0))
			sum_z += raw_z_wall[jx] * w
			sum_w += w
		z_start_arr[ix] = (sum_z / sum_w) - 2.2

	for ix in wall_nx:
		var x := wall_verts[ix * wall_ny].x
		var h_apex := h_apex_arr[ix]
		var z_start := z_start_arr[ix]

		for iz in nz_base:
			var u := float(iz) / float(nz_base - 1)
			var z := lerpf(z_start, z_max, u)
			var d_out := maxf(0.0, z - z_start)
			var fan_x := x / (1.0 + d_out * 0.025)
			var radial_ribs := (0.65 * sin(fan_x * 0.28 + 0.5) + 0.42 * cos(fan_x * 0.61 - 0.9)) * exp(-d_out * 0.045)
			var raw_h := h_apex + radial_ribs - d_out * repose_tan
			var h_cone := 0.55 * log(1.0 + exp(minf(40.0, raw_h / 0.55)))
			var micro := (0.22 * sin(x * 0.24 + z * 0.28) + 0.15 * cos(x * 0.51 - z * 0.37)) * clampf(h_cone / 2.2, 0.22, 1.0)
			var valley_slope := -2.4 * smoothstep(14.0, z_max, z)
			var h := h_cone + micro + valley_slope
			base_verts[ix * nz_base + iz] = Vector3(x, h, z)
			var c_val := 0.72 if h_cone > 0.4 else 0.66
			base_cols[ix * nz_base + iz] = Color(c_val, c_val * 0.96, c_val * 0.91, 1.0)

	for ix in wall_nx:
		for iz in nz_base:
			var dx := base_verts[mini(ix + 1, wall_nx - 1) * nz_base + iz] - base_verts[maxi(ix - 1, 0) * nz_base + iz]
			var dz_v := base_verts[ix * nz_base + mini(iz + 1, nz_base - 1)] - base_verts[ix * nz_base + maxi(iz - 1, 0)]
			var n := dz_v.cross(dx).normalized()
			base_nrms[ix * nz_base + iz] = n if n.y >= 0.0 else -n
			if iz > 3 and iz < nz_base - 2 and ix % 2 == 0 and iz % 2 == 0:
				var v := base_verts[ix * nz_base + iz]
				var wall_z_here := z_start_arr[ix] + 2.2
				if v.z > wall_z_here - 0.2:
					var toe := clampf((v.z - wall_z_here) / 22.0, 0.0, 1.0)
					spawn_samples.append({"pos": v, "nrm": base_nrms[ix * nz_base + iz], "zone": "base", "toe": toe})

	_append_grid_to_st(st, base_verts, base_nrms, base_cols, wall_nx, nz_base)

	return {
		"samples": spawn_samples,
		"h_apex": h_apex_arr,
		"z_start": z_start_arr,
		"repose_tan": repose_tan
	}


func _append_grid_to_st(
	st: SurfaceTool,
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	nx: int,
	nz: int
) -> void:
	for ix in nx - 1:
		for iz in nz - 1:
			var q0 := ix * nz + iz
			var q1 := (ix + 1) * nz + iz
			var q2 := q1 + 1
			var q3 := q0 + 1
			for qi in [q0, q1, q2, q0, q2, q3]:
				st.set_color(colors[qi])
				st.set_normal(normals[qi])
				st.add_vertex(verts[qi])


func _spawn_sorted_boulders(rng: RandomNumberGenerator, samples: Array) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "Boulders"

	var n_shapes := 8
	var shapes := []
	var xforms := []
	var cols := []
	var temp_eb: Node3D = EDGE_BUILDER_SCRIPT.new()
	for k in n_shapes:
		shapes.append(temp_eb.call("_block_mesh", k))
		xforms.append([])
		cols.append([])
	temp_eb.free()

	var n_samples := samples.size()
	var count := 0

	for i in 3200:
		var s: Dictionary = samples[rng.randi() % n_samples]
		var pos: Vector3 = s.pos
		var nrm: Vector3 = s.nrm
		var zone := String(s.zone)
		var toe := float(s.toe)

		if zone == "base":
			var center_fan := 1.75 * exp(-pow((pos.x - (-1.5)) / 15.5, 2.0))
			var left_fan := 1.05 * exp(-pow((pos.x - (-30.0)) / 10.5, 2.0))
			var right_flanks := 1.20 * exp(-pow((pos.x - 28.0) / 8.5, 2.0)) + 1.10 * exp(-pow((pos.x - 48.0) / 9.5, 2.0))
			var cone_bare_apex := (
				exp(-pow((pos.x - 19.5) / 5.0, 2.0)) + exp(-pow((pos.x - 39.5) / 6.0, 2.0))
			) * (1.0 - smoothstep(0.15, 0.42, toe))
			var lobe_w := (0.24 + center_fan + left_fan + right_flanks) * (1.0 - 0.78 * cone_bare_apex)

			# Foreground valley floor (`toe > 0.74`): sparse low boulders & weathered bedrock exposures
			if toe > 0.74:
				if rng.randf() < 0.82:
					continue
				var f_size := rng.randf_range(0.55, 2.10)
				var f_dims := Vector3(f_size * rng.randf_range(0.85, 1.5), f_size * rng.randf_range(0.25, 0.55), f_size * rng.randf_range(0.8, 1.35))
				_add_boulder_instance(rng, xforms, cols, n_shapes, pos, nrm, f_dims)
				count += 1
				continue

			if rng.randf() > lobe_w * 0.75:
				continue

			var size := lerpf(0.50, 2.50, clampf(toe * 1.25, 0.0, 1.0)) * rng.randf_range(0.48, 1.38)
			if rng.randf() < 0.14:
				size *= 1.55
			var dims := Vector3(size, size * rng.randf_range(0.42, 0.78), size * rng.randf_range(0.58, 1.08))
			_add_boulder_instance(rng, xforms, cols, n_shapes, pos, nrm, dims)
			count += 1

			if size > 1.25 and absf(pos.x) < 22.0 and rng.randf() < 0.65:
				var sub_s := size * rng.randf_range(0.35, 0.62)
				var sub_off := Vector3(rng.randf_range(-1.1, 1.1), -0.15, rng.randf_range(-0.9, 0.9))
				_add_boulder_instance(rng, xforms, cols, n_shapes, pos + sub_off, nrm, Vector3(sub_s, sub_s * 0.55, sub_s * 0.82))
				count += 1
		elif zone == "rim":
			if rng.randf() < 0.25:
				continue
			# Flat weathered limestone pavement slabs (clints) along the cliff-top edge (`z_rim .. z_rim - 14 m`),
			# separated by grike fissures and tilted gently with the dip slope!
			var w_slab := rng.randf_range(1.6, 4.2) * lerpf(1.0, 0.55, toe)
			var d_slab := rng.randf_range(1.2, 3.0) * lerpf(1.0, 0.60, toe)
			var h_slab := rng.randf_range(0.32, 0.72)
			var dims := Vector3(w_slab, h_slab, d_slab)
			_add_boulder_instance(rng, xforms, cols, n_shapes, pos + Vector3(0.0, 0.08, 0.0), nrm, dims)
			count += 1
		else:
			if rng.randf() < 0.52:
				continue
			var size := rng.randf_range(0.45, 1.35) * (1.25 if rng.randf() < 0.14 else 1.0)
			var dims := Vector3(size * rng.randf_range(0.85, 1.40), size * rng.randf_range(0.28, 0.55), size * rng.randf_range(0.65, 1.10))
			_add_boulder_instance(rng, xforms, cols, n_shapes, pos, nrm, dims)
			count += 1

	for k in n_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = shapes[k]
		var xf_arr: Array = xforms[k]
		var col_arr: Array = cols[k]
		mm.instance_count = xf_arr.size()
		for idx_i in xf_arr.size():
			mm.set_instance_transform(idx_i, xf_arr[idx_i])
			mm.set_instance_color(idx_i, col_arr[idx_i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "BoulderBatch_%d" % k
		mmi.multimesh = mm
		holder.add_child(mmi)

	return {"node": holder, "count": count}


func _add_boulder_instance(
	rng: RandomNumberGenerator,
	xforms: Array,
	cols: Array,
	n_shapes: int,
	pos: Vector3,
	nrm: Vector3,
	dims: Vector3
) -> void:
	var up: Vector3 = (nrm + Vector3(rng.randf_range(-0.24, 0.24), 0.0, rng.randf_range(-0.24, 0.24))).normalized()
	var fwd := Vector3.BACK.rotated(Vector3.UP, rng.randf() * TAU)
	var bx: Vector3 = up.cross(fwd).normalized()
	var bz: Vector3 = bx.cross(up).normalized()
	var basis := Basis(bx * dims.x, up * dims.y, bz * dims.z)
	var center: Vector3 = pos + up * (dims.y * rng.randf_range(0.14, 0.38))
	var shape_i := rng.randi() % n_shapes
	xforms[shape_i].append(Transform3D(basis, center))
	var c := Color(0.96, 0.95, 0.94).lerp(Color(0.84, 0.86, 0.89), rng.randf()) * rng.randf_range(0.86, 1.10)
	c.a = 1.0
	cols[shape_i].append(c)


# --- Geometry & Noise Helpers ---------------------------------------------------------------

func _hash(x: float) -> float:
	return fposmod(sin(x * 127.1 + 311.7) * 43758.5453, 1.0)


func _noise1(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash(i), _hash(i + 1.0), f)


## Checkpoint 1: Pure chipped bedrock clay test (beds + conjugate joints + retreat tiers, NO talus or boulders).
func _apply_checkpoint1_materials(lab: Dictionary) -> void:
	var rock_clay := StandardMaterial3D.new()
	rock_clay.vertex_color_use_as_albedo = true
	rock_clay.albedo_color = Color(0.93, 0.93, 0.91)
	rock_clay.roughness = 0.92
	(lab.bedrock as MeshInstance3D).material_override = rock_clay
	(lab.floor as MeshInstance3D).material_override = rock_clay
	(lab.floor as MeshInstance3D).visible = true
	(lab.talus as MeshInstance3D).visible = false
	(lab.boulders as Node3D).visible = false

	# Bench triangles have vertex color `Color(0.68, 0.64, 0.59)` for Checkpoint 2; in Checkpoint 1
	# we render them as clean bare rock clay (without vertex color tint) so the structural bedrock
	# retreat shelves read as pure chipped stone before soil/scree deposition!
	var bench_rock_clay := StandardMaterial3D.new()
	bench_rock_clay.vertex_color_use_as_albedo = false
	bench_rock_clay.albedo_color = Color(0.86, 0.86, 0.85)
	bench_rock_clay.roughness = 0.92
	(lab.benches as MeshInstance3D).material_override = bench_rock_clay

	for c in (lab.crags as Node3D).get_children():
		if c is MultiMeshInstance3D:
			(c as MultiMeshInstance3D).material_override = rock_clay


## Checkpoint 2: Mass-wasting deposition clay test (talus & scree cones at angle of repose + bench earth + sorted boulders).
func _apply_checkpoint2_materials(lab: Dictionary) -> void:
	var rock_clay := StandardMaterial3D.new()
	rock_clay.vertex_color_use_as_albedo = true
	rock_clay.albedo_color = Color(0.93, 0.93, 0.91)
	rock_clay.roughness = 0.92
	(lab.bedrock as MeshInstance3D).material_override = rock_clay
	(lab.floor as MeshInstance3D).visible = false
	(lab.talus as MeshInstance3D).visible = true
	(lab.boulders as Node3D).visible = true

	var talus_clay := StandardMaterial3D.new()
	talus_clay.vertex_color_use_as_albedo = true
	talus_clay.albedo_color = Color(0.62, 0.58, 0.54)
	talus_clay.roughness = 0.96
	(lab.benches as MeshInstance3D).material_override = talus_clay
	(lab.talus as MeshInstance3D).material_override = talus_clay

	for c in (lab.crags as Node3D).get_children():
		if c is MultiMeshInstance3D:
			(c as MultiMeshInstance3D).material_override = rock_clay

	for c in (lab.boulders as Node3D).get_children():
		if c is MultiMeshInstance3D:
			(c as MultiMeshInstance3D).material_override = rock_clay


## Checkpoint 3: Surface weathering & materiality driven by the erosion state.
func _apply_lit_materials(lab: Dictionary) -> void:
	(lab.floor as MeshInstance3D).visible = false
	(lab.talus as MeshInstance3D).visible = true
	(lab.boulders as Node3D).visible = true

	var eb: Node3D = EDGE_BUILDER_SCRIPT.new()
	var wall_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 13.0, Color(1.08, 1.09, 1.13), 0.55, false)
	wall_mat.set_shader_parameter("scan_normal_depth", 0.42)
	wall_mat.set_shader_parameter("fracture", 0.16)
	wall_mat.set_shader_parameter("fracture_size", 3.8)
	wall_mat.set_shader_parameter("veg_amount", 0.10)
	(lab.bedrock as MeshInstance3D).material_override = wall_mat

	for c in (lab.crags as Node3D).get_children():
		if c is MultiMeshInstance3D:
			(c as MultiMeshInstance3D).material_override = wall_mat

	var ground_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 11.0, Color(1.02, 1.03, 1.07), 0.35, true)
	ground_mat.set_shader_parameter("ground_tint", Color(0.45, 0.48, 0.54))
	ground_mat.set_shader_parameter("rubble_tint", Color(0.76, 0.78, 0.83))
	ground_mat.set_shader_parameter("scree_top", 45.0)
	ground_mat.set_shader_parameter("veg_amount", 0.22)
	(lab.benches as MeshInstance3D).material_override = ground_mat
	(lab.talus as MeshInstance3D).material_override = ground_mat

	var boulder_mat: ShaderMaterial = eb.call("_rock_mat_instanced")
	boulder_mat.set_shader_parameter("scan_tint", Color(1.02, 1.04, 1.09))
	boulder_mat.set_shader_parameter("scan_normal_depth", 0.48)
	boulder_mat.set_shader_parameter("fracture", 0.20)
	boulder_mat.set_shader_parameter("fracture_size", 1.8)
	boulder_mat.set_shader_parameter("veg_amount", 0.06)
	for c in (lab.boulders as Node3D).get_children():
		if c is MultiMeshInstance3D:
			(c as MultiMeshInstance3D).material_override = boulder_mat
	eb.free()


# --- Study 3: Varied Lift Heights (3 m / 9 m / 18 m / 36 m) & Arena Micro-Outcrops ------------

## Builds a side-by-side comparison of 4 natural limestone lift heights across `x = -62 .. +62 m`:
##   - `x = -60 .. -33`: **3.5 m Micro-Outcrop / Karst Step** (inside-the-arena clearing edge: a single hard caprock
##     bed jutting over a shallow undercut with a narrow 2.5 m boulder-and-fern toe, small enough to weave around)
##   - `x = -29 .. -2`:  **9.0 m Low Bluffs** (two massive beds with one parting seam and a 5 m talus apron, ideal for
##     mid-clearing ridge steps or low perch walls)
##   - `x = +2 .. +29`:  **18.0 m Mid Escarpment** (two tiers separated by a stony-earth bench at `y = 8..10 m`,
##     matching pine canopy height)
##   - `x = +33 .. +60`: **35.0 m Full Escarpment** (three tiers with wide mid-bench, leaning buttress, tall fluted
##     upper pillars, and deep coalescing talus cone)
func _build_lift_scale_study() -> Node3D:
	var holder := Node3D.new()
	holder.name = "LiftScaleStudy"
	var rng := RandomNumberGenerator.new()
	rng.seed = 409

	var eb: Node3D = EDGE_BUILDER_SCRIPT.new()
	var wall_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 13.0, Color(1.08, 1.09, 1.13), 0.55, false)
	wall_mat.set_shader_parameter("scan_normal_depth", 0.42)
	wall_mat.set_shader_parameter("fracture", 0.16)
	wall_mat.set_shader_parameter("fracture_size", 3.8)
	wall_mat.set_shader_parameter("veg_amount", 0.12)

	var ground_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 11.0, Color(1.02, 1.03, 1.07), 0.35, true)
	ground_mat.set_shader_parameter("ground_tint", Color(0.45, 0.48, 0.54))
	ground_mat.set_shader_parameter("rubble_tint", Color(0.76, 0.78, 0.83))
	ground_mat.set_shader_parameter("scree_top", 35.0)
	ground_mat.set_shader_parameter("veg_amount", 0.22)

	var boulder_mat: ShaderMaterial = eb.call("_rock_mat_instanced")
	boulder_mat.set_shader_parameter("scan_tint", Color(1.02, 1.04, 1.09))
	boulder_mat.set_shader_parameter("scan_normal_depth", 0.48)
	boulder_mat.set_shader_parameter("fracture", 0.20)
	boulder_mat.set_shader_parameter("fracture_size", 1.8)
	boulder_mat.set_shader_parameter("veg_amount", 0.08)

	var pine_mesh: ArrayMesh = eb.call("_rock_pine_mesh")
	var n_crag_shapes := 10
	var crag_shapes := []
	var crag_xfs := []
	var crag_cols := []
	for k in n_crag_shapes:
		crag_shapes.append(_sculpted_crag_mesh(k))
		crag_xfs.append([])
		crag_cols.append([])

	var n_boulder_shapes := 8
	var b_shapes := []
	var b_xfs := []
	var b_cols := []
	for k in n_boulder_shapes:
		b_shapes.append(eb.call("_block_mesh", k))
		b_xfs.append([])
		b_cols.append([])
	eb.free()

	var pine_xfs := []
	var pine_cols := []

	var st_talus := SurfaceTool.new()
	st_talus.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Continuous valley floor across `x = -70..+70, z = -22..+42`
	var specs := [
		{"x0": -61.0, "x1": -33.0, "h": 3.8, "tiers": 1, "talus_h": 1.1, "talus_w": 3.4},
		{"x0": -29.0, "x1": -1.0,  "h": 9.5, "tiers": 1, "talus_h": 2.8, "talus_w": 7.5},
		{"x0":  3.0,  "x1": 31.0,  "h": 18.5, "tiers": 2, "talus_h": 5.2, "talus_w": 13.5},
		{"x0":  35.0, "x1": 63.0,  "h": 35.0, "tiers": 3, "talus_h": 9.2, "talus_w": 22.0},
	]

	for sp in specs:
		var d: Dictionary = sp
		var x0 := float(d.x0)
		var x1 := float(d.x1)
		var h_max := float(d.h)
		var tiers := int(d.tiers)
		var talus_h := float(d.talus_h)
		var talus_w := float(d.talus_w)
		var xc := 0.5 * (x0 + x1)
		var span := x1 - x0

		# Build the talus apron & caprock plateau for this lift scale
		var nx_s := 44
		var nz_s := 36
		var v_grid := PackedVector3Array()
		var n_grid := PackedVector3Array()
		var c_grid := PackedColorArray()
		v_grid.resize(nx_s * nz_s)
		n_grid.resize(nx_s * nz_s)
		c_grid.resize(nx_s * nz_s)

		for ix in nx_s:
			var fx := float(ix) / float(nx_s - 1)
			var x := lerpf(x0 - 2.0, x1 + 2.0, fx)
			# Smooth lateral taper at the ends of each outcrop!
			var end_env := smoothstep(x0 - 1.5, x0 + 4.5, x) * (1.0 - smoothstep(x1 - 4.5, x1 + 1.5, x))
			var h_here := h_max * lerpf(0.18, 1.0, end_env)
			var th_here := talus_h * lerpf(0.15, 1.0, end_env)
			for iz in nz_s:
				var fz := float(iz) / float(nz_s - 1)
				var z := lerpf(-16.0, 32.0, fz)
				var y := 0.0
				if z < 0.0:
					# Plateau / back-slope behind the rim
					var d_back := -z
					var grike := -0.45 * (1.0 - smoothstep(0.0, 0.18, absf(fposmod(x * 0.31, 1.0) - 0.5) * 2.0))
					y = h_here + d_back * 0.08 + grike * (1.0 - smoothstep(6.0, 14.0, d_back))
				elif tiers >= 2 and z < 4.2 and h_here > 12.0:
					# Mid-cliff structural bench at ~0.40 * h_here
					y = h_here * 0.40 + 0.35 * sin(x * 0.35)
				else:
					var z_foot := 4.2 if (tiers >= 2 and h_here > 12.0) else 0.0
					var d_out := maxf(0.0, z - z_foot)
					var raw_cone := th_here - d_out * (th_here / maxf(1.5, talus_w))
					y = 0.35 * log(1.0 + exp(minf(30.0, raw_cone / 0.35))) - 0.8 * smoothstep(12.0, 32.0, z)
				v_grid[ix * nz_s + iz] = Vector3(x, y, z)
				c_grid[ix * nz_s + iz] = Color(0.70, 0.67, 0.62, 1.0)

		for ix in nx_s:
			for iz in nz_s:
				var dx := v_grid[mini(ix + 1, nx_s - 1) * nz_s + iz] - v_grid[maxi(ix - 1, 0) * nz_s + iz]
				var dz_v := v_grid[ix * nz_s + mini(iz + 1, nz_s - 1)] - v_grid[ix * nz_s + maxi(iz - 1, 0)]
				var n := dz_v.cross(dx).normalized()
				n_grid[ix * nz_s + iz] = n if n.y >= 0.0 else -n
		_append_grid_to_st(st_talus, v_grid, n_grid, c_grid, nx_s, nz_s)

		# Place 3D faceted crag blocks scaled appropriately to the lift height!
		var n_rows := 1 if h_max < 5.5 else (2 if h_max < 12.0 else (3 if h_max < 22.0 else 5))
		for ri in n_rows:
			var fy0 := float(ri) / float(n_rows)
			var fy1 := float(ri + 1) / float(n_rows)
			var is_lower_tier := (tiers >= 2 and h_max > 12.0 and fy0 < 0.38)
			# Leave an open bench gap at top of the lower tier on 18 m and 35 m cliffs
			if tiers >= 2 and ((n_rows == 3 and ri == 0) or (n_rows == 5 and ri == 1)):
				fy1 = fy0 + 0.78 * (fy1 - fy0)
			var x_cur := x0
			while x_cur < x1:
				var end_k := smoothstep(x0, x0 + 5.0, x_cur) * (1.0 - smoothstep(x1 - 5.0, x1, x_cur))
				var w_b := lerpf(3.2, 6.8, clampf(h_max / 35.0, 0.0, 1.0)) * rng.randf_range(0.82, 1.18)
				var x_b := minf(x1 - 0.8, x_cur + w_b * 0.5)
				x_cur += w_b * 0.86
				var h_env := h_max * lerpf(0.28, 1.0, end_k)
				var y0 := fy0 * h_env
				var y1 := fy1 * h_env
				var h_b := maxf(1.2, y1 - y0)
				var d_b := clampf(h_b * 0.65, 2.8, 6.2)
				var z_b := (4.4 + d_b * 0.35 - float(ri) * 0.35) if is_lower_tier else (0.6 + d_b * 0.38 - float(ri) * 0.45)
				var roll_d := rng.randf_range(-6.0, 6.0)
				var yaw_d := rng.randf_range(-12.0, 12.0)
				var pitch_d := rng.randf_range(-5.0, 3.0)
				var basis := Basis.from_euler(Vector3(deg_to_rad(pitch_d), deg_to_rad(yaw_d), deg_to_rad(roll_d))).scaled(Vector3(w_b, h_b, d_b))
				var si := rng.randi() % n_crag_shapes
				crag_xfs[si].append(Transform3D(basis, Vector3(x_b, 0.5 * (y0 + y1), z_b)))
				var col_c := Color(0.95, 0.95, 0.94).lerp(Color(0.89, 0.90, 0.93), rng.randf()) * rng.randf_range(0.94, 1.04)
				col_c.a = 1.0
				crag_cols[si].append(col_c)

		# Spawn proportional rockfall boulders on the talus toe & rim pavement slabs on top
		var n_boulders := int(28.0 + h_max * 6.5)
		for bi in n_boulders:
			var bx := rng.randf_range(x0 - 1.0, x1 + 1.0)
			var on_rim := rng.randf() < 0.25
			var bz := rng.randf_range(-8.0, -0.8) if on_rim else rng.randf_range(1.0, talus_w + 5.0)
			var end_env := smoothstep(x0 - 1.5, x0 + 4.5, bx) * (1.0 - smoothstep(x1 - 4.5, x1 + 1.5, bx))
			var h_here := h_max * lerpf(0.18, 1.0, end_env)
			var th_here := talus_h * lerpf(0.15, 1.0, end_env)
			var by := h_here + (-bz) * 0.08 if on_rim else maxf(0.0, th_here * (1.0 - bz / maxf(2.0, talus_w + 2.0)))
			var toe_f := clampf(bz / maxf(2.0, talus_w), 0.0, 1.0)
			var b_sz := rng.randf_range(0.8, 2.2) if on_rim else lerpf(0.35, minf(2.4, 0.65 + h_max * 0.055), toe_f) * rng.randf_range(0.6, 1.35)
			var b_dims := Vector3(b_sz * 1.3, b_sz * 0.32, b_sz * 1.1) if on_rim else Vector3(b_sz, b_sz * 0.55, b_sz * 0.82)
			_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, Vector3(bx, by, bz), Vector3.UP, b_dims)

		# Add scale-reference Scots pines (`16..20 m` tall in the arena, `6..11 m` on the cliff top)
		for pi in 5:
			var px := lerpf(x0 + 2.5, x1 - 2.5, float(pi) / 4.0) + rng.randf_range(-1.2, 1.2)
			var pz := rng.randf_range(-12.0, -3.5)
			var end_env := smoothstep(x0 - 1.5, x0 + 4.5, px) * (1.0 - smoothstep(x1 - 4.5, x1 + 1.5, px))
			var py := h_max * lerpf(0.18, 1.0, end_env) + (-pz) * 0.08
			var ph := rng.randf_range(6.5, 10.5)
			pine_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ph, ph, ph)), Vector3(px, py, pz)))
			pine_cols.append(Color(0.85, 0.92, 0.82, 1.0))
		# And a couple of 16 m valley pines in front of the toe for direct scale comparison!
		for pi in 2:
			var px := xc + (-6.0 if pi == 0 else 6.0)
			var pz := talus_w + 8.5
			var ph := rng.randf_range(14.5, 17.5)
			pine_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ph, ph, ph)), Vector3(px, -0.4, pz)))
			pine_cols.append(Color(0.90, 0.95, 0.86, 1.0))

	var talus_mi := MeshInstance3D.new()
	talus_mi.mesh = st_talus.commit()
	talus_mi.material_override = ground_mat
	holder.add_child(talus_mi)

	for k in n_crag_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = crag_shapes[k]
		var xfa: Array = crag_xfs[k]
		var cla: Array = crag_cols[k]
		mm.instance_count = xfa.size()
		for i in xfa.size():
			mm.set_instance_transform(i, xfa[i])
			mm.set_instance_color(i, cla[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = wall_mat
		holder.add_child(mmi)

	for k in n_boulder_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b_shapes[k]
		var xfa: Array = b_xfs[k]
		var cla: Array = b_cols[k]
		mm.instance_count = xfa.size()
		for i in xfa.size():
			mm.set_instance_transform(i, xfa[i])
			mm.set_instance_color(i, cla[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = boulder_mat
		holder.add_child(mmi)

	var pine_mm := MultiMesh.new()
	pine_mm.transform_format = MultiMesh.TRANSFORM_3D
	pine_mm.use_colors = true
	pine_mm.mesh = pine_mesh
	pine_mm.instance_count = pine_xfs.size()
	for i in pine_xfs.size():
		pine_mm.set_instance_transform(i, pine_xfs[i])
		pine_mm.set_instance_color(i, pine_cols[i])
	var pine_mmi := MultiMeshInstance3D.new()
	pine_mmi.multimesh = pine_mm
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.roughness = 0.92
	pine_mmi.material_override = pm
	holder.add_child(pine_mmi)

	return holder


# --- Study 4: Macro Landform Topologies Around the Forest Arena (Full Geological Erosion!) ----

## Warps the full-detail geological erosion model (`_z_rock`, `_skyline_y`, `_bench_layout`, multi-tier
## stony-earth benches, cliff-top karst grike pavement, gullied 27.5 deg talus cones, zone-specific 3D
## sculpted crag monoliths/pillars, and gravity-sorted rockfall boulders) along an arbitrary 2D spine
## curve `(spine_pts, spine_nrms, spine_h_scales)`!
func _build_eroded_cliff_along_spine(
	holder: Node3D,
	seed_val: int,
	spine_pts: PackedVector2Array,
	spine_nrms: PackedVector2Array,
	spine_h_scales: PackedFloat32Array,
	is_closed_loop: bool,
	crag_xfs: Array,
	crag_cols: Array,
	n_crag_shapes: int,
	b_xfs: Array,
	b_cols: Array,
	n_boulder_shapes: int,
	wall_mat: Material,
	ground_mat: Material
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	_init_geology()

	var nx := spine_pts.size()
	var ny := 72
	var wall_verts := PackedVector3Array()
	var wall_d := PackedFloat32Array()
	var s_arr := PackedFloat32Array()
	var x_geo_arr := PackedFloat32Array()
	var sky_raw_arr := PackedFloat32Array()
	var sky_arr := PackedFloat32Array()
	wall_verts.resize(nx * ny)
	wall_d.resize(nx * ny)
	s_arr.resize(nx)
	x_geo_arr.resize(nx)
	sky_raw_arr.resize(nx)
	sky_arr.resize(nx)

	var s_cum := 0.0
	for ix in nx:
		if ix > 0:
			s_cum += spine_pts[ix].distance_to(spine_pts[ix - 1])
		s_arr[ix] = s_cum

	for ix in nx:
		var x_geo := 0.0
		if is_closed_loop:
			var u_loop := float(ix) / float(nx)
			x_geo = 56.0 * sin(u_loop * TAU * 2.0 + float(seed_val) * 0.7)
		else:
			x_geo = 56.0 * sin(s_arr[ix] * 0.038 + float(seed_val) * 1.1)
		var h_sc := spine_h_scales[ix]
		var d_sc := clampf(0.42 + 0.58 * h_sc, 0.38, 1.05)
		var sky_raw := _skyline_y(x_geo)
		var sky := maxf(1.2, sky_raw * h_sc)
		x_geo_arr[ix] = x_geo
		sky_raw_arr[ix] = sky_raw
		sky_arr[ix] = sky

		var p2 := spine_pts[ix]
		var n2 := spine_nrms[ix]
		for iy in ny:
			var fy := float(iy) / float(ny - 1)
			var y_geo := fy * sky_raw
			var y := fy * sky
			var d_rock := _z_rock(x_geo, y_geo) * d_sc
			if y > sky - 1.1 * h_sc:
				d_rock -= (y - (sky - 1.1 * h_sc)) * 1.45
			var p_xz := p2 + n2 * d_rock
			wall_verts[ix * ny + iy] = Vector3(p_xz.x, y, p_xz.y)
			wall_d[ix * ny + iy] = d_rock

	var st_rock := SurfaceTool.new()
	st_rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_benches := SurfaceTool.new()
	st_benches.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_talus := SurfaceTool.new()
	st_talus.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spawn_samples := []

	var emit_spine_tri := func(a: Vector3, b: Vector3, c: Vector3, x_g: float, y_g: float, sky_g: float, h_sc: float) -> void:
		var n := (b - a).cross(c - a).normalized()
		if n.length_squared() < 1e-6:
			return
		var center := (a + b + c) / 3.0
		var bl := _bench_layout(x_g, y_g)
		var y_macro := bl.x
		var bench_mound_h := 3.6 + 1.85 * exp(-pow((x_g - 14.0) / 15.0, 2.0)) + 1.45 * exp(-pow((x_g - 36.0) / 12.0, 2.0))
		var in_mid_band := y_macro > 13.0 and y_macro < (15.0 + bench_mound_h) and bl.y > 1.8
		var in_top_band := y_macro > 25.0 and y_macro < 29.5 and bl.z > 1.8
		var in_mono_cap := x_g > -27.5 and x_g < -8.0 and y_g > 18.8 and y_g < 23.2
		if h_sc > 0.38 and (in_mid_band or in_top_band or in_mono_cap) and n.y > 0.24 and y_g < sky_g - 1.5:
			var col := Color(0.68, 0.64, 0.59, 1.0)
			for v in [a, c, b]:
				st_benches.set_color(col)
				st_benches.set_normal(n)
				st_benches.add_vertex(v)
			if fposmod(center.x * 3.7 + center.z * 5.3, 1.0) < 0.38:
				spawn_samples.append({"pos": center, "nrm": n, "zone": "bench", "toe": 0.5})
		else:
			_emit_rock_tri(st_rock, a, b, c)

	var n_seg_x := nx if is_closed_loop else (nx - 1)
	for ix in n_seg_x:
		var jx := (ix + 1) % nx
		var x_g := x_geo_arr[ix]
		var sky_g := sky_raw_arr[ix]
		var h_sc := spine_h_scales[ix]
		for iy in ny - 1:
			var y_g := (float(iy) + 0.5) / float(ny - 1) * sky_g
			var p00 := wall_verts[ix * ny + iy]
			var p10 := wall_verts[jx * ny + iy]
			var p11 := wall_verts[jx * ny + iy + 1]
			var p01 := wall_verts[ix * ny + iy + 1]
			if (ix + iy) % 2 == 0:
				emit_spine_tri.call(p00, p10, p11, x_g, y_g, sky_g, h_sc)
				emit_spine_tri.call(p00, p11, p01, x_g, y_g, sky_g, h_sc)
			else:
				emit_spine_tri.call(p00, p10, p01, x_g, y_g, sky_g, h_sc)
				emit_spine_tri.call(p10, p11, p01, x_g, y_g, sky_g, h_sc)

		# Rim bevel strip connecting wall top to the karst caprock plateau
		var r0 := wall_verts[ix * ny + (ny - 1)]
		var r1 := wall_verts[jx * ny + (ny - 1)]
		var n0 := spine_nrms[ix]
		var n1 := spine_nrms[jx]
		var b0 := r0 + Vector3(-n0.x * 3.2, -0.32, -n0.y * 3.2)
		var b1 := r1 + Vector3(-n1.x * 3.2, -0.32, -n1.y * 3.2)
		_emit_rock_tri(st_rock, r0, r1, b1)
		_emit_rock_tri(st_rock, r0, b1, b0)

	# 2. Build the 32 m wide Cliff-Top Karst Caprock Pavement & Grike Plateau behind the rim,
	#    smoothing the rim baseline over the first 4 m behind the brow so deep master cleft notches
	#    heal naturally into the plateau without slicing streaks across the back-slope!
	var nz_plat := 18
	var plat_verts := PackedVector3Array()
	var plat_nrms := PackedVector3Array()
	var plat_cols := PackedColorArray()
	plat_verts.resize(nx * nz_plat)
	plat_nrms.resize(nx * nz_plat)
	plat_cols.resize(nx * nz_plat)

	var smooth_nrms := PackedVector2Array()
	var smooth_rim_xz := PackedVector2Array()
	var smooth_rim_y := PackedFloat32Array()
	smooth_nrms.resize(nx)
	smooth_rim_xz.resize(nx)
	smooth_rim_y.resize(nx)
	for ix in nx:
		var acc_n := Vector2.ZERO
		var acc_p := Vector2.ZERO
		var acc_y := 0.0
		var sum_w := 0.0
		for dx in range(-12, 13):
			var jx := posmod(ix + dx, nx) if is_closed_loop else clampi(ix + dx, 0, nx - 1)
			var w := exp(-pow(float(dx) / 6.0, 2.0))
			acc_n += spine_nrms[jx] * w
			var rv := wall_verts[jx * ny + (ny - 1)]
			acc_p += Vector2(rv.x, rv.z) * w
			acc_y += rv.y * w
			sum_w += w
		smooth_nrms[ix] = acc_n.normalized()
		smooth_rim_xz[ix] = acc_p / sum_w
		smooth_rim_y[ix] = acc_y / sum_w

	for ix in nx:
		var rim_v := wall_verts[ix * ny + (ny - 1)]
		var n2 := smooth_nrms[ix]
		var s_val := s_arr[ix]
		var h_sc := spine_h_scales[ix]
		var plat_depth := 32.0 * clampf(0.45 + 0.55 * h_sc, 0.45, 1.0)
		for iz in nz_plat:
			var u := float(iz) / float(nz_plat - 1)
			var d_back := u * plat_depth
			var u_heal := smoothstep(0.0, 0.22, u)
			var base_xz := Vector2(rim_v.x, rim_v.z).lerp(smooth_rim_xz[ix], u_heal)
			var base_y := lerpf(rim_v.y, smooth_rim_y[ix], u_heal)
			var p_xz := base_xz - n2 * d_back
			var grike_u := absf(fposmod(s_val * 0.26 + 0.35 * sin(d_back * 0.18), 1.0) - 0.5) * 2.0
			var grike_v := absf(fposmod(d_back * 0.32 + 0.25 * cos(s_val * 0.15), 1.0) - 0.5) * 2.0
			var grike_groove := -0.78 * h_sc * (1.0 - smoothstep(0.0, 0.16, minf(grike_u, grike_v))) * (1.0 - smoothstep(14.0, 26.0, d_back))
			var swell := (0.75 * sin(s_val * 0.06 + d_back * 0.08) + 0.38 * cos(s_val * 0.14 - d_back * 0.11)) * h_sc
			var back_slope := d_back * 0.08 * h_sc
			if h_sc < 0.42:
				back_slope = -base_y * smoothstep(0.35, 1.0, u)
			var y := maxf(-0.8, base_y - 0.20 * h_sc + back_slope + swell * smoothstep(0.0, 5.0, d_back) + grike_groove)
			plat_verts[ix * nz_plat + iz] = Vector3(p_xz.x, y, p_xz.y)
			var soil_blend := smoothstep(4.5, 16.0, d_back)
			var is_grike := 1.0 if minf(grike_u, grike_v) < 0.18 else 0.0
			plat_cols[ix * nz_plat + iz] = Color(0.74, 0.71, 0.67).lerp(Color(0.58, 0.55, 0.49), maxf(soil_blend, is_grike * 0.85))

	for ix in nx:
		var prev_x := posmod(ix - 1, nx) if is_closed_loop else maxi(ix - 1, 0)
		var next_x := posmod(ix + 1, nx) if is_closed_loop else mini(ix + 1, nx - 1)
		for iz in nz_plat:
			var dx := plat_verts[next_x * nz_plat + iz] - plat_verts[prev_x * nz_plat + iz]
			var dz_v := plat_verts[ix * nz_plat + maxi(iz - 1, 0)] - plat_verts[ix * nz_plat + mini(iz + 1, nz_plat - 1)]
			var n := dz_v.cross(dx).normalized()
			plat_nrms[ix * nz_plat + iz] = n if n.y >= 0.0 else -n
			if iz > 0 and iz < 10 and ix % 3 == 0 and iz % 2 == 0:
				spawn_samples.append({
					"pos": plat_verts[ix * nz_plat + iz],
					"nrm": plat_nrms[ix * nz_plat + iz],
					"zone": "rim",
					"toe": float(iz) / 10.0
				})

	for ix in n_seg_x:
		var jx := (ix + 1) % nx
		for iz in nz_plat - 1:
			var q0 := ix * nz_plat + iz
			var q1 := jx * nz_plat + iz
			var q2 := q1 + 1
			var q3 := q0 + 1
			for qi in [q0, q2, q1, q0, q3, q2]:
				st_benches.set_color(plat_cols[qi])
				st_benches.set_normal(plat_nrms[qi])
				st_benches.add_vertex(plat_verts[qi])

	# 3. Build Gullied Angle-of-Repose (27.5 deg) Base Talus Cones along `+spine_nrms`
	var nz_base := 40
	var h_apex_arr := PackedFloat32Array()
	var raw_d_wall := PackedFloat32Array()
	var d_start_arr := PackedFloat32Array()
	h_apex_arr.resize(nx)
	raw_d_wall.resize(nx)
	d_start_arr.resize(nx)
	var repose_tan := tan(deg_to_rad(27.5))

	for ix in nx:
		var x_g := x_geo_arr[ix]
		var h_sc := spine_h_scales[ix]
		var lobe_left := 5.4 * exp(-pow((x_g - (-30.0)) / 9.5, 2.0))
		var lobe_center := 6.8 * exp(-pow((x_g - (-1.0)) / 16.5, 2.0))
		var lobe_right_1 := 6.8 * exp(-pow((x_g - 19.5) / 9.5, 2.0))
		var lobe_right_2 := 9.8 * exp(-pow((x_g - 39.5) / 13.0, 2.0))
		var gully_mod := 0.72 * sin(x_g * 0.16 + 0.4) + 0.42 * cos(x_g * 0.37 - 0.7)
		var h_apex := maxf(0.8, (1.6 + lobe_left + lobe_center + lobe_right_1 + lobe_right_2 + gully_mod) * h_sc)
		h_apex_arr[ix] = h_apex

		var iy_apex := clampi(int((h_apex / maxf(2.0, sky_arr[ix])) * float(ny - 1)), 0, ny - 1)
		var min_d := wall_d[ix * ny + iy_apex]
		for dy in range(-2, 3):
			var jy := clampi(iy_apex + dy, 0, ny - 1)
			min_d = minf(min_d, wall_d[ix * ny + jy])
		raw_d_wall[ix] = min_d

	for ix in nx:
		var sum_d := 0.0
		var sum_w := 0.0
		for dx in range(-12, 13):
			var jx := posmod(ix + dx, nx) if is_closed_loop else clampi(ix + dx, 0, nx - 1)
			var w := exp(-pow(float(dx) / 6.5, 2.0))
			sum_d += raw_d_wall[jx] * w
			sum_w += w
		d_start_arr[ix] = (sum_d / sum_w) - 2.0

	var base_verts := PackedVector3Array()
	var base_nrms := PackedVector3Array()
	var base_cols := PackedColorArray()
	base_verts.resize(nx * nz_base)
	base_nrms.resize(nx * nz_base)
	base_cols.resize(nx * nz_base)

	for ix in nx:
		var s_val := s_arr[ix]
		var h_sc := spine_h_scales[ix]
		var h_apex := h_apex_arr[ix]
		var d_start := d_start_arr[ix]
		var d_max := lerpf(14.0, 36.0, clampf(h_sc, 0.0, 1.0))
		var p2 := spine_pts[ix]
		var n2 := spine_nrms[ix]
		for iz in nz_base:
			var u := float(iz) / float(nz_base - 1)
			var d := lerpf(d_start, d_max, u)
			var d_out := maxf(0.0, d - d_start)
			var fan_s := s_val / (1.0 + d_out * 0.02)
			var radial_ribs := (0.62 * sin(fan_s * 0.25 + 0.5) + 0.38 * cos(fan_s * 0.55 - 0.9)) * exp(-d_out * 0.045) * h_sc
			var raw_h := h_apex + radial_ribs - d_out * repose_tan
			var h_cone := 0.52 * log(1.0 + exp(minf(40.0, raw_h / 0.52)))
			var micro := (0.20 * sin(s_val * 0.22 + d * 0.28) + 0.14 * cos(s_val * 0.48 - d * 0.35)) * clampf(h_cone / 2.2, 0.2, 1.0)
			var valley_slope := -1.8 * smoothstep(10.0, d_max, d)
			var h := h_cone + micro + valley_slope
			var p_xz := p2 + n2 * d
			base_verts[ix * nz_base + iz] = Vector3(p_xz.x, h, p_xz.y)
			var c_val := 0.72 if h_cone > 0.4 else 0.66
			base_cols[ix * nz_base + iz] = Color(c_val, c_val * 0.96, c_val * 0.91, 1.0)

	for ix in nx:
		var prev_x := posmod(ix - 1, nx) if is_closed_loop else maxi(ix - 1, 0)
		var next_x := posmod(ix + 1, nx) if is_closed_loop else mini(ix + 1, nx - 1)
		for iz in nz_base:
			var dx := base_verts[next_x * nz_base + iz] - base_verts[prev_x * nz_base + iz]
			var dz_v := base_verts[ix * nz_base + mini(iz + 1, nz_base - 1)] - base_verts[ix * nz_base + maxi(iz - 1, 0)]
			var n := dz_v.cross(dx).normalized()
			base_nrms[ix * nz_base + iz] = n if n.y >= 0.0 else -n
			if iz > 2 and iz < nz_base - 2 and ix % 2 == 0 and iz % 2 == 0:
				var v := base_verts[ix * nz_base + iz]
				var wall_d_here := d_start_arr[ix] + 2.0
				var cur_d := (Vector2(v.x, v.z) - spine_pts[ix]).dot(spine_nrms[ix])
				if cur_d > wall_d_here - 0.2:
					var toe := clampf((cur_d - wall_d_here) / 20.0, 0.0, 1.0)
					spawn_samples.append({
						"pos": v,
						"nrm": base_nrms[ix * nz_base + iz],
						"zone": "base",
						"toe": toe,
						"x_geo": x_geo_arr[ix]
					})

	for ix in n_seg_x:
		var jx := (ix + 1) % nx
		for iz in nz_base - 1:
			var q0 := ix * nz_base + iz
			var q1 := jx * nz_base + iz
			var q2 := q1 + 1
			var q3 := q0 + 1
			for qi in [q0, q1, q2, q0, q2, q3]:
				st_talus.set_color(base_cols[qi])
				st_talus.set_normal(base_nrms[qi])
				st_talus.add_vertex(base_verts[qi])

	var bedrock_mi := MeshInstance3D.new()
	bedrock_mi.mesh = st_rock.commit()
	bedrock_mi.material_override = wall_mat
	holder.add_child(bedrock_mi)

	var benches_mi := MeshInstance3D.new()
	benches_mi.mesh = st_benches.commit()
	benches_mi.material_override = ground_mat
	holder.add_child(benches_mi)

	var talus_mi := MeshInstance3D.new()
	talus_mi.mesh = st_talus.commit()
	talus_mi.material_override = ground_mat
	holder.add_child(talus_mi)

	# 4. Spawn Zone-Specific 3D Sculpted Crags (Monoliths, Tall Fluted Pillars, Lower Piers, Stepped Crags)
	#    along the spine stations, respecting the open mid-cliff stony-earth benches!
	var step_accum := 0.0
	for ix in range(2, nx - 2):
		var ds := s_arr[ix] - s_arr[ix - 1]
		step_accum += ds
		var h_sc := spine_h_scales[ix]
		if h_sc < 0.14:
			continue
		var d_sc := clampf(0.42 + 0.58 * h_sc, 0.38, 1.05)
		var w_target := lerpf(3.4, 5.2, clampf(h_sc, 0.0, 1.0))
		if step_accum < w_target * 0.82:
			continue
		step_accum = 0.0

		var x_g := x_geo_arr[ix]
		var sky_g := sky_raw_arr[ix]
		var p2 := spine_pts[ix]
		var n2 := spine_nrms[ix]
		var yaw_base := atan2(n2.x, n2.y)

		var add_spine_crag := func(y0_g: float, y1_g: float, w_m: float, d_m: float, roll_deg: float, yaw_deg: float, pitch_deg: float, pull_out: float) -> void:
			var y0 := y0_g * h_sc
			var y1 := y1_g * h_sc
			var h_b := y1 - y0
			if h_b < 1.6:
				return
			var y_mid_g := 0.5 * (y0_g + y1_g)
			var y_mid := 0.5 * (y0 + y1)
			var d_surf := minf(_z_rock(x_g - w_m * 0.25, y_mid_g), _z_rock(x_g + w_m * 0.25, y_mid_g)) * d_sc
			var d_b := d_m * d_sc
			var d_center := d_surf - d_b * (0.48 - pull_out)
			var c_xz := p2 + n2 * d_center
			var basis := Basis.from_euler(Vector3(
				deg_to_rad(pitch_deg),
				yaw_base + deg_to_rad(yaw_deg),
				deg_to_rad(roll_deg)
			)).scaled(Vector3(w_m, h_b, d_b))
			var shape_i := rng.randi() % n_crag_shapes
			crag_xfs[shape_i].append(Transform3D(basis, Vector3(c_xz.x, y_mid, c_xz.y)))
			var c := Color(0.95, 0.95, 0.94).lerp(Color(0.89, 0.90, 0.93), rng.randf()) * rng.randf_range(0.94, 1.03)
			c.a = 1.0
			crag_cols[shape_i].append(c)

		var w_c := w_target * rng.randf_range(0.92, 1.18)
		if x_g < -29.0:
			# Left Stepped Crag Tiers (respecting the benches at y_g = 13.5..15.8 and 26.0..28.8)
			add_spine_crag.call(2.5, 13.2, w_c, 5.2, rng.randf_range(-6.0, 6.0), rng.randf_range(-14.0, 14.0), rng.randf_range(-4.0, 3.0), 0.16)
			add_spine_crag.call(16.0, 25.8, w_c, 5.0, rng.randf_range(-6.0, 6.0), rng.randf_range(-14.0, 14.0), rng.randf_range(-4.0, 3.0), 0.16)
			add_spine_crag.call(28.8, sky_g + 0.3, w_c, 4.6, rng.randf_range(-5.0, 5.0), rng.randf_range(-12.0, 12.0), rng.randf_range(-5.0, 2.0), 0.14)
		elif x_g < -7.5:
			# Leaning Monolith over basal cave + upper headwall above y_g = 22.8
			add_spine_crag.call(4.4, 19.6, w_c * 1.15, 6.4, rng.randf_range(-17.0, -10.0), rng.randf_range(-12.0, 12.0), rng.randf_range(-6.0, -2.0), 0.24)
			add_spine_crag.call(23.0, sky_g + 0.3, w_c, 4.8, rng.randf_range(-5.0, 5.0), rng.randf_range(-14.0, 14.0), rng.randf_range(-4.0, 3.0), 0.15)
		elif x_g < 20.5:
			# Lower Pier below the wide central bench (`y_g < 13.5`) + Recessed Upper Bay Crags (`y_g > 18.0`)
			add_spine_crag.call(2.2, 13.4, w_c * 1.05, 5.4, rng.randf_range(-5.0, 5.0), rng.randf_range(-14.0, 14.0), rng.randf_range(-3.0, 3.0), 0.18)
			add_spine_crag.call(18.0, 26.2, w_c * 1.05, 5.0, rng.randf_range(-5.0, 5.0), rng.randf_range(-14.0, 14.0), rng.randf_range(-4.0, 2.0), 0.14)
			add_spine_crag.call(25.8, sky_g + 0.3, w_c, 4.6, rng.randf_range(-4.0, 4.0), rng.randf_range(-12.0, 12.0), rng.randf_range(-4.0, 2.0), 0.14)
		else:
			# Right Fluted Headwall: Lower Pier (`y_g < 13.6`) + Tall Unbroken Vertical Pillars (`y_g = 17.5..sky_g`)
			add_spine_crag.call(2.2, 13.4, w_c, 5.2, rng.randf_range(-5.0, 5.0), rng.randf_range(-14.0, 14.0), rng.randf_range(-3.0, 3.0), 0.18)
			var mid_split := rng.randf_range(25.0, 27.5)
			add_spine_crag.call(17.5, mid_split + 0.6, w_c, 5.4, rng.randf_range(-2.5, 2.5), rng.randf_range(-14.0, 14.0), rng.randf_range(-3.0, 3.0), 0.20)
			add_spine_crag.call(mid_split - 0.5, sky_g + 0.3, w_c, 5.2, rng.randf_range(-2.5, 2.5), rng.randf_range(-14.0, 14.0), rng.randf_range(-3.0, 3.0), 0.20)

	# 5. Spawn Gravity-Sorted Rockfall Boulders & Rim Clint Slabs from `spawn_samples`
	var n_samples := spawn_samples.size()
	var n_boulder_draws := mini(2600, n_samples * 2)
	for i in n_boulder_draws:
		if n_samples == 0:
			break
		var s: Dictionary = spawn_samples[rng.randi() % n_samples]
		var pos: Vector3 = s.pos
		var nrm: Vector3 = s.nrm
		var zone := String(s.zone)
		var toe := float(s.toe)
		if zone == "base":
			var x_g := float(s.get("x_geo", 0.0))
			var center_fan := 1.65 * exp(-pow((x_g - (-1.5)) / 15.5, 2.0))
			var left_fan := 1.05 * exp(-pow((x_g - (-30.0)) / 10.5, 2.0))
			var right_flanks := 1.15 * exp(-pow((x_g - 28.0) / 8.5, 2.0)) + 1.05 * exp(-pow((x_g - 48.0) / 9.5, 2.0))
			var lobe_w := 0.26 + center_fan + left_fan + right_flanks
			if toe > 0.74:
				if rng.randf() < 0.82:
					continue
				var f_sz := rng.randf_range(0.55, 2.0)
				_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, pos, nrm, Vector3(f_sz * 1.2, f_sz * 0.42, f_sz * 0.95))
				continue
			if rng.randf() > lobe_w * 0.72:
				continue
			var size := lerpf(0.50, 2.45, clampf(toe * 1.25, 0.0, 1.0)) * rng.randf_range(0.50, 1.35)
			if rng.randf() < 0.14:
				size *= 1.50
			_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, pos, nrm, Vector3(size, size * rng.randf_range(0.42, 0.76), size * rng.randf_range(0.60, 1.05)))
		elif zone == "rim":
			if rng.randf() < 0.30:
				continue
			var w_slab := rng.randf_range(1.6, 4.0) * lerpf(1.0, 0.55, toe)
			var d_slab := rng.randf_range(1.2, 2.8) * lerpf(1.0, 0.60, toe)
			var h_slab := rng.randf_range(0.32, 0.68)
			_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, pos + Vector3(0.0, 0.06, 0.0), nrm, Vector3(w_slab, h_slab, d_slab))
		else:
			if rng.randf() < 0.50:
				continue
			var sz := rng.randf_range(0.45, 1.35)
			_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, pos, nrm, Vector3(sz * 1.15, sz * 0.42, sz * 0.85))

	return {
		"samples": spawn_samples,
		"plat_verts": plat_verts,
		"nx": nx,
		"nz_plat": nz_plat
	}


## Builds a 320 m × 320 m macro arena formation (`mode = 0..3`) with full geological erosion detail
## (`_build_eroded_cliff_along_spine`), multi-tier stony-earth benches, gullied talus cones, 3D sculpted
## crags, gravity-sorted boulder fans, and ecologically rooted pines & shrubs:
##   - `mode = 0` (**Crescent Amphitheatre / Cirque**): High 36 m sunlit eroded escarpment wrapping 230 deg
##     around an irregular embayed cirque (`promontory headlands + recessed bays`), tapering smoothly at both
##     southern arms into open heathland.
##   - `mode = 1` (**Box Gorge / Fault-Guided Defile**): Two opposing full-detail eroded escarpments (`36 m`
##     sunlit NE wall and `28 m` shadow-casting SW wall) with fault-stepped bays and coalescing talus cones.
##   - `mode = 2` (**Karst Sinkhole / Collapsed Dolina**): A 360 deg scalloped collapse dolina (`28..38 m`
##     eroded walls) enclosing the sunken pinewood, breached by a collapsed ramp saddle on the south-west.
##   - `mode = 3` (**Stepped Karst Bench & Internal Outcrop Spurs**): A 36 m rear eroded escarpment plus two
##     full-detail internal eroded karst outcrop spurs (`11 m` and `8.5 m` high) jutting into the clearing!
func _build_macro_formation(mode: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = "MacroFormation_%d" % mode
	var rng := RandomNumberGenerator.new()
	rng.seed = 701 + mode * 37

	var eb: Node3D = EDGE_BUILDER_SCRIPT.new()
	var wall_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 13.0, Color(1.08, 1.09, 1.13), 0.55, false)
	wall_mat.set_shader_parameter("scan_normal_depth", 0.42)
	wall_mat.set_shader_parameter("fracture", 0.16)
	wall_mat.set_shader_parameter("fracture_size", 3.8)
	wall_mat.set_shader_parameter("veg_amount", 0.14)

	var ground_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 11.0, Color(1.02, 1.03, 1.07), 0.35, true)
	ground_mat.set_shader_parameter("ground_tint", Color(0.43, 0.47, 0.42))
	ground_mat.set_shader_parameter("rubble_tint", Color(0.75, 0.77, 0.82))
	ground_mat.set_shader_parameter("scree_top", 46.0)
	ground_mat.set_shader_parameter("veg_amount", 0.30)

	var boulder_mat: ShaderMaterial = eb.call("_rock_mat_instanced")
	boulder_mat.set_shader_parameter("scan_tint", Color(1.02, 1.04, 1.09))
	boulder_mat.set_shader_parameter("scan_normal_depth", 0.48)
	boulder_mat.set_shader_parameter("fracture", 0.20)
	boulder_mat.set_shader_parameter("fracture_size", 1.8)
	boulder_mat.set_shader_parameter("veg_amount", 0.08)

	var pine_mesh: ArrayMesh = eb.call("_pine_mesh")
	var rock_pine_mesh: ArrayMesh = eb.call("_rock_pine_mesh")
	var shrub_mesh := _build_shrub_mesh()

	var n_crag_shapes := 12
	var crag_shapes := []
	var crag_xfs := []
	var crag_cols := []
	for k in n_crag_shapes:
		crag_shapes.append(_sculpted_crag_mesh(k))
		crag_xfs.append([])
		crag_cols.append([])

	var n_boulder_shapes := 8
	var b_shapes := []
	var b_xfs := []
	var b_cols := []
	for k in n_boulder_shapes:
		b_shapes.append(eb.call("_block_mesh", k))
		b_xfs.append([])
		b_cols.append([])
	eb.free()

	# 1. Build the undulating arena valley floor (`-175..+175 m` in X and Z, sitting at `y ~ -1.6 m`
	#    so the gullied talus toes from `_build_eroded_cliff_along_spine` merge seamlessly into the
	#    forested valley floor!)
	var n_grid := 112
	var half_span := 175.0
	var t_verts := PackedVector3Array()
	var t_nrms := PackedVector3Array()
	var t_cols := PackedColorArray()
	t_verts.resize(n_grid * n_grid)
	t_nrms.resize(n_grid * n_grid)
	t_cols.resize(n_grid * n_grid)

	for ix in n_grid:
		var x := lerpf(-half_span, half_span, float(ix) / float(n_grid - 1))
		for iz in n_grid:
			var z := lerpf(-half_span, half_span, float(iz) / float(n_grid - 1))
			var swell := 0.45 * sin(x * 0.045 + z * 0.038) + 0.28 * cos(x * 0.09 - z * 0.08)
			var y := -1.55 + swell
			if mode == 2:
				# Gentle sinkhole basin depression toward the center
				y -= 1.2 * (1.0 - clampf(Vector2(x, z).length() / 75.0, 0.0, 1.0))
			t_verts[ix * n_grid + iz] = Vector3(x, y, z)
			t_cols[ix * n_grid + iz] = Color(0.56, 0.58, 0.50, 1.0)

	for ix in n_grid:
		for iz in n_grid:
			var dx := t_verts[mini(ix + 1, n_grid - 1) * n_grid + iz] - t_verts[maxi(ix - 1, 0) * n_grid + iz]
			var dz_v := t_verts[ix * n_grid + mini(iz + 1, n_grid - 1)] - t_verts[ix * n_grid + maxi(iz - 1, 0)]
			var n := dz_v.cross(dx).normalized()
			t_nrms[ix * n_grid + iz] = n if n.y >= 0.0 else -n

	var st_terr := SurfaceTool.new()
	st_terr.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_grid_to_st(st_terr, t_verts, t_nrms, t_cols, n_grid, n_grid)
	var terr_mi := MeshInstance3D.new()
	terr_mi.mesh = st_terr.commit()
	terr_mi.material_override = ground_mat
	holder.add_child(terr_mi)

	# Helper to compute smooth unit normals along an open or closed 2D spine
	var compute_spine_normals := func(pts: PackedVector2Array, closed: bool, flip_sign: float) -> PackedVector2Array:
		var n_p := pts.size()
		var nrms := PackedVector2Array()
		nrms.resize(n_p)
		for i in n_p:
			var prev_i := posmod(i - 1, n_p) if closed else maxi(i - 1, 0)
			var next_i := posmod(i + 1, n_p) if closed else mini(i + 1, n_p - 1)
			var tang := (pts[next_i] - pts[prev_i]).normalized()
			nrms[i] = Vector2(-tang.y, tang.x) * flip_sign
		return nrms

	var spine_results := []

	if mode == 0:
		# Crescent Amphitheatre / Cirque (`230 deg` irregular embayed headwall wrapping North, East & West)
		var nx_arc := 340
		var pts := PackedVector2Array()
		var h_scs := PackedFloat32Array()
		pts.resize(nx_arc)
		h_scs.resize(nx_arc)
		for i in nx_arc:
			var u := float(i) / float(nx_arc - 1)
			var ang := lerpf(-2.05, 2.05, u) # 0 = North (-Z), +PI/2 = East (+X), -PI/2 = West (-X)
			var r_embay := (
				88.0
				+ 10.5 * sin(ang * 2.0 + 0.35)
				- 6.8 * cos(ang * 3.0 - 0.65)
				+ 3.6 * sin(ang * 5.0 + 1.1)
			)
			var radial := Vector2(sin(ang), -cos(ang))
			pts[i] = radial * r_embay
			var taper := smoothstep(0.0, 0.16, u) * (1.0 - smoothstep(0.84, 1.0, u))
			h_scs[i] = lerpf(0.14, 1.02, taper) * (0.92 + 0.12 * sin(ang * 3.0))
		var nrms: PackedVector2Array = compute_spine_normals.call(pts, false, 1.0)
		spine_results.append(_build_eroded_cliff_along_spine(
			holder, 77, pts, nrms, h_scs, false,
			crag_xfs, crag_cols, n_crag_shapes, b_xfs, b_cols, n_boulder_shapes, wall_mat, ground_mat
		))

	elif mode == 1:
		# Box Gorge / Fault-Guided Defile: Two opposing full-detail eroded escarpments (NE sunlit + SW shadow)
		var nx_wall := 240
		# 1) North-East Opposing Escarpment (`28 m` high, running North->South `z = -128..+128` so `Vector2(-tang.y, tang.x)` = `(-1, 0)` points West into the gorge!)
		var pts_ne := PackedVector2Array()
		var h_ne := PackedFloat32Array()
		pts_ne.resize(nx_wall)
		h_ne.resize(nx_wall)
		for i in nx_wall:
			var u := float(i) / float(nx_wall - 1)
			var z := lerpf(-128.0, 128.0, u)
			var pinch := -11.0 * exp(-pow((z + 8.0) / 48.0, 2.0))
			var embay := 8.5 * sin(z * 0.036 + 0.4) + 4.5 * cos(z * 0.078 - 0.6)
			var x := z * 0.24 + 62.0 + pinch + embay
			pts_ne[i] = Vector2(x, z)
			var taper := smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.86, 1.0, u))
			h_ne[i] = lerpf(0.18, 0.84, taper)
		var nrms_ne: PackedVector2Array = compute_spine_normals.call(pts_ne, false, 1.0)
		spine_results.append(_build_eroded_cliff_along_spine(
			holder, 193, pts_ne, nrms_ne, h_ne, false,
			crag_xfs, crag_cols, n_crag_shapes, b_xfs, b_cols, n_boulder_shapes, wall_mat, ground_mat
		))

		# 2) South-West Sunlit Escarpment (`36 m` high, running South->North `z = +128..-128` so `Vector2(-tang.y, tang.x)` = `(+1, 0)` points East into the gorge, catching the upper-left sun!)
		var pts_sw := PackedVector2Array()
		var h_sw := PackedFloat32Array()
		pts_sw.resize(nx_wall)
		h_sw.resize(nx_wall)
		for i in nx_wall:
			var u := float(i) / float(nx_wall - 1)
			var z := lerpf(128.0, -128.0, u)
			var pinch := 11.0 * exp(-pow((z - 12.0) / 52.0, 2.0))
			var embay := 7.8 * cos(z * 0.041 - 0.5) - 4.2 * sin(z * 0.082 + 0.9)
			var x := z * 0.24 - 62.0 + pinch + embay
			pts_sw[i] = Vector2(x, z)
			var taper := smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(0.86, 1.0, u))
			h_sw[i] = lerpf(0.16, 1.02, taper)
		var nrms_sw: PackedVector2Array = compute_spine_normals.call(pts_sw, false, 1.0)
		spine_results.append(_build_eroded_cliff_along_spine(
			holder, 77, pts_sw, nrms_sw, h_sw, false,
			crag_xfs, crag_cols, n_crag_shapes, b_xfs, b_cols, n_boulder_shapes, wall_mat, ground_mat
		))

	elif mode == 2:
		# Karst Sinkhole / Collapsed Dolina (`360 deg` closed scalloped rim with SW collapsed saddle breach)
		var nx_loop := 400
		var pts := PackedVector2Array()
		var h_scs := PackedFloat32Array()
		pts.resize(nx_loop)
		h_scs.resize(nx_loop)
		for i in nx_loop:
			var u := float(i) / float(nx_loop)
			var ang := -PI + u * TAU
			var r_scallop := (
				86.0
				+ 10.5 * sin(ang * 2.0 - 0.45)
				+ 7.2 * cos(ang * 3.0 + 0.8)
				- 4.6 * sin(ang * 5.0 - 0.3)
			)
			var radial := Vector2(sin(ang), -cos(ang))
			pts[i] = radial * r_scallop
			var breach := 1.0 - 0.78 * exp(-pow(wrapf(ang - (-2.35), -PI, PI) / 0.44, 2.0))
			h_scs[i] = breach * (0.92 + 0.12 * cos(ang * 2.0))
		var nrms: PackedVector2Array = compute_spine_normals.call(pts, true, 1.0)
		spine_results.append(_build_eroded_cliff_along_spine(
			holder, 131, pts, nrms, h_scs, true,
			crag_xfs, crag_cols, n_crag_shapes, b_xfs, b_cols, n_boulder_shapes, wall_mat, ground_mat
		))

	else:
		# Stepped Karst Bench & Internal Outcrop Spurs:
		#   1) Main 36 m rear eroded escarpment along the North/East (`180 deg` arc)
		var nx_main := 280
		var pts_m := PackedVector2Array()
		var h_m := PackedFloat32Array()
		pts_m.resize(nx_main)
		h_m.resize(nx_main)
		for i in nx_main:
			var u := float(i) / float(nx_main - 1)
			var ang := lerpf(-1.65, 1.65, u)
			var r_embay := 92.0 + 9.0 * sin(ang * 2.0 + 0.3) - 5.5 * cos(ang * 4.0 - 0.5)
			pts_m[i] = Vector2(sin(ang), -cos(ang)) * r_embay
			var taper := smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.85, 1.0, u))
			h_m[i] = lerpf(0.16, 1.0, taper)
		var nrms_m: PackedVector2Array = compute_spine_normals.call(pts_m, false, 1.0)
		spine_results.append(_build_eroded_cliff_along_spine(
			holder, 77, pts_m, nrms_m, h_m, false,
			crag_xfs, crag_cols, n_crag_shapes, b_xfs, b_cols, n_boulder_shapes, wall_mat, ground_mat
		))

		#   2) Internal Eroded Karst Spur A (`12 m` high, jutting into the NW clearing `x = -62..+4, z = -22..-8`)
		var nx_spur := 96
		var pts_s1 := PackedVector2Array()
		var h_s1 := PackedFloat32Array()
		pts_s1.resize(nx_spur)
		h_s1.resize(nx_spur)
		for i in nx_spur:
			var u := float(i) / float(nx_spur - 1)
			var x := lerpf(-62.0, 4.0, u)
			var z := -16.0 + 5.5 * sin(u * PI * 1.4) + u * 8.0
			pts_s1[i] = Vector2(x, z)
			var taper := smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.75, 1.0, u))
			h_s1[i] = lerpf(0.08, 0.35, taper)
		var nrms_s1: PackedVector2Array = compute_spine_normals.call(pts_s1, false, 1.0)
		spine_results.append(_build_eroded_cliff_along_spine(
			holder, 241, pts_s1, nrms_s1, h_s1, false,
			crag_xfs, crag_cols, n_crag_shapes, b_xfs, b_cols, n_boulder_shapes, wall_mat, ground_mat
		))

		#   3) Internal Eroded Karst Spur B (`9.5 m` high, jutting into the SE clearing `x = -4..+62, z = +10..+24`)
		var pts_s2 := PackedVector2Array()
		var h_s2 := PackedFloat32Array()
		pts_s2.resize(nx_spur)
		h_s2.resize(nx_spur)
		for i in nx_spur:
			var u := float(i) / float(nx_spur - 1)
			var x := lerpf(-4.0, 62.0, u)
			var z := 14.0 - 5.0 * sin(u * PI * 1.3) + u * 6.0
			pts_s2[i] = Vector2(x, z)
			var taper := smoothstep(0.0, 0.22, u) * (1.0 - smoothstep(0.78, 1.0, u))
			h_s2[i] = lerpf(0.08, 0.28, taper)
		var nrms_s2: PackedVector2Array = compute_spine_normals.call(pts_s2, false, 1.0)
		spine_results.append(_build_eroded_cliff_along_spine(
			holder, 317, pts_s2, nrms_s2, h_s2, false,
			crag_xfs, crag_cols, n_crag_shapes, b_xfs, b_cols, n_boulder_shapes, wall_mat, ground_mat
		))

	# 3. Populate Ecologically Rooted Pines & Shrubs (on the arena valley floor, inter-cone bays,
	#    mid-cliff stony-earth benches, and set-back karst plateau!)
	var pine_xfs := []
	var pine_cols := []
	var rock_pine_xfs := []
	var rock_pine_cols := []
	var shrub_xfs := []
	var shrub_cols := []

	for sr_val in spine_results:
		var sr: Dictionary = sr_val
		var sp_samples: Array = sr.samples
		var p_verts: PackedVector3Array = sr.plat_verts
		var nx_p: int = int(sr.nx)
		var nz_p: int = int(sr.nz_plat)

		for s_item in sp_samples:
			var s: Dictionary = s_item
			var pos: Vector3 = s.pos
			var nrm: Vector3 = s.nrm
			var z_name := String(s.zone)
			var toe := float(s.toe)
			if z_name == "bench" and nrm.y > 0.48:
				if rng.randf() < 0.08:
					var ph := rng.randf_range(6.2, 10.2)
					var basis := Basis.from_euler(Vector3(deg_to_rad(6.0), rng.randf() * TAU, 0.0)).scaled(Vector3(ph, ph, ph))
					rock_pine_xfs.append(Transform3D(basis, pos + Vector3(0.0, -0.30, 0.0)))
					rock_pine_cols.append(Color(0.80, 0.88, 0.75, 1.0) * rng.randf_range(0.90, 1.06))
				elif rng.randf() < 0.16:
					var w_s := rng.randf_range(1.3, 2.4)
					var h_s := rng.randf_range(0.9, 1.6)
					shrub_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w_s, h_s, w_s)), pos + Vector3(0.0, -0.14, 0.0)))
					shrub_cols.append(Color(0.85, 0.92, 0.78, 1.0) * rng.randf_range(0.88, 1.10))
			elif z_name == "base":
				if toe > 0.45 and pos.y < 3.2 and rng.randf() < 0.055:
					var ph := rng.randf_range(14.5, 20.0)
					pine_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ph, ph, ph)), pos + Vector3(0.0, -0.35, 0.0)))
					pine_cols.append(Color(0.82, 0.90, 0.78, 1.0) * rng.randf_range(0.88, 1.08))
				elif toe > 0.18 and toe < 0.65 and rng.randf() < 0.09:
					var w_s := rng.randf_range(1.2, 2.3)
					var h_s := rng.randf_range(0.85, 1.6)
					shrub_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w_s, h_s, w_s)), pos + Vector3(0.0, -0.16, 0.0)))
					shrub_cols.append(Color(0.86, 0.93, 0.80, 1.0) * rng.randf_range(0.88, 1.10))

		# Set-back cliff-top rock-pines on the karst plateau (`iz >= 6`)
		for i in 52:
			var ix := rng.randi_range(6, maxi(6, nx_p - 7))
			var iz := rng.randi_range(6, nz_p - 2)
			var pos := p_verts[ix * nz_p + iz]
			if pos.y < 12.0:
				continue
			var rph := rng.randf_range(6.5, 11.5)
			rock_pine_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rph, rph, rph)), pos + Vector3(0.0, -0.30, 0.0)))
			rock_pine_cols.append(Color(0.80, 0.88, 0.76, 1.0) * rng.randf_range(0.88, 1.08))

	# Additional central pinewood trees on the valley floor (`r = 18..56 m`, avoiding internal spurs in mode 3)
	for i in 120:
		var px := rng.randf_range(-56.0, 56.0)
		var pz := rng.randf_range(-56.0, 56.0)
		var r := Vector2(px, pz).length()
		if r < 16.0 or r > 56.0:
			continue
		if mode == 3 and ((px < 8.0 and absf(pz - (-14.0)) < 16.0) or (px > -8.0 and absf(pz - 16.0) < 16.0)):
			continue
		var py := -1.55 + 0.45 * sin(px * 0.045 + pz * 0.038) + 0.28 * cos(px * 0.09 - pz * 0.08)
		if mode == 2:
			py -= 1.2 * (1.0 - clampf(r / 75.0, 0.0, 1.0))
		var ph := rng.randf_range(15.0, 21.0)
		pine_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ph, ph, ph)), Vector3(px, py - 0.30, pz)))
		pine_cols.append(Color(0.82, 0.90, 0.78, 1.0) * rng.randf_range(0.88, 1.08))

	for k in n_crag_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = crag_shapes[k]
		var xfa: Array = crag_xfs[k]
		var cla: Array = crag_cols[k]
		mm.instance_count = xfa.size()
		for i in xfa.size():
			mm.set_instance_transform(i, xfa[i])
			mm.set_instance_color(i, cla[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = wall_mat
		holder.add_child(mmi)

	for k in n_boulder_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b_shapes[k]
		var xfa: Array = b_xfs[k]
		var cla: Array = b_cols[k]
		mm.instance_count = xfa.size()
		for i in xfa.size():
			mm.set_instance_transform(i, xfa[i])
			mm.set_instance_color(i, cla[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = boulder_mat
		holder.add_child(mmi)

	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.roughness = 0.92

	var add_veg_batch := func(mesh: ArrayMesh, xfs: Array, cols: Array) -> void:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, cols[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = pm
		holder.add_child(mmi)

	add_veg_batch.call(pine_mesh, pine_xfs, pine_cols)
	add_veg_batch.call(rock_pine_mesh, rock_pine_xfs, rock_pine_cols)
	add_veg_batch.call(shrub_mesh, shrub_xfs, shrub_cols)

	return holder


# --- Study 5: The Surrounding Karst Landscape & Ground-Protruding Rocks -----------------------

## Builds a side-by-side field guide (`x = -38 .. +38 m`) of the 4 natural ways rock protrudes
## from the ground around a karst limestone escarpment:
##   - Patch 0 (`xc = -27.5`): **Emergent Dip-Slope Rib ("Whaleback" / Cuesta Ledge)** — tilted
##     bedrock stratum (`13 deg` dip) whose back slope merges smoothly into turf/soil while its
##     down-slope brow breaks off in a sharp `1.8..2.6 m` fractured rock face with toe spall.
##   - Patch 1 (`xc = -9.2`): **Sub-Soil Karst Pavement Knoll (Flush Clints & Grike Fissures)** —
##     a slight ground rise where thin forest soil has washed away, exposing flat-topped limestone
##     clint tables (`0.3..0.75 m` above soil) separated by dark soil-filled solution grikes.
##   - Patch 2 (`xc = +9.2`): **Earth-Fast Founder Boulders (Half-Buried Ancient Erratics)** —
##     massive `2.5..4.2 m` blocks from ancient rockfalls sunken 45% into raised soil collars,
##     weathered grey with stony earth/moss caps on their upper facets.
##   - Patch 3 (`xc = +27.5`): **Dry Karst Wash Gully (Stepped Bedrock Banks + Cobble Bed)** —
##     a seasonal drainage channel cutting `1.9 m` into the forest floor, exposing horizontal
##     bedrock ledges in its cut-banks and a pale bed of water-sorted limestone cobbles.
func _build_protruding_rock_catalog() -> Node3D:
	var holder := Node3D.new()
	holder.name = "ProtrudingRockCatalog"
	var rng := RandomNumberGenerator.new()
	rng.seed = 909

	var eb: Node3D = EDGE_BUILDER_SCRIPT.new()
	var wall_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 13.0, Color(1.08, 1.09, 1.13), 0.55, false)
	wall_mat.set_shader_parameter("scan_normal_depth", 0.42)
	wall_mat.set_shader_parameter("fracture", 0.16)
	wall_mat.set_shader_parameter("fracture_size", 3.8)
	wall_mat.set_shader_parameter("veg_amount", 0.14)
	wall_mat.set_shader_parameter("scree_top", 2.8)

	var ground_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 11.0, Color(1.02, 1.03, 1.07), 0.35, true)
	ground_mat.set_shader_parameter("ground_tint", Color(0.45, 0.48, 0.54))
	ground_mat.set_shader_parameter("rubble_tint", Color(0.76, 0.78, 0.83))
	ground_mat.set_shader_parameter("scree_top", 25.0)
	ground_mat.set_shader_parameter("veg_amount", 0.28)

	var boulder_mat: ShaderMaterial = eb.call("_rock_mat_instanced")
	boulder_mat.set_shader_parameter("scan_tint", Color(1.02, 1.04, 1.09))
	boulder_mat.set_shader_parameter("scan_normal_depth", 0.48)
	boulder_mat.set_shader_parameter("fracture", 0.20)
	boulder_mat.set_shader_parameter("fracture_size", 1.8)
	boulder_mat.set_shader_parameter("veg_amount", 0.12)

	var pine_mesh: ArrayMesh = eb.call("_pine_mesh")
	var n_crag_shapes := 12
	var crag_shapes := []
	var crag_xfs := []
	var crag_cols := []
	for k in n_crag_shapes:
		crag_shapes.append(_sculpted_crag_mesh(k))
		crag_xfs.append([])
		crag_cols.append([])

	var n_boulder_shapes := 8
	var b_shapes := []
	var b_xfs := []
	var b_cols := []
	for k in n_boulder_shapes:
		b_shapes.append(eb.call("_block_mesh", k))
		b_xfs.append([])
		b_cols.append([])
	eb.free()

	var pine_xfs := []
	var pine_cols := []

	# Continuous 160x64 terrain carpet (`x = -38..+38`, `z = -14..+18`) sculpted for the 4 patches
	var nx := 160
	var nz := 64
	var t_verts := PackedVector3Array()
	var t_nrms := PackedVector3Array()
	var t_cols := PackedColorArray()
	t_verts.resize(nx * nz)
	t_nrms.resize(nx * nz)
	t_cols.resize(nx * nz)

	var patch_xs := [-27.5, -9.2, 9.2, 27.5]
	for ix in nx:
		var x := lerpf(-38.0, 38.0, float(ix) / float(nx - 1))
		for iz in nz:
			var z := lerpf(-14.0, 18.0, float(iz) / float(nz - 1))
			var y := 0.15 * sin(x * 0.18) * cos(z * 0.22)
			# Patch 0 (`xc = -27.5`): Dip-slope soil ramp rising from `z = -10` to `z = +1.2`, dropping at the scarp
			var dx0 := x - (-27.5)
			if absf(dx0) < 8.5:
				var env_x0 := 1.0 - smoothstep(5.0, 8.2, absf(dx0))
				if z < 1.8:
					var ramp := clampf((z - (-9.5)) / 11.3, 0.0, 1.0) * 2.35
					y += ramp * env_x0
				else:
					var apron := maxf(0.0, 0.95 * (1.0 - (z - 1.8) / 5.5))
					y += apron * env_x0
			# Patch 1 (`xc = -9.2`): Gentle karst knoll swell (`+1.0 m` dome)
			var dx1 := x - (-9.2)
			var r1 := Vector2(dx1, z - 1.0).length()
			if r1 < 8.5:
				y += 1.05 * exp(-pow(r1 / 5.5, 2.0))
			# Patch 2 (`xc = +9.2`): Raised earth collars ramped around 3 founder boulders
			var b_centers := [Vector2(7.6, -0.5), Vector2(11.2, 1.8), Vector2(8.8, 4.8)]
			var b_radii := [2.8, 2.3, 1.9]
			for bi in 3:
				var bc: Vector2 = b_centers[bi]
				var br: float = b_radii[bi]
				var d_b := Vector2(x - bc.x, z - bc.y).length()
				if d_b < br * 2.2:
					y += 1.15 * exp(-pow(d_b / (br * 1.15), 2.0))
			# Patch 3 (`xc = +27.5`): Winding dry karst wash gully (`-1.85 m` trough)
			var gully_x := 27.5 + 1.8 * sin(z * 0.28)
			var d_gully := absf(x - gully_x)
			if d_gully < 6.0:
				y -= 1.75 * exp(-pow(d_gully / 2.6, 2.0)) + 0.35 * exp(-pow(d_gully / 4.8, 2.0))
			t_verts[ix * nz + iz] = Vector3(x, y, z)
			t_cols[ix * nz + iz] = Color(0.68, 0.66, 0.60, 1.0)

	for ix in nx:
		for iz in nz:
			var dx := t_verts[mini(ix + 1, nx - 1) * nz + iz] - t_verts[maxi(ix - 1, 0) * nz + iz]
			var dz_v := t_verts[ix * nz + mini(iz + 1, nz - 1)] - t_verts[ix * nz + maxi(iz - 1, 0)]
			var n := dz_v.cross(dx).normalized()
			t_nrms[ix * nz + iz] = n if n.y >= 0.0 else -n

	var st_terr := SurfaceTool.new()
	st_terr.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(nx - 1):
		for iz in range(nz - 1):
			var i00 := ix * nz + iz
			var i10 := (ix + 1) * nz + iz
			var i01 := ix * nz + (iz + 1)
			var i11 := (ix + 1) * nz + (iz + 1)
			for idx in [i00, i10, i11, i00, i11, i01]:
				st_terr.set_color(t_cols[idx])
				st_terr.set_normal(t_nrms[idx])
				st_terr.add_vertex(t_verts[idx])
	var terr_mi := MeshInstance3D.new()
	terr_mi.mesh = st_terr.commit()
	terr_mi.material_override = ground_mat
	holder.add_child(terr_mi)

	# --- Populate Patch 0 (`xc = -27.5`): Emergent Dip-Slope Rib ("Whaleback" Cuesta Ledge) ---
	for si in 5:
		var u := float(si) / 4.0
		var x_b := lerpf(-33.0, -22.0, u)
		var env0 := 1.0 - 0.55 * pow(absf(u - 0.5) * 2.0, 2.0)
		var w_b := 2.9 * rng.randf_range(0.92, 1.12)
		var h_b := 2.4 * env0 * rng.randf_range(0.90, 1.08)
		var d_b := 5.2
		# Tilted backward (`-15 deg` pitch around X) so the back slope merges into the soil ramp
		# and the front face forms a crisp fractured karst step at `z ~ 1.8 m`!
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(-15.0 + rng.randf_range(-2.5, 2.5)),
			deg_to_rad(rng.randf_range(-8.0, 8.0)),
			deg_to_rad(rng.randf_range(-4.0, 4.0))
		)).scaled(Vector3(w_b, h_b, d_b))
		var shape_i := rng.randi() % n_crag_shapes
		crag_xfs[shape_i].append(Transform3D(basis, Vector3(x_b, 1.15 * env0, 0.4 + rng.randf_range(-0.3, 0.3))))
		crag_cols[shape_i].append(Color(0.94, 0.94, 0.93, 1.0))
	# Spalled cobbles along the foot of the dip-slope rib (`z = 2.2 .. 6.2`)
	for bi in 28:
		var bx := rng.randf_range(-33.5, -21.5)
		var bz := rng.randf_range(2.2, 6.8)
		var b_sz := rng.randf_range(0.35, 1.15)
		_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, Vector3(bx, 0.35, bz), Vector3.UP, Vector3(b_sz * 1.2, b_sz * 0.48, b_sz * 0.9))

	# --- Populate Patch 1 (`xc = -9.2`): Sub-Soil Karst Pavement Knoll (Clints & Grikes) ---
	for r_i in 4:
		for c_i in 5:
			var cx := -14.0 + float(c_i) * 2.40 + (0.65 if r_i % 2 == 1 else -0.35) + rng.randf_range(-0.35, 0.35)
			var cz := -2.6 + float(r_i) * 2.25 + rng.randf_range(-0.32, 0.32)
			var dist_k := Vector2(cx - (-9.2), cz - 1.0).length()
			if dist_k > 6.2:
				continue
			var y_k := 1.05 * exp(-pow(dist_k / 5.5, 2.0))
			var cw := rng.randf_range(1.75, 2.55)
			var cd := rng.randf_range(1.65, 2.35)
			var ch := rng.randf_range(0.50, 0.90)
			var basis := Basis.from_euler(Vector3(
				deg_to_rad(rng.randf_range(-5.0, 5.0)),
				deg_to_rad(rng.randf_range(-22.0, 22.0)),
				deg_to_rad(rng.randf_range(-5.0, 5.0))
			)).scaled(Vector3(cw, ch, cd))
			var shape_i := rng.randi() % n_crag_shapes
			crag_xfs[shape_i].append(Transform3D(basis, Vector3(cx, y_k + ch * 0.16, cz)))
			crag_cols[shape_i].append(Color(0.92, 0.92, 0.90, 1.0))

	# --- Populate Patch 2 (`xc = +9.2`): Earth-Fast Founder Boulders (Half-Buried Erratics) ---
	var f_pos := [Vector3(7.6, 0.85, -0.5), Vector3(11.2, 0.75, 1.8), Vector3(8.8, 0.65, 4.8)]
	var f_scale := [Vector3(3.8, 2.6, 3.2), Vector3(3.1, 2.2, 2.7), Vector3(2.5, 1.7, 2.2)]
	for fi in 3:
		var fp: Vector3 = f_pos[fi]
		var fs: Vector3 = f_scale[fi]
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(rng.randf_range(-10.0, 10.0)),
			deg_to_rad(rng.randf_range(-35.0, 35.0)),
			deg_to_rad(rng.randf_range(-8.0, 8.0))
		)).scaled(fs)
		var shape_i := rng.randi() % n_crag_shapes
		crag_xfs[shape_i].append(Transform3D(basis, fp))
		crag_cols[shape_i].append(Color(0.88, 0.89, 0.91, 1.0))
	for bi in 24:
		var ang_b := rng.randf() * TAU
		var rad_b := rng.randf_range(1.6, 5.2)
		var bx := 9.2 + cos(ang_b) * rad_b
		var bz := 1.8 + sin(ang_b) * rad_b
		var b_sz := rng.randf_range(0.40, 1.25)
		_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, Vector3(bx, 0.35, bz), Vector3.UP, Vector3(b_sz * 1.15, b_sz * 0.55, b_sz * 0.95))

	# --- Populate Patch 3 (`xc = +27.5`): Dry Karst Wash Gully (Stepped Banks + Cobble Bed) ---
	for zi in 7:
		var gz := lerpf(-6.5, 8.5, float(zi) / 6.0)
		var gx_center := 27.5 + 1.8 * sin(gz * 0.28)
		for side_v in [-1.0, 1.0]:
			var sgn := float(side_v)
			var bx := gx_center + sgn * rng.randf_range(2.3, 3.1)
			var basis := Basis.from_euler(Vector3(
				deg_to_rad(rng.randf_range(-3.0, 3.0)),
				deg_to_rad((-90.0 if sgn > 0.0 else 90.0) + rng.randf_range(-14.0, 14.0)),
				deg_to_rad(rng.randf_range(-4.0, 4.0))
			)).scaled(Vector3(2.6, 1.35, 2.4))
			var shape_i := rng.randi() % n_crag_shapes
			crag_xfs[shape_i].append(Transform3D(basis, Vector3(bx, -0.35, gz)))
			crag_cols[shape_i].append(Color(0.92, 0.92, 0.91, 1.0))
	for bi in 55:
		var gz := rng.randf_range(-8.0, 10.5)
		var gx := 27.5 + 1.8 * sin(gz * 0.28) + rng.randf_range(-1.8, 1.8)
		var b_sz := rng.randf_range(0.32, 0.95)
		_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, Vector3(gx, -1.35, gz), Vector3.UP, Vector3(b_sz * 1.25, b_sz * 0.42, b_sz * 1.05))

	# Add scale-reference Scots pines behind/beside each patch
	for pi in 4:
		var pxc: float = patch_xs[pi]
		for side_i in 2:
			var px := pxc + (-5.2 if side_i == 0 else 5.2)
			var pz := -7.5 + float(side_i) * 2.5
			var ph := rng.randf_range(13.5, 16.5)
			pine_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ph, ph, ph)), Vector3(px, 0.2, pz)))
			pine_cols.append(Color(0.86, 0.92, 0.82, 1.0))

	for k in n_crag_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = crag_shapes[k]
		var xfa: Array = crag_xfs[k]
		var cla: Array = crag_cols[k]
		mm.instance_count = xfa.size()
		for i in xfa.size():
			mm.set_instance_transform(i, xfa[i])
			mm.set_instance_color(i, cla[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = wall_mat
		holder.add_child(mmi)

	for k in n_boulder_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b_shapes[k]
		var xfa: Array = b_xfs[k]
		var cla: Array = b_cols[k]
		mm.instance_count = xfa.size()
		for i in xfa.size():
			mm.set_instance_transform(i, xfa[i])
			mm.set_instance_color(i, cla[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = boulder_mat
		holder.add_child(mmi)

	var p_mm := MultiMesh.new()
	p_mm.transform_format = MultiMesh.TRANSFORM_3D
	p_mm.use_colors = true
	p_mm.mesh = pine_mesh
	p_mm.instance_count = pine_xfs.size()
	for i in pine_xfs.size():
		p_mm.set_instance_transform(i, pine_xfs[i])
		p_mm.set_instance_color(i, pine_cols[i])
	var p_mmi := MultiMeshInstance3D.new()
	p_mmi.multimesh = p_mm
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.roughness = 0.92
	p_mmi.material_override = pm
	holder.add_child(p_mmi)

	return holder


## Builds an extended foreground karst landscape (`z = 22 .. 105 m`, `x = -75 .. +75 m`) in front
## of the main 35 m escarpment (`lab.node`), showing how protruding bedrock ribs, flush karst
## pavement knolls, earth-fast founder boulders, and a dry wash gully integrate with the pinewood.
func _build_surrounding_landscape_study() -> Node3D:
	var holder := Node3D.new()
	holder.name = "SurroundingLandscapeStudy"
	var rng := RandomNumberGenerator.new()
	rng.seed = 941

	var eb: Node3D = EDGE_BUILDER_SCRIPT.new()
	var wall_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 13.0, Color(1.08, 1.09, 1.13), 0.55, false)
	wall_mat.set_shader_parameter("scan_normal_depth", 0.42)
	wall_mat.set_shader_parameter("fracture", 0.16)
	wall_mat.set_shader_parameter("fracture_size", 3.8)
	wall_mat.set_shader_parameter("veg_amount", 0.14)
	wall_mat.set_shader_parameter("scree_top", 3.2)

	var ground_mat: ShaderMaterial = eb.call("_rock_mat", "marble_cliff_05", 11.0, Color(1.02, 1.03, 1.07), 0.35, true)
	ground_mat.set_shader_parameter("ground_tint", Color(0.45, 0.48, 0.54))
	ground_mat.set_shader_parameter("rubble_tint", Color(0.76, 0.78, 0.83))
	ground_mat.set_shader_parameter("scree_top", 25.0)
	ground_mat.set_shader_parameter("veg_amount", 0.28)

	var boulder_mat: ShaderMaterial = eb.call("_rock_mat_instanced")
	boulder_mat.set_shader_parameter("scan_tint", Color(1.02, 1.04, 1.09))
	boulder_mat.set_shader_parameter("scan_normal_depth", 0.48)
	boulder_mat.set_shader_parameter("fracture", 0.20)
	boulder_mat.set_shader_parameter("fracture_size", 1.8)
	boulder_mat.set_shader_parameter("veg_amount", 0.12)

	var pine_mesh: ArrayMesh = eb.call("_pine_mesh")
	var n_crag_shapes := 12
	var crag_shapes := []
	var crag_xfs := []
	var crag_cols := []
	for k in n_crag_shapes:
		crag_shapes.append(_sculpted_crag_mesh(k))
		crag_xfs.append([])
		crag_cols.append([])

	var n_boulder_shapes := 8
	var b_shapes := []
	var b_xfs := []
	var b_cols := []
	for k in n_boulder_shapes:
		b_shapes.append(eb.call("_block_mesh", k))
		b_xfs.append([])
		b_cols.append([])
	eb.free()

	var pine_xfs := []
	var pine_cols := []

	# 1. Foreground terrain carpet (`x = -75..+75 m`, `z = 22..105 m`)
	var nx := 120
	var nz := 84
	var t_verts := PackedVector3Array()
	var t_nrms := PackedVector3Array()
	var t_cols := PackedColorArray()
	t_verts.resize(nx * nz)
	t_nrms.resize(nx * nz)
	t_cols.resize(nx * nz)

	var surface_y := func(x: float, z: float) -> float:
		var y := -0.8 + 0.65 * sin(x * 0.055 + z * 0.045) + 0.35 * cos(x * 0.11 - z * 0.08)
		# Two diagonal emergent dip-slope ribs striking ENE across the clearing
		var u_rib1 := (z - 42.0) + x * 0.22
		if absf(x - (-18.0)) < 22.0 and u_rib1 > -11.0 and u_rib1 < 5.5:
			var env1 := 1.0 - smoothstep(14.0, 22.0, absf(x - (-18.0)))
			var profile1 := clampf((u_rib1 + 11.0) / 11.0, 0.0, 1.0) * 2.5 if u_rib1 <= 0.0 else maxf(0.0, 1.1 * (1.0 - u_rib1 / 5.5))
			y += profile1 * env1
		var u_rib2 := (z - 64.0) + x * 0.20
		if absf(x - 16.0) < 20.0 and u_rib2 > -10.0 and u_rib2 < 5.0:
			var env2 := 1.0 - smoothstep(12.0, 20.0, absf(x - 16.0))
			var profile2 := clampf((u_rib2 + 10.0) / 10.0, 0.0, 1.0) * 2.1 if u_rib2 <= 0.0 else maxf(0.0, 0.9 * (1.0 - u_rib2 / 5.0))
			y += profile2 * env2
		# Karst pavement knoll centered at `(x = -4.0, z = 56.0)`
		var d_knoll := Vector2(x - (-4.0), z - 56.0).length()
		if d_knoll < 12.0:
			y += 1.25 * exp(-pow(d_knoll / 7.5, 2.0))
		# Winding dry karst wash gully from the right-center cleft (`x ~ 16 -> +2`)
		var gx := 12.0 - (z - 22.0) * 0.14 + 3.2 * sin(z * 0.16)
		var dg := absf(x - gx)
		if dg < 6.5:
			y -= 1.45 * exp(-pow(dg / 2.8, 2.0))
		return y

	for ix in nx:
		var x := lerpf(-75.0, 75.0, float(ix) / float(nx - 1))
		for iz in nz:
			var z := lerpf(22.0, 105.0, float(iz) / float(nz - 1))
			t_verts[ix * nz + iz] = Vector3(x, surface_y.call(x, z), z)
			t_cols[ix * nz + iz] = Color(0.66, 0.65, 0.58, 1.0)

	for ix in nx:
		for iz in nz:
			var dx := t_verts[mini(ix + 1, nx - 1) * nz + iz] - t_verts[maxi(ix - 1, 0) * nz + iz]
			var dz_v := t_verts[ix * nz + mini(iz + 1, nz - 1)] - t_verts[ix * nz + maxi(iz - 1, 0)]
			var n := dz_v.cross(dx).normalized()
			t_nrms[ix * nz + iz] = n if n.y >= 0.0 else -n

	var st_terr := SurfaceTool.new()
	st_terr.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(nx - 1):
		for iz in range(nz - 1):
			var i00 := ix * nz + iz
			var i10 := (ix + 1) * nz + iz
			var i01 := ix * nz + (iz + 1)
			var i11 := (ix + 1) * nz + (iz + 1)
			for idx in [i00, i10, i11, i00, i11, i01]:
				st_terr.set_color(t_cols[idx])
				st_terr.set_normal(t_nrms[idx])
				st_terr.add_vertex(t_verts[idx])
	var terr_mi := MeshInstance3D.new()
	terr_mi.mesh = st_terr.commit()
	terr_mi.material_override = ground_mat
	holder.add_child(terr_mi)

	# 2. Populate Rib 1 (`x = -36..-2`, `z ~ 42 - x * 0.22`) & Rib 2 (`x = 0..32`, `z ~ 64 - x * 0.20`)
	for si in 9:
		var u := float(si) / 8.0
		var rx := lerpf(-34.0, -2.0, u)
		var rz := 42.0 - rx * 0.22
		var env := sin(u * PI)
		var ry: float = surface_y.call(rx, rz)
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(-15.0 + rng.randf_range(-2.5, 2.5)),
			deg_to_rad(12.0 + rng.randf_range(-6.0, 6.0)),
			deg_to_rad(rng.randf_range(-4.0, 4.0))
		)).scaled(Vector3(4.2, 1.4 + 1.4 * env, 5.2))
		var shape_i := rng.randi() % n_crag_shapes
		crag_xfs[shape_i].append(Transform3D(basis, Vector3(rx, ry + 0.35, rz - 1.2)))
		crag_cols[shape_i].append(Color(0.93, 0.93, 0.92, 1.0))

	for si in 8:
		var u := float(si) / 7.0
		var rx := lerpf(0.0, 30.0, u)
		var rz := 64.0 - rx * 0.20
		var env := sin(u * PI)
		var ry: float = surface_y.call(rx, rz)
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(-14.0 + rng.randf_range(-2.5, 2.5)),
			deg_to_rad(11.0 + rng.randf_range(-6.0, 6.0)),
			deg_to_rad(rng.randf_range(-4.0, 4.0))
		)).scaled(Vector3(4.2, 1.2 + 1.2 * env, 4.8))
		var shape_i := rng.randi() % n_crag_shapes
		crag_xfs[shape_i].append(Transform3D(basis, Vector3(rx, ry + 0.30, rz - 1.0)))
		crag_cols[shape_i].append(Color(0.93, 0.93, 0.91, 1.0))

	# 3. Populate the Sub-Soil Karst Pavement Knoll at `(x = -4.0, z = 56.0)`
	for r_i in 5:
		for c_i in 6:
			var cx := -10.5 + float(c_i) * 2.5 + rng.randf_range(-0.22, 0.22)
			var cz := 50.5 + float(r_i) * 2.4 + rng.randf_range(-0.22, 0.22)
			if Vector2(cx - (-4.0), cz - 56.0).length() > 7.5:
				continue
			var cy: float = surface_y.call(cx, cz)
			var ch := rng.randf_range(0.55, 0.95)
			var basis := Basis.from_euler(Vector3(
				deg_to_rad(rng.randf_range(-4.0, 4.0)),
				deg_to_rad(rng.randf_range(-14.0, 14.0)),
				deg_to_rad(rng.randf_range(-4.0, 4.0))
			)).scaled(Vector3(rng.randf_range(1.8, 2.3), ch, rng.randf_range(1.7, 2.2)))
			var shape_i := rng.randi() % n_crag_shapes
			crag_xfs[shape_i].append(Transform3D(basis, Vector3(cx, cy + ch * 0.24, cz)))
			crag_cols[shape_i].append(Color(0.92, 0.92, 0.90, 1.0))

	# 4. Populate Earth-Fast Founder Boulders & Dry Wash Gully Banks + Cobbles
	for fi in 18:
		var fx := rng.randf_range(-46.0, 44.0)
		var fz := rng.randf_range(30.0, 84.0)
		var fy: float = surface_y.call(fx, fz)
		var f_sz := rng.randf_range(1.8, 3.6)
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(rng.randf_range(-10.0, 10.0)),
			deg_to_rad(rng.randf_range(-45.0, 45.0)),
			deg_to_rad(rng.randf_range(-8.0, 8.0))
		)).scaled(Vector3(f_sz * 1.15, f_sz * 0.72, f_sz))
		var shape_i := rng.randi() % n_crag_shapes
		crag_xfs[shape_i].append(Transform3D(basis, Vector3(fx, fy + f_sz * 0.22, fz)))
		crag_cols[shape_i].append(Color(0.89, 0.90, 0.92, 1.0))

	for bi in 140:
		var gz := rng.randf_range(24.0, 92.0)
		var gx := 12.0 - (gz - 22.0) * 0.14 + 3.2 * sin(gz * 0.16) + rng.randf_range(-2.6, 2.6)
		var gy: float = surface_y.call(gx, gz)
		var b_sz := rng.randf_range(0.35, 1.25)
		_add_boulder_instance(rng, b_xfs, b_cols, n_boulder_shapes, Vector3(gx, gy + 0.12, gz), Vector3.UP, Vector3(b_sz * 1.2, b_sz * 0.45, b_sz))

	# 5. Populate Scots pines clustered along soil margins (leaving clearings over bare rock)
	for pi in 48:
		var px := rng.randf_range(-58.0, 58.0)
		var pz := rng.randf_range(28.0, 92.0)
		# Keep the central view corridor (`x = -16..+14`, `z = 46..78`) open so the ground rocks read clearly
		if px > -15.0 and px < 12.0 and pz > 46.0 and pz < 78.0:
			continue
		var py: float = surface_y.call(px, pz)
		var ph := rng.randf_range(15.0, 20.5)
		pine_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ph, ph, ph)), Vector3(px, py, pz)))
		pine_cols.append(Color(0.84, 0.91, 0.80, 1.0) * rng.randf_range(0.90, 1.08))

	for k in n_crag_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = crag_shapes[k]
		var xfa: Array = crag_xfs[k]
		var cla: Array = crag_cols[k]
		mm.instance_count = xfa.size()
		for i in xfa.size():
			mm.set_instance_transform(i, xfa[i])
			mm.set_instance_color(i, cla[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = wall_mat
		holder.add_child(mmi)

	for k in n_boulder_shapes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b_shapes[k]
		var xfa: Array = b_xfs[k]
		var cla: Array = b_cols[k]
		mm.instance_count = xfa.size()
		for i in xfa.size():
			mm.set_instance_transform(i, xfa[i])
			mm.set_instance_color(i, cla[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = boulder_mat
		holder.add_child(mmi)

	var p_mm := MultiMesh.new()
	p_mm.transform_format = MultiMesh.TRANSFORM_3D
	p_mm.use_colors = true
	p_mm.mesh = pine_mesh
	p_mm.instance_count = pine_xfs.size()
	for i in pine_xfs.size():
		p_mm.set_instance_transform(i, pine_xfs[i])
		p_mm.set_instance_color(i, pine_cols[i])
	var p_mmi := MultiMeshInstance3D.new()
	p_mmi.multimesh = p_mm
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.roughness = 0.92
	p_mmi.material_override = pm
	holder.add_child(p_mmi)

	return holder


# --- Study 6: Ecological Plant & Tree Distribution by Rooting Soil Depth -----------------------

## Applies a diagnostic shader across the cliff, crags, talus, and boulders that colors every
## surface by its **effective rooting soil depth & disturbance regime**:
##   - **Bone/Pale Grey (`soil < 2 cm`)**: Bare steep limestone facets (`n.y < 0.45`) and active
##     high-energy boulder chutes (`x ~ -1.5, +28, +48 m`) where rockfall strips saplings.
##   - **Ochre / Amber (`soil = 5..25 cm`)**: Horizontal softer marl parting seams (`y = 6.2, 11.8,
##     19.6, 25.4, 30.2 m`) and damp joint crevices — supports chasmophyte ferns, grasses & moss.
##   - **Olive / Sage (`soil = 25..75 cm`)**: Narrow rock ledges (`n.y > 0.55`), rim grike seams,
##     and stabilized outer talus slopes — supports woody shrubs, heather & prostrate juniper,
##     but too shallow (`< 0.8 m`) to anchor full trees against windthrow.
##   - **Deep Forest Green (`soil > 0.8..2.0 m`)**: Deep rooting pockets — the wide mid-cliff
##     structural bench (`y = 13.5..18.0 m`), deep cleft floors (`x ~ -7.5, +21.0 m`), plateau
##     soil set back `> 6 m` from the bare karst rim, and deep valley colluvium between/beyond
##     the active talus cones (the **only** zones where trees can anchor!).
func _apply_rooting_depth_diagnostic_materials(lab: Dictionary) -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform bool is_boulder = false;
varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float ny = clamp(w_nrm.y, 0.0, 1.0);
	// Active rockfall chute intensity (highest down the 3 main talus cone axes)
	float chute = (
		exp(-pow((w_pos.x - (-1.5)) / 9.5, 2.0)) +
		0.85 * exp(-pow((w_pos.x - 28.0) / 7.5, 2.0)) +
		0.80 * exp(-pow((w_pos.x - 48.0) / 8.0, 2.0)) +
		0.70 * exp(-pow((w_pos.x - (-30.0)) / 8.0, 2.0))
	) * smoothstep(21.0, 6.0, w_pos.z) * smoothstep(20.0, 1.0, w_pos.y);

	// Horizontal marl parting seams along the cliff wall (seepage & crevice fern lines)
	float seam_dist = min(
		min(abs(w_pos.y - 6.2), abs(w_pos.y - 11.8)),
		min(abs(w_pos.y - 19.8), min(abs(w_pos.y - 25.4), abs(w_pos.y - 30.2)))
	);
	float is_seam = (1.0 - smoothstep(0.15, 0.65, seam_dist)) * smoothstep(0.12, 0.48, ny) * (1.0 - smoothstep(8.0, 13.0, w_pos.z));

	// Deep rooting pockets (`soil > 0.8 m`):
	//   1) Wide mid-cliff structural bench (`y = 13.0 .. 18.2 m`, `ny > 0.62`)
	float mid_bench = smoothstep(0.58, 0.78, ny) * smoothstep(12.2, 13.8, w_pos.y) * (1.0 - smoothstep(17.5, 19.2, w_pos.y)) * smoothstep(1.5, 5.5, w_pos.z);
	//   2) Deep vertical master cleft pockets (`x ~ -7.5` and `x ~ 21.0`)
	float cleft_pocket = (exp(-pow((w_pos.x - (-7.5)) / 3.2, 2.0)) + exp(-pow((w_pos.x - 21.0) / 3.2, 2.0))) * smoothstep(0.42, 0.68, ny) * smoothstep(6.0, 24.0, w_pos.y);
	//   3) Cliff-top plateau set back behind the bare karst rim (`y > 29 m` and `z < -4.5 m`)
	float plateau_deep = smoothstep(0.65, 0.85, ny) * smoothstep(28.0, 31.5, w_pos.y) * smoothstep(-3.0, -7.5, w_pos.z);
	//   4) Deep valley colluvial soil beyond the active talus cones (`z > 18 m` or in inter-cone bays)
	float valley_deep = smoothstep(0.62, 0.82, ny) * (1.0 - smoothstep(5.5, 9.5, w_pos.y)) * smoothstep(11.0, 17.5, w_pos.z + (1.0 - chute) * 6.5);

	float deep_soil = clamp(max(max(mid_bench, cleft_pocket), max(plateau_deep, valley_deep)) * (1.0 - 0.85 * chute), 0.0, 1.0);
	float med_soil = clamp(smoothstep(0.48, 0.72, ny) * (1.0 - 0.65 * chute) * (1.0 - deep_soil), 0.0, 1.0);
	float shallow_seam = clamp(max(is_seam, smoothstep(0.32, 0.52, ny) * 0.65) * (1.0 - deep_soil - med_soil * 0.7), 0.0, 1.0);

	if (is_boulder) {
		deep_soil = 0.0;
		med_soil *= 0.25;
	}

	vec3 c_bare = vec3(0.46, 0.45, 0.43);      // Bone grey: bare rock / active boulder chute (<2 cm soil)
	vec3 c_seam = vec3(0.58, 0.38, 0.06);      // Ochre gold: crevice fern & grass parting seams (5..25 cm)
	vec3 c_shrub = vec3(0.24, 0.36, 0.11);     // Olive sage: narrow ledge & talus-fringe shrub zone (25..75 cm)
	vec3 c_tree = vec3(0.04, 0.17, 0.06);      // Deep forest green: deep tree-rooting soil pockets (>0.8..2.0 m)

	vec3 col = c_bare;
	col = mix(col, c_seam, shallow_seam);
	col = mix(col, c_shrub, med_soil);
	col = mix(col, c_tree, deep_soil);

	ALBEDO = col;
	ROUGHNESS = 0.88;
	SPECULAR = 0.12;
}
"""
	var mat_terrain := ShaderMaterial.new()
	mat_terrain.shader = sh
	mat_terrain.set_shader_parameter("is_boulder", false)

	var mat_boulder := ShaderMaterial.new()
	mat_boulder.shader = sh
	mat_boulder.set_shader_parameter("is_boulder", true)

	(lab.bedrock as MeshInstance3D).material_override = mat_terrain
	(lab.benches as MeshInstance3D).material_override = mat_terrain
	(lab.talus as MeshInstance3D).material_override = mat_terrain
	(lab.floor as MeshInstance3D).visible = false
	(lab.talus as MeshInstance3D).visible = true
	(lab.crags as Node3D).visible = true
	for child in (lab.crags as Node3D).get_children():
		if child is MultiMeshInstance3D:
			(child as MultiMeshInstance3D).material_override = mat_terrain
	(lab.boulders as Node3D).visible = true
	for child in (lab.boulders as Node3D).get_children():
		if child is MultiMeshInstance3D:
			(child as MultiMeshInstance3D).material_override = mat_boulder


## Builds a low spreading multi-lobe woody shrub mesh (`1.0..2.2 m` wide, `0.6..1.2 m` tall) whose
## basal root skirt extends down to `y = -0.36 m` below its origin so it buries solidly into sloped
## talus cones, mid-cliff benches, and rock ledges without ever floating!
func _build_shrub_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobes := [
		Vector4(0.0, 0.16, 0.0, 0.56),
		Vector4(-0.34, 0.10, 0.18, 0.44),
		Vector4(0.36, 0.12, -0.14, 0.46),
		Vector4(0.08, 0.09, 0.32, 0.40),
		Vector4(-0.18, 0.08, -0.28, 0.38)
	]
	var n_seg := 7
	for li in lobes.size():
		var lb: Vector4 = lobes[li]
		var center := Vector3(lb.x, lb.y, lb.z)
		var r := lb.w
		var h := r * 0.82
		var apex := center + Vector3(0.0, h, 0.0)
		var mid_c := Color(0.13, 0.22, 0.09, 1.0)
		var base_c := Color(0.07, 0.12, 0.05, 1.0)
		var top_c := Color(0.19, 0.30, 0.12, 1.0)
		for si in n_seg:
			var a0 := float(si) * TAU / float(n_seg)
			var a1 := float(si + 1) * TAU / float(n_seg)
			var p_mid0 := center + Vector3(cos(a0) * r, 0.0, sin(a0) * r * 0.90)
			var p_mid1 := center + Vector3(cos(a1) * r, 0.0, sin(a1) * r * 0.90)
			var p_bot0 := center + Vector3(cos(a0) * r * 0.82, -0.44, sin(a0) * r * 0.75)
			var p_bot1 := center + Vector3(cos(a1) * r * 0.82, -0.44, sin(a1) * r * 0.75)
			var nrm_top := (p_mid1 - apex).cross(p_mid0 - apex).normalized()
			_emit_tri_safe(st, apex, p_mid0, p_mid1, nrm_top, nrm_top, nrm_top, top_c, mid_c, mid_c, nrm_top)
			var nrm_skirt := (p_bot1 - p_mid0).cross(p_bot0 - p_mid0).normalized()
			_emit_tri_safe(st, p_mid0, p_bot0, p_bot1, nrm_skirt, nrm_skirt, nrm_skirt, mid_c, base_c, base_c, nrm_skirt)
			_emit_tri_safe(st, p_mid0, p_bot1, p_mid1, nrm_skirt, nrm_skirt, nrm_skirt, mid_c, base_c, mid_c, nrm_skirt)
	return st.commit()


## Builds a rosette / clump mesh of arching fronds (`0.4..0.8 m` across) whose root crown extends down
## to `y = -0.18 m` so chasmophyte ferns and sedges anchor directly into horizontal marl parting seams
## and damp vertical rock crevices without floating.
func _build_crevice_fern_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_fronds := 10
	var c_base := Color(0.09, 0.17, 0.06, 1.0)
	var c_mid := Color(0.16, 0.27, 0.10, 1.0)
	var c_tip := Color(0.23, 0.35, 0.13, 1.0)
	for fi in n_fronds:
		var ang := float(fi) * TAU / float(n_fronds) + 0.21 * float(fi % 3)
		var dir_xz := Vector2(cos(ang), sin(ang))
		var perp_xz := Vector2(-dir_xz.y, dir_xz.x)
		var p_root := Vector3(dir_xz.x * 0.03, -0.18, dir_xz.y * 0.03)
		var p_midL := Vector3(dir_xz.x * 0.26 + perp_xz.x * 0.09, 0.14, dir_xz.y * 0.26 + perp_xz.y * 0.09)
		var p_midR := Vector3(dir_xz.x * 0.26 - perp_xz.x * 0.09, 0.14, dir_xz.y * 0.26 - perp_xz.y * 0.09)
		var p_tip := Vector3(dir_xz.x * 0.50, -0.06, dir_xz.y * 0.50)
		var n1 := (p_midR - p_root).cross(p_midL - p_root).normalized()
		if n1.y < 0.0:
			n1 = -n1
		for v in [p_root, p_midL, p_midR, p_root, p_midR, p_midL]:
			st.set_color(c_base if v == p_root else c_mid)
			st.set_normal(n1)
			st.add_vertex(v)
		var n2 := (p_tip - p_midL).cross(p_midR - p_midL).normalized()
		if n2.y < 0.0:
			n2 = -n2
		for v in [p_midL, p_tip, p_midR, p_midL, p_midR, p_tip]:
			st.set_color(c_tip if v == p_tip else c_mid)
			st.set_normal(n2)
			st.add_vertex(v)
	return st.commit()


## Spawns the 4 ecological plant guilds across the 150 m escarpment (`lab`) strictly on the EXACT
## surface vertices of `lab.samples`, `lab.plat_verts`, and `_z_rock(x, y)` so no plant or ground-cover
## clump ever floats:
##   1) **Guild 1 — Crevice Ferns & Grasses** (`soil = 5..25 cm`): Embedded directly into the bedrock
##      surface `z = _z_rock(x, y)` along horizontal marl parting seams (`y = 6.2, 11.8, 19.8, 25.4, 30.2 m`).
##   2) **Guild 2 — Woody Ledge Shrubs & Dwarf Juniper** (`soil = 25..75 cm`): Rooted directly on
##      `zone == "bench"` ledges, `zone == "rim"` grike fissures, and stabilized `zone == "base"` talus
##      cone flanks.
##   3) **Guild 3 — Mid-Cliff Bench, Cleft & Set-Back Rim Pines** (`soil = 0.8..1.5 m`): Stunted
##      `6.5..12.5 m` rock-pines rooted **only** on the actual `zone == "bench"` triangles (`y ~ 14..18 m`),
##      deep master cleft pockets (`x ~ -7.5, +21.0 m`), and `lab.plat_verts` set back behind the bare
##      karst pavement clints (`iz >= 6`).
##   4) **Guild 4 — Tall Valley Scots Pines** (`soil > 1.5 m`): Full `15.5..21.5 m` forest pines
##      rooted directly on `zone == "base"` valley/inter-cone vertices where active rockfall is low!
func _build_ecological_vegetation_study(lab: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = "EcologicalVegetationStudy"
	var rng := RandomNumberGenerator.new()
	rng.seed = 1024

	var eb: Node3D = EDGE_BUILDER_SCRIPT.new()
	var valley_pine_mesh: ArrayMesh = eb.call("_pine_mesh")
	var rock_pine_mesh: ArrayMesh = eb.call("_rock_pine_mesh")
	eb.free()
	var shrub_mesh := _build_shrub_mesh()
	var fern_mesh := _build_crevice_fern_mesh()

	var v_pine_xfs := []
	var v_pine_cols := []
	var r_pine_xfs := []
	var r_pine_cols := []
	var shrub_xfs := []
	var shrub_cols := []
	var fern_xfs := []
	var fern_cols := []

	# Helper for active rockfall cone intensity at `(x, z)`
	var chute_at := func(x: float, z: float) -> float:
		return (
			exp(-pow((x - (-1.5)) / 9.5, 2.0)) +
			0.85 * exp(-pow((x - 28.0) / 7.5, 2.0)) +
			0.80 * exp(-pow((x - 48.0) / 8.0, 2.0)) +
			0.70 * exp(-pow((x - (-30.0)) / 8.0, 2.0))
		) * smoothstep(22.0, 6.0, z)

	var samples: Array = lab.samples
	var base_samples := []
	var bench_samples := []
	var rim_samples := []
	for s_val in samples:
		var s: Dictionary = s_val
		var z_name := String(s.zone)
		if z_name == "base":
			base_samples.append(s)
		elif z_name == "bench":
			bench_samples.append(s)
		elif z_name == "rim":
			rim_samples.append(s)

	# 1. Guild 4: Tall Valley Scots Pines (`14.0..19.5 m`) rooted directly on `base_samples` in the
	#    sheltered inter-cone soil bays (`x in [-58..-38], [-22..-13], [+9..+17], [+53..+66]`),
	#    parting cleanly around the bare active boulder cones so both the valley forest bays and
	#    the lower cliff / talus cones remain clearly visible!
	for i in 125:
		if base_samples.is_empty():
			break
		var s: Dictionary = base_samples[rng.randi() % base_samples.size()]
		var pos: Vector3 = s.pos
		var in_soil_bay := (
			(pos.x > -58.0 and pos.x < -38.0) or
			(pos.x > -22.5 and pos.x < -12.5) or
			(pos.x > 9.0 and pos.x < 17.5) or
			(pos.x > 53.0 and pos.x < 66.0)
		)
		var ch: float = chute_at.call(pos.x, pos.z)
		var min_z_allowed := (13.0 if in_soil_bay else 22.0) + ch * 12.0
		if pos.z < min_z_allowed or pos.y > 3.8 or absf(pos.x) > 68.0:
			continue
		if not in_soil_bay and rng.randf() < 0.68:
			continue
		var ph := rng.randf_range(13.5, 19.0) * lerpf(0.80, 1.04, clampf((pos.z - 12.0) / 16.0, 0.0, 1.0))
		var lean := Vector3(rng.randf_range(-0.04, 0.04), rng.randf() * TAU, rng.randf_range(-0.04, 0.04))
		# Sink trunk base `-0.35 m` into the exact talus/valley mesh vertex `pos` so it never floats!
		var root_pos := pos + Vector3(0.0, -0.35, 0.0)
		v_pine_xfs.append(Transform3D(Basis.from_euler(lean).scaled(Vector3(ph, ph, ph)), root_pos))
		v_pine_cols.append(Color(0.82, 0.90, 0.78, 1.0) * rng.randf_range(0.88, 1.08))

	# 2. Guild 3: Mid-Cliff Structural Bench Pines & Deep Cleft Pocket Pines (`6.2..10.8 m`)
	#    Rooted directly on actual `bench_samples` vertices (`y = 13.0..18.5 m`)!
	for i in 90:
		if bench_samples.is_empty():
			break
		var s: Dictionary = bench_samples[rng.randi() % bench_samples.size()]
		var pos: Vector3 = s.pos
		var nrm: Vector3 = s.nrm
		if nrm.y < 0.48 or pos.y > 23.0 or absf(pos.x) > 64.0:
			continue
		# Cluster preferentially in the wide central bench (`x = 1..15`), left bench (`x = -46..-16`),
		# and the two deep master cleft pockets (`x ~ -7.5` and `x ~ +20.5`)
		var in_pocket := (
			(pos.x > 1.0 and pos.x < 15.5 and pos.y < 18.0) or
			(pos.x > -46.0 and pos.x < -16.0 and pos.y < 17.5) or
			absf(pos.x - (-7.5)) < 3.5 or
			absf(pos.x - 20.5) < 3.5
		)
		if not in_pocket or rng.randf() < 0.52:
			continue
		var ph := rng.randf_range(6.2, 10.5)
		var basis := Basis.from_euler(Vector3(
			deg_to_rad(rng.randf_range(4.0, 10.0)),
			rng.randf() * TAU,
			deg_to_rad(rng.randf_range(-6.0, 6.0))
		)).scaled(Vector3(ph, ph, ph))
		r_pine_xfs.append(Transform3D(basis, pos + Vector3(0.0, -0.32, 0.0)))
		r_pine_cols.append(Color(0.80, 0.88, 0.75, 1.0) * rng.randf_range(0.90, 1.06))

	#    Plus cliff-top rock-pines set back behind the bare karst rim on the exact `plat_verts` mesh!
	var plat_verts: PackedVector3Array = lab.plat_verts
	var nx_p: int = int(lab.nx)
	var nz_p: int = int(lab.nz_plat)
	for i in 48:
		var ix := rng.randi_range(24, nx_p - 25)
		var iz := rng.randi_range(6, nz_p - 3) # `iz >= 6` sets trees back `> 6.5 m` behind the bare rim!
		var pos := plat_verts[ix * nz_p + iz]
		if pos.y < 14.0:
			continue
		var ph := rng.randf_range(6.5, 11.5) * clampf(pos.y / 32.0, 0.65, 1.0)
		r_pine_xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ph, ph, ph)), pos + Vector3(0.0, -0.30, 0.0)))
		r_pine_cols.append(Color(0.82, 0.90, 0.76, 1.0) * rng.randf_range(0.88, 1.08))

	# 3. Guild 2: Woody Ledge Shrubs & Prostrate Juniper (`1.1..2.4 m`) rooted directly on:
	#    (a) `bench_samples` (narrow and wide cliff shelves),
	#    (b) `rim_samples` (grike fissures between the limestone pavement clints), and
	#    (c) `base_samples` (stabilized flanks of the talus cones)!
	for i in 140:
		if bench_samples.is_empty():
			break
		var s: Dictionary = bench_samples[rng.randi() % bench_samples.size()]
		var pos: Vector3 = s.pos
		var nrm: Vector3 = s.nrm
		if nrm.y < 0.35 or absf(pos.x) > 68.0:
			continue
		var w_s := rng.randf_range(1.2, 2.4)
		var h_s := rng.randf_range(0.85, 1.65)
		var up_v := (nrm + Vector3(0.0, 1.2, 0.0)).normalized()
		var fwd_v := Vector3.BACK.rotated(Vector3.UP, rng.randf() * TAU)
		var rx_v := up_v.cross(fwd_v).normalized()
		var rz_v := rx_v.cross(up_v).normalized()
		var basis := Basis(rx_v * w_s, up_v * h_s, rz_v * w_s)
		shrub_xfs.append(Transform3D(basis, pos - up_v * 0.12))
		shrub_cols.append(Color(0.85, 0.92, 0.78, 1.0) * rng.randf_range(0.86, 1.12))

	for i in 65:
		if rim_samples.is_empty():
			break
		var s: Dictionary = rim_samples[rng.randi() % rim_samples.size()]
		var pos: Vector3 = s.pos
		var nrm: Vector3 = s.nrm
		if pos.y < 10.0 or absf(pos.x) > 68.0:
			continue
		var w_s := rng.randf_range(1.2, 2.4)
		var h_s := rng.randf_range(0.85, 1.65)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w_s, h_s, w_s))
		shrub_xfs.append(Transform3D(basis, pos + Vector3(0.0, -0.14, 0.0)))
		shrub_cols.append(Color(0.84, 0.90, 0.76, 1.0) * rng.randf_range(0.88, 1.10))

	for i in 160:
		if base_samples.is_empty():
			break
		var s: Dictionary = base_samples[rng.randi() % base_samples.size()]
		var pos: Vector3 = s.pos
		var nrm: Vector3 = s.nrm
		var toe := float(s.toe)
		var ch: float = chute_at.call(pos.x, pos.z)
		# Colonize the stabilized flanks of the talus cones (`0.12 < toe < 0.68`, avoiding raw active chute apex `ch > 0.65`)
		if toe < 0.12 or toe > 0.68 or ch > 0.65 or absf(pos.x) > 68.0:
			continue
		var w_s := rng.randf_range(1.15, 2.35)
		var h_s := rng.randf_range(0.85, 1.65)
		# Align shrub with the talus slope normal `nrm` and embed `-0.14 m` into the exact talus surface vertex `pos`!
		var up_v := (nrm + Vector3(0.0, 0.65, 0.0)).normalized()
		var fwd_v := Vector3.BACK.rotated(Vector3.UP, rng.randf() * TAU)
		var rx_v := up_v.cross(fwd_v).normalized()
		var rz_v := rx_v.cross(up_v).normalized()
		var basis := Basis(rx_v * w_s, up_v * h_s, rz_v * w_s)
		shrub_xfs.append(Transform3D(basis, pos - nrm * 0.14))
		shrub_cols.append(Color(0.86, 0.93, 0.80, 1.0) * rng.randf_range(0.86, 1.12))

	# 4. Guild 1: Chasmophyte Crevice Ferns & Grass Tufts (`0.4..0.95 m`) embedded directly into the
	#    exact bedrock surface `_z_rock(fx, fy)` along horizontal marl parting seams (`y = 6.2, 11.8, 19.8, 25.4, 30.2 m`)!
	var seam_ys := [6.2, 11.8, 19.8, 25.4, 30.2]
	for sy_val in seam_ys:
		var seam_y := float(sy_val)
		for fi in 56:
			var fx := rng.randf_range(-64.0, 64.0)
			var sky_y := _skyline_y(fx)
			var fy := seam_y + rng.randf_range(-0.25, 0.25)
			if fy > sky_y - 1.5 or fy < 3.5:
				continue
			# Evaluate the EXACT bedrock wall Z coordinate at `(fx, fy)` so the fern is rooted right inside the rock seam!
			var fz := _z_rock(fx, fy) - 0.05
			var f_sc := rng.randf_range(0.85, 1.65)
			var basis := Basis.from_euler(Vector3(
				deg_to_rad(rng.randf_range(16.0, 32.0)),
				rng.randf() * TAU,
				deg_to_rad(rng.randf_range(-10.0, 10.0))
			)).scaled(Vector3(f_sc, f_sc, f_sc))
			fern_xfs.append(Transform3D(basis, Vector3(fx, fy, fz)))
			fern_cols.append(Color(0.90, 0.96, 0.82, 1.0) * rng.randf_range(0.88, 1.12))

	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.roughness = 0.90

	var add_guild_mmi := func(mesh: ArrayMesh, xfs: Array, cols: Array) -> void:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, cols[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = pm
		holder.add_child(mmi)

	add_guild_mmi.call(valley_pine_mesh, v_pine_xfs, v_pine_cols)
	add_guild_mmi.call(rock_pine_mesh, r_pine_xfs, r_pine_cols)
	add_guild_mmi.call(shrub_mesh, shrub_xfs, shrub_cols)
	add_guild_mmi.call(fern_mesh, fern_xfs, fern_cols)

	return holder
