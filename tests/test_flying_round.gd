extends TestCase
## A rocket or a seeker in flight is drawn as the very round its pod carries: leaving the pod, as long as the one still
## in the pod beside it (measured on the drawn meshes: the farthest two vertices apart, times the drawn scale); once
## it's a few metres out, no more than CombatWorld.ROUND_GROW x that, so it still reads but never outgrows the bird.


func setup() -> void:
	var layout := ArenaLayout.new()
	var world := CombatWorld.new()
	world.layout = layout
	add_child(world)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.crow(), layout, ScriptedInput.new())
	b.fly_from(Vector3(0, 30, 0), Vector3.FORWARD, 10.0)
	var l := world.add_bird(b, null)
	var t := Tack.fit(b.rig, b, ["rockets", "seekers"])
	l.set_tack(t)
	await frames(2)
	for w in [Launcher.Weapon.ROCKETS, Launcher.Weapon.SEEKERS]:
		var name: String = Launcher.KIND_NAMES[w]
		var in_pod := _pod_round(t.saddle, name)
		check(in_pod > 0.0, "%s: one still in the pod (%.3f m)" % [name, in_pod])
		l.weapon = w
		var p := l.fire(world)
		await frames(1)
		await get_tree().process_frame
		var at_launch := _drawn(world, p)
		check(absf(at_launch / in_pod - 1.0) < 0.15, "%s: leaving the pod, drawn as long as the one in it (%.3f m, the pod's %.3f m)" % [name, at_launch, in_pod])
		var far := at_launch
		for i in 30:
			await frames(1)
			await get_tree().process_frame
			if not world.projectiles.has(p):
				break
			far = _drawn(world, p)
			if p.travelled > CombatWorld.GROW_OVER + 1.0:
				break
		check(far / in_pod > 1.5 and far / in_pod <= CombatWorld.ROUND_GROW + 0.05, "%s: further out, drawn bigger to read, but at most %.0fx (%.2fx)" % [name, CombatWorld.ROUND_GROW, far / in_pod])
		world.projectiles.erase(p)
	b.queue_free()
	world.queue_free()
	finish()


## The drawn length of projectile `p`'s body.
func _drawn(world: CombatWorld, p: Projectile) -> float:
	var i := world.projectiles.find(p)
	var mi: MeshInstance3D = world._bodies[i]
	return _extent(mi.mesh) * mi.global_basis.get_scale().y


## The length of a round of `kind` still in its pod (the first one: its mesh, in the saddle's space).
func _pod_round(s: Saddle, kind: String) -> float:
	for m in s.mounts:
		if m.kind == kind:
			for r in m.rounds:
				var mi := r as MeshInstance3D
				if mi != null and mi.visible:
					return _extent(mi.mesh) * mi.global_basis.get_scale().y
	return 0.0


## The farthest two vertices apart.
static func _extent(mesh: Mesh) -> float:
	var pts := PackedVector3Array()
	for si in mesh.get_surface_count():
		pts.append_array(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
	var best := 0.0
	var step := maxi(1, pts.size() / 400)
	for i in range(0, pts.size(), step):
		for j in range(i + 1, pts.size(), step):
			best = maxf(best, pts[i].distance_squared_to(pts[j]))
	return sqrt(best)
