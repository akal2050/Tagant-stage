extends Node
## iPad bridge for THE ASSEMBLY.
## The native remote on the iPad sends short commands over UDP (localhost 47100);
## this node turns them into what the assembly already understands (its own keys and functions)
## and sends back the panel layout, the current section text and the mic level (47101).
## No assembly file is changed: songs, water, cameras and text stay exactly as on the laptop.

const LISTEN_PORT := 47100
const PANEL_PORT := 47101
const Tr = preload("res://dove_man/assembly/tr.gd")

var udp := PacketPeerUDP.new()
var reply := PacketPeerUDP.new()
var world: Node
var tick := 0.0
var last_status := ""
var quality := 1            # 0 high · 1 medium · 2 low
var cam := 0
var song := 0

# recording (own mic bus, muted: you hear yourself on the mixer, never through the app)
var rec_bus := -1
var rec_fx: AudioEffectRecord
var rec_player: AudioStreamPlayer
var take_player: AudioStreamPlayer
var takes: Array[AudioStreamWAV] = []
var recording := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	udp.bind(LISTEN_PORT, "127.0.0.1")
	reply.set_dest_address("127.0.0.1", PANEL_PORT)
	_setup_recorder()
	_apply_quality()
	get_tree().node_added.connect(_on_node_added)
	await get_tree().process_frame
	_find_world()
	send_ui()
	_send_previous_log()


# The tail of the previous run's log (errors only), shown small on the remote.
func _send_previous_log() -> void:
	var d := DirAccess.open("user://logs")
	if d == null:
		return
	var files := Array(d.get_files()).filter(func(f): return f.ends_with(".log") and f != "godot.log")
	if files.is_empty():
		return
	files.sort()
	var txt := FileAccess.get_file_as_string("user://logs/" + files[-1])
	var errs: Array = []
	for l in txt.split("\n"):
		if l.begins_with("ERROR") or l.begins_with("SCRIPT ERROR") or l.contains("crash") or l.contains("CrashHandler"):
			errs.append(l.substr(0, 140))
	if errs.size() > 0:
		_send("diag:" + " | ".join(errs.slice(-3)))


func _on_node_added(n: Node) -> void:
	if n.get_parent() == get_tree().root and n != self:
		world = n
		await get_tree().process_frame
		_apply_quality()
		send_ui()


func _find_world() -> void:
	for c in get_tree().root.get_children():
		if c != self and c.has_method("start_song"):
			world = c


# ---------------------------------------------------------------- panel layout

func ar() -> bool:
	return Tr.ar()


func L(en: String, a: String) -> String:
	return a if ar() else en


func send_ui() -> void:
	var songs: Array = []
	if world != null and world.get("A") is Dictionary and world.A.has("songs"):
		for i in world.A.songs.size():
			var s: Dictionary = world.A.songs[i]
			var t: String = s.get("title_ar", s.title) if ar() else s.title
			songs.append({"id": "song:%d" % i, "label": "%d · %s" % [i + 1, t], "on": i == song})
	var cams := [
		["Auto", "تلقائي"], ["Wide", "واسع"], ["Behind the choir", "خلف الجوقة"],
		["What the titan sees", "ما يراه العملاق"], ["The singers", "المغنّون"], ["From above", "من الأعلى"]]
	var cam_buttons: Array = []
	for i in cams.size():
		cam_buttons.append({"id": "cam:%d" % i, "label": L(cams[i][0], cams[i][1]), "on": i == cam})
	var q := [["High", "عالية"], ["Medium", "متوسطة"], ["Low", "منخفضة"]]
	var q_buttons: Array = [{"id": "hud", "label": L("Show / hide text", "إظهار / إخفاء النص")}]
	for i in q.size():
		q_buttons.append({"id": "quality:%d" % i, "label": L("Quality: ", "الجودة: ") + L(q[i][0], q[i][1]), "on": i == quality})
	var ui := {
		"title": Tr.t("THE ASSEMBLY · claiming water"),
		"rtl": ar(),
		"sections": [
			{"title": L("Songs", "الأغاني"), "compact": true, "buttons": songs},
			{"title": L("The titan", "العملاق"), "compact": true, "buttons": [
				{"id": "water", "label": L("Water cannon — now", "مدفع الماء — الآن")}]},
			{"title": L("Camera", "الكاميرا"), "buttons": cam_buttons},
			{"title": L("Your voice", "صوتك"), "buttons": [
				{"id": "rec", "label": L("● Record", "● تسجيل") if not recording else L("■ Stop recording", "■ أوقف التسجيل"), "on": recording},
				{"id": "play", "label": L("▶ Hear last take", "▶ استمع للتسجيل")},
				{"id": "stop", "label": L("■ Stop", "■ إيقاف")}]},
			{"title": L("Screen", "الشاشة"), "buttons": q_buttons},
			{"title": L("Language", "اللغة"), "compact": true, "buttons": [
				{"id": "lang:en", "label": "English", "on": not ar()},
				{"id": "lang:ar", "label": "العربية", "on": ar()}]},
		],
		"takes": L("takes: %d", "التسجيلات: %d") % takes.size(),
		"no_tv": L("No TV detected — the stage is shown here. Plug in HDMI.", "لا توجد شاشة — المشهد يظهر هنا. وصّل كابل HDMI."),
		"tv": L("TV / projector connected — the stage is on the big screen", "الشاشة متصلة — المشهد على الشاشة الكبيرة"),
	}
	_send("ui:" + JSON.stringify(ui))


# ---------------------------------------------------------------- commands

func _process(delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		_handle(udp.get_packet().get_string_from_utf8())
	tick += delta
	if tick >= 0.1:
		tick = 0.0
		_send("level:%.3f" % _mic_level())
		var st := _status()
		if st != last_status:
			last_status = st
			_send("status:" + st)


func _handle(msg: String) -> void:
	var parts := msg.split(":", true, 1)
	var key := parts[0]
	var val := parts[1] if parts.size() > 1 else ""
	match key:
		"hello":
			send_ui()
		"song":
			song = int(val)
			if world != null:
				world.start_song(song)
			send_ui()
		"water":
			_key(KEY_W)
		"cam":
			cam = int(val)
			_key(KEY_0 + cam)
			send_ui()
		"hud":
			_key(KEY_H)
		"quality":
			quality = clampi(int(val), 0, 2)
			_apply_quality()
			send_ui()
		"lang":
			_set_lang(val)
		"rec":
			_toggle_rec()
		"play":
			if takes.size() > 0:
				take_player.stream = takes[-1]
				take_player.play()
		"stop":
			take_player.stop()
			if recording:
				_toggle_rec()
		"screen":
			pass


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _set_lang(l: String) -> void:
	if l == Tr.lang:
		return
	Tr.lang = l
	Tr._font = null
	song = 0
	cam = 0
	get_tree().reload_current_scene()


func _apply_quality() -> void:
	var vp := get_viewport()
	vp.scaling_3d_scale = [1.0, 0.75, 0.55][quality]
	vp.msaa_3d = Viewport.MSAA_DISABLED if quality > 0 else Viewport.MSAA_2X
	RenderingServer.directional_shadow_atlas_set_size([4096, 2048, 1024][quality], true)


func _status() -> String:
	if world != null and world.get("hud") is Label and (world.hud as Label).visible:
		return (world.hud as Label).text
	return ""


func _mic_level() -> float:
	if world != null:
		var c = world.get("choir")
		if c != null and c.get("mic") != null:
			var m = c.mic
			if m.get("level_db") != null:
				return clampf((float(m.level_db) + 70.0) / 60.0, 0.0, 1.0)
	if rec_bus >= 0:
		var db := AudioServer.get_bus_peak_volume_left_db(rec_bus, 0)
		return clampf((db + 70.0) / 60.0, 0.0, 1.0)
	return 0.0


# ---------------------------------------------------------------- recording

func _setup_recorder() -> void:
	rec_bus = AudioServer.bus_count
	AudioServer.add_bus(rec_bus)
	AudioServer.set_bus_name(rec_bus, "IpadTake")
	rec_fx = AudioEffectRecord.new()
	AudioServer.add_bus_effect(rec_bus, rec_fx)
	AudioServer.set_bus_mute(rec_bus, true)
	rec_player = AudioStreamPlayer.new()
	rec_player.stream = AudioStreamMicrophone.new()
	rec_player.bus = "IpadTake"
	add_child(rec_player)
	take_player = AudioStreamPlayer.new()
	add_child(take_player)


func _toggle_rec() -> void:
	if not recording:
		if not rec_player.playing:
			rec_player.play()
		rec_fx.set_recording_active(true)
		recording = true
	else:
		rec_fx.set_recording_active(false)
		recording = false
		var take := rec_fx.get_recording()
		if take:
			takes.append(take)
			DirAccess.make_dir_recursive_absolute("user://takes")
			take.save_to_wav("user://takes/assembly_%s.wav" % Time.get_datetime_string_from_system().replace(":", "-"))
	send_ui()


func _send(s: String) -> void:
	reply.put_packet(s.to_utf8_buffer())
