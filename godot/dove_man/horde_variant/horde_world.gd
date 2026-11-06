extends "res://dove_man/dove_man_world.gd"
## Thirty-creature variant. The fourteen inherited pilgrim paths are untouched.

const ACTOR = preload("res://dove_man/horde_variant/hybrid_actor.gd")
const SPECIES := ["myna", "longear", "hyena"]
var settings: Dictionary = {}
var wanderers: Array = []
var bands: Array = []
var crowd_rng := RandomNumberGenerator.new()
var crowd_camera: Camera3D
var inspected_band := -1

func _ready() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://dove_man/horde_variant/horde_config.json"))
	assert(not settings.is_empty())
	crowd_rng.seed = int(settings.seed)
	super._ready()
	create_bands()
	print("TAGANT HORDE READY: ", mannequins.size(), " circling + ", wanderers.size(), " wandering; three custom species")

func make_actor(which: String, height: float, seed_value: int, parent: Node3D) -> Node3D:
	var actor := Node3D.new()
	actor.set_script(ACTOR)
	parent.add_child(actor)
	var palette: Array = settings.palette[seed_value % settings.palette.size()]
	actor.setup(which, height, seed_value, Color(palette[0], palette[1], palette[2]))
	return actor

func create_mannequins() -> void:
	super.create_mannequins()
	for index in mannequins.size():
		var pilgrim: Dictionary = mannequins[index]
		var sway: Node3D = pilgrim.sway
		var original := sway.get_child(0)
		sway.remove_child(original)
		original.queue_free()
		pilgrim["hybrid"] = make_actor(SPECIES[index % 3], pilgrim.height, 71 + index * 19, sway)
		pilgrim["hybrid_species"] = SPECIES[index % 3]

func update_mannequins(delta: float) -> void:
	var before: Array[Vector2] = []
	for pilgrim in mannequins: before.append(pilgrim.pos)
	super.update_mannequins(delta)
	var quake: Dictionary = D.quake.mannequin
	var sink := timeline_value("mannequin_sink")
	for index in mannequins.size():
		var pilgrim: Dictionary = mannequins[index]
		var sway: Node3D = pilgrim.sway
		var down := pilgrim_down(pilgrim, D.pilgrims)
		sway.basis = Basis(pilgrim.fall_axis, deg_to_rad(88.0) * down) if pilgrim.get("fallen", false) else Basis.IDENTITY
		var hop := quake_at(pilgrim.pos, 0.0, quake.hop_tau)
		sway.position.y = float(quake.hop_m) * hop.z * (1.0 - down) - 0.15 * float(pilgrim.height) * down - sink * float(pilgrim.height)
		var pose := "walk" if float(pilgrim.speed) > 0.015 else ("watch" if index % 2 == 0 else "idle")
		var actor: Node3D = pilgrim.hybrid
		set_actor_interval(actor)
		actor.update_pose(delta, (pilgrim.pos as Vector2).distance_to(before[index]), pose, t / 3600.0, false, bool(pilgrim.get("fallen", false)))

func create_bands() -> void:
	for index in int(settings.bands):
		var angle := TAU * float(index) / float(settings.bands) + 0.4
		var centre := Vector2.from_angle(angle) * float(settings.band_radius_m[index])
		bands.append({"centre": centre, "goal": centre + Vector2.from_angle(angle + PI * 0.5) * 80.0,
			"mode": ["walk", "run", "rest"][index % 3], "until": 18.0 + index * 8.0})
	for index in int(settings.wanderers):
		var band_index := index % bands.size()
		var species_index := (int(index / 3) + band_index) % 3
		var band: Dictionary = bands[band_index]
		var height := crowd_rng.randf_range(settings.height_m[0], settings.height_m[1])
		var offset := Vector2.from_angle(float(index) * 2.39996) * crowd_rng.randf_range(6.0, 19.0)
		var root := Node3D.new()
		root.name = "Wanderer_%02d_%s" % [index, SPECIES[species_index]]
		add_child(root)
		var agent := {"root": root, "pos": band.centre + offset, "height": height,
			"band": band_index, "offset": offset, "speed": 0.0, "heading": Vector2.from_angle(float(index)),
			"panic_until": -1.0, "threat": Vector2.ZERO, "freeze": false,
			"pose": ["idle", "watch", "gesture", "crouch", "bow"][index % 5]}
		agent.pos = resolve(agent.pos, height * 0.30, agent)
		root.position = Vector3(agent.pos.x, sand_height(agent.pos.x, agent.pos.y) - 0.08, agent.pos.y)
		agent["actor"] = make_actor(SPECIES[species_index], height, 901 + index * 17, root)
		wanderers.append(agent)

func obstacles(me: Variant = null) -> Array:
	var result := super.obstacles(me)
	for agent in wanderers:
		if not is_same(agent, me):
			result.append({"p": agent.pos, "r": agent.height * 0.30, "kind": "hybrid"})
	return result

func _process(delta: float) -> void:
	super._process(delta)
	if D.is_empty(): return
	update_bands(delta)
	if inspected_band >= 0: update_inspection_camera(delta)

func update_bands(delta: float) -> void:
	for band in bands:
		if t >= float(band.until):
			var roll := crowd_rng.randf()
			band.mode = "rest" if roll < 0.28 else ("run" if roll > 0.84 else "walk")
			band.until = t + crowd_rng.randf_range(settings.band_change_s[0], settings.band_change_s[1])
			band.goal = random_free_target(crowd_rng, 8.0, 85.0, 270.0)
		var direction: Vector2 = band.goal - band.centre
		if band.mode != "rest" and direction.length() > 4.0:
			band.centre += direction.normalized() * delta * (2.0 if band.mode == "run" else 0.8)
	var burial := timeline_value("mannequin_sink")
	for agent in wanderers:
		var band: Dictionary = bands[agent.band]
		var old: Vector2 = agent.pos
		var target: Vector2 = band.centre + agent.offset.rotated(sin(t * 0.009 + float(agent.band)) * 0.18)
		var desired: Vector2 = target - old
		var panic := t < float(agent.panic_until)
		# Godzilla's presence can alarm them before the next footfall.
		if not gz.is_empty() and gz.state == GZ_WALKING:
			var giant := Vector2(gz.root.position.x, gz.root.position.z)
			if old.distance_to(giant) < 85.0:
				agent.panic_until = maxf(agent.panic_until, t + 5.0)
				agent.threat = giant
				panic = true
		var pose := "walk"
		var target_speed := float(settings.walk_speed_per_height) * float(agent.height)
		if panic:
			desired = (old - agent.threat).normalized() * 45.0
			pose = "crouch" if agent.freeze else "run"
			target_speed = 0.0 if agent.freeze else float(settings.run_speed_per_height) * float(agent.height)
		elif band.mode == "rest":
			target_speed = 0.0
			pose = agent.pose
		elif desired.length() < 3.0:
			target_speed = 0.0
			pose = "watch"
		elif band.mode == "run":
			target_speed = float(settings.run_speed_per_height) * float(agent.height)
			pose = "run"
		target_speed *= 1.0 - burial * 0.6
		# Stay within the stage rather than fleeing forever into the distance.
		if old.length() > 350.0:
			desired = -old
		var heading: Vector2 = steer(old, desired.normalized(), float(agent.height) * 0.30, agent)
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			var away := old - Vector2(camera.global_position.x, camera.global_position.z)
			if away.length() < 12.0: heading = (heading + away.normalized() * 2.0).normalized()
		if heading.length() > 0.1 and target_speed > 0.0:
			agent.heading = (agent.heading as Vector2).slerp(heading, 1.0 - exp(-delta * 1.6)).normalized()
		agent.speed = move_toward(agent.speed, target_speed, delta * float(agent.height) * 0.65)
		var next: Vector2 = old + (agent.heading as Vector2) * float(agent.speed) * delta
		next = resolve(next, float(agent.height) * 0.30, agent)
		agent.pos = next
		var node: Node3D = agent.root
		node.position = Vector3(next.x, sand_height(next.x, next.y) - 0.08 - burial * float(agent.height), next.y)
		if float(agent.speed) > 0.03:
			node.rotation.y = atan2(agent.heading.x, agent.heading.y)
		# Brake into an expressive pose rather than sliding while standing still.
		if target_speed == 0.0 and float(agent.speed) > 0.08: pose = "walk"
		var actor: Node3D = agent.actor
		set_actor_interval(actor)
		actor.update_pose(delta, next.distance_to(old), pose, t / 3600.0)

func set_actor_interval(actor: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	var distance := camera.global_position.distance_to(actor.global_position) if camera != null else 0.0
	actor.update_interval = 1.0 / (12.0 if distance > 220.0 else (20.0 if distance > 110.0 else 30.0))

func react_to_impact(point: Vector2, kind: String) -> void:
	super.react_to_impact(point, kind)
	for agent in wanderers:
		if (agent.pos as Vector2).distance_to(point) < (100.0 if kind == "car" else 70.0):
			agent.threat = point
			agent.panic_until = t + crowd_rng.randf_range(settings.panic_s[0], settings.panic_s[1])
			agent.freeze = crowd_rng.randf() < 0.18

func cycle_crowd_view() -> void:
	inspected_band += 1
	if inspected_band >= bands.size():
		inspected_band = -1
		if crowd_camera != null: crowd_camera.current = false
		director.cam.current = true
		director.set_process(true)
		return
	if crowd_camera == null:
		crowd_camera = Camera3D.new()
		crowd_camera.far = 3500.0
		crowd_camera.fov = 52.0
		add_child(crowd_camera)
	director.set_process(false)
	director.fade.color.a = 0.0
	crowd_camera.current = true
	update_inspection_camera(0.0)

func update_inspection_camera(_delta: float) -> void:
	var centre := Vector3.ZERO
	var count := 0
	for agent in wanderers:
		if int(agent.band) == inspected_band:
			centre += agent.root.position
			count += 1
	if count == 0: return
	centre /= float(count)
	var outward := Vector3(centre.x, 0.0, centre.z).normalized()
	crowd_camera.position = centre + outward * 38.0 + Vector3(0, 14, 0)
	crowd_camera.position.y = maxf(crowd_camera.position.y, sand_height(crowd_camera.position.x, crowd_camera.position.z) + 4.0)
	crowd_camera.look_at(centre + Vector3(0, 3, 0))

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		cycle_crowd_view()
