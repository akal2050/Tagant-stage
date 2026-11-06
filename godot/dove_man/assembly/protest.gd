extends "res://dove_man/assembly/choir.gd"
## A protest song as karaoke. The leader calls a phrase (a phrase cut from its own recording),
## then it is your turn: repeat it into the microphone and the crowd repeats it with you,
## louder and more together the more you sing. After some rounds the titan turns its water
## on the crowd like a police water cannon; the crowd scatters, then walks back, faster while
## you keep singing, and the song goes on.

const MIC = preload("res://dove_man/assembly/mic.gd")
const Tr = preload("res://dove_man/assembly/tr.gd")

var song: Dictionary
var lead: Dictionary = {}
var mic: Node
var phrases: Array = []          # [start_s, end_s] cut from the leader's recording
var leader_player: AudioStreamPlayer3D
var crowd_players: Array = []
var state := ""
var state_t := 0.0
var round_n := 0
var phrase_i := 0
var phrase_a := 0.0
var phrase_b := 0.0
var voice := 0.0                 # the singer's voice, smoothed, 0..1
var trace: PackedFloat32Array = PackedFloat32Array()   # the singer's voice during the answer
var follow := 0.0                # how well the crowd follows you (0..1)
var attacks := 0
var next_attack := 0
var hit_clock := 0.0
var water_t := 0.0
var sweep: Array = [0.0, 0.0]
var crowd_gain := 0.35
var lyrics: Array = []           # [line, translation] - the singer's own chant about water (lyrics_water.txt)
var lyric_i := 0
var lyric := ["", "", ""]           # the groups' own voices are only a texture under the repeated phrase


func setup(w: Node3D, settings: Dictionary) -> void:
	super.setup(w, settings)
	song = A.songs[world.song_index]
	lead = world.leader()
	var L: Dictionary = song.leader
	var path: String = VOICES + String(L.voice) + ".ogg"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VOICES + String(L.voice) + ".json"))
	for ph in data.phrases:
		var a: float = float(ph[0])
		var b: float = minf(float(ph[1]), a + 6.0)
		if b - a >= 1.2:
			phrases.append([a, b])
	var peak := 0.0001
	for x in data.rms:
		peak = maxf(peak, float(x))
	var lead_pos: Vector3 = (lead.root as Node3D).position + Vector3(0, float(lead.h) * 0.8, 0)
	leader_player = AudioStreamPlayer3D.new()
	leader_player.stream = stream
	leader_player.pitch_scale = float(L.pitch)
	leader_player.unit_size = 140.0
	leader_player.max_db = 6.0
	leader_player.volume_db = float(L.volume_db)
	leader_player.position = lead_pos
	add_child(leader_player)
	var crowd_at := Vector3(world.titan_pos.x, 0.0, world.titan_pos.y) + Vector3(-world.titan_pos.x, 0.0, -world.titan_pos.y).normalized() * 85.0 + Vector3(0, 6, 0)
	for k in 3:
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		p.pitch_scale = float(L.pitch) * [0.94, 1.0, 1.07][k]
		p.unit_size = 160.0
		p.max_db = 6.0
		p.volume_db = -80.0
		p.position = crowd_at + Vector3((k - 1) * 30.0, 0, 0)
		add_child(p)
		crowd_players.append(p)
	players["leader"] = leader_player
	players["crowd"] = crowd_players[1]
	rms["leader"] = {"values": data.rms, "hop": float(data.hop), "peak": peak, "pitch": float(L.pitch)}
	rms["crowd"] = rms["leader"]
	env["leader"] = 0.0
	mic = MIC.new()
	add_child(mic)
	mic.setup()
	mic.start()
	next_attack = int(song.first_attack_after)
	load_lyrics()
	enter("gather")


# The singer's part: lines of a chant about water in the singer's own language, one per round.
# Edit res://dove_man/assembly/lyrics_water.txt: one line per round, "words | translation".
func load_lyrics() -> void:
	var path := "res://dove_man/assembly/lyrics_water.txt"
	if FileAccess.file_exists(path):
		for raw in FileAccess.get_file_as_string(path).split("\n"):
			var line: String = raw.strip_edges()
			if line == "" or line.begins_with("#"):
				continue
			var f: PackedStringArray = line.split("|")
			while f.size() < 6:
				f.append("")
			for k in f.size():
				f[k] = f[k].strip_edges()
			# what is shown: the line big, a second script under it, a translation small
			var big: String = f[3] if Tr.ar() else f[1]
			var under: String = ""
			if f[0] == "amazigh":
				under = f[2]                                # Tifinagh under the Latin (EN) or under the Arabic letters (AR)
			elif not Tr.ar():
				under = f[3]                                # Arabic script under its Latin transliteration (EN)
			var tr_line: String = f[5] if Tr.ar() else f[4]
			if tr_line == big:
				tr_line = ""
			lyrics.append([big, tr_line, under])
	if lyrics.is_empty():
		lyrics.append(["(sing your own chant about water)", "", ""])


func leader_name() -> String:
	return String(song.leader_ar) if Tr.ar() else String(song.leader_en)


func title() -> String:
	return String(song.title_ar) if Tr.ar() else String(song.title)


func sub() -> String:
	return String(song.sub_ar) if Tr.ar() else String(song.sub)


func enter(s: String) -> void:
	state = s
	state_t = 0.0
	world.camera_rig.focus_member = {}
	match s:
		"gather":
			section_changed.emit("%s  ·  %s\n%s" % [title(), sub(), Tr.t("the crowd is gathering")], ["all"])
		"call":
			var ph: Array = phrases[phrase_i % phrases.size()]
			phrase_a = ph[0]
			phrase_b = ph[1]
			phrase_i += 1
			leader_player.play(phrase_a)
			world.camera_rig.focus_member = lead
			section_changed.emit("%s  ·  %s\n%s" % [title(), Tr.t("round %d / %d") % [round_n + 1, int(song.rounds)], Tr.t("listen: %s calls") % leader_name()], ["leader"])
		"respond":
			trace.clear()
			lyric = lyrics[lyric_i % lyrics.size()]
			lyric_i += 1
			for k in crowd_players.size():
				(crowd_players[k] as AudioStreamPlayer3D).play(phrase_a + 0.0)
			section_changed.emit("%s  ·  %s\n%s" % [title(), Tr.t("round %d / %d") % [round_n + 1, int(song.rounds)], Tr.t("your turn: sing your line about water - the crowd joins")], ["all"])
		"attack":
			attacks += 1
			var J: Dictionary = A.jet
			var s0: float = float(J.sweep_deg[0])
			var s1: float = float(J.sweep_deg[1])
			sweep = [s0, s1] if attacks % 2 == 1 else [s1, s0]
			world.start_attack(float(song.attack_s))
			section_changed.emit("%s\n%s" % [title(), Tr.t("the titan turns its water on the crowd")], ["titan"])
		"regroup":
			section_changed.emit("%s\n%s" % [title(), Tr.t("they scatter - keep singing to bring them back")], [])
		"end":
			section_changed.emit("%s\n%s" % [title(), Tr.t("all together")], ["all"])


func phrase_len() -> float:
	return (phrase_b - phrase_a) / maxf(leader_player.pitch_scale, 0.01)


func phrase_level(u: float) -> float:
	var r: Dictionary = rms["leader"]
	var values: Array = r.values
	var i := int((phrase_a + u * (phrase_b - phrase_a)) / float(r.hop))
	return clampf(float(values[clampi(i, 0, values.size() - 1)]) / float(r.peak), 0.0, 1.0)


func score_answer() -> float:
	if trace.is_empty():
		return 0.0
	var sung := 0
	for x in trace:
		if x > 0.12:
			sung += 1
	return clampf(float(sung) / float(trace.size()) * 1.4, 0.0, 1.0)


func score_imitation() -> float:
	if trace.is_empty():
		return 0.0
	var lo := 0.0
	var hi := 0.0
	var tmax := 0.0001
	for x in trace:
		tmax = maxf(tmax, x)
	for k in trace.size():
		var a: float = phrase_level(float(k) / float(trace.size()))
		var b: float = trace[k] / tmax * clampf(tmax * 2.0, 0.0, 1.0)
		lo += minf(a, b)
		hi += maxf(a, b)
	return lo / maxf(hi, 0.0001)


# During the answer the crowd moves with the repeated phrase, not with its own recording.
func loud_at(g: String, delay_s: float) -> float:
	if g == "leader":
		return loudness("leader", 0.0) if state == "call" else 0.0
	if state == "respond" and g != "titan" and g != "doves":
		return loudness("crowd", delay_s * 0.6)
	return super.loud_at(g, delay_s)


func set_env(g: String, target: float, delta: float, rate_up := 3.0, rate_down := 1.4) -> void:
	var cur: float = env.get(g, 0.0)
	env[g] = lerpf(cur, target, 1.0 - exp(-delta * (rate_up if target > cur else rate_down)))


func _process(delta: float) -> void:
	state_t += delta
	voice = lerpf(voice, mic.energy() if mic != null else 0.0, 1.0 - exp(-delta * 8.0))
	var crowd_level: float = clampf(0.3 + 0.55 * voice + 0.35 * follow, 0.0, 1.0)
	var group_target := 0.0
	var leader_target := 0.0
	var titan_target := 0.0
	match state:
		"gather":
			group_target = 0.12
			if not world.opening_done():
				state_t = 0.0
			elif (state_t > 4.0 and world.home_fraction() > 0.6) or state_t > 30.0:
				enter("call")
		"call":
			leader_target = 1.0
			group_target = 0.04
			if state_t > phrase_len() + 0.15:
				leader_player.stop()
				if state_t > phrase_len() + float(song.gap_s):
					enter("respond")
		"respond":
			leader_target = 0.45
			group_target = crowd_level
			trace.append(mic.energy() if mic != null else 0.0)
			for k in crowd_players.size():
				var p: AudioStreamPlayer3D = crowd_players[k]
				if p.playing and state_t > phrase_len() + 0.1:
					p.stop()
				p.volume_db = linear_to_db(maxf(crowd_level, 0.0001)) + 2.0 - k * 1.5
			if state_t > phrase_len() + float(song.gap_s):
				for p in crowd_players:
					(p as AudioStreamPlayer3D).stop()
				follow = lerpf(follow, score_answer(), 0.5)
				round_n += 1
				if round_n >= next_attack:
					next_attack = round_n + int(song.attack_every)
					enter("attack")
				elif round_n >= int(song.rounds):
					enter("end")
				else:
					enter("call")
		"attack":
			group_target = 0.35 + 0.3 * voice
			if world.attack_done():
				enter("regroup")
		"regroup":
			group_target = 0.12 + 0.6 * voice
			if (state_t > 6.0 and world.home_fraction() > 0.85) or state_t > 40.0:
				enter("end" if round_n >= int(song.rounds) else "call")
		"end":
			group_target = 1.0
			leader_target = 1.0
			if state_t > 16.0:
				round_n = 0
				next_attack = int(song.first_attack_after)
				enter("call")
	world.regroup_voice = voice
	for g in groups:
		if g == "titan":
			set_env(g, titan_target, delta)
		elif g == "doves":
			set_env(g, 0.6 if state == "end" or state == "regroup" else 0.0, delta)
		else:
			set_env(g, group_target, delta)
		loud[g] = loudness(g, 0.0) * env[g]
		var gain: float = crowd_gain if g != "titan" and g != "doves" and state != "end" else 1.0
		(players[g] as AudioStreamPlayer3D).volume_db = linear_to_db(maxf(env[g] * gain, 0.0001)) + float(base_db[g])
	set_env("leader", leader_target, delta, 8.0, 3.0)


# ------------------------------------------------------------ for the karaoke screen

func lane() -> Dictionary:
	var n := 120
	var curve := PackedFloat32Array()
	curve.resize(n)
	for k in n:
		curve[k] = phrase_level(float(k) / float(n - 1))
	var u := 0.0
	if state == "call" or state == "respond":
		u = clampf(state_t / maxf(phrase_len(), 0.01), 0.0, 1.0)
	var tr := PackedFloat32Array()
	if state == "respond" and not trace.is_empty():
		var total: float = maxf(phrase_len(), 0.01) * Engine.get_frames_per_second()
		for k in trace.size():
			tr.append(trace[k])
		tr.append(total)            # last value = how many samples make the whole phrase
	return {"state": state, "curve": curve, "u": u, "trace": tr, "voice": voice, "follow": follow,
		"round": round_n, "rounds": int(song.rounds), "mic": mic != null and mic.active,
		"lyric": lyric[0] if state == "respond" else "", "lyric_tr": lyric[1] if state == "respond" else "",
		"lyric_under": lyric[2] if state == "respond" else "",
		"next_lyric": lyrics[lyric_i % lyrics.size()][0] if state == "call" else ""}
