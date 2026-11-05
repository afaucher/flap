class_name RaceRecord
extends RefCounted
## Race times, kept between runs in a ConfigFile (`path`, user://race_best.cfg), per course, bird and way of flying
## (key()): the best, with the splits that made it (the HUD's split deltas), and the last RECENT finishes (the HUD's
## average of the last AVERAGE_OF).

static var path := "user://race_best.cfg"
const RECENT := 10
const AVERAGE_OF := 3


static func key(course_seed: int, arena_seed: int, bird: String, flying: String) -> String:
	return "a%d_c%d_%s_%s" % [arena_seed, course_seed, bird, flying]


## {time, splits}, or {} if none yet.
static func best(k: String) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(path) != OK or not cf.has_section(k):
		return {}
	return {"time": float(cf.get_value(k, "time", INF)), "splits": cf.get_value(k, "splits", [])}


## A finish: kept among the recent ones, and as the best (with its splits) if it beats it. Returns whether it did.
static func offer(k: String, time: float, splits: Array) -> bool:
	if time == INF:
		return false
	var b := best(k)
	var cf := ConfigFile.new()
	cf.load(path)
	var r: Array = cf.get_value(k, "recent", [])
	r.append(time)
	cf.set_value(k, "recent", r.slice(maxi(0, r.size() - RECENT)))
	var beat := b.is_empty() or time < float(b.time)
	if beat:
		cf.set_value(k, "time", time)
		cf.set_value(k, "splits", splits)
	cf.save(path)
	return beat


## The last finishes, oldest first (at most RECENT).
static func recent(k: String) -> Array:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return []
	return cf.get_value(k, "recent", [])


## [the mean of the last AVERAGE_OF finishes (or as many as there are), how many] ([INF, 0]: none yet).
static func average(k: String) -> Array:
	var r := recent(k)
	var n := mini(AVERAGE_OF, r.size())
	if n == 0:
		return [INF, 0]
	var sum := 0.0
	for t in r.slice(r.size() - n):
		sum += float(t)
	return [sum / n, n]
