extends Node
## Autoload "Remote": the iPad remote for TAGANT / حداء خلان الريح.
##
## On the iPad with a TV plugged in, the native plugin (ios/plugins/tagant_display) moves this
## Godot view to the TV and turns the whole iPad screen into a control panel. This node:
##   · describes the controls that are on screen right now (opening, the two entrances, a world)
##     and sends them to the panel ("ui:{json}") — labels are read from the live widgets,
##     so words, language and states are exactly the ones Godot shows;
##   · receives the panel's taps and presses the very same widgets (nothing is re-implemented);
##   · on the TV hides the buttons and tabs, keeping the stage, the title, the voice's origin,
##     the creature's name and the voice line.
## Without a TV the panel is hidden and the iPad works exactly as before (touch on screen).
## Inert on the laptop (no plugin, nobody on the ports).

const LISTEN_PORT := 47100
const PANEL_PORT := 47101

var udp := PacketPeerUDP.new()
var out := PacketPeerUDP.new()
var tv := false
var _t := 0.0
var _last_ui := ""
var _last_status := ""
var _resend := 0.0
var _ok := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not (OS.has_feature("ios") or OS.get_name() == "iOS" or OS.get_cmdline_user_args().has("--remote")):
		set_process(false)
		return
	_ok = udp.bind(LISTEN_PORT, "127.0.0.1") == OK
	out.set_dest_address("127.0.0.1", PANEL_PORT)
	if OS.get_cmdline_user_args().has("--remote-tv"):
		tv = true


func _send(s: String) -> void:
	out.put_packet(s.to_utf8_buffer())


# ------------------------------------------------------------------ what is on screen

func _scene() -> Node:
	return get_tree().current_scene


func _world_ui():
	var s := _scene()
	if s == null:
		return null
	var u = s.get("ui")
	if u is Control and u.get("mode_buttons") is Dictionary:
		return u
	return null


func _start():
	var s := _scene()
	if s != null and s.get("enter_btn") is Button and s.get("cards") is Dictionary:
		return s
	return null


func _btn(id: String, label: String, on := false) -> Dictionary:
	return {"id": id, "label": label.strip_edges(), "on": on}


func _ar() -> bool:
	return Worlds.world_lang() == "ar"


func _h(key: String) -> String:
	return Lex.get_text("panel", key, _ar())


func describe() -> Dictionary:
	var ar := _ar()
	var d := {"rtl": ar, "sections": [], "title": "TAGANT", "status": ""}
	var st = _start()
	var u = _world_ui()
	var lang_label := "English" if ar else "العربية"
	if st != null:
		d.title = st.o_title.text
		if st.page == "opening":
			var b: Array = []
			if st.enter_btn.visible:
				b.append(_btn("enter", st.enter_btn.text))
			d.sections.append({"title": _h("enter"), "big": true, "buttons": b})
			d.status = st.o_status.text
			if st.diag_lbl and st.diag_lbl.text != "":
				d.status += ("\n" if d.status != "" else "") + st.diag_lbl.text
		else:
			d.title = st.w_heading.text
			var b: Array = []
			for k in ["circles", "aitwadu"]:
				var c: Array = st.cards[k]
				var l: String = c[0].text
				if c[1].visible and c[1].text != "":
					l += "\n" + c[1].text
				b.append(_btn("world:" + k, l))
			d.sections.append({"title": _h("worlds"), "big": true, "cols": 2, "buttons": b})
			d.sections.append({"title": "", "cols": 2, "buttons": [_btn("opening", st.back_btn.text)]})
			d.status = st.w_status.text
		d.sections.append({"title": _h("view"), "cols": 2, "buttons": [_btn("lang", st.lang_btn.text)]})
		return d
	if u == null:
		return d
	var main: Node = _scene()
	d.title = u.title.text
	# sections (animals | bestiary …)
	var secs: Array = []
	var sec_row: Control = null
	for k in u.section_buttons:
		var b: Button = u.section_buttons[k]
		sec_row = b.get_parent()
		secs.append(_btn("sec:" + k, b.text, b.button_pressed))
	if secs.size() > 1 and sec_row != null and sec_row.visible:
		d.sections.append({"title": _h("group"), "cols": secs.size(), "buttons": secs})
	# singers (the strip on the left of the stage)
	var sing: Array = []
	for id in u.animal_buttons:
		var b: Button = u.animal_buttons[id]
		var name := b.tooltip_text
		if name == "":
			name = b.text
		sing.append(_btn("slot:" + id, name, b.button_pressed))
	if sing.size() > 0:
		d.sections.append({"title": _h("singers"), "cols": 4, "buttons": sing})
	# the creature on this block (the on-screen arrows)
	if u.arrow_l.visible:
		d.sections.append({"title": _h("creature") + "  ·  " + u.arrow_name.text, "cols": 2, "buttons": [
			_btn("cr:-1", "◀" if not ar else "▶"), _btn("cr:1", "▶" if not ar else "◀")]})
	# voices: own first, then the others
	var own: Array = []
	var other: Array = []
	var other_title := ""
	var into := own
	var so: OptionButton = u.song_opt
	for i in so.item_count:
		if so.is_item_separator(i):
			other_title = so.get_item_text(i)
			into = other
			continue
		into.append(_btn("song:%d" % i, so.get_item_text(i), so.selected == i))
	if own.size() > 0:
		d.sections.append({"title": _h("voice"), "cols": 3, "buttons": own})
	# modes
	var modes: Array = []
	for md in u.mode_buttons:
		var b: Button = u.mode_buttons[md]
		modes.append(_btn("mode:" + md, b.text, b.button_pressed))
	d.sections.append({"title": _h("mode"), "cols": 4, "buttons": modes})
	# what this mode offers
	var act: Array = []
	if u.play_btn.visible:
		act.append(_btn("play", u.play_btn.text, main.player != null and main.player.playing))
	if u.row_rehearse.visible:
		act.append(_btn("prev", u.phrase_prev.text))
		act.append(_btn("next", u.phrase_next.text))
		act.append(_btn("rec", u.rec_btn.text, main.mic != null and main.mic.recording()))
		if not u.take_btn.disabled:
			act.append(_btn("hear", u.take_btn.text))
	if u.row_dialogue.visible:
		act.append(_btn("dlg", u.dlg_btn.text, main.dlg_on))
	if act.size() > 0:
		d.sections.append({"title": _h("controls"), "big": true, "cols": mini(act.size(), 4), "buttons": act})
	if u.row_rehearse.visible:
		var r: Array = [_btn("loop", u.loop_chk.text, u.loop_chk.button_pressed)]
		for i in u.speed_opt.item_count:
			r.append(_btn("speed:%d" % i, u.speed_opt.get_item_text(i), u.speed_opt.selected == i))
		d.sections.append({"title": _h("practice"), "cols": 4, "buttons": r})
	if other.size() > 0:
		d.sections.append({"title": other_title, "cols": 3, "small": true, "buttons": other})
	# view and language
	var v: Array = [_btn("see", u.see_btn.text, Lex.analysis)]
	if u.style_btn.visible:
		v.append(_btn("style", u.style_btn.text))
	if u.fold_chk.visible:
		v.append(_btn("fold", u.fold_chk.text, u.fold_chk.button_pressed))
	v.append(_btn("lang", u.lang_btn.text))
	v.append(_btn("back", Worlds.back.text))
	d.sections.append({"title": _h("view"), "cols": mini(v.size(), 3), "buttons": v})
	# status: where the voice comes from, the phrase, the dialogue, (the score in analysis)
	var lines: Array = []
	for l in [u.origin_lbl, u.phrase_lbl, u.dlg_lbl, u.score_lbl, u.mic_lbl]:
		if l is Label and l.is_visible_in_tree() and l.text.strip_edges() != "":
			lines.append(l.text.strip_edges())
	d.status = "\n".join(PackedStringArray(lines))
	return d


# ------------------------------------------------------------------ taps from the panel

func _press(b: BaseButton) -> void:
	if b == null:
		return
	if b is CheckButton or (b.toggle_mode and b.button_group == null):
		b.button_pressed = not b.button_pressed      # emits toggled
		return
	if b.toggle_mode:
		b.button_pressed = true
	b.pressed.emit()


func _pick(o: OptionButton, i: int) -> void:
	if o == null or i < 0 or i >= o.item_count or o.is_item_separator(i):
		return
	o.select(i)
	o.item_selected.emit(i)


func handle(msg: String) -> void:
	if OS.get_cmdline_user_args().has("--remote-log"): print("REMOTE <- ", msg)
	var parts := msg.split(":", true, 1)
	var key := parts[0]
	var val := parts[1] if parts.size() > 1 else ""
	match key:
		"hello":
			_last_ui = ""
			return
		"screen":
			tv = val == "tv"
			_apply_tv()
			_last_ui = ""
			return
	var st = _start()
	if st != null:
		match key:
			"enter": if st.enter_btn.visible: st._go_worlds()
			"world": st._open(val)
			"opening": st.back_btn.pressed.emit()
			"lang": st._toggle_lang()
		_last_ui = ""
		return
	var u = _world_ui()
	if u == null:
		return
	var main: Node = _scene()
	match key:
		"sec": _press(u.section_buttons.get(val))
		"slot": _press(u.animal_buttons.get(val))
		"cr": main.step_creature(int(val))
		"song": _pick(u.song_opt, int(val))
		"mode": _press(u.mode_buttons.get(val))
		"play": _press(u.play_btn)
		"prev": _press(u.phrase_prev)
		"next": _press(u.phrase_next)
		"loop": _press(u.loop_chk)
		"speed": _pick(u.speed_opt, int(val))
		"rec": _press(u.rec_btn)
		"hear": if not u.take_btn.disabled: _press(u.take_btn)
		"dlg": _press(u.dlg_btn)
		"see": _press(u.see_btn)
		"style": _press(u.style_btn)
		"fold": _press(u.fold_chk)
		"lang": _press(u.lang_btn)
		"back": Worlds.go_start()
	_last_ui = ""


# ------------------------------------------------------------------ TV: stage only

func _hide(c) -> void:
	# the TV is not touchable: only the look changes, the widgets keep working for the panel
	if c is CanvasItem:
		c.modulate.a = 0.0 if tv else 1.0


func _apply_tv() -> void:
	if Worlds.back:
		Worlds.back.visible = Worlds.current != "" and not tv
	var st = _start()
	if st != null:
		for c in [st.enter_btn, st.lang_btn, st.back_btn]:
			_hide(c)
		return
	var u = _world_ui()
	if u == null:
		return
	var rows: Array = [u.strip, u.mic_lbl, u.arrow_l, u.arrow_r, u.row_rehearse, u.row_dialogue, u.play_btn.get_parent()]
	for k in u.section_buttons:
		rows.append(u.section_buttons[k].get_parent())
		break
	for k in u.mode_buttons:
		rows.append(u.mode_buttons[k].get_parent())
		break
	for c in rows:
		_hide(c)


func _process(delta: float) -> void:
	if _ok:
		while udp.get_available_packet_count() > 0:
			handle(udp.get_packet().get_string_from_utf8())
	if tv:
		_apply_tv()
	_t += delta
	_resend += delta
	if _t < 0.2:
		return
	_t = 0.0
	var d := describe()
	var status: String = d.status
	d.erase("status")
	var js := JSON.stringify(d)
	if js != _last_ui or _resend > 3.0:
		_last_ui = js
		_resend = 0.0
		_send("ui:" + js)
	if status != _last_status:
		_last_status = status
		_send("status:" + status)
	var main := _scene()
	var m = main.get("mic") if main != null else null
	if m != null and m.get("level_db") != null:
		_send("level:%.3f" % clampf((float(m.level_db) + 60.0) / 60.0, 0.0, 1.0))
