extends Node
## The conductor. Plays one voice per group, from where that group stands, and runs the chant
## written in assembly.json: a call from one group, the response of all, the titan's attack,
## the doves in the silence, everyone together. env[group] = how much the group sings now (0..1),
## loud_at(group) = how loud its voice is at this instant (from the analysed loudness of the recording).

signal section_changed(section_name: String, groups: Array)

const VOICES := "res://dove_man/assembly/voices/"
var world: Node3D
var A: Dictionary
var players: Dictionary = {}     # group -> AudioStreamPlayer3D
var rms: Dictionary = {}         # group -> {values, hop, peak, pitch}
var env: Dictionary = {}
var loud: Dictionary = {}
var base_db: Dictionary = {}
var section := -1
var section_t := 0.0
var groups: Array = []


func setup(w: Node3D, settings: Dictionary) -> void:
	world = w
	A = settings
	var places: Dictionary = {}
	var counts: Dictionary = {}
	for m in world.members:
		var g: String = m.group
		places[g] = places.get(g, Vector3.ZERO) + (m.root as Node3D).position + Vector3(0, float(m.h) * 0.7, 0)
		counts[g] = counts.get(g, 0) + 1
	for g in places:
		places[g] /= float(counts[g])
	places["doves"] = Vector3(world.titan_pos.x * 0.5, 45.0, world.titan_pos.y * 0.5)
	places["titan"] = Vector3(world.titan_pos.x, 34.0, world.titan_pos.y)
	var voices: Dictionary = A.voices.duplicate()
	voices["titan"] = {"song": A.titan.voice, "pitch": A.titan.pitch, "volume_db": A.titan.volume_db}
	for g in voices:
		var v: Dictionary = voices[g]
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice_" + g
		var path: String = VOICES + String(v.song) + ".ogg"
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		p.stream = stream
		p.pitch_scale = float(v.pitch)
		p.unit_size = 90.0 if g != "titan" else 160.0
		p.max_db = 6.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.volume_db = -80.0
		p.position = places.get(g, Vector3.ZERO)
		add_child(p)
		p.play(fposmod(float(g.hash() % 997) * 0.37, 20.0))
		players[g] = p
		base_db[g] = float(v.volume_db)
		env[g] = 0.0
		loud[g] = 0.0
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(VOICES + String(v.song) + ".json"))
		var values: Array = data.rms if data != null else []
		var peak := 0.0001
		for x in values:
			peak = maxf(peak, float(x))
		rms[g] = {"values": values, "hop": float(data.hop) if data != null else 0.02, "peak": peak, "pitch": float(v.pitch)}
		groups.append(g)


func jump(index: int) -> void:
	section = index - 1
	section_t = 0.0
	for g in groups:
		env[g] = float(A.score[index].level) if (A.score[index].sing.has(g) or (A.score[index].sing.has("all") and g != "titan" and g != "doves")) else 0.0


func loudness(g: String, back_s: float) -> float:
	if not rms.has(g):
		return 0.0
	var r: Dictionary = rms[g]
	var values: Array = r.values
	if values.is_empty():
		return 0.5
	var pos: float = (players[g] as AudioStreamPlayer3D).get_playback_position() - back_s * float(r.pitch)
	var i := int(fposmod(pos, float(values.size()) * float(r.hop)) / float(r.hop))
	return clampf(float(values[clampi(i, 0, values.size() - 1)]) / float(r.peak), 0.0, 1.0)


# the voice reaches the singers further from the front a little later: a ripple through the crowd
func loud_at(g: String, delay_s: float) -> float:
	return loudness(g, delay_s * 0.6) if env.get(g, 0.0) > 0.02 else 0.0


func _process(delta: float) -> void:
	var score: Array = A.score
	if not world.opening_done():
		return                      # the chant waits for the opening (the world, the titan, the crowd coming)
	section_t -= delta
	if section < 0 or section_t <= 0.0:
		section = (section + 1) % score.size()
		section_t = float(score[section].len)
		section_changed.emit(preload("res://dove_man/assembly/tr.gd").t(String(score[section].name)), score[section].sing)
		if score[section].sing.has("titan"):
			world.start_attack(maxf(float(score[section].len) - 3.0, 4.0))   # the titan does not sing: it attacks
	var S: Dictionary = score[section]
	var singing: Array = S.sing
	var level: float = float(S.level)
	for g in groups:
		var on: bool = g != "titan" and (singing.has(g) or (singing.has("all") and g != "doves"))
		var target: float = level if on else 0.0
		var rate: float = 3.0 if target > env[g] else 1.4         # quick to rise, slower to let go
		env[g] = lerpf(env[g], target, 1.0 - exp(-delta * rate))
		loud[g] = loudness(g, 0.0) * env[g]
		var p: AudioStreamPlayer3D = players[g]
		p.volume_db = linear_to_db(maxf(env[g], 0.0001)) + float(base_db[g])
