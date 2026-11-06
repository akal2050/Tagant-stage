extends Control
## The karaoke screen of the assembly: the songs on the left, and at the bottom the lane:
## the leader's phrase as a loudness contour, the moving cursor, and your voice drawn over it
## when it is your turn. Right of the lane: your voice and how well the crowd follows you.

var world: Node3D
var buttons: Array = []
var font: Font
const Tr = preload("res://dove_man/assembly/tr.gd")
const AMBER := Color(1.0, 0.72, 0.32)
const PALE := Color(1.0, 0.95, 0.86)
const GREEN := Color(0.55, 0.95, 0.7)


func setup(w: Node3D) -> void:
	world = w
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = Tr.font()
	var th := Theme.new()
	th.default_font = font
	theme = th
	var title := Label.new()
	title_label = title
	title.text = Tr.t("THE ASSEMBLY · claiming water")
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(PALE, 0.75))
	add_child(title)
	var y := 44.0
	for i in world.A.songs.size():
		var s: Dictionary = world.A.songs[i]
		var b := Button.new()
		b.text = "%d · %s" % [i + 1, song_title(i)]
		b.tooltip_text = s.sub_ar if Tr.ar() else s.sub
		b.position = Vector2(26, y)
		b.custom_minimum_size = Vector2(230, 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func(): world.start_song(i))
		add_child(b)
		buttons.append(b)
		y += 40.0
	hud_y = y + 14.0
	(world.hud as Label).position = Vector2(28, hud_y)
	(world.hud as Label).add_theme_font_override("font", font)
	if Tr.ar():
		for b in buttons:
			(b as Button).alignment = HORIZONTAL_ALIGNMENT_RIGHT
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		(world.hud as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


var title_label: Label
var hud_y := 0.0

func song_title(i: int) -> String:
	var s: Dictionary = world.A.songs[i]
	return String(s.title_ar) if Tr.ar() else String(s.title)


# Arabic: the song list and texts sit on the right side of the screen
func mirror() -> void:
	if not Tr.ar():
		return
	var vw: float = get_viewport_rect().size.x
	title_label.size.x = 400
	title_label.position = Vector2(vw - 28 - 400, 18)
	for b in buttons:
		(b as Button).position.x = vw - 26 - 230
	var hud: Label = world.hud
	hud.size.x = 700
	hud.position = Vector2(vw - 28 - 700, hud_y)


func set_song(i: int) -> void:
	for k in buttons.size():
		var b: Button = buttons[k]
		b.modulate = Color(1, 1, 1, 1) if k == i else Color(1, 1, 1, 0.55)
		b.text = ("▶ " if k == i else "") + "%d · %s" % [k + 1, song_title(k)]


func _process(_d: float) -> void:
	mirror()
	queue_redraw()


func _draw() -> void:
	var c: Node = world.choir
	if c == null or not c.has_method("lane") or not world.opening_done():
		return
	var L: Dictionary = c.lane()
	var vs: Vector2 = get_viewport_rect().size
	var w: float = minf(860.0, vs.x - 260.0)
	var h := 84.0
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y - h - 34.0), Vector2(w, h))
	draw_rect(r.grow(12.0), Color(0, 0, 0, 0.26))
	var st: String = L.state
	var calling: bool = st == "call"
	var answering: bool = st == "respond"
	var col: Color = AMBER if calling else (PALE if answering else Color(PALE, 0.35))
	# the phrase: a loudness contour, mirrored like a waveform
	var curve: PackedFloat32Array = L.curve
	var n: int = curve.size()
	var top := PackedVector2Array()
	var mid: float = r.position.y + r.size.y * 0.5
	for k in n:
		top.append(Vector2(r.position.x + r.size.x * float(k) / float(n - 1), mid - curve[k] * r.size.y * 0.46))
	for k in range(n - 1, -1, -1):
		top.append(Vector2(r.position.x + r.size.x * float(k) / float(n - 1), mid + curve[k] * r.size.y * 0.46))
	if n > 1 and (calling or answering):
		# drawn as thin vertical strokes (a polygon fails when the phrase is silent)
		for k in n:
			var x: float = r.position.x + r.size.x * float(k) / float(n - 1)
			var hh: float = maxf(curve[k] * r.size.y * 0.46, 0.5)
			draw_line(Vector2(x, mid - hh), Vector2(x, mid + hh), Color(col, 0.35 if answering else 0.55), r.size.x / float(n) + 0.6)
		draw_polyline(top.slice(0, n), Color(col, 0.9), 2.0, true)
	# your voice over it
	var tr: PackedFloat32Array = L.trace
	if tr.size() > 2:
		var total: float = maxf(tr[tr.size() - 1], 1.0)
		for k in tr.size() - 1:
			if tr[k] < 0.03:
				continue
			var x: float = r.position.x + r.size.x * minf(float(k) / total, 1.0)
			draw_line(Vector2(x, mid - tr[k] * r.size.y * 0.46), Vector2(x, mid + tr[k] * r.size.y * 0.46), Color(GREEN, 0.8), 2.0)
	# the cursor
	if calling or answering:
		var x: float = r.position.x + r.size.x * float(L.u)
		draw_line(Vector2(x, r.position.y - 6.0), Vector2(x, r.end.y + 6.0), Color(1, 1, 1, 0.9), 2.0)
	# what to do now
	var say := ""
	match st:
		"gather": say = Tr.t("the crowd is gathering…")
		"call": say = Tr.t("LISTEN")
		"respond": say = Tr.t("YOUR TURN — sing it")
		"attack": say = Tr.t("THE WATER CANNON — keep singing")
		"regroup": say = Tr.t("sing them back together")
		"end": say = Tr.t("ALL TOGETHER")
	draw_string(font, Vector2(r.position.x, r.position.y - 22.0), say, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, AMBER if calling else PALE)
	draw_string(font, Vector2(r.end.x - 160.0, r.position.y - 22.0), Tr.t("round %d / %d") % [L.round, L.rounds], HORIZONTAL_ALIGNMENT_RIGHT, 160, 15, Color(PALE, 0.7))
	# your line: a chant about water in your own language (lyrics_water.txt)
	var ly: String = L.get("lyric", "")
	if ly != "":
		var fs := 44
		var wpx: float = font.get_string_size(ly, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y0: float = r.position.y - 122.0
		draw_string(font, Vector2(vs.x * 0.5 - wpx * 0.5 + 2, y0 + 2), ly, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(vs.x * 0.5 - wpx * 0.5, y0), ly, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PALE)
		# the part already sung lights up with the cursor
		var lit: String = ly.substr(0, int(round(float(ly.length()) * float(L.u))))
		if lit != "":
			var lx: float = vs.x * 0.5 - wpx * 0.5
			if Tr.ar() and ly.unicode_at(0) > 0x590:
				lx = vs.x * 0.5 + wpx * 0.5 - font.get_string_size(lit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x    # right to left
			draw_string(font, Vector2(lx, y0), lit, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GREEN)
		var dy := 30.0
		var un: String = L.get("lyric_under", "")
		if un != "":
			var wu: float = font.get_string_size(un, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			draw_string(font, Vector2(vs.x * 0.5 - wu * 0.5, y0 + 36.0), un, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(AMBER, 0.95))
			dy = 62.0
		var tr2: String = L.get("lyric_tr", "")
		if tr2 != "":
			var w2: float = font.get_string_size(tr2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, Vector2(vs.x * 0.5 - w2 * 0.5, y0 + dy), tr2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(PALE, 0.75))
	var nx: String = L.get("next_lyric", "")
	if nx != "":
		draw_string(font, Vector2(r.position.x + 170.0, r.position.y - 22.0), Tr.t("next, you sing:") + "  " + nx, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(PALE, 0.7))
	# your voice, and the crowd following you
	var bx: float = r.end.x + 30.0
	var bar := Rect2(Vector2(bx, r.position.y), Vector2(14.0, r.size.y))
	draw_rect(bar, Color(1, 1, 1, 0.12))
	var v: float = float(L.voice)
	draw_rect(Rect2(Vector2(bx, bar.end.y - bar.size.y * v), Vector2(14.0, bar.size.y * v)), GREEN)
	draw_string(font, Vector2(bx - 8.0, bar.end.y + 22.0), Tr.t("you") if L.mic else Tr.t("no mic"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(PALE, 0.8))
	draw_string(font, Vector2(r.position.x, r.end.y + 30.0), Tr.t("you sang: %d%%") % int(round(float(L.follow) * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(PALE, 0.75))
