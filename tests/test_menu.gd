extends TestCase
## The start menu and what its choices open: the menu lists Flight, the two Fights and the Lab; Flight (its
## options in Boot.extra) is the game with no tack on any bird, and without them the riders are back; Fight
## carries one kind of round, six rockets or four seekers, with nothing to switch to.


const SHARDS := 2   ## (the menu and the game in one process, the range in another)


func _init() -> void:
	timeout_sec = 90.0


func setup() -> void:
	if in_shard(0):
		await _menu_and_flight()
	if in_shard(1):
		await _fights()
	Boot.extra = PackedStringArray()
	finish()


func _menu_and_flight() -> void:
	var menu: Menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await frames(2)
	var labels := []
	for c in Menu.CHOICES:
		labels.append(c[0])
	for want in ["Flight", "Fight: six rockets", "Fight: four seekers", "Lab"]:
		check(labels.has(want), "the menu offers " + want)
	eq(menu.find_children("Choice*", "Button", true, false).size(), Menu.CHOICES.size(), "a button per choice")
	menu.queue_free()

	for flight in [true, false]:
		Boot.extra = PackedStringArray(Menu.CHOICES[0][2] if flight else [])
		var game: Game = load("res://scenes/game.tscn").instantiate()
		add_child(game)
		await frames(3)
		var tacks := 0
		for b in game.ai_birds + [game.bird]:
			for c in (b as Bird).rig.get_children():
				tacks += int(c is Tack)
		if flight:
			eq(tacks, 0, "Flight: no rider or weapons on any bird")
		else:
			check(tacks >= 1, "the game's riders are there without Flight's options (%d)" % tacks)
		game.queue_free()
		await frames(2)


func _fights() -> void:
	for seekers in [false, true]:
		Boot.extra = PackedStringArray(Menu.CHOICES[2][2] if seekers else Menu.CHOICES[1][2])
		var r: Node = load("res://scenes/combat_range.tscn").instantiate()
		add_child(r)
		await frames(3)
		var l: Launcher = r.world.player
		var R := Launcher.Weapon.ROCKETS
		var S := Launcher.Weapon.SEEKERS
		var want := {R: 0, S: 4} if seekers else {R: 6, S: 0}
		check(int(l.capacity[R]) == want[R] and int(l.capacity[S]) == want[S], "Fight carries %s (%s)" % ["four seekers" if seekers else "six rockets", str(l.capacity)])
		eq(l.weapon, S if seekers else R, "with that weapon selected")
		var w := l.weapon
		l.controller = _Switch.new()
		await frames(2)
		eq(l.weapon, w, "and nothing to switch to")
		r.queue_free()
		await frames(2)


class _Switch:
	var done := false
	func sample(_l: Launcher, _dt: float) -> CombatInput:
		var first := not done
		done = true
		return CombatInput.new(false, false, first)
