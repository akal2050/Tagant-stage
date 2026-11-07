extends Node
## Autoload "Lex": every visitor-facing word, read from res://lexicon/lexicon.json (English + Arabic).
## Internal IDs (sounds, models, scenes) never change; only what is shown.

var L: Dictionary = {}
var analysis := false        # "See the sound": the full scientific view + measurements (off for the public)
signal view_changed


func _ready() -> void:
	var f := FileAccess.open("res://lexicon/lexicon.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			L = d
	if L.is_empty():
		push_error("lexicon.json missing or broken")


func _pick(entry, ar: bool) -> String:
	if entry is Dictionary:
		var s: String = entry.get("ar" if ar else "en", "")
		return s if s != "" else String(entry.get("en", ""))
	return ""


## A section's string: L[section][key] in the given language ("" if absent).
func get_text(section: String, key: String, ar: bool) -> String:
	var sec = L.get(section, {})
	if sec is Dictionary and sec.has(key):
		return _pick(sec[key], ar)
	return ""


## Interface word for a world ("circles" / "aitwadu"): its own override first, then the shared one.
func ui(key: String, world: String, ar: bool) -> String:
	var s := get_text("ui_" + world, key, ar)
	return s if s != "" else get_text("ui", key, ar)


func has_voice(id: String) -> bool:
	return L.get("voices", {}).has(id)


func voice(id: String, ar: bool) -> String:
	return _pick(L.get("voices", {}).get(id, {}), ar)


## "From the archive", "Synthesised voice", "Imagined voice" or "Borrowed voice" (+ a short note).
func origin(voice_id: String, body_name: String, own_first: bool, ar: bool) -> String:
	var v: Dictionary = L.get("voices", {}).get(voice_id, {})
	var src: String = v.get("source", "synth")
	if own_first and L.get("borrowed_voice_bodies", []).has(body_name):
		return "%s — %s" % [get_text("origin", "borrowed", ar), get_text("origin", "borrowed_note", ar)]
	var s := get_text("origin", src, ar)
	if src == "archive" and String(v.get("code", voice_id)) != voice_id:
		s += "  ·  " + String(v.get("code", voice_id))
	return s


func toggle_analysis() -> void:
	analysis = not analysis
	view_changed.emit()
