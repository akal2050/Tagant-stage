extends Node
## (copied from the animal karaoke) Microphone: live pitch (MIDI, 0 = none) and level from the "Mic" bus.
## Pitch = harmonic sum over a spectrum analyser (native FFT, cheap enough for phones),
## refined with a centroid on the strongest harmonic. Octave errors are harmless:
## the karaoke scoring folds octaves, so a human can sing a bird line in their own register.

const FFT := 4096
var bus := -1
var spec: AudioEffectSpectrumAnalyzerInstance
var player: AudioStreamPlayer
var active := false
var midi := 0.0
var level_db := -90.0
var gate_db := -58.0
var _acc := 0.0
var _hist: Array = []
var _bin := 44100.0 / FFT


func setup(bus_idx: int = -1) -> void:
	if bus_idx < 0:
		bus_idx = AudioServer.get_bus_index("AssemblyMic")
		if bus_idx < 0:
			AudioServer.add_bus()
			bus_idx = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_idx, "AssemblyMic")
			AudioServer.set_bus_send(bus_idx, "Master")
			var an := AudioEffectSpectrumAnalyzer.new()
			an.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_4096
			an.buffer_length = 0.5
			AudioServer.add_bus_effect(bus_idx, an, 0)
			AudioServer.set_bus_volume_db(bus_idx, -80.0)   # analysed, never heard (no feedback)
	bus = bus_idx
	spec = AudioServer.get_bus_effect_instance(bus, 0)
	_bin = AudioServer.get_mix_rate() / FFT
	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = AudioServer.get_bus_name(bus)
	add_child(player)


func start() -> void:
	if not player.playing:
		player.play()
	active = true


func stop() -> void:
	active = false
	midi = 0.0
	player.stop()


func loud() -> bool:
	return active and level_db > gate_db + 8.0


func _mag(f0: float, f1: float) -> float:
	var v := spec.get_magnitude_for_frequency_range(f0, f1, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX)
	return max(v.x, v.y)


func _process(delta: float) -> void:
	if not active or spec == null:
		return
	_acc += delta
	if _acc < 1.0 / 30.0:
		return
	_acc = 0.0
	var lv := spec.get_magnitude_for_frequency_range(80.0, 3500.0, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
	level_db = linear_to_db(max(lv.x, lv.y) + 1e-9)
	if level_db < gate_db:
		midi = 0.0
		_hist.clear()
		return
	var best := -1e9
	var bm := 0.0
	var m := 40.0
	while m <= 96.0:
		var f := 440.0 * pow(2.0, (m - 69.0) / 12.0)
		var s := 0.0
		for h in range(1, 5):
			var fh := f * h
			var w: float = max(_bin * 0.5, fh * 0.015)
			s += log(_mag(fh - w, fh + w) + 1e-7) * (1.0 if h == 1 else 0.8)
		if s > best:
			best = s
			bm = m
		m += 0.5
	# refine on the strongest harmonic (finer relative resolution higher up)
	var f0 := 440.0 * pow(2.0, (bm - 69.0) / 12.0)
	var hb := 1
	var mb := 0.0
	for h in range(1, 6):
		var mh := _mag(f0 * h * 0.985, f0 * h * 1.015)
		if mh > mb:
			mb = mh
			hb = h
	var fc := f0 * hb
	var num := 0.0
	var den := 0.0
	var k := int((fc * 0.97) / _bin)
	var k1 := int((fc * 1.03) / _bin) + 1
	while k <= k1:
		var fk := k * _bin
		var mk := _mag(fk - _bin * 0.5, fk + _bin * 0.5)
		num += fk * mk
		den += mk
		k += 1
	var refined := bm
	if den > 0.0:
		var fr := num / den / hb
		var mr := 69.0 + 12.0 * log(fr / 440.0) / log(2.0)
		if abs(mr - bm) < 0.75:
			refined = mr
	_hist.append(refined)
	if _hist.size() > 3:
		_hist.pop_front()
	var sorted := _hist.duplicate()
	sorted.sort()
	midi = sorted[sorted.size() / 2]


# 0 silent .. 1 singing out loud
func energy() -> float:
	if not active:
		return 0.0
	return clampf((level_db - gate_db) / 30.0, 0.0, 1.0)
