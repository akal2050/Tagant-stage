extends Node3D

# ============================================================
# Pigeon flocks — interactive, never in lockstep.
#
# Each flock follows its own wandering "intention" through the sky (smooth, never
# through Dove Man). Each bird is a boid inside its flock and chooses its own wing
# action: flapping when climbing or accelerating, gliding when level or sinking,
# banking into turns. Flocks sometimes settle on perches — Dove Man's head and
# shoulders, wreck roofs, rock-camel humps, palm crowns — stand there (idle clip),
# and burst into the air when the world shakes, Godzilla comes close or the plane
# passes. A new bird joins every few minutes.
# ============================================================

const FLY: int = 0
const LANDING: int = 1
const PERCHED: int = 2
const TAKEOFF: int = 3

var world: Node3D
var scene: PackedScene
var r: RandomNumberGenerator = RandomNumberGenerator.new()
var cfg: Dictionary
var birds: Array = []
var flocks: Array = []        # {id, goal, wander_t, mode, perch_set, perch_timer}
var growth_timer: float = 0.0


func setup(w: Node3D, c: Dictionary) -> void:
	world = w
	cfg = c
	r.randomize()
	scene = load(c["model_path"])
	for i in int(c["initial"]):
		spawn(false)


func flock_of(id: int) -> Dictionary:
	while flocks.size() <= id:
		var a: float = r.randf_range(0.0, TAU)
		flocks.append({"id": flocks.size(), "goal": Vector3(cos(a) * 90.0, 30.0, sin(a) * 90.0),
			"wander_t": r.randf_range(0.0, 100.0), "mode": "roam", "perches": [], "perch_timer": r.randf_range(60.0, 150.0),
			"seed": r.randf_range(0.0, 1000.0)})
	return flocks[id]


# A growing community: the newcomer joins the youngest flock that still has room
# (at most 7 birds a flock, as in the TAGANT score); when every flock is full it
# founds a new one, and the next arrivals gather around it.
func members(id: int) -> int:
	var n: int = 0
	for b in birds:
		if b["flock"] == id:
			n += 1
	return n


func spawn(arriving: bool) -> void:
	if birds.size() >= int(cfg["max"]):
		return
	var id: int = flocks.size()
	for f0 in flocks:
		if members(f0["id"]) < int(cfg["flock_size"]):
			id = f0["id"]
			break
	var f: Dictionary = flock_of(id)
	var node: Node3D = Node3D.new()
	add_child(node)
	var model: Node3D = scene.instantiate()
	model.scale = Vector3.ONE * float(cfg["model_scale"])
	node.add_child(model)
	world.apply_desert_skin(model, 0.0, 0.4)
	var player: AnimationPlayer = world.find_player(model)
	var A: Dictionary = cfg["anims"]
	if player != null:
		for k in A:
			if k != "landing" and k != "takeoff":
				world.loop_animation(player, A[k])
		player.play(A["flap"])
		player.seek(r.randf_range(0.0, 1.0), true)
	var dir: Vector3 = Vector3(r.randf_range(-1, 1), 0.0, r.randf_range(-1, 1)).normalized()
	var joining: bool = false
	if arriving:
		# it comes in from the haze at the edge of the world and looks for its flock
		var a: float = r.randf_range(0.0, TAU)
		node.position = Vector3(cos(a) * 420.0, r.randf_range(55.0, 85.0), sin(a) * 420.0)
		var centre: Vector3 = flock_centre(id) if members(id) > 0 else f["goal"]
		dir = (centre - node.position).normalized()
		joining = members(id) > 0
		if not joining:
			# founder of a new flock: its flock's wandering starts from where it arrives
			f["seed"] = a
			f["wander_t"] = 0.0
	else:
		node.position = f["goal"] + Vector3(r.randf_range(-12, 12), r.randf_range(-4, 4), r.randf_range(-12, 12))
	birds.append({"node": node, "player": player, "vel": dir * r.randf_range(5.0, 7.5), "flock": id, "joining": joining,
		"state": FLY, "anim": "flap", "anim_hold": 0.0, "bank": 0.0, "perch": Vector3.ZERO, "timer": 0.0,
		"tempo": r.randf_range(0.85, 1.2), "phase": r.randf_range(0.0, TAU)})


func flock_centre(id: int) -> Vector3:
	var c: Vector3 = Vector3.ZERO
	var n: int = 0
	for b in birds:
		if b["flock"] == id and not b.get("joining", false):
			c += (b["node"] as Node3D).global_position
			n += 1
	return c / n if n > 0 else flock_of(id)["goal"]


# Now and then two flocks meet and fly the same loop for a while, then part.
var meeting: Dictionary = {}
var meeting_timer: float = 420.0


func update_meetings(delta: float) -> void:
	meeting_timer -= delta
	if meeting.is_empty():
		if meeting_timer <= 0.0 and flocks.size() >= 2:
			var a: int = r.randi_range(0, flocks.size() - 1)
			var b: int = (a + r.randi_range(1, flocks.size() - 1)) % flocks.size()
			meeting = {"lead": a, "guest": b, "left": r.randf_range(60.0, 120.0)}
	else:
		meeting["left"] -= delta
		if meeting["left"] <= 0.0:
			meeting = {}
			meeting_timer = r.randf_range(300.0, 600.0)


func perch_points() -> Array:
	# places a bird can stand, refreshed each time a flock decides to land
	var pts: Array = []
	var dove: Array = world.D["dove"]["debris_points"]
	var top: float = -1e9
	for p in dove:
		top = maxf(top, p[1])
	for p in dove:
		if p[1] > top - 6.0 and r.randf() < 0.5:
			pts.append(Vector3(p[0], p[1] + 0.4, p[2]))     # head
	for c in world.cars:
		if c["impacted"] and c["sinking"] < 0.0:
			var cp: Vector3 = c["root"].global_position
			pts.append(cp + Vector3(r.randf_range(-2, 2), c["h"] * 0.55, r.randf_range(-2, 2)))
	for rc in world.rock_camels:
		var h: float = float(rc.get_meta("height"))
		pts.append(rc.global_position + Vector3(0.0, h * 0.82, 0.0))
	for pm in world.palms:
		if not pm.get("fallen", false):
			pts.append(pm["root"].global_position + Vector3(0.0, pm["height"] * 0.92, 0.0))
	return pts


func disturb(center: Vector3, radius: float, strength: float) -> void:
	for b in birds:
		var d: float = (b["node"] as Node3D).global_position.distance_to(center)
		if d < radius:
			var away: Vector3 = ((b["node"] as Node3D).global_position - center)
			away.y = absf(away.y) + radius * 0.4
			away = away.normalized()
			if b["state"] == PERCHED or b["state"] == LANDING:
				b["state"] = TAKEOFF
				b["timer"] = 0.0
				flock_of(b["flock"])["mode"] = "roam"
				flock_of(b["flock"])["perch_timer"] = r.randf_range(90.0, 200.0)
			b["vel"] += away * strength * (1.0 - d / radius) * r.randf_range(0.7, 1.3)


func _process(delta: float) -> void:
	if world == null or world.D.is_empty():
		return
	# the community grows along the hour: slowly at first, then more and more
	var Gc: Dictionary = cfg["growth"]
	var u: float = clampf(world.t / float(world.D["timeline"]["duration_s"]), 0.0, 1.0)
	var target: float = float(Gc["start"]) + (float(Gc["end"]) - float(Gc["start"])) * pow(u, float(Gc["power"]))
	growth_timer -= delta
	if birds.size() < int(target) and growth_timer <= 0.0:
		spawn(true)
		growth_timer = 2.0      # arrivals never come all at once
	update_meetings(delta)
	for f in flocks:
		update_flock(f, delta)
	for b in birds:
		update_bird(b, delta)


func update_flock(f: Dictionary, delta: float) -> void:
	f["wander_t"] += delta
	f["perch_timer"] -= delta
	if f["mode"] == "roam" and f["perch_timer"] <= 0.0:
		var pts: Array = perch_points()
		if pts.size() > 0:
			var anchor: Vector3 = pts[r.randi_range(0, pts.size() - 1)]
			var group: Array = []
			for p in pts:
				if p.distance_to(anchor) < 25.0:
					group.append(p)
			f["perches"] = group
			f["mode"] = "perch"
			f["perch_timer"] = r.randf_range(40.0, 110.0)
			for b in birds:
				if b["flock"] == f["id"] and b["state"] == FLY:
					var pp: Vector3 = group[r.randi_range(0, group.size() - 1)]
					b["perch"] = pp + Vector3(r.randf_range(-1.2, 1.2), 0.0, r.randf_range(-1.2, 1.2))
					b["state"] = LANDING
	elif f["mode"] == "perch" and f["perch_timer"] <= 0.0:
		f["mode"] = "roam"
		f["perch_timer"] = r.randf_range(80.0, 220.0)
		for b in birds:
			if b["flock"] == f["id"] and (b["state"] == PERCHED or b["state"] == LANDING):
				b["state"] = TAKEOFF
				b["timer"] = r.randf_range(-1.5, 0.0)   # they leave one after another
	# the flock's wandering intention: a slow loop in the sky around the stage, never through Dove Man
	var s: float = f["seed"]
	var tt: float = f["wander_t"]
	var ang: float = tt * (0.012 + 0.003 * f["id"]) + s
	var rad: float = 80.0 + 45.0 * sin(tt * 0.007 + s) + 20.0 * f["id"]
	var alt: float = 26.0 + 12.0 * sin(tt * 0.011 + s * 1.7) + 7.0 * f["id"]
	f["goal"] = Vector3(cos(ang) * rad, alt, sin(ang) * rad)
	if not meeting.is_empty() and meeting["guest"] == f["id"] and f["mode"] == "roam":
		var lead: Dictionary = flock_of(meeting["lead"])
		f["goal"] = lead["goal"] + Vector3(0.0, 6.0, 0.0)


func set_anim(b: Dictionary, key: String, speed: float) -> void:
	var p: AnimationPlayer = b["player"]
	if p == null:
		return
	var name: String = cfg["anims"][key]
	if b["anim"] != key:
		b["anim"] = key
		p.play(name, 0.35)
	p.speed_scale = speed * b["tempo"]


func update_bird(b: Dictionary, delta: float) -> void:
	var node: Node3D = b["node"]
	var pos: Vector3 = node.global_position
	var vel: Vector3 = b["vel"]
	var f: Dictionary = flock_of(b["flock"])
	b["timer"] += delta
	match b["state"]:
		PERCHED:
			vel = Vector3.ZERO
			node.global_position = b["perch"]
			set_anim(b, "idle", 1.0)
			# little turns of the head/body while standing
			node.rotation.y += sin(b["timer"] * 0.4 + b["phase"]) * delta * 0.3
			# Godzilla or the plane coming close: leave
			if world.threat_near(pos, 45.0):
				disturb(pos, 30.0, 8.0)
			return
		LANDING:
			var to: Vector3 = b["perch"] - pos
			var dist: float = to.length()
			var want: Vector3 = to.normalized() * clampf(dist * 0.6, 1.2, 7.0)
			vel = vel.lerp(want, minf(1.0, delta * 1.5))
			if dist < 6.0:
				set_anim(b, "landing", 1.0)
			else:
				set_anim(b, "glide" if vel.y < 0.0 else "flap", 1.0)
			if dist < 0.5:
				b["state"] = PERCHED
				b["timer"] = 0.0
				node.global_position = b["perch"]
				b["vel"] = Vector3.ZERO
				return
		TAKEOFF:
			if b["timer"] < 0.0:
				set_anim(b, "idle", 1.0)
				return
			set_anim(b, "takeoff", 1.2)
			vel += (Vector3(0.0, 6.0, 0.0) + (pos - Vector3(0, pos.y, 0)).normalized() * 3.0) * delta * 2.0
			if b["timer"] > 1.6:
				b["state"] = FLY
		FLY:
			vel += boids(b, pos, vel, f) * delta
	# keep speed sane
	var sp: float = vel.length()
	var mn: float = 3.0 + world.mid_level
	var mx: float = 9.0 + world.air_level * 4.0
	if b["state"] == FLY:
		if sp < mn:
			vel = (vel.normalized() if sp > 0.001 else Vector3.RIGHT) * mn
		elif sp > mx:
			vel = vel.normalized() * mx
	b["vel"] = vel
	node.global_position = pos + vel * delta
	# face the flight direction (model faces +Z), bank into turns
	if vel.length() > 0.3:
		var fwd: Vector3 = vel.normalized()
		var flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z).normalized() if Vector2(fwd.x, fwd.z).length() > 0.05 else node.global_basis.z
		var yaw: float = atan2(flat.x, flat.z)
		var turn: float = wrapf(yaw - node.rotation.y, -PI, PI)
		b["bank"] = lerpf(b["bank"], clampf(-turn * 6.0, -0.7, 0.7), minf(1.0, delta * 3.0))
		node.rotation = Vector3(-asin(clampf(fwd.y, -0.6, 0.6)) * 0.8, node.rotation.y + turn * minf(1.0, delta * 4.0), b["bank"])
	# wing action: flap when climbing / slow / turning hard, glide otherwise (with hold so it doesn't flicker)
	if b["state"] == FLY:
		b["anim_hold"] -= delta
		if b["anim_hold"] <= 0.0:
			var effort: float = vel.y * 0.6 + (mn + 1.5 - vel.length()) * 0.5 + absf(b["bank"]) * 1.5
			var key: String = "flap" if effort > 0.2 or randf() < 0.15 else "glide"
			b["anim_hold"] = r.randf_range(1.2, 3.5)
			set_anim(b, key, clampf(0.8 + effort * 0.4, 0.7, 1.8))


func boids(b: Dictionary, pos: Vector3, vel: Vector3, f: Dictionary) -> Vector3:
	var ali: Vector3 = Vector3.ZERO
	var coh: Vector3 = Vector3.ZERO
	var sep: Vector3 = Vector3.ZERO
	var n: int = 0
	for o in birds:
		if is_same(o, b) or o["flock"] != b["flock"] or o["state"] != FLY:
			continue
		var op: Vector3 = (o["node"] as Node3D).global_position
		var off: Vector3 = op - pos
		var d: float = off.length()
		if d > 25.0:
			continue
		n += 1
		ali += o["vel"]
		coh += op
		if d < 4.5 and d > 0.001:
			sep -= off.normalized() / maxf(d, 0.4)
	var steer: Vector3 = Vector3.ZERO
	if n > 0:
		steer += ((ali / n).normalized() * 7.0 - vel) * 0.7
		steer += ((coh / n) - pos).normalized() * 0.5
		steer += sep * 2.0
	var goal: Vector3 = f["goal"]
	if b.get("joining", false):
		goal = flock_centre(b["flock"])
		if goal.distance_to(pos) < 22.0:
			b["joining"] = false
	var to_goal: Vector3 = goal - pos
	steer += to_goal.normalized() * clampf(to_goal.length() / 30.0, 0.3, 1.6)
	# Dove Man is a solid column: go around, not through
	var flat: Vector2 = Vector2(pos.x, pos.z)
	if flat.length() < 55.0 and pos.y < 185.0:
		steer += Vector3(pos.x, 0.0, pos.z).normalized() * (55.0 - flat.length()) * 0.25
	var ground: float = world.sand_height(pos.x, pos.z)
	if pos.y - ground < 8.0:
		steer.y += (8.0 - (pos.y - ground)) * 0.8
	if pos.y > 95.0:
		steer.y -= 1.0
	if flat.length() > 260.0 and not b.get("joining", false):
		steer += Vector3(-pos.x, 0.0, -pos.z).normalized() * 2.0
	# small personal turbulence + the sound field
	var sonic: float = 0.4 + world.mid_level * 1.8 + world.air_level * 2.5
	var t: float = Engine.get_meta("tagant_film_t", Time.get_ticks_msec() * 0.001)   # film-safe clock (5 Nov)
	steer += Vector3(sin(t * 1.3 + b["phase"]), sin(t * 1.9 + b["phase"] * 0.7) * 0.3, cos(t * 1.1 + b["phase"])) * sonic
	return steer
