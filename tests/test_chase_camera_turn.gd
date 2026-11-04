extends TestCase
## The chase camera swings round to a bird that faces the other way at once (it perched facing back the way it
## came, or respawned so): from looking exactly away, it turns to it smoothly, with no engine error (slerp between
## opposite directions has no axis). And when it has all but caught up -- off by a hair (1e-20 or less) in height from a
## level look -- it settles onto it, with no engine error either (slerp's axis, from so small a cross product,
## isn't of unit length).


func setup() -> void:
	var layout := ArenaLayout.lab()
	var world := Node3D.new()
	add_child(world)
	var b := Bird.new()
	world.add_child(b)
	b.setup(BirdProfile.by_id("crow"), layout, ScriptedInput.new())
	b.perch_at(layout.perches[0])
	var cam := ChaseCamera.new()
	world.add_child(cam)
	cam.bird = b
	cam.snap()
	await frames(2)
	var want := cam._look_dir(b.telemetry())
	cam._look = -want   # (exactly away)
	await frames(90)
	check(cam._look.is_normalized() and cam._look.dot(want) > 0.9, "it has turned round to the bird (%.2f)" % cam._look.dot(want))
	b.look_pitch = 0.0
	await frames(2)
	want = cam._look_dir(b.telemetry())
	check(want.y == 0.0, "a level look (%s)" % want)
	for f in 24:   # (offsets from 1e-20 down to 1e-23: somewhere in there the cross product's length loses its precision)
		var hair := pow(10.0, -20.0 - f / 8.0)
		cam._look = Vector3(want.x, hair, want.z).normalized()
		cam._follow(1.0 / 60.0)
		check(cam._look.is_normalized() and cam._look.dot(want) > 0.9999, "a hair (%s) off a level look, it settles onto it (%s)" % [str(hair), cam._look])
	world.queue_free()
	finish()
