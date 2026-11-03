extends TestCase
## The chase camera swings round to a bird that faces the other way at once (it perched facing back the way it
## came, or respawned so): from looking exactly away, it turns to it smoothly, with no engine error (slerp between
## opposite directions has no axis).


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
	world.queue_free()
	finish()
