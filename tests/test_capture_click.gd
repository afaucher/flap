extends TestCase
## The click that captures the mouse doesn't fire (PlayerCombat): a left click while the mouse is free gives no shot,
## pressed or held; once it's released, a click with the mouse captured fires, and holding it holds the trigger.
## The F key fires as ever. In the range itself, the events delivered as the engine delivers them: a click with the
## mouse free fires nothing (headless the mouse never captures, so every click is a capturing one), while F, then,
## fires.


func _init() -> void:
	timeout_sec = 60.0


func setup() -> void:
	var pc := PlayerCombat.new()
	# The capturing click: pressed while the mouse is free.
	var got := await _click(pc, false)
	check(not got[0] and not got[1], "the click that captures the mouse doesn't fire (pressed %s, held %s)" % got)
	# Then a click with the mouse captured: it fires.
	PlayerCombat.assume_captured = true
	got = await _click(pc, true)
	PlayerCombat.assume_captured = false
	check(got[0] and got[1], "a click with the mouse captured fires (pressed %s, held %s)" % got)
	# The F key, mouse free or not.
	Input.action_press("fire")
	await get_tree().physics_frame
	var k := pc.sample(null, 1.0 / 60.0)
	check(k.fire_pressed, "F fires")
	Input.action_release("fire")
	await get_tree().physics_frame
	await _in_the_range()
	finish()


func _in_the_range() -> void:
	var r: Node = load("res://scenes/combat_range.tscn").instantiate()
	add_child(r)
	if not r.is_loaded:
		await r.loaded
	await frames(10)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var before := int(r.world.stats.shots)
	for i in 3:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		Input.parse_input_event(down)
		await frames(8)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		Input.parse_input_event(up)
		await frames(20)
	eq(int(r.world.stats.shots) - before, 0, "clicking to capture the mouse in the range fires nothing")
	before = int(r.world.stats.shots)
	var f := InputEventKey.new()
	f.keycode = KEY_F
	f.physical_keycode = KEY_F
	f.pressed = true
	Input.parse_input_event(f)
	await frames(8)
	f = f.duplicate()
	f.pressed = false
	Input.parse_input_event(f)
	await frames(20)
	check(int(r.world.stats.shots) - before >= 1, "while F, then, fires (%d)" % (int(r.world.stats.shots) - before))
	r.queue_free()
	await frames(2)


## A left click (`captured`: the mouse captured as it comes): [fire pressed, fire held] sampled while it's down.
func _click(pc: PlayerCombat, captured: bool) -> Array:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	PlayerCombat.handle_event(down, captured)
	Input.parse_input_event(down)
	await get_tree().physics_frame
	var a := pc.sample(null, 1.0 / 60.0)
	await get_tree().physics_frame
	var b := pc.sample(null, 1.0 / 60.0)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	PlayerCombat.handle_event(up, captured)
	Input.parse_input_event(up)
	await get_tree().physics_frame
	return [a.fire_pressed, a.fire_held or b.fire_held]
