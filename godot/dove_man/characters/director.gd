extends Node

# ============================================================
# The cinematic director.
#
# Long, slow, composed shots through the haze. The camera keeps a respectful
# distance from animated bodies (telephoto, low, atmospheric), so their small
# inconsistencies are never in close-up. From time to time it stands among
# things at human eye level. Shots are chosen from what is happening in the
# world (Godzilla crossing, a car about to fall, calm) and paced by the hour.
#
# Shot types:
#   wide_orbit     slow circle far from Dove Man, telephoto, looking up at him
#   dolly          lateral glide at mid distance, low, through the heat haze
#   crane          a slow rise from the sand to the height of his chest
#   horizon        lens almost on the sand, very long lens: ripples, compressed giants
#   follow         tracking alongside Godzilla from far, Dove Man behind him
#   event          a wide view of the place where a car is about to fall
#   human          standing at eye level, still, breathing slightly
#   high           a high distant look down over the whole stage (rare)
# ============================================================

var world: Node3D
var cam: Camera3D
var attrs: CameraAttributesPractical
var fade: ColorRect
var r: RandomNumberGenerator = RandomNumberGenerator.new()

var shot: Dictionary = {}
var shot_t: float = 0.0
const FADE_OUT_S: float = 0.45     # shot → dust
const FADE_IN_S: float = 0.6       # dust → next shot
const FADE_PEAK: float = 0.88      # how white the dust gets between shots
var fading: float = 0.0           # >0 while a fade is running
var fade_dir: int = 0
var pending: Dictionary = {}
var shots_since_human: int = 0
var last_types: Array = []
var shake_ph: Array = []


func setup(w: Node3D) -> void:
	world = w
	r.randomize()
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.near = 0.3
	world.add_child(cam)
	attrs = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 650.0
	attrs.dof_blur_far_transition = 400.0
	attrs.dof_blur_amount = 0.06
	cam.attributes = attrs
	cam.current = true
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	world.add_child(layer)
	fade = ColorRect.new()
	fade.color = Color(0.86, 0.78, 0.66, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	for i in 5:
		shake_ph.append(r.randf_range(0.0, TAU))
	shot = plan_shot()
	start(shot)
	cam.global_transform = frame_shot(shot, 0.0)   # in place from the very first frame
	fade.color.a = 1.0
	fading = 1.0
	fade_dir = -1


# ------------------------------------------------------------ choosing shots
func plan_shot() -> Dictionary:
	# plan, then look through the lens at the start, middle and end before committing
	var s: Dictionary = {}
	for attempt in 30:
		s = plan_one()
		var ok: bool = true
		for f in [0.0, 0.5, 1.0]:
			var st: float = s["len"] * f
			if s["kind"] == "follow" or s["kind"] == "event":
				st = 0.0
			if shot_is_bad(s, frame_shot(s, st), true):
				ok = false
				break
		if ok:
			return s
	if OS.get_environment("DM_PROBE") != "":
		print("PLAN FALLBACK")
	# nothing clean: a high distant look is always safe
	s = {"kind": "high", "len": r.randf_range(22.0, 34.0), "pos2": Vector2.from_angle(r.randf_range(0.0, TAU)) * 200.0,
		"height": 150.0, "fov": 40.0, "spin": 0.003}
	return s


func plan_one() -> Dictionary:
	var gz: Dictionary = world.gz
	# still (tripod) and moving shots in about equal measure
	var weights: Dictionary = {"fixed": 4.5, "horizon": 2.2, "wide_orbit": 2.0, "dolly": 2.6, "crane": 1.8, "zenith": 1.6,
		"high": 0.5, "flock": 0.0, "human": 0.0, "follow": 0.0, "event": 0.0, "tawaf": 0.0}
	var nb: int = world.birds.birds.size() if world.birds != null else 0
	if nb >= 7:
		weights["flock"] = 1.0 + minf(float(nb) / 25.0, 2.0)
	if not pilgrims_standing("middle").is_empty():
		weights["tawaf"] = 1.8
	if shots_since_human >= 4:
		weights["human"] = 2.0 + float(shots_since_human - 4) * 1.0
	if not gz.is_empty() and gz["state"] == 2 and gz_on_stage():
		weights["follow"] = 5.0
	var drop: Dictionary = world.next_car_drop()
	if not drop.is_empty() and drop["eta"] > 3.0 and drop["eta"] < 14.0:
		weights["event"] = 8.0
	for lt in last_types:
		if weights.has(lt):
			weights[lt] *= 0.25
	var total: float = 0.0
	for k in weights:
		total += weights[k]
	var pick: float = r.randf() * total
	var kind: String = "wide_orbit"
	for k in weights:
		pick -= weights[k]
		if pick <= 0.0:
			kind = k
			break
	last_types.append(kind)
	if last_types.size() > 2:
		last_types.pop_front()
	shots_since_human = 0 if kind == "human" else shots_since_human + 1
	var pace: float = world.timeline_value("shot_length")
	var s: Dictionary = {"kind": kind, "len": r.randf_range(22.0, 48.0) * pace, "thirds": (1.0 if r.randf() < 0.5 else -1.0) * r.randf_range(0.6, 1.0)}
	match kind:
		"fixed":
			# a locked-off tripod: nothing moves but the world
			var af: float = r.randf_range(0.0, TAU)
			s["pos2"] = Vector2(cos(af), sin(af)) * r.randf_range(150.0, 380.0)
			s["height"] = r.randf_range(1.2, 16.0)
			s["look"] = Vector3(r.randf_range(-25, 25), r.randf_range(45.0, 90.0), r.randf_range(-25, 25))
			s["fov"] = 30.0
			s["fit"] = r.randf() < 0.7
			if not s["fit"]:
				s["fov"] = r.randf_range(18.0, 28.0)
		"zenith":
			# straight above Dove Man: his axis is the centre of the frame, the world turns around it
			s["height"] = r.randf_range(420.0, 560.0)
			s["fov"] = r.randf_range(50.0, 58.0)
			s["spin"] = r.randf_range(0.0025, 0.005) * (1.0 if r.randf() < 0.5 else -1.0)
			s["a0"] = r.randf_range(0.0, TAU)
			s["len"] = maxf(s["len"], 34.0)
		"flock":
			s["flock"] = r.randi_range(0, maxi(world.birds.flocks.size() - 1, 0))
			s["dist"] = r.randf_range(70.0, 110.0)
			s["side"] = 1.0 if r.randf() < 0.5 else -1.0
			s["fov"] = r.randf_range(30.0, 40.0)
			s["len"] = r.randf_range(20.0, 32.0)
		"wide_orbit":
			s["radius"] = r.randf_range(290.0, 370.0)
			s["a0"] = r.randf_range(0.0, TAU)
			s["spin"] = r.randf_range(0.003, 0.006) * (1.0 if r.randf() < 0.5 else -1.0)
			s["height"] = r.randf_range(2.0, 14.0)
			s["look_h"] = r.randf_range(55.0, 95.0)
			s["fit"] = true
			s["fov"] = 30.0
		"dolly":
			var a: float = r.randf_range(0.0, TAU)
			var d: float = r.randf_range(150.0, 300.0)
			s["origin"] = Vector2(cos(a), sin(a)) * d
			s["side"] = Vector2(-sin(a), cos(a)) * (1.0 if r.randf() < 0.5 else -1.0)
			s["speed"] = r.randf_range(0.6, 1.5)
			s["height"] = r.randf_range(2.0, 12.0)
			s["look"] = Vector3(r.randf_range(-20, 20), r.randf_range(40.0, 80.0), r.randf_range(-20, 20))
			s["fov"] = r.randf_range(26.0, 38.0)
			s["fit"] = true
		"crane":
			var a2: float = r.randf_range(0.0, TAU)
			s["pos2"] = Vector2(cos(a2), sin(a2)) * r.randf_range(140.0, 220.0)
			s["h0"] = r.randf_range(1.5, 4.0)
			s["h1"] = r.randf_range(45.0, 85.0)
			s["fov"] = r.randf_range(32.0, 40.0)
			s["fit"] = true
			s["len"] = maxf(s["len"], 30.0)
		"horizon":
			var a3: float = r.randf_range(0.0, TAU)
			s["pos2"] = Vector2(cos(a3), sin(a3)) * r.randf_range(300.0, 390.0)
			s["height"] = r.randf_range(0.8, 1.4)
			s["fov"] = r.randf_range(16.0, 22.0)
			s["look"] = Vector3(0.0, r.randf_range(40.0, 75.0), 0.0)
			s["drift"] = Vector2(-sin(a3), cos(a3)) * r.randf_range(-0.3, 0.3)
		"high":
			var a4: float = r.randf_range(0.0, TAU)
			s["pos2"] = Vector2(cos(a4), sin(a4)) * r.randf_range(300.0, 380.0)
			s["height"] = r.randf_range(120.0, 170.0)
			s["fov"] = r.randf_range(36.0, 44.0)
			s["spin"] = r.randf_range(-0.004, 0.004)
		"follow":
			s["fov"] = r.randf_range(22.0, 30.0)
			s["offset"] = r.randf_range(170.0, 240.0)
			s["height"] = r.randf_range(3.0, 18.0)
			s["len"] = r.randf_range(30.0, 55.0) * pace
		"event":
			s["drop"] = drop
			var p: Vector2 = drop["pos"]
			var away: Vector2 = (p - Vector2.ZERO).normalized().rotated(r.randf_range(-1.2, 1.2))
			s["pos2"] = p + away * r.randf_range(150.0, 210.0)
			s["height"] = r.randf_range(4.0, 14.0)
			s["fov"] = r.randf_range(24.0, 32.0)
			s["len"] = drop["eta"] + r.randf_range(12.0, 18.0)
		"tawaf":
			# walk with the outer circle of mannequins, at eye height, just outside their ring
			var ps: Array = pilgrims_standing("middle")
			s["who"] = ps[r.randi_range(0, ps.size() - 1)]
			s["out"] = r.randf_range(22.0, 40.0)
			s["ahead"] = r.randf_range(-0.10, 0.22)       # radians ahead of (or behind) the walker
			s["height"] = r.randf_range(1.5, 3.2)
			s["fov"] = r.randf_range(34.0, 46.0)
			s["mix"] = r.randf_range(0.25, 0.55)          # how much the lens leans toward Dove Man
			s["len"] = r.randf_range(24.0, 40.0)
		"human":
			s["pos2"] = world.random_free_target(r, 4.0, 105.0, 190.0)
			s["fov"] = r.randf_range(48.0, 58.0)
			s["len"] = r.randf_range(20.0, 34.0)
			# look at what matters: Godzilla if he is up, otherwise Dove Man's chest
			if not gz.is_empty() and gz["state"] != 0:
				s["track_gz"] = true
			s["look"] = Vector3(r.randf_range(-15, 15), r.randf_range(55.0, 90.0), r.randf_range(-15, 15))
	return s


# ------------------------------------------------------------ framing each frame
func frame_shot(s: Dictionary, st: float) -> Transform3D:
	var pos: Vector3
	var look: Vector3 = Vector3(0.0, 60.0, 0.0)
	match s["kind"]:
		"fixed":
			pos = Vector3(s["pos2"].x, 0.0, s["pos2"].y)
			pos.y = ground_clear(pos, s["height"])
			look = s["look"]
		"zenith":
			var yaw: float = s["a0"] + s["spin"] * st
			return Transform3D(Basis.from_euler(Vector3(-PI * 0.5, yaw, 0.0), EULER_ORDER_YXZ), Vector3(0.0, s["height"], 0.0))
		"flock":
			var fc: Vector3 = world.birds.flock_centre(s["flock"])
			if not s.has("smooth"):
				s["smooth"] = fc
			s["smooth"] = (s["smooth"] as Vector3).lerp(fc, 0.12)
			var c3: Vector3 = s["smooth"]
			# stand on the outside of the flock, never between it and the mountain
			var out2: Vector2 = Vector2(c3.x, c3.z).normalized().rotated(0.45 * s["side"])
			pos = c3 + Vector3(out2.x, 0.0, out2.y) * s["dist"]
			pos.y = maxf(c3.y - 12.0, ground_clear(pos, 2.0))
			look = c3
			var trf: Transform3D = Transform3D(Basis.IDENTITY, pos).looking_at(look, Vector3.UP)
			return trf
		"wide_orbit":
			var a: float = s["a0"] + s["spin"] * st
			pos = Vector3(cos(a) * s["radius"], 0.0, sin(a) * s["radius"])
			pos.y = ground_clear(pos, s["height"])
			look = Vector3(0.0, s["look_h"], 0.0)
		"dolly":
			var p2: Vector2 = s["origin"] + s["side"] * s["speed"] * st
			pos = Vector3(p2.x, 0.0, p2.y)
			pos.y = ground_clear(pos, s["height"])
			look = s["look"]
		"crane":
			var u: float = smoothstep(0.0, 1.0, st / s["len"])
			pos = Vector3(s["pos2"].x, 0.0, s["pos2"].y)
			pos.y = ground_clear(pos, lerpf(s["h0"], s["h1"], u))
			look = Vector3(0.0, lerpf(40.0, 95.0, u), 0.0)
		"horizon":
			var p3: Vector2 = s["pos2"] + s["drift"] * st
			pos = Vector3(p3.x, 0.0, p3.y)
			pos.y = ground_clear(pos, s["height"])
			look = s["look"]
		"high":
			var p4: Vector2 = s["pos2"].rotated(s["spin"] * st)
			pos = Vector3(p4.x, s["height"], p4.y)
			look = Vector3(0.0, 20.0, 0.0)
		"follow":
			var gz: Dictionary = world.gz
			var groot: Node3D = gz["root"]
			var g2: Vector2 = Vector2(groot.position.x, groot.position.z)
			var dir: Vector2 = gz["dir"]
			var n: Vector2 = Vector2(-dir.y, dir.x)
			# stand on the far side of his path, so Dove Man stays behind him
			if n.dot(-g2) > 0.0:
				n = -n
			var p5: Vector2 = g2 + n * s["offset"] - dir * 40.0
			pos = Vector3(p5.x, 0.0, p5.y)
			pos.y = ground_clear(pos, s["height"])
			look = Vector3(g2.x, groot.position.y + 32.0, g2.y)
		"event":
			pos = Vector3(s["pos2"].x, 0.0, s["pos2"].y)
			pos.y = ground_clear(pos, s["height"])
			var dp: Vector2 = s["drop"]["pos"]
			look = Vector3(dp.x, world.sand_height(dp.x, dp.y) + 25.0, dp.y)
		"tawaf":
			var m: Dictionary = s["who"]
			var mp: Vector2 = m["pos"]
			if not s.has("ang"):
				s["ang"] = atan2(mp.y, mp.x)
			# the camera drifts round with the circle, a little slower than the walkers, never jumps
			s["ang"] = lerp_angle(s["ang"], atan2(mp.y, mp.x), 0.004)
			var ca: float = s["ang"] - s["ahead"]
			var rr: float = mp.length() + s["out"]
			pos = Vector3(cos(ca) * rr, 0.0, sin(ca) * rr)
			pos.y = ground_clear(pos, s["height"])
			var body: Vector3 = Vector3(mp.x, world.sand_height(mp.x, mp.y) + float(m["height"]) * 0.55, mp.y)
			if not s.has("look_s"):
				s["look_s"] = body
			s["look_s"] = (s["look_s"] as Vector3).lerp(body, 0.03)
			look = (s["look_s"] as Vector3).lerp(Vector3(0.0, 45.0, 0.0), s["mix"])
		"human":
			pos = Vector3(s["pos2"].x, 0.0, s["pos2"].y)
			pos.y = ground_clear(pos, 1.65)
			look = s["look"]
			if s.get("track_gz", false) and not world.gz.is_empty() and world.gz["state"] != 0:
				var gr: Node3D = world.gz["root"]
				look = look.lerp(Vector3(gr.position.x, gr.position.y + 35.0, gr.position.z), 0.7)
			# breathing
			pos.y += sin(st * 1.3) * 0.012
			look += Vector3(sin(st * 0.37) * 0.25, sin(st * 0.29) * 0.18, 0.0)
	return compose(s, pos, look)


# Horizon low in the frame, subject on a third. Only the high shot may look down.
func compose(s: Dictionary, pos: Vector3, look: Vector3) -> Transform3D:
	var fov: float = s.get("fov", 30.0)
	var to: Vector3 = look - pos
	var flat: float = Vector2(to.x, to.z).length()
	if s.get("fit", false):
		# choose the lens so his whole height stands in the frame with sand below
		var need: float = atan((185.0 - pos.y) / maxf(flat, 1.0))
		fov = clampf(rad_to_deg(need * 1.12 / 1.55) * 2.0, 18.0, 62.0)
		s["fov"] = fov
	var hv: float = deg_to_rad(fov) * 0.5
	var hh: float = atan(tan(hv) * 1.78)
	var yaw: float = atan2(-to.x, -to.z) + s.get("thirds", 0.0) * hh / 3.0
	var pitch: float = atan2(to.y, flat)
	if s["kind"] == "human":
		pitch = clampf(pitch, -hv * 0.3, hv * 0.9)      # on foot we look up at the giant
	elif s["kind"] != "high":
		pitch = clampf(pitch, -hv * 0.3, hv * 0.55)
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0), EULER_ORDER_YXZ), pos)


func pilgrims_standing(group: String) -> Array:
	var out: Array = []
	for m in world.mannequins:
		if m.get("group", "") == group and not m.get("fallen", false):
			out.append(m)
	return out


func gz_on_stage() -> bool:
	var g: Node3D = world.gz["root"]
	return Vector2(g.position.x, g.position.z).length() < 420.0


func ground_clear(p: Vector3, above: float) -> float:
	var floor_y: float = -1e9
	for off in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		floor_y = maxf(floor_y, world.sand_height(p.x + off.x, p.z + off.y))
	return floor_y + maxf(above, 0.8)


# Too close to an animated body, inside something, or the subject is gone: end the shot.
func shot_is_bad(s: Dictionary, tr: Transform3D, strict: bool = false) -> bool:
	var p2: Vector2 = Vector2(tr.origin.x, tr.origin.z)
	if s["kind"] == "follow" and (world.gz.is_empty() or world.gz["state"] != 2 or not gz_on_stage()):
		return true
	if s["kind"] == "zenith":
		return false
	var k: float = 1.0 if strict else 0.4
	for c in world.camels:
		if p2.distance_to(c.pos) < c.height * (2.2 if strict else 1.2):
			return true
	for d in world.dinos:
		if p2.distance_to(d["pos"]) < d["h"] * (1.6 if strict else 0.9):
			return true
	for m in world.mannequins:
		if p2.distance_to(m["pos"]) < m["height"] * (2.0 if strict else 1.0):
			return true
	if not world.gz.is_empty() and world.gz["state"] != 0:
		var g: Node3D = world.gz["root"]
		if p2.distance_to(Vector2(g.position.x, g.position.z)) < (95.0 if strict else 50.0):
			return true
	if p2.length() < 70.0 and tr.origin.y < 190.0:
		return true
	return view_blocked(s, tr, 0.5 if strict else 0.85)


# Something big and close sits in the frame (a dino tail across a long lens,
# a rock camel filling the corner): the shot would read as a mistake.
func view_blocked(s: Dictionary, tr: Transform3D, limit: float = 0.3) -> bool:
	var fwd: Vector3 = -tr.basis.z
	var tv: float = tan(deg_to_rad(s["fov"]) * 0.5)
	var th: float = tv * 1.78
	var bodies: Array = []
	for c in world.camels:
		bodies.append([Vector3(c.pos.x, world.sand_height(c.pos.x, c.pos.y) + c.height * 0.5, c.pos.y), c.height * 0.9])
	for d in world.dinos:
		var dp: Vector2 = d["pos"]
		bodies.append([Vector3(dp.x, world.sand_height(dp.x, dp.y) + d["h"] * 0.5, dp.y), d["h"] * 0.8])
	for m in world.mannequins:
		var mp: Vector2 = m["pos"]
		bodies.append([Vector3(mp.x, world.sand_height(mp.x, mp.y) + m["height"] * 0.5, mp.y), m["height"] * 0.45])
	for rc in world.rock_camels:
		var h: float = rc.get_meta("height", 3.0)
		bodies.append([rc.global_position + Vector3(0, h * 0.5, 0), h * 0.9])
	for b in bodies:
		var v: Vector3 = b[0] - tr.origin
		var depth: float = v.dot(fwd)
		if depth <= 0.5:
			continue
		var x: float = absf(v.dot(tr.basis.x)) - b[1]
		var y: float = absf(v.dot(tr.basis.y)) - b[1]
		if x > depth * th or y > depth * tv:
			continue
		if b[1] / (depth * tv) > limit:
			return true
	return false


# ------------------------------------------------------------ running
func _process(delta: float) -> void:
	if world == null or world.D.is_empty() or shot.is_empty():
		return
	shot_t += delta
	var tr: Transform3D = frame_shot(shot, shot_t)
	if fade_dir == 0 and (shot_t >= shot["len"] or (shot_t > 10.0 and shot_is_bad(shot, tr))):
		if OS.get_environment("DM_PROBE") != "":
			print("END %s after %.1f/%.1f  reason=%s" % [shot["kind"], shot_t, shot["len"], why(shot, tr)])
		pending = plan_shot()
		# most transitions breathe through the dust, some are hard cuts
		if r.randf() < 0.7:
			fade_dir = 1
			fading = FADE_OUT_S
		else:
			start(pending)
	if fade_dir != 0:
		fading -= delta
		# a quick breath of dust: it never goes fully opaque, never holds
		var dur: float = FADE_OUT_S if fade_dir == 1 else FADE_IN_S
		var u: float = clampf(fading / dur, 0.0, 1.0)
		var a: float = (1.0 - u) if fade_dir == 1 else u
		fade.color.a = FADE_PEAK * a * a * (3.0 - 2.0 * a)
		if fading <= 0.0:
			if fade_dir == 1:
				start(pending)
				fade_dir = -1
				fading = FADE_IN_S
			else:
				fade_dir = 0
				fade.color.a = 0.0
	tr = frame_shot(shot, shot_t)
	# the ground shake reaches the lens (less with long lenses, more on foot)
	var k: float = 1.0 if shot["kind"] == "human" else 0.45
	var Q: Dictionary = world.D["quake"]["camera"]
	var lx: float = 0.0
	var ly: float = 0.0
	var rx: float = 0.0
	var rz: float = 0.0
	for q in world.quakes:
		var age: float = world.t - q["t"]
		if age < 0.0 or age > 5.0:
			continue
		var d: float = Vector2(tr.origin.x, tr.origin.z).distance_to(q["pos"])
		var a: float = q["s"] / (1.0 + pow(d / (q["reach"] * float(Q["reach_scale"]) * 2.0), 2.0)) * exp(-age / float(Q["tau"]))
		ly += a * float(Q["vertical_m"]) * sin(TAU * 9.0 * age + shake_ph[0])
		lx += a * float(Q["lateral_m"]) * sin(TAU * 6.3 * age + shake_ph[1])
		rx += a * deg_to_rad(Q["pitch_deg"]) * sin(TAU * 5.2 * age + shake_ph[3])
		rz += a * deg_to_rad(Q["roll_deg"]) * sin(TAU * 4.4 * age + shake_ph[4])
	cam.fov = shot["fov"]
	cam.global_transform = tr.translated(Vector3(lx, ly, 0.0) * k) * Transform3D(Basis.from_euler(Vector3(rx, 0.0, rz) * k), Vector3.ZERO)


func start(s: Dictionary) -> void:
	shot = s
	shot_t = 0.0
	cam.fov = s["fov"]
	# long lenses get a softer far distance; on foot the far haze is crisper
	attrs.dof_blur_far_enabled = s["kind"] != "zenith"
	attrs.dof_blur_far_distance = 900.0 if s["fov"] < 25.0 else 650.0
	world.fog_view_scale = 0.12 if s["kind"] == "zenith" else 1.0
	attrs.dof_blur_near_enabled = s["kind"] == "horizon"
	attrs.dof_blur_near_distance = 6.0
	attrs.dof_blur_near_transition = 5.0


func shot_name() -> String:
	return shot.get("kind", "-")


func why(s: Dictionary, tr: Transform3D) -> String:
	if shot_t >= s["len"]: return "len"
	var p2: Vector2 = Vector2(tr.origin.x, tr.origin.z)
	if s["kind"] == "follow" and (world.gz.is_empty() or world.gz["state"] != 2): return "gz gone"
	for c in world.camels:
		if p2.distance_to(c.pos) < c.height * 1.2: return "camel near"
	for d in world.dinos:
		if p2.distance_to(d["pos"]) < d["h"] * 0.9: return "dino near"
	if not world.gz.is_empty() and world.gz["state"] != 0:
		var g: Node3D = world.gz["root"]
		if p2.distance_to(Vector2(g.position.x, g.position.z)) < 95.0: return "gz near"
	if p2.length() < 70.0 and tr.origin.y < 190.0: return "dove near"
	if view_blocked(s, tr, 0.8): return "blocked"
	return "?"
