extends TestCase
## The rig is posed at most once per rendered frame, however many physics ticks the frame runs (Bird._physics_process):
## a frame catching up after a slow one runs several ticks but draws once, and posing on every tick multiplied the
## rig's cost by the catch-up ticks -- one slow frame made the next slower (20 birds: 290 ms frames, 8 ticks each).
## And frame by frame, it is posed every frame, for the time the frame's ticks covered.


func setup() -> void:
	var layout := ArenaLayout.generate(7)
	var b := Bird.new()
	add_child(b)
	b.setup(BirdProfile.by_id("crow"), layout, ScriptedInput.new())
	b.fly_from(Vector3(0, 30, 0), Vector3.FORWARD, 12.0)
	await frames(5)
	var n0 := b.rig.poses
	var dt := 1.0 / Engine.physics_ticks_per_second
	for k in 3:   # (three ticks inside this one rendered frame, as a frame catching up runs them)
		b._physics_process(dt)
	check(b.rig.poses - n0 <= 1, "three ticks in one frame pose the rig once (%d)" % (b.rig.poses - n0))
	var n1 := b.rig.poses
	await frames(10)
	check(b.rig.poses - n1 >= 9, "and every frame poses it (%d in 10 frames)" % (b.rig.poses - n1))
	finish()
