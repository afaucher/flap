extends TestCase
## A combat-AI duel plays out the same whatever ran before it in the process: the same duel, started once on an even
## physics tick and once on an odd one, flies the same paths to the bit. (The brains think every other tick; when
## which tick was the engine's global count, a test's outcome hung on how many ticks the tests before it took.)

const SECONDS := 6.0


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var prints := []
	var starts := []
	for k in 2:
		if k == 1 and posmod(Engine.get_physics_frames() - int(starts[0]), 2) == 0:
			await frames(1)   # (the second starts on the other parity)
		starts.append(Engine.get_physics_frames())
		prints.append(await _duel())
	check(posmod(int(starts[1]) - int(starts[0]), 2) == 1, "(the two start on ticks of opposite parity: %s)" % str(starts))
	print("fingerprints: ", prints)
	eq(prints[0], prints[1], "the duel flies the same, started on an even tick or an odd one")
	finish()


## A crow (seekers) hunting a sparrow (rockets), both combat AI, in the open; a hash of every bird's position each tick.
func _duel() -> int:
	var d := Duel.new()
	add_child(d)
	d.setup(ArenaLayout.new())
	await frames(1)
	d.add_ai("crow", 0, Vector3(0, 22, 20), Vector3.FORWARD, CombatSkill.preset("pilot"), 3)
	d.add_ai("sparrow", 1, Vector3(0, 22, 0), Vector3.FORWARD, CombatSkill.preset("pilot"), 9)
	for e in d.entries:
		(e.bird as Bird).rig.visible = false
	var fp := 0
	for f in int(SECONDS * 60.0):
		await d.step()
		for e in d.entries:
			fp = hash([fp, (e.bird as Bird).global_position])
	d.cleanup()
	d.queue_free()
	await frames(2)
	return fp
