extends Control
## The karaoke lane as a scientific instrument: a log-frequency spectrogram of the animal's Pd voice
## (50 Hz - 9 kHz, 72 dB, TAGANT palette: oil black -> indigo -> poppy red -> ochre -> salt white),
## scrolling right to left past the "now" line, with
##  - the tracked pitch of the animal (thin salt-white trace) on the same frequency axis,
##  - the singer's voice in poppy red (gold where in tune; scoring folds octaves, the drawing does not),
##  - frequency axis in Hz with note names, time axis in seconds, a dB colour bar.
## segments: [{"at": lane time where the segment starts, "from": song time, "to": song time, "alpha": 0..1}]

const SALT := Color(0.96, 0.95, 0.91)
const RED := Color(0.93, 0.18, 0.10)
const GOLD := Color(1.0, 0.80, 0.32)
const PAST := 3.0
const AHEAD := 6.0
const ML := 74.0      # left margin (frequency labels)
const MB := 22.0      # bottom margin (time labels)
const MT := 22.0      # top margin (title)
const MR := 40.0      # right margin (colour bar)

var data: Dictionary = {}
var spec: Texture2D
var meta: Dictionary = {"pxps": 40.0, "rows": 256, "fmin": 50.0, "fmax": 9000.0, "range_db": 72.0}
var shift := 0.0          # kept for the octave-folded scoring (not drawn)
var centre := 60.0
var now := 0.0
var segments: Array = []
var user: Array = []      # Vector3(lane_t, midi, hit)
var region := Vector2(-1, -1)
var caption := ""
var song_title := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_spectrum(id: String) -> void:
	var p := "res://spectra/%s.png" % id
	spec = load(p) if ResourceLoader.exists(p) else null
	var f := FileAccess.open("res://spectra/%s.json" % id, FileAccess.READ)
	if f:
		meta = JSON.parse_string(f.get_as_text())


func _plot() -> Rect2:
	return Rect2(ML, MT, size.x - ML - MR, size.y - MT - MB)


func _x(t: float) -> float:
	var r := _plot()
	return r.position.x + r.size.x * PAST / (PAST + AHEAD) + (t - now) * r.size.x / (PAST + AHEAD)


func _y_hz(f: float) -> float:
	var r := _plot()
	var k := log(clampf(f, meta.fmin, meta.fmax) / meta.fmin) / log(meta.fmax / meta.fmin)
	return r.position.y + r.size.y * (1.0 - k)


static func _hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _font() -> Font:
	return get_theme_default_font()


func _draw() -> void:
	var r := _plot()
	var font := _font()
	var dim := Color(SALT.r, SALT.g, SALT.b, 0.55)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.01, 0.012, 0.86))
	draw_rect(r, Color(0.016, 0.012, 0.024, 1.0))
	var full: bool = Lex.analysis
	# --- spectrogram strips (scientific view only)
	if full and spec and not data.is_empty():
		var pxps: float = meta.pxps
		var rows: float = meta.rows
		for sg in segments:
			var at: float = sg.at
			var t0: float = maxf(sg.from, (now - PAST) - at + sg.from)
			var t1: float = minf(sg.to, (now + AHEAD) - at + sg.from)
			if t1 <= t0:
				continue
			var xa := _x(at + t0 - sg.from)
			var xb := _x(at + t1 - sg.from)
			draw_texture_rect_region(spec, Rect2(xa, r.position.y, xb - xa, r.size.y),
				Rect2(t0 * pxps, 0, (t1 - t0) * pxps, rows), Color(1, 1, 1, sg.alpha))
	# --- loop / phrase region
	if region.x >= 0.0:
		var xa := _x(region.x)
		var xb := _x(region.y)
		draw_rect(Rect2(xa, r.position.y, xb - xa, r.size.y), Color(1, 1, 1, 0.06))
		draw_line(Vector2(xa, r.position.y), Vector2(xa, r.end.y), Color(RED, 0.8), 1.0)
		draw_line(Vector2(xb, r.position.y), Vector2(xb, r.end.y), Color(RED, 0.8), 1.0)
	# --- frequency grid + labels (Hz and note)
	for f in ([] if not full else [100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0]):
		var yy := _y_hz(f)
		draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(1, 1, 1, 0.09), 1.0)
		var lab := ("%d Hz" % int(f)) if f < 1000.0 else ("%d kHz" % int(f / 1000.0))
		draw_string(font, Vector2(6, yy + 5), lab, HORIZONTAL_ALIGNMENT_LEFT, ML - 10, 13, dim)
	for oct in ([] if not full else [3, 4, 5, 6, 7]):          # A3..A7 ticks on the axis
		var yy := _y_hz(_hz(57.0 + 12.0 * (oct - 3)))
		draw_line(Vector2(r.position.x - 6, yy), Vector2(r.position.x, yy), Color(GOLD, 0.6), 1.0)
		draw_string(font, Vector2(r.position.x + 4, yy - 2), "A%d" % oct, HORIZONTAL_ALIGNMENT_LEFT, 28, 10, Color(GOLD, 0.6))
	# --- time grid (seconds)
	var s0 := floori(now - PAST)
	for s in range(s0, s0 + int(PAST + AHEAD) + 2):
		var xx := _x(float(s))
		if xx < r.position.x or xx > r.end.x:
			continue
		draw_line(Vector2(xx, r.end.y), Vector2(xx, r.end.y + 5), dim, 1.0)
		draw_line(Vector2(xx, r.position.y), Vector2(xx, r.end.y), Color(1, 1, 1, 0.035), 1.0)
		if full:
			draw_string(font, Vector2(xx + 3, size.y - 5), "%ds" % s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	# --- the animal's tracked pitch
	if not data.is_empty():
		var midi: PackedFloat32Array = data.midi
		var hop: float = data.hop
		for sg in segments:
			var at: float = sg.at
			var t0: float = maxf(sg.from, (now - PAST) - at + sg.from)
			var t1: float = minf(sg.to, (now + AHEAD) - at + sg.from)
			if t1 <= t0:
				continue
			var prev := Vector2.ZERO
			var ok := false
			for i in range(int(t0 / hop), mini(int(t1 / hop) + 1, midi.size() - 1)):
				var m: float = midi[i]
				if m <= 0.0:
					ok = false
					continue
				var p := Vector2(_x(at + i * hop - sg.from), _y_hz(_hz(m)))
				if ok and absf(p.y - prev.y) < 18.0:
					draw_line(prev, p, Color(SALT, 0.9 * sg.alpha), 1.6 if full else 3.4, true)
				prev = p
				ok = true
	# --- the singer
	var last := Vector2.ZERO
	var last_ok := false
	for u: Vector3 in user:
		if u.x < now - PAST - 0.1 or u.y <= 0.0:
			last_ok = false
			continue
		var p := Vector2(_x(u.x), _y_hz(_hz(u.y)))
		var col := GOLD if (u.z > 0.5 and full) else RED
		if last_ok and p.x - last.x < 12.0:
			draw_line(last, p, col, 2.6, true)
		draw_circle(p, 2.6 if (u.z < 0.5 or not full) else 4.0, col)
		last = p
		last_ok = true
	# --- now line
	var xn := _x(now)
	draw_line(Vector2(xn, r.position.y - 4), Vector2(xn, r.end.y + 4), Color(SALT, 0.85), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(xn - 5, r.position.y - 8), Vector2(xn + 5, r.position.y - 8), Vector2(xn, r.position.y - 1)]), SALT)
	# --- colour bar (dB)
	if full and spec:
		var cb := Rect2(r.end.x + 12, r.position.y, 10, r.size.y)
		var steps := 32
		for k in steps:
			var v := 1.0 - float(k) / steps
			draw_rect(Rect2(cb.position.x, cb.position.y + cb.size.y * k / steps, cb.size.x, cb.size.y / steps + 1), _ramp(v))
		draw_string(font, Vector2(cb.position.x - 4, cb.position.y - 6), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dim)
		draw_string(font, Vector2(cb.position.x - 8, cb.end.y + 14), "-%d" % int(meta.range_db), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, dim)
	# --- frame: thin double line with sigil ticks at the corners
	draw_rect(r, Color(SALT, 0.35), false, 1.0)
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		draw_circle(c, 2.5, RED)
	# --- title
	if not full:
		if caption != "":
			draw_string(font, Vector2(r.position.x + 10, r.position.y + 22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SALT)
		return
	var title := "SPECTROGRAM  ·  log f 50 Hz – 9 kHz  ·  72 dB  ·  %s" % song_title
	draw_string(font, Vector2(ML, 15), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 13, Color(SALT, 0.7))
	if caption != "":
		draw_string(font, Vector2(r.position.x + 10, r.position.y + 22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SALT)


func _ramp(v: float) -> Color:
	var stops := [[0.0, Color8(4, 3, 6)], [0.22, Color8(28, 14, 48)], [0.45, Color8(120, 16, 22)], [0.64, Color8(205, 40, 22)],
		[0.80, Color8(226, 140, 60)], [0.92, Color8(240, 214, 160)], [1.0, Color8(250, 248, 240)]]
	for i in stops.size() - 1:
		if v <= stops[i + 1][0]:
			var t: float = (v - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
			return (stops[i][1] as Color).lerp(stops[i + 1][1], t)
	return stops[-1][1]


func _process(_d: float) -> void:
	queue_redraw()
