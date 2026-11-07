extends Node3D
## TAGANT Animal Karaoke - main controller.
## Listen   : the animal sings its Pd song, the lane shows its contour.
## Sing     : sing along; your voice is scored against the contour (octaves folded, so any voice can follow a bird).
## Rehearse : phrase by phrase, loop, slow down (pitch kept), record your take and hear it back.
## Dialogue : call and response - the animal calls one phrase, you answer, it reacts and goes on (or repeats).
## Tap any body on the stage: it calls one phrase and becomes the singer.

const Stage := preload("res://herding/scripts/valley.gd")
const Animal := preload("res://herding/scripts/animal.gd")
const Director := preload("res://herding/scripts/director.gd")
const Mic := preload("res://herding/scripts/mic.gd")
const UI := preload("res://herding/scripts/ui.gd")

var stage
var cam
var mic
var ui
var animals := {}
var current := ""
var _is_dove := false
var mode := "Listen"

var song_ids: Array = []
var song_name := ""
var song: Dictionary = {}
var streams := {}
var player: AudioStreamPlayer
var take_player: AudioStreamPlayer
var take: AudioStreamWAV
var bus_song := -1
var bus_mic := -1
var bus_calls := -1

var fold := true
var shift := 0.0
var latency := 0.18           # seconds: phone mic + speaker round trip
var tol := 1.0                # semitones
var hits := 0
var total := 0
var speed := 1.0
var loop_on := true
var phrase := 0
var user_trace: Array = []
var _sing_t := 0.0

# dialogue
var dlg_on := false
var dlg_state := ""
var dlg_clock := 0.0
var dlg_turn_t0 := 0.0
var dlg_phrase := 0
var dlg_user: Array = []
var dlg_turn_len := 0.0
var dlg_wins := 0


func _ready() -> void:
	randomize()
	_setup_buses()
	stage = Stage.new()
	add_child(stage)
	stage.build()
	cam = Director.new()
	add_child(cam)
	cam.current = true
	for s in HCatalog.SLOTS:
		_spawn(s.id)
	mic = Mic.new()
	add_child(mic)
	mic.setup(bus_mic)
	player = AudioStreamPlayer.new()
	player.bus = "Song"
	add_child(player)
	player.finished.connect(_on_song_finished)
	take_player = AudioStreamPlayer.new()
	add_child(take_player)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = UI.new()
	layer.add_child(ui)
	ui.build(self)
	if OS.get_name() == "Android":
		get_tree().on_request_permissions_result.connect(_on_permission)
		OS.request_permissions()
	ui.apply_language()
	ui.style_btn.visible = false           # herding karaoke: no creature glaze to choose
	ui.info.visible = true                 # the place name under the title
	ui.info.add_theme_font_size_override("font_size", 17)
	ui.info.modulate = Color(1, 1, 1, 0.8)
	select_animal(HCatalog.SLOTS[0].id, false)          # the first place of the open section (was "palm", not in the first section)
	set_mode("Listen")


## Real animals <-> imaginary bestiary: the same seven blocks, a different cast.
func set_section(sec: String) -> void:
	if sec == HCatalog.section:
		return
	stop_all()
	for id in animals:
		animals[id].queue_free()
	animals.clear()
	HCatalog.set_section(sec)
	for s in HCatalog.SLOTS:
		_spawn(s.id)
	ui.build_strip()
	ui.show_section(sec)
	current = ""
	select_animal(HCatalog.SLOTS[0].id, false)          # first place of the section (the copied "b1"/"x1" do not exist here)


func _on_permission(perm: String, granted: bool) -> void:
	# the microphone only delivers sound if it is (re)started after RECORD_AUDIO is granted
	if granted and perm.ends_with("RECORD_AUDIO") and mic.active:
		mic.stop()
		mic.start()


## Builds (or rebuilds) the creature standing on a place, facing outward from the centre.
func _spawn(id: String) -> void:
	if animals.has(id):
		animals[id].queue_free()
	var a: Dictionary = HCatalog.by_id(id)
	if typeof(a.slot) == TYPE_INT:
		a["fit_r"] = Stage.cylinder_radius(a.slot)
	var n = Animal.new()
	add_child(n)
	n.setup(a)
	var p: Vector3 = stage.place_position(a.slot)
	n.position = p
	n.base_y = p.y
	n.set_yaw_offset(deg_to_rad(a.get("yaw", 0.0)))
	n.rotation.y = atan2(p.x, p.z)
	n.set_meta("view", stage.view(a.slot))          # start facing outward, then follow the camera
	animals[id] = n


## The on-screen arrows sit left and right of the selected creature (only when its block has options).
func _place_arrows() -> void:
	var s: Dictionary = HCatalog.slot(current)
	var n = animals.get(current)
	var show: bool = n != null and n.model != null and s.options.size() > 1 and not dlg_on
	if show:
		var h: float = HCatalog.by_id(current).get("height", 1.2)
		var centre: Vector3 = n.global_position + Vector3.UP * (h * 0.5 + n.hover)
		show = not cam.is_position_behind(centre)
		if show:
			var c2: Vector2 = cam.unproject_position(centre)
			var edge: Vector2 = cam.unproject_position(centre + cam.global_transform.basis.x * maxf(h * 0.9, 1.0))
			var off: float = clampf(absf(edge.x - c2.x), 90.0, 320.0)
			ui.place_arrows(c2, off, "%s   %s" % [HTr.creature(HCatalog.by_id(current).name), HTr.num("%d / %d" % [int(HCatalog.choice.get(current, 0)) + 1, s.options.size()])])
	ui.show_arrows(show)


func cycle_style() -> void:
	var i := (Animal.STYLES.find(Animal.style) + 1) % Animal.STYLES.size()
	Animal.style = Animal.STYLES[i]
	for id in animals:
		animals[id].apply_style()
	ui.style_btn.text = HTr.t("style_" + Animal.style)


func toggle_language() -> void:
	Worlds.lang = "en" if HTr.ar() else "ar"
	HTr.lang = "en" if HTr.ar() else "ar"
	ui.apply_language()
	var _w2: Dictionary = HCatalog.by_id(current)
	ui.set_origin(Lex.origin(song_name, String(_w2.get("name", "")), Array(_w2.get("songs", [])).has(song_name), HTr.ar()))
	var keep := song_ids.find(song_name)
	var a: Dictionary = HCatalog.by_id(current)
	ui.set_songs(song_ids, a.songs.size())
	ui.select_song(keep)
	ui.info.text = "%s  —  %s" % [HTr.creature(a.name), HTr.body(a.body)]
	ui.play_btn.text = HTr.t("stop") if player.playing else HTr.t("play")
	ui.dlg_btn.text = HTr.t("dlg_stop") if dlg_on else HTr.t("dlg_start")
	_update_phrase_ui()


func step_creature(d: int) -> void:
	var s: Dictionary = HCatalog.slot(current)
	choose_creature(posmod(int(HCatalog.choice.get(current, 0)) + d, s.options.size()))


func choose_creature(k: int) -> void:
	stop_all()
	HCatalog.choice[current] = k
	_spawn(current)
	ui.refresh_labels()
	select_animal(current, false)


func _setup_buses() -> void:
	AudioServer.add_bus()
	bus_song = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_song, "Song")
	AudioServer.set_bus_send(bus_song, "Master")
	var ps := AudioEffectPitchShift.new()
	AudioServer.add_bus_effect(bus_song, ps)
	AudioServer.set_bus_effect_enabled(bus_song, 0, false)
	AudioServer.add_bus()
	bus_calls = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_calls, "Calls")
	AudioServer.set_bus_send(bus_calls, "Master")
	AudioServer.add_bus()
	bus_mic = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_mic, "Mic")
	AudioServer.set_bus_send(bus_mic, "Master")
	AudioServer.set_bus_volume_db(bus_mic, -80.0)   # analysed and recorded, never heard (no feedback)
	var sa := AudioEffectSpectrumAnalyzer.new()
	sa.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_4096
	sa.buffer_length = 0.5
	AudioServer.add_bus_effect(bus_mic, sa)
	AudioServer.add_bus_effect(bus_mic, AudioEffectRecord.new())


# ---------------------------------------------------------------- data

func _stream(name: String) -> AudioStream:
	if not streams.has(name):
		var s: AudioStream = load("res://herding/songs/%s.ogg" % name)
		if s is AudioStreamOggVorbis:
			s.loop = false
		streams[name] = s
	return streams[name]


func _load_song(name: String) -> Dictionary:
	var f := FileAccess.open("res://herding/data/%s.json" % name, FileAccess.READ)
	if f == null:
		return {}
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var midi := PackedFloat32Array()
	for v in d.midi:
		var m := float(v)
		midi.append(0.0 if m >= 107.0 else m)   # 108.9 = analysis ceiling, not a note
	d.midi = midi
	d.rms = PackedFloat32Array(d.rms)
	return d


func _song_shift() -> float:
	if not fold or song.is_empty():
		return 0.0
	var vals: Array = []
	for m in song.midi:
		if m > 0.0:
			vals.append(m)
	if vals.size() < 10:
		return 0.0
	vals.sort()
	var med: float = vals[vals.size() / 2]
	return 12.0 * round((57.0 - med) / 12.0)     # bring the median near a comfortable voice (A3)


func _frame(t: float) -> int:
	return clampi(int(t / song.hop), 0, song.midi.size() - 1)


func _phrases() -> Array:
	return song.get("phrases", [])


# ---------------------------------------------------------------- UI actions

func select_animal(id: String, from_ui: bool = true) -> void:
	if id == current and from_ui:
		return
	stop_all()
	current = id
	var a: Dictionary = HCatalog.by_id(id)
	song_ids = HCatalog.voice_list(id)
	ui.set_songs(song_ids, a.songs.size())
	ui.set_creatures(id)
	_is_dove = String(a.get("model", "")).ends_with("dove.glb")
	ui.animal_buttons[id].button_pressed = true
	_set_song(song_ids[0])
	var n = animals[id]
	cam.focus = n if a.model != "" else _voice_anchor(id)
	cam.focus_height = a.get("height", 1.2)
	ui.info.text = "%s  —  %s" % [HTr.creature(a.name), HTr.body(a.body)]


func _voice_anchor(id: String) -> Node3D:
	if id == "cicadas":
		return stage.cicada_anchor
	return animals[id]


func choose_song_index(i: int) -> void:
	stop_all()
	_set_song(song_ids[i])


func _set_song(name: String) -> void:
	song_name = name
	song = _load_song(name)
	shift = _song_shift()
	phrase = 0
	player.stream = _stream(name)
	ui.lane.data = song
	ui.lane.set_spectrum(name)
	ui.lane.song_title = HTr.voice(name)
	var _who: Dictionary = HCatalog.by_id(current)
	ui.set_origin(Lex.origin(name, String(_who.get("name", "")), Array(_who.get("songs", [])).has(name), HTr.ar()))
	ui.lane.shift = shift
	ui.lane.centre = 57.0 if fold else _median_or(60.0)
	ui.lane.segments = [{"at": 0.0, "from": 0.0, "to": song.duration, "alpha": 1.0}]
	ui.lane.user = []
	ui.lane.now = 0.0
	_update_phrase_ui()


func _median_or(dflt: float) -> float:
	var r: Array = song.get("midi_range", [dflt - 6, dflt + 6])
	return (float(r[0]) + float(r[1])) * 0.5


func set_fold(on: bool) -> void:
	fold = on
	shift = _song_shift()
	ui.lane.shift = shift
	ui.lane.centre = 57.0 if fold else _median_or(60.0)


func set_mode(md: String) -> void:
	stop_all()
	mode = md
	ui.show_mode(md)
	cam.lane_open = true
	if md in ["Sing", "Rehearse", "Dialogue"]:
		mic.start()
	else:
		mic.stop()
	_update_phrase_ui()


func toggle_play() -> void:
	if player.playing:
		stop_all()
		return
	hits = 0
	total = 0
	user_trace = []
	ui.lane.user = user_trace
	var from := 0.0
	if mode == "Rehearse":
		var ph := _phrases()
		if ph.size() > 0:
			from = max(0.0, float(ph[phrase][0]) - 0.6)
	player.play(from)
	ui.play_btn.text = HTr.t("stop")
	animals[current].set_state("sing")


func stop_all() -> void:
	if player and player.playing:
		player.stop()
	if ui:
		ui.play_btn.text = HTr.t("play")
	if dlg_on:
		toggle_dialogue()
	if current != "" and animals.has(current):
		animals[current].set_state("idle")


func _on_song_finished() -> void:
	ui.play_btn.text = HTr.t("play")
	animals[current].set_state("idle")
	if mode == "Sing" and total > 0:
		var pct := int(100.0 * hits / total)
		ui.score_lbl.text = HTr.num("%d %%" % pct)
		animals[current].react("great" if pct > 55 else ("good" if pct > 30 else "confused"))


func step_phrase(d: int) -> void:
	var ph := _phrases()
	if ph.is_empty():
		return
	phrase = posmod(phrase + d, ph.size())
	_update_phrase_ui()
	if player.playing:
		player.seek(max(0.0, float(ph[phrase][0]) - 0.6))


func _update_phrase_ui() -> void:
	var ph := _phrases()
	if ui == null:
		return
	ui.phrase_lbl.text = HTr.num("%d / %d" % [phrase + 1, ph.size()]) if ph.size() else "-"
	if mode == "Rehearse" and ph.size() > 0:
		ui.lane.region = Vector2(float(ph[phrase][0]), float(ph[phrase][1]))
	else:
		ui.lane.region = Vector2(-1, -1)


func set_loop(on: bool) -> void:
	loop_on = on


func set_speed_index(i: int) -> void:
	speed = [1.0, 0.75, 0.5][i]
	player.pitch_scale = speed
	var ps: AudioEffectPitchShift = AudioServer.get_bus_effect(bus_song, 0)
	ps.pitch_scale = 1.0 / speed            # slow down, keep the pitch
	AudioServer.set_bus_effect_enabled(bus_song, 0, speed < 0.999)


func toggle_take() -> void:
	if mic.recording():
		take = mic.record_stop()
		ui.rec_btn.text = HTr.t("rec")
		ui.take_btn.disabled = take == null
		if take:
			DirAccess.make_dir_recursive_absolute("user://takes")
			var fn := "user://takes/%s_%s.wav" % [song_name, Time.get_datetime_string_from_system().replace(":", "-")]
			take.save_to_wav(fn)
			ui.dlg_lbl.text = ""
			ui.info.text = HTr.t("take_saved") + ProjectSettings.globalize_path(fn)
	else:
		mic.start()
		mic.record_start()
		ui.rec_btn.text = HTr.t("rec_stop")
		if not player.playing:
			toggle_play()


func play_take() -> void:
	if take:
		take_player.stream = take
		take_player.play()


# ---------------------------------------------------------------- tap the stage

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var from: Vector3 = cam.project_ray_origin(ev.position)
		var to: Vector3 = from + cam.project_ray_normal(ev.position) * 300.0
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit.collider.has_meta("animal_id"):
			var id: String = hit.collider.get_meta("animal_id")
			if id != current:
				select_animal(id, false)
			_tap_call(id)


func _tap_call(id: String) -> void:
	if player.playing or dlg_on:
		return
	var a: Dictionary = HCatalog.by_id(id)
	var sname: String = a.songs[0] if id != current else song_name
	var d: Dictionary = song if sname == song_name else _load_song(sname)
	var ph: Array = d.get("phrases", [])
	if ph.is_empty():
		return
	var p: Array = ph[randi() % ph.size()]
	animals[id].call_phrase(_stream(sname), float(p[0]), float(p[1]))
	animals[id].react("good")


# ---------------------------------------------------------------- dialogue (call and response)

func toggle_dialogue() -> void:
	dlg_on = not dlg_on
	ui.dlg_btn.text = HTr.t("dlg_stop") if dlg_on else HTr.t("dlg_start")
	if dlg_on:
		mic.start()
		dlg_phrase = 0
		dlg_wins = 0
		dlg_clock = 0.0
		user_trace = []
		ui.lane.user = user_trace
		stage.flock_target = 3.0
		_dlg_call()
	else:
		player.stop()
		dlg_state = ""
		ui.dlg_lbl.text = ""
		ui.lane.segments = [{"at": 0.0, "from": 0.0, "to": song.get("duration", 0.0), "alpha": 1.0}]
		animals[current].set_state("idle")


func _dlg_call() -> void:
	var ph := _phrases()
	if ph.is_empty():
		ui.dlg_lbl.text = HTr.t("no_phrases")
		return
	var p: Array = ph[dlg_phrase % ph.size()]
	var a := float(p[0])
	var b := float(p[1])
	dlg_state = "call"
	dlg_turn_len = b - a
	dlg_turn_t0 = dlg_clock + 0.15
	var gap := 0.6
	ui.lane.segments = [
		{"at": dlg_turn_t0, "from": a, "to": b, "alpha": 1.0},
		{"at": dlg_turn_t0 + dlg_turn_len + gap, "from": a, "to": b, "alpha": 0.3},
	]
	player.play(a)
	animals[current].set_state("sing")
	ui.dlg_lbl.text = HTr.num(HTr.t("calls") % [HTr.creature(HCatalog.by_id(current).name), dlg_phrase % ph.size() + 1])


func _dlg_process(delta: float) -> void:
	dlg_clock += delta
	ui.lane.now = dlg_clock
	var ph := _phrases()
	if ph.is_empty():
		return
	var p: Array = ph[dlg_phrase % ph.size()]
	match dlg_state:
		"call":
			if player.get_playback_position() >= float(p[1]) or not player.playing:
				player.stop()
				dlg_state = "answer"
				dlg_user = []
				animals[current].set_state("listen")
				ui.dlg_lbl.text = HTr.t("your_turn")
		"answer":
			var lt := dlg_clock
			var start := dlg_turn_t0 + dlg_turn_len + 0.6
			if lt >= start - 0.2:
				dlg_user.append(Vector3(lt - start, mic.midi, 1.0 if mic.loud() else 0.0))
				user_trace.append(Vector3(lt, mic.midi, 0.0))
			if lt > start + dlg_turn_len + 1.0:
				dlg_state = "judge"
				var s := _answer_score(float(p[0]), float(p[1]), dlg_user)
				_dlg_react(s)


func _answer_score(a: float, b: float, ans: Array) -> float:
	var sv: Array = []
	var song_loud := 0
	for i in range(_frame(a), _frame(b)):
		if song.midi[i] > 0.0:
			sv.append(song.midi[i])
		if song.rms[i] > 0.2:
			song_loud += 1
	var uv: Array = []
	var user_loud := 0
	for u: Vector3 in ans:
		if u.y > 0.0:
			uv.append(u.y)
		if u.z > 0.5:
			user_loud += 1
	# rhythm / breath part: did you make sound for about as long as the call?
	var song_dur: float = float(maxi(1, song_loud)) * song.hop
	var user_dur: float = float(user_loud) * (dlg_turn_len + 1.2) / maxf(1.0, float(ans.size()))
	var r: float = user_dur / song_dur if song_dur > 0.0 else 0.0
	var breath: float = clamp(1.0 - abs(log(max(r, 0.05))) * 0.9, 0.0, 1.0)
	if sv.size() < 8 or uv.size() < 6:
		return breath                      # noisy call (camel, hyena laugh...): follow the swell
	# contour part: shape only, transposition removed, octave slips folded
	var n := 16
	var sm := _median(sv)
	var um := _median(uv)
	var err := 0.0
	for k in n:
		var s: float = sv[int(float(k) / n * sv.size())] - sm
		var u: float = uv[int(float(k) / n * uv.size())] - um
		var dd: float = fposmod(u - s + 6.0, 12.0) - 6.0
		err += absf(dd)
	err /= n
	var shape: float = clamp(1.0 - err / 4.0, 0.0, 1.0)
	return 0.7 * shape + 0.3 * breath


func _median(v: Array) -> float:
	var c := v.duplicate()
	c.sort()
	return c[c.size() / 2]


func _dlg_react(s: float) -> void:
	var name: String = HTr.creature(HCatalog.by_id(current).name)
	var ph := _phrases()
	if s >= 0.6:
		dlg_wins += 1
		animals[current].react("great" if s > 0.8 else "good")
		ui.dlg_lbl.text = HTr.t("heard") % [name] if not Lex.analysis else HTr.num("%s  (%d%%)" % [HTr.t("heard") % [name], int(s * 100)])
		dlg_phrase += 1
		stage.flock_target = min(7.0, 3.0 + dlg_wins)
	elif s >= 0.3:
		animals[current].react("good")
		ui.dlg_lbl.text = HTr.t("almost") if not Lex.analysis else HTr.num("%s  (%d%%)" % [HTr.t("almost"), int(s * 100)])
	else:
		animals[current].react("confused")
		ui.dlg_lbl.text = HTr.t("not_yet") if not Lex.analysis else HTr.num("%s  (%d%%)" % [HTr.t("not_yet"), int(s * 100)])
	if dlg_phrase >= ph.size():
		dlg_phrase = 0
	await get_tree().create_timer(1.6).timeout
	if dlg_on:
		_dlg_call()


# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	var a_cur = animals.get(current)
	# energy of what is sounding -> bodies move with it
	var lvl := 0.0
	if player.playing and not song.is_empty():
		lvl = song.rms[_frame(player.get_playback_position())]
	for id in animals:
		var n = animals[id]
		var l := lvl if id == current else 0.0
		if n.calling():
			var d: Dictionary = song if id == current else {}
			if not d.is_empty():
				l = d.rms[_frame(n.call_position())]
			else:
				l = 0.6
		n.sing_level = lerp(n.sing_level, l, 0.25)
		n.face_target = cam.global_position
	_place_arrows()
	
	if _is_dove and not dlg_on:
		stage.flock_target = 3.0 + 4.0 * animals[current].sing_level
	stage.set_focus_distance(cam.global_position.distance_to(cam.focus.global_position) if cam.focus else 34.0)
	if a_cur:
		var fp: Vector3 = (cam.focus.global_position if cam.focus else Vector3.ZERO)
		stage.light_singer(fp, 3.0 if (player.playing or a_cur.calling()) else 0.8)
	ui.mic_lbl.text = ("%s  %s" % [HTr.t("mic"), (_note_name(mic.midi) if mic.midi > 0 else "·")]) if mic.active else ""

	if dlg_on:
		_dlg_process(delta)
		return
	if not player.playing:
		return
	var t := player.get_playback_position() + AudioServer.get_time_since_last_mix()
	ui.lane.now = t
	# rehearsal loop
	if mode == "Rehearse" and loop_on:
		var ph := _phrases()
		if ph.size() > 0 and t > float(ph[phrase][1]) + 0.4:
			player.seek(max(0.0, float(ph[phrase][0]) - 0.6))
	if mode in ["Sing", "Rehearse"]:
		_score_frame(t)


func _score_frame(t: float) -> void:
	_sing_t += 1
	var ts := t - latency
	if ts < 0.0:
		return
	var i := _frame(ts)
	var sm: float = song.midi[i]
	var se: float = song.rms[i]
	var hit := false
	var um: float = mic.midi
	if sm > 0.0 and se > 0.12:
		total += 1
		if um > 0.0:
			# compare with a small time window (+-0.12 s), octaves folded
			var best := 99.0
			for k in range(-6, 7, 2):
				var j := clampi(i + k, 0, song.midi.size() - 1)
				var s2: float = song.midi[j]
				if s2 <= 0.0:
					continue
				var dd: float = absf(fposmod(um - s2 + 6.0, 12.0) - 6.0)
				best = min(best, dd)
			hit = best <= tol
	elif se > 0.3:
		total += 1                      # noisy call: be there with your breath
		hit = mic.loud()
	if hit:
		hits += 1
	user_trace.append(Vector3(t, um, 1.0 if hit else 0.0))
	if user_trace.size() > 900:
		user_trace.pop_front()
	if total > 0:
		ui.score_lbl.text = HTr.num("%d %%" % int(100.0 * hits / total))


func _note_name(m: float) -> String:
	var names := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var r := int(round(m))
	var cents := int(round((m - r) * 100))
	return "%s%d %+d¢" % [names[posmod(r, 12)], r / 12 - 1, cents]
