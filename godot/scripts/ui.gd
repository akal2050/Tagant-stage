extends Control
## Plain, touch-sized interface. Built in code so the layout stays readable and never overlaps:
## left = the singers, right = the four modes, bottom = lane + transport, top = what is happening.

const RED := Color(0.62, 0.04, 0.03)
const SALT := Color(0.94, 0.94, 0.91)

var main
var animal_buttons := {}
var section_buttons := {}
var strip: VBoxContainer
var mode_buttons := {}
var title: Label
var info: Label
var lane: Control
var bottom: PanelContainer
var play_btn: Button
var song_opt: OptionButton
var creature_opt: OptionButton
var _song_index_map: Array = []
var arrow_l: Button
var phrase_prev: Button
var phrase_next: Button
var lang_btn: Button
var style_btn: Button
var f_latin: FontFile       # Tektur (with Handjet as fallback for Arabic glyphs)
var f_title: FontFile       # Megrim
var f_arabic: FontFile      # Handjet
var arrow_r: Button
var arrow_name: Label
var score_lbl: Label
var fold_chk: CheckButton
var row_rehearse: HBoxContainer
var row_dialogue: HBoxContainer
var loop_chk: CheckButton
var speed_opt: OptionButton
var rec_btn: Button
var take_btn: Button
var phrase_lbl: Label
var dlg_btn: Button
var dlg_lbl: Label
var mic_lbl: Label
var origin_lbl: Label
var see_btn: Button
var _mode := "Listen"


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _load_fonts() -> void:
	f_arabic = load("res://fonts/Handjet.ttf")
	f_latin = load("res://fonts/Tektur.ttf")
	f_latin.fallbacks = [f_arabic]
	f_title = load("res://fonts/Megrim.ttf")
	f_title.fallbacks = [f_arabic]


## Interface frame family: "heptagram" (sigil corners), "arabesque" (vine scrolls), "signal" (instrument cuts),
## or "" for the old flat boxes. Textures live in res://ui_frames/<family>/ (made by tools/make_frames.py).
const FRAME := "mix"


func _frame(file: String, pad_x := 22, pad_y := 12) -> StyleBox:
	var t: Texture2D = load("res://ui_frames/%s/%s.png" % [FRAME, file])
	var s := StyleBoxTexture.new()
	s.texture = t
	s.set_texture_margin_all(32)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


const ARROW_W := 56.0


## A quiet text tab: no box, a thin red line under it when chosen.
func _tab() -> Button:
	var b := Button.new()
	var e := StyleBoxEmpty.new()
	e.content_margin_left = 4
	e.content_margin_right = 4
	e.content_margin_top = 6
	e.content_margin_bottom = 8
	var on := StyleBoxFlat.new()
	on.bg_color = Color(0, 0, 0, 0)
	on.border_color = Color(0.95, 0.22, 0.12)
	on.border_width_bottom = 2
	on.content_margin_left = 4
	on.content_margin_right = 4
	on.content_margin_top = 6
	on.content_margin_bottom = 8
	var hv := on.duplicate()
	hv.border_color = Color(SALT, 0.45)
	hv.border_width_bottom = 1
	b.add_theme_stylebox_override("normal", e)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(SALT, 0.78))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_pressed_color", Color(1, 1, 1))
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 0.7))
	return b


func _make_theme() -> Theme:
	if FRAME != "":
		return _make_frame_theme()
	var th := Theme.new()
	th.default_font = f_latin
	th.default_font_size = 21
	th.set_stylebox("normal", "Button", _box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.18)))
	th.set_stylebox("hover", "Button", _box(Color(0.12, 0.05, 0.04, 0.7), Color(1, 1, 1, 0.35)))
	th.set_stylebox("pressed", "Button", _box(RED, SALT))
	th.set_stylebox("hover_pressed", "Button", _box(RED, SALT))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("disabled", "Button", _box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.06)))
	th.set_color("font_color", "Button", SALT)
	th.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	th.set_color("font_hover_pressed_color", "Button", Color(1, 1, 1))
	th.set_stylebox("normal", "OptionButton", _box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.18)))
	th.set_stylebox("panel", "PanelContainer", _box(Color(0.02, 0.01, 0.01, 0.62), Color(1, 1, 1, 0.08)))
	th.set_color("font_color", "Label", SALT)
	th.set_color("font_outline_color", "Label", Color(0.08, 0.03, 0.02, 0.85))
	th.set_constant("outline_size", "Label", 6)
	th.set_color("font_outline_color", "Button", Color(0.08, 0.03, 0.02, 0.6))
	th.set_constant("outline_size", "Button", 3)
	return th


func _make_frame_theme() -> Theme:
	var th := Theme.new()
	th.default_font = f_latin
	th.default_font_size = 21
	th.set_stylebox("normal", "Button", _frame("button"))
	th.set_stylebox("hover", "Button", _frame("button_hover"))
	th.set_stylebox("pressed", "Button", _frame("button_pressed"))
	th.set_stylebox("hover_pressed", "Button", _frame("button_pressed"))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var dis := _frame("button")
	dis.modulate_color = Color(1, 1, 1, 0.4)
	th.set_stylebox("disabled", "Button", dis)
	th.set_color("font_color", "Button", SALT)
	th.set_color("font_hover_color", "Button", Color(1, 1, 1))
	th.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	th.set_color("font_hover_pressed_color", "Button", Color(1, 1, 1))
	th.set_stylebox("normal", "OptionButton", _frame("button"))
	th.set_stylebox("hover", "OptionButton", _frame("button_hover"))
	th.set_stylebox("pressed", "OptionButton", _frame("button_pressed"))
	th.set_stylebox("panel", "PanelContainer", _frame("panel", 30, 26))
	th.set_color("font_color", "Label", SALT)
	th.set_color("font_outline_color", "Label", Color(0.08, 0.03, 0.02, 0.85))
	th.set_constant("outline_size", "Label", 6)
	th.set_color("font_outline_color", "Button", Color(0.08, 0.03, 0.02, 0.6))
	th.set_constant("outline_size", "Button", 3)
	return th


func build(m: Node) -> void:
	main = m
	_load_fonts()
	theme = _make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- top: title + what is happening
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -250
	top.offset_top = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	title = Label.new()
	title.text = "TAGANT  ·  ANIMAL KARAOKE"
	title.add_theme_font_size_override("font_size", 26)
	top.add_child(title)
	info = Label.new()             # kept for main.gd, but not shown: the creature's name sits under it on stage
	info.visible = false
	top.add_child(info)
	origin_lbl = Label.new()
	origin_lbl.add_theme_font_size_override("font_size", 17)
	origin_lbl.modulate = Color(1, 1, 1, 0.72)
	top.add_child(origin_lbl)

	# --- left: singers
	# a slim strip of block numbers (glyphs for the lake, the frogs, the cicadas); the full name is on stage
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 16
	left.offset_top = 80
	left.offset_right = 16 + 64
	left.offset_bottom = -20
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	strip = left
	build_strip()

	# --- section tabs under the title: real animals | imaginary bestiary
	var sec := HBoxContainer.new()
	sec.add_theme_constant_override("separation", 22)
	sec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sec)
	var sg := ButtonGroup.new()
	for k in ["animals", "bestiary"]:
		var b := _tab()
		b.toggle_mode = true
		b.button_group = sg
		b.pressed.connect(main.set_section.bind(k))
		sec.add_child(b)
		section_buttons[k] = b
	section_buttons["animals"].button_pressed = true
	top.mouse_filter = Control.MOUSE_FILTER_PASS

	# --- top right: one quiet row of text tabs (modes | glaze | language)
	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -24
	right.offset_top = 16
	right.add_theme_constant_override("separation", 22)
	add_child(right)
	var mg := ButtonGroup.new()
	for md in ["Listen", "Sing", "Rehearse", "Dialogue"]:
		var b := _tab()
		b.text = md
		b.toggle_mode = true
		b.button_group = mg
		b.pressed.connect(main.set_mode.bind(md))
		right.add_child(b)
		mode_buttons[md] = b
	var bar := ColorRect.new()
	bar.color = Color(SALT, 0.35)
	bar.custom_minimum_size = Vector2(1, 26)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(bar)
	style_btn = _tab()
	style_btn.pressed.connect(main.cycle_style)
	right.add_child(style_btn)
	see_btn = _tab()
	see_btn.pressed.connect(func(): Lex.toggle_analysis())
	right.add_child(see_btn)
	Lex.view_changed.connect(apply_view)
	lang_btn = _tab()
	lang_btn.pressed.connect(main.toggle_language)
	right.add_child(lang_btn)
	mic_lbl = Label.new()
	mic_lbl.add_theme_font_size_override("font_size", 16)
	mic_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mic_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mic_lbl.offset_right = -26
	mic_lbl.offset_top = 64
	mic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mic_lbl.modulate = Color(1, 1, 1, 0.6)
	add_child(mic_lbl)

	# --- bottom: lane + transport
	bottom = PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.anchor_left = 0.17          # centred, with the stage left open around it
	bottom.anchor_right = 0.83
	bottom.anchor_top = 0.63
	bottom.offset_top = 0
	bottom.offset_left = 0
	bottom.offset_right = 0
	bottom.offset_bottom = -14
	add_child(bottom)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	bottom.add_child(col)
	lane = preload("res://scripts/lane.gd").new()
	lane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lane.custom_minimum_size = Vector2(0, 140)
	col.add_child(lane)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	play_btn = Button.new()
	play_btn.text = "▶  Play"
	play_btn.custom_minimum_size = Vector2(176, 64)
	play_btn.pressed.connect(main.toggle_play)
	row.add_child(play_btn)
	# on-screen arrows beside the creature (positioned every frame by main.gd)
	for k in 2:
		var ab := Button.new()      # a thin chevron, nothing else
		ab.icon = load("res://ui_frames/icons/chevron_%s.png" % ("l" if k == 0 else "r"))
		ab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ab.custom_minimum_size = Vector2(ARROW_W, 80)
		ab.size = Vector2(ARROW_W, 80)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			ab.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		ab.add_theme_color_override("icon_hover_color", Color(1, 0.75, 0.6))
		ab.pressed.connect(main.step_creature.bind(-1 if k == 0 else 1))
		ab.visible = false
		add_child(ab)
		if k == 0:
			arrow_l = ab
		else:
			arrow_r = ab
	arrow_name = Label.new()
	arrow_name.add_theme_font_size_override("font_size", 18)
	arrow_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	arrow_name.add_theme_constant_override("shadow_offset_x", 2)
	arrow_name.add_theme_constant_override("shadow_offset_y", 2)
	arrow_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_name.custom_minimum_size = Vector2(420, 30)
	arrow_name.size = Vector2(420, 30)
	arrow_name.visible = false
	arrow_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arrow_name)
	creature_opt = OptionButton.new()
	creature_opt.custom_minimum_size = Vector2(250, 50)
	creature_opt.tooltip_text = "creature on this block"
	creature_opt.item_selected.connect(main.choose_creature)
	row.add_child(creature_opt)
	song_opt = OptionButton.new()
	song_opt.custom_minimum_size = Vector2(300, 50)
	song_opt.tooltip_text = "voice"
	song_opt.item_selected.connect(_on_song_selected)
	row.add_child(song_opt)
	fold_chk = CheckButton.new()
	fold_chk.text = "Fold to my voice"
	fold_chk.button_pressed = true
	fold_chk.toggled.connect(main.set_fold)
	row.add_child(fold_chk)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	score_lbl = Label.new()
	score_lbl.add_theme_font_size_override("font_size", 24)
	row.add_child(score_lbl)

	row_rehearse = HBoxContainer.new()
	row_rehearse.add_theme_constant_override("separation", 16)
	col.add_child(row_rehearse)
	var pp := Button.new()
	phrase_prev = pp
	pp.custom_minimum_size = Vector2(0, 50)
	pp.pressed.connect(main.step_phrase.bind(-1))
	row_rehearse.add_child(pp)
	phrase_lbl = Label.new()
	phrase_lbl.custom_minimum_size = Vector2(120, 0)
	phrase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row_rehearse.add_child(phrase_lbl)
	var pn := Button.new()
	phrase_next = pn
	pn.pressed.connect(main.step_phrase.bind(1))
	row_rehearse.add_child(pn)
	loop_chk = CheckButton.new()
	loop_chk.text = "Loop"
	loop_chk.button_pressed = true
	loop_chk.toggled.connect(main.set_loop)
	row_rehearse.add_child(loop_chk)
	speed_opt = OptionButton.new()
	for s in ["speed 1", "speed 0.75", "speed 0.5"]:
		speed_opt.add_item(s)
	speed_opt.item_selected.connect(main.set_speed_index)
	row_rehearse.add_child(speed_opt)
	rec_btn = Button.new()
	rec_btn.text = "●  Record take"
	rec_btn.pressed.connect(main.toggle_take)
	row_rehearse.add_child(rec_btn)
	take_btn = Button.new()
	take_btn.text = "▷  Hear take"
	take_btn.disabled = true
	take_btn.pressed.connect(main.play_take)
	row_rehearse.add_child(take_btn)

	row_dialogue = HBoxContainer.new()
	row_dialogue.add_theme_constant_override("separation", 16)
	col.add_child(row_dialogue)
	dlg_btn = Button.new()
	dlg_btn.text = "Start the dialogue"
	dlg_btn.custom_minimum_size = Vector2(240, 50)
	dlg_btn.pressed.connect(main.toggle_dialogue)
	row_dialogue.add_child(dlg_btn)
	dlg_lbl = Label.new()
	dlg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_dialogue.add_child(dlg_lbl)


## All visible words, fonts and direction for the current language (Tr.lang).
func apply_language() -> void:
	var a := Tr.ar()
	layout_direction = Control.LAYOUT_DIRECTION_RTL if a else Control.LAYOUT_DIRECTION_LTR
	theme.default_font = f_arabic if a else f_latin
	theme.default_font_size = 26 if a else 21
	title.text = Tr.t("title")
	title.add_theme_font_override("font", f_arabic if a else f_title)
	title.add_theme_font_size_override("font_size", 30 if a else 28)
	title.add_theme_constant_override("outline_size", 8)
	for md in mode_buttons:
		mode_buttons[md].text = Tr.t(md)
	for k in section_buttons:
		section_buttons[k].text = Tr.t("sec_" + k)
	fold_chk.text = Tr.t("fold")
	fold_chk.tooltip_text = Tr.t("fold_tip")
	song_opt.tooltip_text = Tr.t("choose_voice")
	see_btn.text = Tr.t("see_sound_on" if Lex.analysis else "see_sound")
	origin_lbl.add_theme_font_override("font", f_arabic if a else f_latin)
	phrase_prev.text = Tr.t("prev_phrase")
	phrase_next.text = Tr.t("next_phrase")
	loop_chk.text = Tr.t("loop")
	var sel := speed_opt.selected
	speed_opt.clear()
	for sp in ["1", "0.75", "0.5"]:
		speed_opt.add_item("%s %s" % [Tr.t("speed"), Tr.num(sp)])
	speed_opt.select(maxi(sel, 0))
	rec_btn.text = Tr.t("rec")
	take_btn.text = Tr.t("hear")
	dlg_btn.text = Tr.t("dlg_start")
	play_btn.text = Tr.t("play")
	lang_btn.text = Tr.t("lang_button")
	style_btn.text = Tr.t("style_" + preload("res://scripts/animal.gd").style)
	lang_btn.add_theme_font_override("font", f_latin if a else f_arabic)
	arrow_name.add_theme_font_override("font", f_arabic if a else f_latin)
	refresh_labels()


func show_mode(md: String) -> void:
	mode_buttons[md].button_pressed = true
	row_rehearse.visible = md == "Rehearse"
	row_dialogue.visible = md == "Dialogue"
	play_btn.visible = md != "Dialogue"
	_mode = md
	score_lbl.text = ""
	apply_view()


func place_arrows(centre: Vector2, off: float, label: String) -> void:
	var s := get_viewport_rect().size
	var lp := Vector2(clampf(centre.x - off - ARROW_W, 96.0, s.x - 160.0), clampf(centre.y - 40.0, 90.0, s.y * 0.52))
	var rp := Vector2(clampf(centre.x + off, 160.0, s.x - 90.0), lp.y)
	arrow_l.position = lp
	arrow_r.position = rp
	arrow_name.text = label
	arrow_name.position = Vector2((lp.x + rp.x + ARROW_W) * 0.5 - 210.0, lp.y + 84.0)


func show_arrows(on: bool) -> void:
	arrow_l.visible = on
	arrow_r.visible = on
	arrow_name.visible = on


func refresh_labels() -> void:
	for s in Catalog.SLOTS:
		var info: Dictionary = Catalog.by_id(s.id)
		var b: Button = animal_buttons[s.id]
		b.text = Tr.num(str(int(s.slot) + 1)) if typeof(s.slot) == TYPE_INT else ""
		b.tooltip_text = Tr.creature(info.name)


func set_creatures(id: String) -> void:
	var s: Dictionary = Catalog.slot(id)
	creature_opt.clear()
	for o in s.options:
		creature_opt.add_item(Tr.creature(o.name))
	creature_opt.select(int(Catalog.choice.get(id, 0)))
	creature_opt.visible = false     # creatures are chosen with the on-screen arrows


## Own voices first, a separator, then every other voice (for hybrids).
func set_songs(ids: Array, own: int = 1) -> void:
	song_opt.clear()
	_song_index_map.clear()
	for i in ids.size():
		if i == own and own < ids.size():
			song_opt.add_separator(Tr.t("other_voices"))
			_song_index_map.append(-1)
		song_opt.add_item(Tr.voice(ids[i]))
		_song_index_map.append(i)
	song_opt.select(0)


func select_song(i: int) -> void:
	var item := _song_index_map.find(i)
	if item >= 0:
		song_opt.select(item)


func _on_song_selected(item: int) -> void:
	var i: int = _song_index_map[item]
	if i >= 0:
		main.choose_song_index(i)


func build_strip() -> void:
	for c in strip.get_children():
		c.queue_free()
	animal_buttons.clear()
	var group := ButtonGroup.new()
	for s in Catalog.SLOTS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(64, 64)
		if typeof(s.slot) != TYPE_INT:
			var ic := "res://ui_frames/icons/%s.png" % ("above" if s.id == "above" else s.id)
			if ResourceLoader.exists(ic):
				b.icon = load(ic)
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(main.select_animal.bind(s.id, true))
		strip.add_child(b)
		animal_buttons[s.id] = b
	refresh_labels()


func show_section(sec: String) -> void:
	section_buttons[sec].button_pressed = true


## The public view is simple (the voice's line + yours); "See the sound" opens the scientific
## spectrogram, the measurements and the secondary controls. Audio and microphone are not touched.
func apply_view() -> void:
	var full: bool = Lex.analysis
	fold_chk.visible = full and _mode != "Listen"
	score_lbl.visible = full
	style_btn.visible = full and true
	if see_btn:
		see_btn.text = Tr.t("see_sound_on" if full else "see_sound")


func set_origin(text: String) -> void:
	origin_lbl.text = text
