extends TestCase
## What a burst and a hit look like (CombatFx), as drawn and simulated:
##   - knocked-out feathers leave from where the rig drew them, as copies of those very cards (the rig's mesh and
##     material), fall far slower than a stone while slipping side to side, come to rest on the ground, and go;
##   - a puff of down, gone in about a second;
##   - a burst lights its surroundings at once and goes dark within LIGHT_TIME; a fizzle doesn't light; its smoke
##     swells to about the blast's reach (a seeker's more than a rocket's); its embers fall;
##   - the coverts over lost flight feathers stand up out of the wing, on either wing, and only there;
##   - a badly damaged bird sheds the odd covert in flight, a whole one doesn't.


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	var layout := ArenaLayout.lab()
	var world := CombatWorld.new()
	world.layout = layout
	add_child(world)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var a := Bird.new()
	add_child(a)
	a.setup(BirdProfile.crow(), layout, null)
	a.fly_from(Vector3(0, 4, 0), Vector3(0, 0, 1), 9.0)
	world.add_bird(a, null)
	cam.look_at_from_position(Vector3(6, 6, 0), Vector3(0, 4, 0))
	await frames(2)
	var fx := world.fx
	# Knocked out: copies of the drawn cards, from where they were drawn.
	var at := a.global_position + a.rig.global_basis.x.normalized() * 0.3
	var before := {}
	for n in a.rig.feather_keys.size():
		before[a.rig.feather_keys[n]] = a.rig.global_transform * a.rig.feather_xforms[n]
	var keys := a.lose_feathers(at, 3)
	var n0 := fx.loose.size()
	fx.knocked_out(a, at, keys, Vector3.RIGHT)
	eq(fx.loose.size() - n0, keys.size(), "each knocked-out feather comes away")
	var same_look := true
	var from_place := true
	for q in range(n0, fx.loose.size()):
		var f: Dictionary = fx.loose[q]
		var mi := (f.node as Node3D).get_child(0) as MultiMeshInstance3D
		var rig_mm := false
		for c in a.rig.get_children():
			if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).multimesh.mesh == mi.multimesh.mesh and (c as MultiMeshInstance3D).material_override == mi.material_override:
				rig_mm = true
		same_look = same_look and rig_mm
		var nearest := INF
		for key in keys:
			nearest = minf(nearest, (before[key] as Transform3D).origin.distance_to(f.pos))
		from_place = from_place and nearest < 0.03
	check(same_look, "the falling feathers are the rig's own cards (its mesh and material)")
	check(from_place, "and leave from where they were drawn")
	var start: Vector3 = fx.loose[n0].pos
	await frames(60)
	var f0: Dictionary = fx.loose[n0]
	var fell: float = start.y - (f0.pos as Vector3).y
	check(fell > 0.3 and fell < 2.5, "a feather falls slowly: %.2f m in 1 s (a stone: 4.9)" % fell)
	check(float(f0.path) > 0.1, "slipping side to side as it goes (%.2f m)" % float(f0.path))
	await frames(60 * 5)
	check(bool(f0.landed) and absf((f0.pos as Vector3).y - ArenaLayout.GROUND_Y) < 0.02, "and comes to rest on the ground")
	var rest: Vector3 = f0.pos
	await frames(10)
	check((f0.pos as Vector3).distance_to(rest) < 1e-4, "where it stays")
	await frames(int(CombatFx.FALL_LIFE * 60))
	check(not fx.loose.has(f0), "then it's gone")
	check(fx.down.is_empty(), "the down has blown away")
	# A burst: light at once, dark soon; a fizzle isn't lit.
	var far := Vector3(0, 20, 30)
	cam.look_at_from_position(far + Vector3(6, 0, 0), far)
	world._burst(far, null, "fuse", Projectile.Kind.ROCKET)
	await frames(2)
	var lit := 0.0
	for s in fx._lights:
		lit = maxf(lit, (s[0] as OmniLight3D).light_energy if (s[0] as OmniLight3D).visible else 0.0)
	check(lit > 1.0, "a burst lights what's round it (%.1f)" % lit)
	await frames(int(CombatFx.LIGHT_TIME * 60) + 3)
	var after := 0.0
	for s in fx._lights:
		after = maxf(after, (s[0] as OmniLight3D).light_energy if (s[0] as OmniLight3D).visible else 0.0)
	eq(after, 0.0, "and goes dark within %.2f s" % CombatFx.LIGHT_TIME)
	await frames(20)
	var rocket_smoke := _extent(fx._soft)
	check(rocket_smoke > CombatWorld.blast * 1.2 and rocket_smoke < CombatWorld.blast * 4.0, "its smoke swells to about the blast's reach (%.2f m across, reach %.1f)" % [rocket_smoke, CombatWorld.blast])
	var e_hi := _centre_y(fx._mesh)
	await frames(20)
	check(_centre_y(fx._mesh) < e_hi, "its embers fall")
	await frames(int(CombatFx.SMOKE_TIME * 60))
	world._burst(far, null, "fuse", Projectile.Kind.SEEKER)
	await frames(2 + int(CombatFx.LIGHT_TIME * 60) + 3 + 20)
	check(_extent(fx._soft) > rocket_smoke * 1.1, "a seeker's burst is bigger than a rocket's (%.2f m, a rocket's %.2f)" % [_extent(fx._soft), rocket_smoke])
	await frames(int(CombatFx.SMOKE_TIME * 60))
	world._burst(far, null, "expired", Projectile.Kind.ROCKET)
	await frames(2)
	var fizz := 0.0
	for s in fx._lights:
		fizz = maxf(fizz, (s[0] as OmniLight3D).light_energy if (s[0] as OmniLight3D).visible else 0.0)
	eq(fizz, 0.0, "a fizzle isn't lit")
	# Ruffled coverts, either wing, only over the gap.
	a.mend()
	a.rig.lost = a.lost_feathers
	a.rig.apply_pose()
	for side in [-1, 1]:
		var whole := _covert_dirs(a)
		var prim := BirdRig.feather_key(0 if side < 0 else 1, WingShape.Kind.PRIMARY, 6)
		a.lost_feathers = {prim: true}
		a.rig.lost = a.lost_feathers
		a.rig.apply_pose()   # (posed now: far off, the rig is posed only every few frames)
		var hurt := _covert_dirs(a)
		var over := BirdRig.feather_key(0 if side < 0 else 1, WingShape.Kind.GREATER_COVERT, 6, WingShape.Bone.HAND)
		var mirror := BirdRig.feather_key(1 if side < 0 else 0, WingShape.Kind.GREATER_COVERT, 6, WingShape.Bone.HAND)
		var moved := rad_to_deg((whole[over] as Vector3).angle_to(hurt[over]))
		var other := rad_to_deg((whole[mirror] as Vector3).angle_to(hurt[mirror]))
		check(moved > 8.0 and other < 1.0, "%s wing: the covert over a lost primary stands up (%.0f deg; the other wing's %.1f)" % ["left" if side < 0 else "right", moved, other])
		a.mend()
		a.rig.lost = a.lost_feathers
		a.rig.apply_pose()
	# Shedding: damaged, it sheds now and then; whole, it doesn't.
	a.fly_from(Vector3(0, 40, 0), Vector3(0, 0, 1), 9.0)
	var n1 := fx.loose.size()
	await frames(60 * 15)   # (long enough that a whole bird shedding as a damaged one does, 0.35 a second, would: 99.5%)
	eq(fx.loose.size(), n1, "a whole bird sheds nothing")
	for q in 5:
		a.lose_feathers(a.global_position, 1)
	n1 = fx.loose.size()
	await frames(60 * 15)
	check(fx.loose.size() > n1, "a badly damaged one sheds the odd covert (%d in 15 s)" % (fx.loose.size() - n1))
	a.queue_free()
	world.queue_free()
	finish()


## Greater coverts' drawn directions, by key (rig space).
func _covert_dirs(b: Bird) -> Dictionary:
	var out := {}
	for n in b.rig.feather_keys.size():
		var key := b.rig.feather_keys[n]
		if floori((key % 1000) / 100.0) == WingShape.Kind.GREATER_COVERT and key < 3000:
			out[key] = b.rig.feather_xforms[n].basis.z.normalized()
	return out


static func _extent(m: ImmediateMesh) -> float:
	var box := m.get_aabb()
	return maxf(box.size.x, maxf(box.size.y, box.size.z))


static func _centre_y(m: ImmediateMesh) -> float:
	return m.get_aabb().get_center().y
