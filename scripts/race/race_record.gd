class_name RaceRecord
extends RefCounted
## Best race times, kept between runs in a ConfigFile (`path`, user://race_best.cfg): one per course, bird and way of
## flying (key()), with the splits that made it (the HUD's split deltas).

static var path := "user://race_best.cfg"


static func key(course_seed: int, arena_seed: int, bird: String, flying: String) -> String:
	return "a%d_c%d_%s_%s" % [arena_seed, course_seed, bird, flying]


## {time, splits}, or {} if none yet.
static func best(k: String) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(path) != OK or not cf.has_section(k):
		return {}
	return {"time": float(cf.get_value(k, "time", INF)), "splits": cf.get_value(k, "splits", [])}


## Keep `time` (and its splits) if it beats the best. Returns whether it did.
static func offer(k: String, time: float, splits: Array) -> bool:
	if time == INF:
		return false
	var b := best(k)
	if not b.is_empty() and float(b.time) <= time:
		return false
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value(k, "time", time)
	cf.set_value(k, "splits", splits)
	cf.save(path)
	return true
