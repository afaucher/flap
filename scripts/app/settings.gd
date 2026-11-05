class_name Settings
extends RefCounted
## The player's settings, kept between runs in `path` (user://settings.cfg): which way the mouse and the gamepad's
## stick pitch the bird. The menu's Settings screen sets them and saves; Boot loads them at start (not for a test
## run, which keeps the defaults); a PlayerController takes them when it's made.

static var path := "user://settings.cfg"
static var invert_mouse_y := false   ## false: the mouse toward you climbs (a flight stick's pull); true: the mouse up climbs
static var invert_pad_y := false     ## false: the stick back climbs; true: the stick forward climbs


## The saved settings, or the defaults for any not saved.
static func load_saved() -> void:
	var c := ConfigFile.new()
	var ok := c.load(path) == OK
	invert_mouse_y = ok and bool(c.get_value("controls", "invert_mouse_y", false))
	invert_pad_y = ok and bool(c.get_value("controls", "invert_pad_y", false))


static func save() -> void:
	var c := ConfigFile.new()
	c.set_value("controls", "invert_mouse_y", invert_mouse_y)
	c.set_value("controls", "invert_pad_y", invert_pad_y)
	var err := c.save(path)
	if err != OK:
		print("settings: couldn't save %s (error %d)" % [path, err])
