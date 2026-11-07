extends Node
## Autoload "Diag": breadcrumbs for the iPad. Every step (opening, loading a world, inside a world,
## with memory figures) is written to user://trail.txt as it happens. If the app dies, the next
## opening shows a small red line saying where it stopped and the last errors of Godot's log,
## so a photo of the opening is enough to know what happened.

const TRAIL := "user://trail.txt"
var prev: Array = []
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var old := FileAccess.get_file_as_string(TRAIL)
	for l in old.split("\n"):
		if l.strip_edges() != "":
			prev.append(l)
	var f := FileAccess.open(TRAIL, FileAccess.WRITE)
	if f:
		f.close()
	mark("launch")


func _mem() -> String:
	return "ram %d MB · video %d MB" % [OS.get_static_memory_usage() / 1048576,
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576]


func mark(what: String) -> void:
	var f := FileAccess.open(TRAIL, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(TRAIL, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%s | %s" % [what, _mem()])
	f.flush()
	f.close()


func _notification(n: int) -> void:
	if n == NOTIFICATION_APPLICATION_PAUSED or n == NOTIFICATION_WM_CLOSE_REQUEST:
		mark("paused")


func _process(delta: float) -> void:
	_t += delta
	if _t >= 5.0 and Worlds.current != "":
		_t = 0.0
		mark("in " + Worlds.current)


## "" if the last run ended normally; otherwise one or two short lines for the opening page.
func previous_problem() -> String:
	if prev.is_empty():
		return ""
	var last: String = prev[-1]
	if last.begins_with("paused") or last.begins_with("opening") or last.begins_with("launch"):
		return ""
	var txt := "Last time the app stopped:  " + last
	var errs := _log_errors()
	if errs != "":
		txt += "\n" + errs
	return txt


func _log_errors() -> String:
	var d := DirAccess.open("user://logs")
	if d == null:
		return ""
	var files := Array(d.get_files()).filter(func(f): return f.ends_with(".log") and f != "godot.log")
	if files.is_empty():
		return ""
	files.sort()
	var lines: Array = []
	for l in FileAccess.get_file_as_string("user://logs/" + files[-1]).split("\n"):
		if l.begins_with("ERROR") or l.begins_with("SCRIPT ERROR") or l.contains("CrashHandler") or l.contains("signal "):
			lines.append(l.substr(0, 110))
	return " | ".join(PackedStringArray(lines.slice(-3)))
