extends CanvasLayer
## Autoload "Worlds": the language shared by the opening and the two worlds, and one quiet button
## ("Back to TAGANT", bottom right) inside a world. The worlds themselves are not rebuilt.

const START := "res://start/start.tscn"
var lang := "en"
var current := ""          # "", "circles" or "aitwadu"
var skip_opening := false  # coming back from a world: show the two entrances, not the whole opening
var back: Button


func _ready() -> void:
	layer = 100
	back = Button.new()
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	var f: FontFile = load("res://fonts/Tektur.ttf")
	f.fallbacks = [load("res://fonts/Handjet.ttf")]
	back.add_theme_font_override("font", f)
	back.add_theme_font_size_override("font_size", 19)
	back.add_theme_color_override("font_color", Color(0.94, 0.94, 0.91, 0.6))
	back.add_theme_color_override("font_hover_color", Color(0.95, 0.22, 0.12))
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	back.grow_vertical = Control.GROW_DIRECTION_BEGIN
	back.offset_right = -18
	back.offset_bottom = -10
	back.pressed.connect(go_start)
	add_child(back)
	_refresh()
	if OS.get_cmdline_user_args().has("--qa"):
		var q := Node.new()
		q.set_script(load("res://tools/qa_run.gd"))
		add_child(q)


func world_lang() -> String:
	if current == "circles":
		return Tr.lang
	if current == "aitwadu":
		return HTr.lang
	return lang


func enter(key: String, packed: PackedScene) -> void:
	# every entry starts the world fresh (the worlds keep their choices in static variables)
	Catalog.set_section("animals")
	Catalog.choice = {}
	HCatalog.set_section("aitwadu")
	HCatalog.choice = {}
	Lex.analysis = false      # every visitor starts in the simple view
	if key == "circles":
		Tr.lang = lang
	else:
		HTr.lang = lang
	current = key
	_refresh()
	AudioServer.bus_count = 1
	get_tree().change_scene_to_packed(packed)


func go_start() -> void:
	lang = world_lang()
	current = ""
	skip_opening = true
	_refresh()
	get_tree().change_scene_to_file(START)
	await get_tree().process_frame
	AudioServer.bus_count = 1


func _refresh() -> void:
	back.visible = current != ""
	back.text = Lex.get_text("ui", "back", world_lang() == "ar")


func _process(_d: float) -> void:
	if current != "":
		var tx := Lex.get_text("ui", "back", world_lang() == "ar")
		if back.text != tx:
			back.text = tx
