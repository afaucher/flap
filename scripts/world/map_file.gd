class_name MapFile
extends RefCounted
## A map kept as data: an ArenaLayout written out whole (its trees and their limbs and solid branches, perches,
## outposts, openings, the floor's field, the air's thermals) and read back as it was, so a shipped map stays the same
## however the generator that first made it changes. A seed is only a map while the generator never changes; this
## file is the map. Pinewood.generate reads the baked map for a seed when there is one (Pinewood.baked);
## tools/bake_map.gd writes them.
##
## Every script variable is kept except those starting with "_" (caches and the spatial hashes, rebuilt on reading:
## ArenaLayout.rehash). A variable added later reads back as its default from an older file. The escarpment is not
## kept (it is on hold: added after reading, Pinewood.add_cliff).

const FORMAT := 1
const DIR := "res://maps"

## Each kept class by its tag in the file.
static func classes() -> Dictionary:
	return {
		"Layout": ArenaLayout, "Tree": ArenaLayout.TreeData, "Branch": ArenaLayout.BranchData, "Outpost": ArenaLayout.OutpostData,
		"Perch": Perch, "Floor": FloorField, "Air": AirField,
	}


static func path_for(name: String) -> String:
	return "%s/%s.map" % [DIR, name]


## Writes `a` to `path` (compressed). Returns OK or the error.
static func save(a: ArenaLayout, path: String, made_by := "") -> Error:
	assert(a.rock == null, "MapFile keeps no escarpment: bake with Pinewood.cliff off")
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return FileAccess.get_open_error()
	f.store_var({"format": FORMAT, "made_by": made_by, "layout": _encode(a)})
	f.close()
	return OK


## Reads the map at `path` (null if there is none or it can't be read).
static func read(path: String) -> ArenaLayout:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return null
	var d: Variant = f.get_var()
	f.close()
	if not d is Dictionary or int(d.get("format", 0)) != FORMAT:
		push_warning("MapFile: %s is not a map this build reads" % path)
		return null
	var a: ArenaLayout = _decode(d.layout)
	a.rehash()
	return a


static func _tag(o: Object) -> String:
	var s: Script = o.get_script()
	var cl := classes()
	for k in cl:
		if cl[k] == s:
			return k
	return ""


static func _encode(v: Variant) -> Variant:
	if v is Object:
		var tag := _tag(v)
		assert(tag != "", "MapFile can't keep a %s" % v)
		var out := {"@": tag}
		for p in (v as Object).get_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(p.name).begins_with("_"):
				out[p.name] = _encode((v as Object).get(p.name))
		return out
	if v is Array:
		var out := []
		for e in v:
			out.append(_encode(e))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _encode(v[k])
		return out
	return v


static func _decode(v: Variant) -> Variant:
	if v is Dictionary and v.has("@"):
		var o: Object = classes()[v["@"]].new()
		var have := {}
		for p in o.get_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				have[p.name] = true
		for k in v:
			if k == "@" or not have.has(k):
				continue
			var val: Variant = _decode(v[k])
			var cur: Variant = o.get(k)
			if cur is Array and val is Array:
				(cur as Array).clear()
				(cur as Array).assign(val)   # (keeps a typed array typed)
			elif typeof(val) == TYPE_NIL and cur is Object:
				pass
			else:
				o.set(k, val)
		return o
	if v is Array:
		var out := []
		for e in v:
			out.append(_decode(e))
		return out
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _decode(v[k])
		return out
	return v
