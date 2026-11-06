extends Node

# ============================================================
# Score recorder — writes down what every body in the world does during the hour,
# so the hour can be read back as a score (score/dove_man_score.html).
#
# It only watches; it never changes the world. One sample a second of positions,
# speeds and states, plus every event at its exact moment: Godzilla's footfalls,
# each mannequin and dinosaur step, falls and risings, car impacts.
#
# Saved when the hour ends (or when you stop the scene) to
#   res://dove_man/scores/score_YYYY-MM-DD_HHMM.json   (running from the editor)
#   user://dove_man_scores/...                         (exported build)
# ============================================================

var world: Node3D
var dt: float = 1.0
var next_sample: float = 0.0
var started: String = ""
var saved: bool = false

var T: Array = []
var env: Dictionary = {"sun_elev": [], "fog": [], "phase": []}
var dove: Dictionary = {"rocks": []}
var dinos: Array = []
var mannequins: Array = []
var camels: Array = []
var gz: Dictionary = {"r": [], "fade": [], "steps": []}
var cars: Array = []
var seen_cars: Array = []
var birds: Dictionary = {"count": [], "flocks": []}
var boeing: Dictionary = {"r": [], "a": [], "alt": []}
var last_quake_t: float = -1.0


func setup(w: Node3D) -> void:
	world = w
	var S: Dictionary = world.D.get("score", {})
	dt = float(S.get("sample_s", 1.0))
	var now: Dictionary = Time.get_datetime_dict_from_system()
	started = "%04d-%02d-%02d_%02d%02d" % [now.year, now.month, now.day, now.hour, now.minute]
	for d in world.dinos:
		dinos.append({"name": String(d["root"].name), "h": d["h"], "r": [], "a": [], "v": [], "steps": [], "_s": floor(d["step"] * 2.0)})
	for m in world.mannequins:
		mannequins.append({"group": m["group"], "h": m["height"], "r": [], "a": [], "v": [], "down": [],
			"steps": [], "falls": [], "rises": [], "_s": floor(m["step"]), "_f": false})
	for c in world.camels:
		camels.append({"name": String(c.name), "h": c.height, "r": [], "a": [], "v": [], "mood": []})


func _process(_delta: float) -> void:
	if world == null:
		return
	var t: float = world.t
	events(t)
	if t >= next_sample:
		next_sample += dt
		sample(t)


# things that happen at a precise moment
func events(t: float) -> void:
	for i in world.dinos.size():
		var d: Dictionary = world.dinos[i]
		var s: float = floor(d["step"] * 2.0)           # one footfall pair every half stride
		if s != dinos[i]["_s"]:
			dinos[i]["_s"] = s
			dinos[i]["steps"].append(snappedf(t, 0.01))
	for i in world.mannequins.size():
		var m: Dictionary = world.mannequins[i]
		var rec: Dictionary = mannequins[i]
		var s2: float = floor(m["step"])
		if s2 != rec["_s"]:
			rec["_s"] = s2
			rec["steps"].append(snappedf(t, 0.01))
		var f: bool = m.get("fallen", false)
		if f and not rec["_f"]:
			rec["falls"].append(snappedf(t, 0.01))
		if not f and rec["_f"]:
			rec["rises"].append(snappedf(t, 0.01))
		rec["_f"] = f
	# Godzilla's footfalls: the step quakes (reach of a step)
	var step_reach: float = float(world.D["quake"]["step"]["reach"])
	for q in world.quakes:
		if q["t"] > last_quake_t and is_equal_approx(float(q["reach"]), step_reach):
			var gp: Vector2 = q["pos"]
			gz["steps"].append([snappedf(q["t"], 0.01), snappedf(gp.length(), 0.1), snappedf(gz_fade(), 0.01)])
	for q in world.quakes:
		last_quake_t = maxf(last_quake_t, float(q["t"]))
	# car impacts
	for c in world.cars:
		if c["impacted"] and not seen_cars.any(func(x): return is_same(x, c)):
			seen_cars.append(c)
			var p: Vector2 = c["pos"]
			cars.append([snappedf(t, 0.01), snappedf(p.length(), 0.1), snappedf(atan2(p.y, p.x), 0.001)])
	if seen_cars.size() > 40:
		seen_cars = seen_cars.slice(seen_cars.size() - 20)


func gz_fade() -> float:
	if world.gz.is_empty() or world.gz["state"] == 0:
		return 0.0
	var F: Dictionary = world.D["godzilla"]["fade"]
	var r: Node3D = world.gz["root"]
	return 1.0 - smoothstep(float(F["full_m"]), float(F["gone_m"]), Vector2(r.position.x, r.position.z).length())


func polar(p: Vector2, rec: Dictionary) -> void:
	rec["r"].append(snappedf(p.length(), 0.1))
	rec["a"].append(snappedf(atan2(p.y, p.x), 0.001))


func sample(t: float) -> void:
	T.append(snappedf(t, 0.01))
	env["sun_elev"].append(snappedf(world.timeline_value("sun_elev"), 0.1))
	env["fog"].append(snappedf(world.timeline_value("fog_density"), 0.00001))
	env["phase"].append(String(world.TL.get("name", "")))
	dove["rocks"].append(world.falling_rocks.rocks.size() if world.falling_rocks != null else 0)
	for i in world.dinos.size():
		var d: Dictionary = world.dinos[i]
		polar(d["pos"], dinos[i])
		dinos[i]["v"].append(snappedf(d["speed"], 0.01))
	for i in world.mannequins.size():
		var m: Dictionary = world.mannequins[i]
		polar(m["pos"], mannequins[i])
		mannequins[i]["v"].append(snappedf(m["speed"], 0.01))
		mannequins[i]["down"].append(1 if m.get("fallen", false) else 0)
	for i in world.camels.size():
		var c: Node3D = world.camels[i]
		polar(c.pos, camels[i])
		camels[i]["v"].append(snappedf(c.speed, 0.01))
		camels[i]["mood"].append(String(c.mood).substr(0, 1))     # w wander, g graze, s stand, f flee
	if world.gz.is_empty() or world.gz["state"] == 0:
		gz["r"].append(-1)
		gz["fade"].append(0)
	else:
		var gr: Node3D = world.gz["root"]
		gz["r"].append(snappedf(Vector2(gr.position.x, gr.position.z).length(), 0.1))
		gz["fade"].append(snappedf(gz_fade(), 0.01))
	# birds: one entry per flock — members, distance from Dove Man, altitude, how many perched
	var fl: Dictionary = {}
	for b in world.birds.birds:
		var id: int = b["flock"]
		if not fl.has(id):
			fl[id] = [0, Vector3.ZERO, 0]
		fl[id][0] += 1
		fl[id][1] += (b["node"] as Node3D).global_position
		if b["state"] == 2:          # PERCHED
			fl[id][2] += 1
	var flocks: Array = []
	for id in fl:
		var c3: Vector3 = fl[id][1] / float(fl[id][0])
		flocks.append([id, fl[id][0], snappedf(Vector2(c3.x, c3.z).length(), 0.1), snappedf(c3.y, 0.1), fl[id][2]])
	birds["count"].append(world.birds.birds.size())
	birds["flocks"].append(flocks)
	if not world.boeing.is_empty():
		var bp: Vector3 = (world.boeing["orbit"] as Node3D).position
		boeing["r"].append(snappedf(Vector2(bp.x, bp.z).length(), 0.1))
		boeing["a"].append(snappedf(atan2(bp.z, bp.x), 0.001))
		boeing["alt"].append(snappedf(bp.y, 0.1))


func _exit_tree() -> void:
	save()


func save() -> void:
	if saved or world == null or T.size() < 60:
		return
	saved = true
	for d in dinos:
		d.erase("_s")
	for m in mannequins:
		m.erase("_s")
		m.erase("_f")
	var phases: Array = []
	for k in world.D["timeline"]["keys"]:
		phases.append({"min": k["min"], "name": k["name"]})
	var out: Dictionary = {
		"meta": {"world": "TAGANT — Dove Man", "recorded": started, "duration_s": T[T.size() - 1], "sample_s": dt,
			"godzilla_contacts": world.D["godzilla"]["contacts"], "crater_fill_s": float(world.D["cars"]["crater"]["fill_delay_s"]) + float(world.D["cars"]["crater"]["fill_s"])},
		"phases": phases, "t": T, "env": env, "dove": dove, "dinos": dinos, "mannequins": mannequins,
		"camels": camels, "godzilla": gz, "cars": cars, "birds": birds, "boeing": boeing}
	var dir: String = "res://dove_man/scores/" if OS.has_feature("editor") else "user://dove_man_scores/"
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir + "score_" + started + ".json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Dove Man score: could not write " + path)
		return
	f.store_string(JSON.stringify(out))
	f.close()
	print("Dove Man score saved: ", ProjectSettings.globalize_path(path))
