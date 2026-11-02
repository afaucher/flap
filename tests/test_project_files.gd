extends TestCase
## The project's files: every script parses (not just the ones some test happens to load -- a parse error in an
## unloaded script, like a method clashing with Object's `_set`, would otherwise go unnoticed), and every text
## file is clean UTF-8: no byte-order mark, no mojibake from a round trip through a legacy code page (the design
## doc was once double-encoded that way).

const TEXT := ["gd", "md", "ps1", "tscn", "tres", "gdshader", "cfg", "godot", "html", "json"]
const SKIP_DIRS := ["test_logs", "build"]
## Mojibake signatures: UTF-8 bytes of common punctuation read as Windows-1252 and re-encoded.
var _mojibake := [String.chr(0xE2) + String.chr(0x20AC), String.chr(0xC3), String.chr(0xC2)]


func setup() -> void:
	var files: Array[String] = []
	_walk("res://", files)
	var scripts := 0
	var texts := 0
	for path in files:
		var ext := path.get_extension()
		if ext == "gd":
			scripts += 1
			check(load(path) is Script, "%s parses" % path)
		if ext in TEXT:
			texts += 1
			var bytes := FileAccess.get_file_as_bytes(path)
			check(not (bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF), "%s has no BOM" % path)
			var text := bytes.get_string_from_utf8()
			check(bytes.size() == 0 or text.length() > 0, "%s is valid UTF-8" % path)
			for sig in _mojibake:
				check(text.find(sig) < 0, "%s has no mojibake (%s)" % [path, sig.c_escape()])
	check(scripts > 30, "found the scripts (%d)" % scripts)
	check(texts > scripts, "found the text files (%d)" % texts)
	finish()


## Every file under `dir`, skipping hidden folders (.godot, .git, .claude) and generated output.
func _walk(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with(".") or sub in SKIP_DIRS:
			continue
		_walk(dir.path_join(sub), out)
