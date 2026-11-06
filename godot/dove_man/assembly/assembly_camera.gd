extends Node3D
## Five ways of looking at the assembly. It cuts by itself with the chant (key 0),
## or hold one view: 1 wide · 2 behind the choir · 3 what the titan sees · 4 the group that sings · 5 from above.

var world: Node3D
var cam: Camera3D
var auto := true
var shot := 1
var shot_t := 0.0
var focus_group := "myna"
var focus_member: Dictionary = {}     # set by a protest song: the leader while it calls
var from := Vector3.ZERO
var to := Vector3.ZERO


func setup(w: Node3D) -> void:
	world = w
	cam = Camera3D.new()
	cam.far = 4000.0
	cam.fov = 52.0
	add_child(cam)
	cam.current = true
	set_shot(1)


func key(code: int) -> void:
	seq_i = -1                   # any camera key ends the opening sequence
	if code >= KEY_1 and code <= KEY_6:
		auto = false
		set_shot(code - KEY_0)
	elif code == KEY_0:
		auto = true


var seq: Array = []          # opening: [{dur, from_a, from_b, to_a, to_b, fov} or {dur, shot}]
var seq_t := 0.0
var seq_i := -1


func play_opening(full: bool, titan_at: float) -> void:
	seq.clear()
	var T := Vector3(world.titan_pos.x, 0.0, world.titan_pos.y)
	var back := -T.normalized()
	var side := Vector3(back.z, 0.0, -back.x)
	var dm := Vector3(0, 70, 0)          # Dove Man
	if full:
		# 1 the desert from high, drifting toward Dove Man
		seq.append({"dur": 9.0, "from_a": Vector3(-520, 190, -430), "from_b": Vector3(-330, 140, -260), "to_a": dm, "to_b": dm, "fov": 50.0})
		# 2 low among the petrified crowds, Dove Man far behind them
		var site: Vector2 = world.frozen_ruins.sites[0].center if world.frozen_ruins != null else Vector2(-400, 300)
		var sp := Vector3(site.x, 0, site.y)
		var g: float = world.sand_height(sp.x, sp.z)
		var dir: Vector3 = (dm - sp).normalized()
		seq.append({"dur": 8.0, "from_a": sp - dir * 30.0 + Vector3(0, g + 3.0, 0), "from_b": sp - dir * 12.0 + Vector3(0, g + 4.0, 0), "to_a": dm, "to_b": dm, "fov": 52.0})
		# 3 Dove Man, from his feet, the palms
		seq.append({"dur": 7.0, "from_a": Vector3(175, 4, -40), "from_b": Vector3(135, 3, -30), "to_a": Vector3(0, 95, 0), "to_b": Vector3(0, 120, 0), "fov": 62.0})
	# 4 the titan comes: seen from the sand in front of it
	seq.append({"dur": 9.0, "shot": 6})
	# 5 the counter view: from the titan, the crowd coming across the desert
	var eye: Vector3 = T - back * 34.0 + side * 14.0 + Vector3(0, 60, 0)      # over the titan's shoulder
	seq.append({"dur": 13.0, "from_a": eye, "from_b": eye + back * 8.0 + Vector3(0, -4, 0), "to_a": T + back * 150.0, "to_b": T + back * 115.0, "fov": 56.0})
	seq_i = 0
	seq_t = 0.0
	start_seq_item()


func start_seq_item() -> void:
	var it: Dictionary = seq[seq_i]
	if it.has("shot"):
		set_shot(int(it.shot))
	else:
		shot = 0
		cam.fov = float(it.fov)


func run_seq(delta: float) -> bool:
	if seq_i < 0:
		return false
	seq_t += delta
	var it: Dictionary = seq[seq_i]
	if seq_t >= float(it.dur):
		seq_i += 1
		seq_t = 0.0
		if seq_i >= seq.size():
			seq_i = -1
			set_shot(1)
			return false
		start_seq_item()
		it = seq[seq_i]
	if it.has("shot"):
		place(0.0)
		return true
	var u: float = seq_t / float(it.dur)
	u = u * u * (3.0 - 2.0 * u)
	var p: Vector3 = (it.from_a as Vector3).lerp(it.from_b, u)
	p.y = maxf(p.y, world.sand_height(p.x, p.z) + 1.5)
	cam.position = p + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.4
	shake = maxf(0.0, shake - delta * 2.5)
	cam.look_at((it.to_a as Vector3).lerp(it.to_b, u), Vector3.UP)
	return true


var hold_until := 0.0      # a shot held on purpose (the titan's entrance)

func hold(s: int, seconds: float) -> void:
	set_shot(s)
	hold_until = Time.get_ticks_msec() * 0.001 + seconds


func on_section(section_name: String, groups: Array) -> void:
	if Time.get_ticks_msec() * 0.001 < hold_until or seq_i >= 0:
		return
	for g in groups:
		if g != "all":
			focus_group = g
			break
	if groups.has("all") and groups.size() == 1:
		focus_group = ""
	if not auto:
		set_shot(shot)
		return
	if groups.has("leader"):
		set_shot(4)
	elif groups.has("titan"):
		set_shot([1, 2, 5][attack_view % 3])
		attack_view += 1
	elif groups.has("all"):
		set_shot([1, 3, 5][int(Time.get_ticks_msec() / 1000) % 3])
	elif groups.is_empty():
		set_shot(5)
	elif groups.has("doves"):
		set_shot(1)
	else:
		set_shot(4)


func group_center(g: String) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for m in world.members:
		if m.group == g:
			c += (m.root as Node3D).position
			n += 1
	return c / float(n) if n > 0 else Vector3(world.titan_pos.x * 0.6, 0.0, world.titan_pos.y * 0.6)


var picks: Dictionary = {}
var attack_view := 0

func pick_member(g: String) -> Dictionary:
	# one singer near the middle of the group's arc, a different one each time the group is filmed
	var list: Array = []
	for m in world.members:
		if m.group == g:
			list.append(m)
	if list.is_empty():
		return world.members[0]
	var n: int = picks.get(g, 0)
	picks[g] = n + 1
	list.sort_custom(func(a, b): return absf((a.root as Node3D).position.x) < absf((b.root as Node3D).position.x))
	return list[(n * 3) % mini(list.size(), 9)]


func set_shot(s: int) -> void:
	shot = s
	shot_t = 0.0
	var T := Vector3(world.titan_pos.x, 0.0, world.titan_pos.y)
	var back := -T.normalized()                      # from the titan toward Dove Man
	var side := Vector3(back.z, 0.0, -back.x)
	var crowd := T + back * 90.0
	match s:
		1:  # wide, from the side: the titan, the assembly, Dove Man behind
			from = T + back * 15.0 - side * 235.0 + Vector3(0, 58, 0)
			to = crowd + Vector3(0, 10, 0) + back * 25.0
			cam.fov = 50.0
		2:  # behind the choir, at shoulder height of the giants, toward the titan
			from = T + back * 205.0 + side * 18.0 + Vector3(0, 22, 0)
			to = T + Vector3(0, 30, 0)
			cam.fov = 46.0
		3:  # what the titan sees: the crowd, Dove Man behind them
			from = T + back * 22.0 + Vector3(0, 46, 0)
			to = T + back * 140.0 + Vector3(0, 10, 0)
			cam.fov = 58.0
		4:  # a portrait of one singer of the group that sings now, the titan behind the camera
			var g := focus_group if focus_group != "" else "myna"
			var m: Dictionary = focus_member if not focus_member.is_empty() else pick_member(g)
			var p: Vector3 = (m.root as Node3D).position
			var h: float = float(m.h)
			var f: Vector3 = (T - p).normalized()
			if m.group == "leader":
				f = -f               # the leader faces the crowd: film it from the crowd
			var sd := Vector3(f.z, 0.0, -f.x)
			var reach: float = h * (2.6 if h > 12.0 else 3.4)
			from = p + f * reach + sd * reach * 0.55 + Vector3(0, h * 0.75, 0)
			to = p + Vector3(0, h * 0.62, 0) - sd * h * 0.2
			cam.fov = 42.0
		6:  # from under: on the sand in front of the titan, looking up at it
			from = T + back * 17.0 + side * 7.0
			from.y = world.sand_height(from.x, from.z) + 1.1
			to = T + Vector3(0, 38, 0)
			cam.fov = 74.0
		5:  # from above
			from = crowd + back * 40.0 + Vector3(0, 300, 0)
			to = crowd + Vector3(0, 0, 0) - back * 20.0
			cam.fov = 55.0
	place(0.0)


var shake := 0.0

func kick(amount: float) -> void:
	shake = maxf(shake, amount)


func place(k: float) -> void:
	if shot == 6:
		# stay low and fixed, keep the titan in frame while it comes
		var head: Vector3 = (world.gz.root as Node3D).position + Vector3(0, 36, 0)
		cam.position = from + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.35
		cam.look_at(head, Vector3.UP)
		shake = maxf(0.0, shake - get_process_delta_time() * 2.5)
		return
	# a slow push and drift so no view is frozen
	var push := (to - from).normalized() * k * 10.0
	var drift := Vector3(sin(k * 0.7), 0.0, cos(k * 0.6)) * k * 2.0
	var p := from + push + drift + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.6
	shake = maxf(0.0, shake - get_process_delta_time() * 2.5)
	var ground: float = world.sand_height(p.x, p.z) + 2.0
	p.y = maxf(p.y, ground)
	cam.position = p
	cam.look_at(to, Vector3.UP)


func _process(delta: float) -> void:
	if run_seq(delta):
		return
	shot_t += delta
	place(minf(shot_t / 14.0, 1.6))
