extends Node
## QA walk-through (only with:  -- --qa): opening -> both worlds -> every mode, both languages,
## "See the sound", sections, back. Prints QA lines; any SCRIPT ERROR shows in the log.

func _ready() -> void:
	await _wait(1.0)
	var st := get_tree().current_scene
	print("QA opening page=", st.page, " title=", st.o_title.text, " sub=", st.o_sub.text)
	while not st.enter_btn.visible:
		if st.failed:
			print("QA FAIL load"); get_tree().quit(1); return
		await _wait(0.5)
	print("QA enter visible after ", snappedf(st.t, 0.1), "s")
	st._toggle_lang(); print("QA ar heading:", st.w_heading.text, " | ", st.o_question.text); st._toggle_lang()
	st._go_worlds()
	for w in ["circles", "aitwadu"]:
		for lang in ["en", "ar"]:
			Worlds.lang = lang
			st = get_tree().current_scene
			st._open(w)
			await _wait(4.0)
			var m := get_tree().current_scene
			print("QA world=", w, " lang=", lang, " title=", m.ui.title.text, " origin=", m.ui.origin_lbl.text)
			for md in ["Listen", "Sing", "Rehearse", "Dialogue"]:
				m.set_mode(md)
				await _wait(0.6)
				print("QA   mode ", md, " -> ", m.ui.mode_buttons[md].text)
			m.set_mode("Listen")
			m.toggle_play(); await _wait(1.5); m.toggle_play()
			Lex.toggle_analysis(); await _wait(0.5); print("QA   analysis on, see_btn=", m.ui.see_btn.text); Lex.toggle_analysis()
			var secs: Array = ["animals", "bestiary"] if w == "circles" else ["aitwadu", "adu", "aghanim"]
			for sname in secs:
				m.set_section(sname); await _wait(0.8)
				print("QA   section ", sname, " = ", m.ui.section_buttons[sname].text, " | voice: ", m.ui.song_opt.get_item_text(0) if m.ui.song_opt.item_count > 0 else "-", " | ", m.ui.origin_lbl.text)
			m.toggle_language(); await _wait(0.3); print("QA   toggled lang -> ", m.ui.title.text, " back=", Worlds.back.text)
			Worlds.go_start(); await _wait(2.0)
			print("QA back at start page=", get_tree().current_scene.page)
	print("QA DONE")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
