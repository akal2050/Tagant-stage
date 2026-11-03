extends Node3D
## TAGANT stage — two-screen test.
## The stage is what the TV / projector shows. Commands arrive from the iPad panel over UDP.
##   creature:N   sky:N   mic:on|off   rec:start|stop   play:last   stop   screen:tv|ipad

const LISTEN_PORT := 47100
const PANEL_PORT := 47101

var udp := PacketPeerUDP.new()
var reply := PacketPeerUDP.new()

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var creature_root: Node3D
var camera: Camera3D
var title: Label
var spectrum_bars: Array[ColorRect] = []

var mic_player: AudioStreamPlayer
var take_player: AudioStreamPlayer
var record_fx: AudioEffectRecord
var spectrum: AudioEffectSpectrumAnalyzerInstance
var takes: Array[AudioStreamWAV] = []
var level_timer := 0.0
var t := 0.0

const CREATURES := ["MYNA", "DOVE", "CAMEL", "FROG", "GOAT"]
const SKIES := [
	[Color(0.93, 0.62, 0.48), Color(0.98, 0.85, 0.70), 0.5, Color(1.0, 0.75, 0.55)],
	[Color(0.35, 0.60, 0.92), Color(0.75, 0.85, 0.95), 1.2, Color(1.0, 0.97, 0.90)],
	[Color(0.45, 0.25, 0.40), Color(0.95, 0.55, 0.35), 0.6, Color(1.0, 0.55, 0.35)],
	[Color(0.03, 0.04, 0.10), Color(0.08, 0.10, 0.20), 0.15, Color(0.55, 0.65, 1.0)],
]

func _ready() -> void:
	_build_world()
	_build_overlay()
	_build_audio()
	udp.bind(LISTEN_PORT, "127.0.0.1")
	reply.set_dest_address("127.0.0.1", PANEL_PORT)
	set_creature(0)
	set_sky(1)

# ---------------------------------------------------------------- world

func _build_world() -> void:
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-35, 40, 0)
	add_child(sun)

	# terracotta floor
	var floor_mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 14.0
	cyl.bottom_radius = 14.0
	cyl.height = 0.2
	cyl.radial_segments = 96
	floor_mi.mesh = cyl
	floor_mi.material_override = _mat(Color(0.72, 0.38, 0.24), 0.9)
	floor_mi.position.y = -0.1
	add_child(floor_mi)

	# salt circle
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 3.0
	tor.outer_radius = 3.25
	tor.rings = 96
	ring.mesh = tor
	ring.material_override = _mat(Color(0.95, 0.94, 0.90), 0.6)
	ring.scale = Vector3(1, 0.15, 1)
	add_child(ring)

	# rammed-earth cylinder (plinth)
	var plinth := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 1.4
	pc.bottom_radius = 1.5
	pc.height = 1.6
	plinth.mesh = pc
	plinth.material_override = _mat(Color(0.62, 0.45, 0.32), 1.0)
	plinth.position.y = 0.8
	add_child(plinth)

	creature_root = Node3D.new()
	creature_root.position.y = 1.6
	add_child(creature_root)

	camera = Camera3D.new()
	camera.fov = 45
	add_child(camera)

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func set_creature(i: int) -> void:
	i = clampi(i, 0, CREATURES.size() - 1)
	for c in creature_root.get_children():
		c.queue_free()
	var blue := _mat(Color(0.45, 0.70, 0.92), 0.5)
	var body := MeshInstance3D.new()
	var head := MeshInstance3D.new()
	match i:
		0: # myna: small round bird
			body.mesh = _sphere(0.45); body.position.y = 0.45
			head.mesh = _sphere(0.25); head.position = Vector3(0, 0.95, 0.15)
		1: # dove
			body.mesh = _capsule(0.4, 1.2); body.rotation_degrees.x = 70; body.position.y = 0.45
			head.mesh = _sphere(0.22); head.position = Vector3(0, 0.85, 0.45)
		2: # camel
			body.mesh = _capsule(0.5, 1.8); body.rotation_degrees.z = 90; body.position.y = 1.2
			head.mesh = _capsule(0.2, 0.9); head.position = Vector3(1.0, 1.9, 0)
		3: # frog
			body.mesh = _sphere(0.6); body.scale = Vector3(1.2, 0.6, 1); body.position.y = 0.35
			head.mesh = _sphere(0.18); head.position = Vector3(0.25, 0.75, 0.35)
		4: # goat
			body.mesh = _capsule(0.4, 1.4); body.rotation_degrees.z = 90; body.position.y = 0.9
			head.mesh = _sphere(0.3); head.position = Vector3(0.8, 1.4, 0)
	for m in [body, head]:
		m.material_override = blue
		creature_root.add_child(m)
	title.text = CREATURES[i]

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2; return s

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = h; return c

func set_sky(i: int) -> void:
	var s: Array = SKIES[clampi(i, 0, SKIES.size() - 1)]
	sky_mat.sky_top_color = s[0]
	sky_mat.sky_horizon_color = s[1]
	sky_mat.ground_horizon_color = s[1]
	sun.light_energy = s[2]
	sun.light_color = s[3]
	env.fog_light_color = s[1]

# ---------------------------------------------------------------- overlay (on the big screen)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 40
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(title)

	# minimal centred spectrogram strip
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = -120
	box.add_theme_constant_override("separation", 4)
	layer.add_child(box)
	for k in 48:
		var bar := ColorRect.new()
		bar.color = Color(0.62, 0.84, 0.98, 0.85)
		bar.custom_minimum_size = Vector2(10, 2)
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		box.add_child(bar)
		spectrum_bars.append(bar)

# ---------------------------------------------------------------- audio

func _build_audio() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Mic")
	AudioServer.set_bus_mute(idx, true)  # monitoring happens on the mixer, not here (no feedback)
	record_fx = AudioEffectRecord.new()
	AudioServer.add_bus_effect(idx, record_fx)
	AudioServer.add_bus_effect(idx, AudioEffectSpectrumAnalyzer.new())
	spectrum = AudioServer.get_bus_effect_instance(idx, 1)

	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Mic"
	add_child(mic_player)

	take_player = AudioStreamPlayer.new()
	add_child(take_player)

func mic(on: bool) -> void:
	if on and not mic_player.playing:
		mic_player.play()
	elif not on:
		mic_player.stop()

func rec(start: bool) -> void:
	if start:
		mic(true)
		record_fx.set_recording_active(true)
		_send("rec:on")
	elif record_fx.is_recording_active():
		record_fx.set_recording_active(false)
		var take := record_fx.get_recording()
		if take:
			takes.append(take)
			var path := "user://take_%03d.wav" % takes.size()
			take.save_to_wav(path)
		_send("rec:off")
		_send("takes:%d" % takes.size())

# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	t += delta
	camera.position = Vector3(sin(t * 0.08) * 9.0, 3.2, cos(t * 0.08) * 9.0)
	camera.look_at(Vector3(0, 1.8, 0))
	creature_root.rotation.y = -camera.rotation.y * 0.0 + sin(t * 0.5) * 0.15

	while udp.get_available_packet_count() > 0:
		_handle(udp.get_packet().get_string_from_utf8())

	_update_spectrum(delta)

func _update_spectrum(delta: float) -> void:
	var lo := 80.0
	var hi := 8000.0
	var total := 0.0
	for k in spectrum_bars.size():
		var f0 := lo * pow(hi / lo, float(k) / spectrum_bars.size())
		var f1 := lo * pow(hi / lo, float(k + 1) / spectrum_bars.size())
		var mag := 0.0
		if spectrum and mic_player.playing:
			mag = spectrum.get_magnitude_for_frequency_range(f0, f1).length()
		var db := linear_to_db(maxf(mag, 1e-6))
		var h := clampf((db + 70.0) / 70.0, 0.0, 1.0)
		total += h
		var bar := spectrum_bars[k]
		bar.custom_minimum_size.y = lerpf(bar.custom_minimum_size.y, 2.0 + h * 160.0, 0.35)
	level_timer += delta
	if level_timer > 0.1:
		level_timer = 0.0
		_send("level:%.3f" % (total / spectrum_bars.size()))

func _handle(msg: String) -> void:
	var parts := msg.split(":", true, 1)
	var key := parts[0]
	var val := parts[1] if parts.size() > 1 else ""
	match key:
		"creature": set_creature(int(val))
		"sky": set_sky(int(val))
		"mic": mic(val == "on")
		"rec": rec(val == "start")
		"play":
			if takes.size() > 0:
				take_player.stream = takes[-1]
				take_player.play()
		"stop":
			take_player.stop()
			rec(false)
		"screen":
			_send("info:stage now on " + val)

func _send(s: String) -> void:
	reply.put_packet(s.to_utf8_buffer())
