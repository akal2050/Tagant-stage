extends Control
## TAGANT / حداء خلان الريح — the opening text, then the two entrances.
## All words come from res://lexicon/lexicon.json (Lex). Only the world that is chosen is loaded
## (the iPad cannot hold both worlds at once); a truthful error appears if it fails.
## If the previous run stopped inside a world, a small red line on the opening says where (Diag).

const SALT := Color(0.94, 0.94, 0.91)
const RED := Color(0.95, 0.22, 0.12)
const SCENES := {"circles": "res://scenes/main.tscn", "aitwadu": "res://herding/scenes/main.tscn"}
const MIN_READ := 4.0        # seconds the text stays before the button can appear

var f_title: FontFile
var f_latin: FontFile
var f_arabic: FontFile
var page := "opening"
var t := 0.0
var loaded := {}
var failed := false
var pending := ""          # world being loaded after its card was tapped
var _wait_frames := 0
var w_status: Label
var diag_lbl: Label

var opening: VBoxContainer
var o_title: Label
var o_sub: Label
var o_body: Label
var o_question: Label
var o_func: Label
var o_status: Label
var enter_btn: Button
var lang_btn: Button
var worlds: VBoxContainer
var w_heading: Label
var cards := {}
var back_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f_arabic = load("res://fonts/Handjet.ttf")
	f_latin = load("res://fonts/Tektur.ttf")
	f_latin.fallbacks = [f_arabic]
	f_title = load("res://fonts/Megrim.ttf")
	f_title.fallbacks = [f_arabic]
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.01)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_opening()
	_build_worlds()
	lang_btn = _quiet_button(22)
	lang_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lang_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lang_btn.offset_right = -28
	lang_btn.offset_top = 18
	lang_btn.pressed.connect(_toggle_lang)
	add_child(lang_btn)
	diag_lbl = _label(f_latin, 15, 0.9)
	diag_lbl.add_theme_color_override("font_color", RED)
	diag_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	diag_lbl.offset_left = 30
	diag_lbl.offset_right = -30
	diag_lbl.offset_bottom = -8
	diag_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	diag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diag_lbl.text = Diag.previous_problem()
	add_child(diag_lbl)
	Diag.mark("opening")
	if Worlds.skip_opening:
		page = "worlds"
	_apply()


func _label(f: Font, size: int, alpha := 1.0) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(SALT, alpha))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _quiet_button(size: int) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(SALT, 0.8))
	b.add_theme_color_override("font_hover_color", RED)
	return b


func _frame(file: String) -> StyleBox:
	var s := StyleBoxTexture.new()
	s.texture = load("res://ui_frames/mix/%s.png" % file)
	s.set_texture_margin_all(32)
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	return s


func _build_opening() -> void:
	opening = VBoxContainer.new()
	opening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opening.offset_left = 120
	opening.offset_right = -120
	opening.offset_top = 40
	opening.offset_bottom = -30
	opening.alignment = BoxContainer.ALIGNMENT_CENTER
	opening.add_theme_constant_override("separation", 14)
	add_child(opening)
	o_title = _label(f_title, 64)
	opening.add_child(o_title)
	o_sub = _label(f_arabic, 40)
	opening.add_child(o_sub)
	o_body = _label(f_latin, 23, 0.9)
	o_body.custom_minimum_size = Vector2(0, 10)
	opening.add_child(o_body)
	o_question = _label(f_latin, 27)
	opening.add_child(o_question)
	enter_btn = Button.new()
	enter_btn.add_theme_stylebox_override("normal", _frame("button"))
	enter_btn.add_theme_stylebox_override("hover", _frame("button_hover"))
	enter_btn.add_theme_stylebox_override("pressed", _frame("button_pressed"))
	enter_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	enter_btn.add_theme_font_size_override("font_size", 28)
	enter_btn.add_theme_color_override("font_color", SALT)
	enter_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter_btn.custom_minimum_size = Vector2(320, 70)
	enter_btn.visible = false
	enter_btn.pressed.connect(_go_worlds)
	opening.add_child(enter_btn)
	o_status = _label(f_latin, 17, 0.5)
	opening.add_child(o_status)
	o_func = _label(f_latin, 16, 0.45)
	opening.add_child(o_func)


func _build_worlds() -> void:
	worlds = VBoxContainer.new()
	worlds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	worlds.alignment = BoxContainer.ALIGNMENT_CENTER
	worlds.add_theme_constant_override("separation", 40)
	worlds.visible = false
	add_child(worlds)
	w_heading = _label(f_title, 44)
	worlds.add_child(w_heading)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	worlds.add_child(row)
	for k in ["circles", "aitwadu"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(560, 300)
		b.add_theme_stylebox_override("normal", _frame("panel"))
		b.add_theme_stylebox_override("hover", _frame("button_hover"))
		b.add_theme_stylebox_override("pressed", _frame("button_pressed"))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_open.bind(k))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 30
		v.offset_right = -30
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 12)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var tl := _label(f_title, 36)
		var sl := _label(f_latin, 22, 0.85)
		var dl := _label(f_latin, 20, 0.75)
		for l in [tl, sl, dl]:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)
		row.add_child(b)
		cards[k] = [tl, sl, dl]
	w_status = _label(f_latin, 20, 0.6)
	worlds.add_child(w_status)
	back_btn = _quiet_button(20)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(func(): page = "opening"; _apply())
	worlds.add_child(back_btn)


func _ar() -> bool:
	return Worlds.lang == "ar"


func _apply() -> void:
	var ar := _ar()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if ar else Control.LAYOUT_DIRECTION_LTR
	var body_font := f_arabic if ar else f_latin
	opening.visible = page == "opening"
	worlds.visible = page == "worlds"
	o_title.text = Lex.get_text("opening", "title", ar)
	o_title.add_theme_font_override("font", f_arabic if ar else f_title)
	o_sub.text = Lex.get_text("opening", "subtitle", ar)
	var paras: Array = Lex.L.get("opening", {}).get("paragraphs", {}).get("ar" if ar else "en", [])
	o_body.text = "\n\n".join(PackedStringArray(paras))
	o_question.text = Lex.get_text("opening", "question", ar)
	o_func.text = Lex.get_text("opening", "functional", ar)
	enter_btn.text = Lex.get_text("opening", "enter", ar)
	for l in [o_body, o_question, o_func, o_status, w_status]:
		l.add_theme_font_override("font", body_font)
	o_body.add_theme_font_size_override("font_size", 27 if ar else 23)
	o_question.add_theme_font_size_override("font_size", 32 if ar else 27)
	enter_btn.add_theme_font_override("font", body_font)
	lang_btn.text = Lex.get_text("opening", "lang", ar)
	lang_btn.add_theme_font_override("font", f_latin if ar else f_arabic)
	w_heading.text = Lex.get_text("worlds", "heading", ar)
	w_heading.add_theme_font_override("font", f_arabic if ar else f_title)
	for k in cards:
		var c: Array = cards[k]
		c[0].text = String(Lex.L.worlds[k].title.get("ar" if ar else "en"))
		c[1].text = String(Lex.L.worlds[k].sub.get("ar" if ar else "en"))
		c[2].text = String(Lex.L.worlds[k].desc.get("ar" if ar else "en"))
		c[0].add_theme_font_override("font", f_arabic if ar else f_title)
		c[1].add_theme_font_override("font", body_font)
		c[2].add_theme_font_override("font", body_font)
		c[1].visible = c[1].text != ""
	back_btn.text = Lex.get_text("worlds", "back_opening", ar)
	back_btn.add_theme_font_override("font", body_font)
	_status()


func _status() -> void:
	var ar := _ar()
	if failed:
		o_status.text = Lex.get_text("opening", "load_error", ar)
		enter_btn.visible = false
		return
	var ready := t >= MIN_READ
	enter_btn.visible = ready
	o_status.text = "" if ready else Lex.get_text("opening", "loading", ar)


func _process(delta: float) -> void:
	t += delta
	if pending != "":
		# plain loading on the main thread (background loading stopped the app on the iPad);
		# wait a few frames so "loading…" is on screen first
		_wait_frames -= 1
		if _wait_frames <= 0:
			var k := pending
			pending = ""
			var ps = ResourceLoader.load(SCENES[k], "PackedScene")
			if ps is PackedScene:
				loaded[k] = ps
				Diag.mark("loaded " + k)
				Worlds.enter(k, ps)
				return
			Diag.mark("load failed " + k)
			w_status.text = Lex.get_text("opening", "load_error", _ar())
	if page == "opening":
		_status()


func _toggle_lang() -> void:
	Worlds.lang = "en" if _ar() else "ar"
	_apply()


func _go_worlds() -> void:
	page = "worlds"
	_apply()


func _open(k: String) -> void:
	if pending != "" or not SCENES.has(k):
		return
	Diag.mark("loading " + k)
	pending = k
	_wait_frames = 4
	w_status.text = Lex.get_text("opening", "loading", _ar())
