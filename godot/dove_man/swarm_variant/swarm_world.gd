extends "res://dove_man/dove_man_world.gd"
## Counter-clockwise personal orbits with delay → sync → delay gait phasing.

const ACTOR = preload("res://dove_man/swarm_variant/swarm_actor.gd")
const SPECIES := ["myna", "longear", "hyena"]
var settings: Dictionary = {}
var swarm_rng := RandomNumberGenerator.new()
var static_discs: Array = []
var spatial_grid: Dictionary = {}
var view_camera: Camera3D
var inspection := -1
var phase_stage := "DELAYED"
var phase_spread := 1.0
var synchronization := 0.0

func _ready() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://dove_man/swarm_variant/swarm_config.json"))
	assert(not settings.is_empty())
	swarm_rng.seed = int(settings.seed)
	super._ready()
	get_viewport().mesh_lod_threshold = float(settings.mesh_lod_threshold_pixels)
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	get_viewport().scaling_3d_scale = float(settings.render_scale)
	environment_resource.volumetric_fog_enabled = bool(settings.volumetric_fog)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = float(settings.shadow_distance_m)
	print("PHASING SWARM READY: ", mannequins.size(), " members; ", settings.members_per_species, " of each custom species")

func create_mannequins() -> void:
	super.create_mannequins()
	for item in D.rock_camels:
		static_discs.append({"position": Vector2(item.xform[9], item.xform[11]), "radius": float(item.height) * 0.55})
	for item in D.palms:
		static_discs.append({"position": Vector2(item.xform[9], item.xform[11]), "radius": 3.0})
	var retained := mannequins.size()
	var total := int(settings.members_per_species) * SPECIES.size()
	assert(total >= retained)
	for index in total:
		var member: Dictionary
		if index < retained:
			member = mannequins[index]
			var sway: Node3D = member.sway
			var previous := sway.get_child(0)
			sway.remove_child(previous)
			previous.queue_free()
		else:
			var root := Node3D.new()
			root.name = "Orbit_%03d" % index
			add_child(root)
			var sway := Node3D.new()
			root.add_child(sway)
			var fraction := (float(index - retained) + 0.5) / float(total - retained)
			var radius := lerpf(settings.additional_ring_radius_m[0], settings.additional_ring_radius_m[1], fraction)
			var angle := choose_start_angle(radius, fposmod(float(index) * 0.61803398875, 1.0))
			var height := swarm_rng.randf_range(settings.height_m[0], settings.height_m[1])
			var random := RandomNumberGenerator.new()
			random.seed = int(settings.seed) + index * 31
			member = {"root": root, "sway": sway, "height": height, "phase": float(index),
				"pos": Vector2(sin(angle), cos(angle)) * radius, "ring": radius, "group": "inner",
				"rng": random, "speed": 0.0, "step": 0.0, "walk": 1.0, "stall": 0.0,
				"rise_after": random.randf_range(D.pilgrims.rise_after_s[0], D.pilgrims.rise_after_s[1])}
			mannequins.append(member)
		var which: String = SPECIES[index % SPECIES.size()]
		var actor := Node3D.new()
		actor.set_script(ACTOR)
		(member.sway as Node3D).add_child(actor)
		var base: Array = settings.palette[index % settings.palette.size()]
		var tone := Color(base[0], base[1], base[2])
		tone *= swarm_rng.randf_range(0.88, 1.12)
		tone.a = 1.0
		actor.setup(which, member.height, 733 + index * 23, tone)
		if index >= retained:
			# Similar angular progress per gait cycle keeps neighbouring personal rings
			# compatible while preserving real, distance-driven footsteps.
			var desired_stride := float(settings.stride_per_orbit_radius) * float(member.ring)
			var scale_ratio := desired_stride / float(actor.strides.walk)
			var corrected_height := clampf(float(member.height) * scale_ratio, settings.height_m[0], settings.height_m[1])
			scale_ratio = corrected_height / float(member.height)
			actor.scale *= scale_ratio
			for clip in actor.strides: actor.strides[clip] *= scale_ratio
			actor.size_m = corrected_height
			member.height = corrected_height
			for mesh in actor.meshes: mesh.set_instance_shader_parameter("body_height", corrected_height)
		member["actor"] = actor
		member["species"] = which
		member["orbit_radius"] = member.ring
		member["angle"] = atan2(member.pos.x, member.pos.y)
		member["delay"] = fposmod(float(index) * 0.61803398875, 1.0)
		member["cycle"] = fposmod(actor.contact_phase - float(member.delay), 1.0)
		member.step = fposmod(float(member.cycle) - float(actor.contact_phase), 1.0) * 2.0
		member["body_r"] = float(member.height) * float(settings.personal_radius_per_height)
		member["blocked"] = false
		member["retained"] = index < retained
		actor.phase = member.cycle
		actor.update_pose(0.02, 0.0, "walk", 0.0, true)
		member.pos = orbit_position(member, member.angle)
		(member.root as Node3D).position = Vector3(member.pos.x, sand_height(member.pos.x, member.pos.y) - 0.08, member.pos.y)
		(member.root as Node3D).rotation.y = float(member.angle) + PI * 0.5

func choose_start_angle(radius: float, delay_fraction: float) -> float:
	var best_angle := 0.0
	var best_clearance := -INF
	for attempt in 40:
		var angle := swarm_rng.randf_range(0.0, TAU)
		var clearance := INF
		for other in mannequins:
			# Reserve room at delayed, intermediate and synchronous positions.
			# This reduces overtaking conflicts during the phasing transition.
			for weight in [0.0, 0.5, 1.0]:
				var shift := float(settings.stride_per_orbit_radius) * delay_fraction * float(weight)
				var point := Vector2(sin(angle + shift), cos(angle + shift)) * radius
				var other_angle := atan2(other.pos.x, other.pos.y) + float(settings.stride_per_orbit_radius) * float(other.get("delay", 0.0)) * float(weight)
				var other_point := Vector2(sin(other_angle), cos(other_angle)) * (other.pos as Vector2).length()
				clearance = minf(clearance, point.distance_to(other_point))
		if clearance > best_clearance:
			best_clearance = clearance
			best_angle = angle
	return best_angle

func orbit_position(member: Dictionary, angle: float) -> Vector2:
	var nominal := float(member.orbit_radius)
	var radial_offset := 0.0
	# Only the inherited outer orbits need small, repeatable bends around scenery.
	for obstacle in static_discs:
		var point: Vector2 = obstacle.position
		var gap := nominal - point.length()
		var safe := float(obstacle.radius) + float(member.get("body_r", 1.0)) + 1.0
		if absf(gap) >= safe: continue
		var arc := wrapf(angle - atan2(point.x, point.y), -PI, PI) * nominal
		var presence := exp(-pow(arc / (safe * 1.35), 2.0))
		var sign_out := 1.0 if gap >= 0.0 else -1.0
		radial_offset += sign_out * (safe - absf(gap)) * presence
	var radius := maxf(35.0, nominal + radial_offset)
	return Vector2(sin(angle), cos(angle)) * radius

func spread_at(time: float) -> float:
	var local := fposmod(time, float(settings.phase_cycle_s))
	var stages: Array = settings.phase_stage_s
	if local < float(stages[0]): return 1.0
	if local < float(stages[1]): return 1.0 - smoothstep(float(stages[0]), float(stages[1]), local)
	if local < float(stages[2]): return 0.0
	if local < float(stages[3]): return smoothstep(float(stages[2]), float(stages[3]), local)
	return 1.0

func update_mannequins(delta: float) -> void:
	if delta <= 0.0: return
	phase_spread = spread_at(t)
	var stage_time := fposmod(t, float(settings.phase_cycle_s))
	var stages: Array = settings.phase_stage_s
	phase_stage = "DELAYED" if stage_time < float(stages[0]) or stage_time >= float(stages[3]) else ("CONVERGING" if stage_time < float(stages[1]) else ("SYNCHRONIZED" if stage_time < float(stages[2]) else "DRIFTING"))
	var spread_rate := (phase_spread - spread_at(maxf(0.0, t - delta))) / delta
	var base_frequency := 1.0 / float(settings.walk_cycle_s)
	var reference := fposmod(t * base_frequency, 1.0)
	var sink := timeline_value("mannequin_sink")
	build_spatial_grid()
	var sum_x := 0.0
	var sum_y := 0.0
	var active := 0
	for member in mannequins:
		if member.get("fallen", false):
			walk_pilgrim(member, delta, sink, D.pilgrims)
		var actor: Node3D = member.actor
		var distance_m := 0.0
		member.blocked = false
		if not member.get("fallen", false):
			var desired_phase := fposmod(reference - float(member.delay) * phase_spread + actor.contact_phase, 1.0)
			var feed_forward := base_frequency - float(member.delay) * spread_rate
			var predicted := fposmod(float(member.cycle) + feed_forward * delta, 1.0)
			var error := wrapf(desired_phase - predicted, -0.5, 0.5)
			var frequency := clampf(feed_forward + float(settings.phase_correction) * error,
				base_frequency * (1.0 - float(settings.tempo_variation_limit)), base_frequency * (1.0 + float(settings.tempo_variation_limit)))
			var stride := float(actor.strides.walk)
			var requested := stride * frequency * delta
			distance_m = safe_distance(member, requested, delta)
			member.blocked = distance_m < requested * 0.65
			member.angle += distance_m / float(member.orbit_radius)
			member.cycle = fposmod(float(member.cycle) + distance_m / stride, 1.0)
			member.step += distance_m / stride * 2.0
			member.pos = orbit_position(member, member.angle)
			member.speed = distance_m / delta
			var corrected := TAU * (float(member.cycle) - float(actor.contact_phase))
			sum_x += cos(corrected)
			sum_y += sin(corrected)
			active += 1
		else:
			member.speed = 0.0
		var root: Node3D = member.root
		root.position = Vector3(member.pos.x, sand_height(member.pos.x, member.pos.y) - 0.08, member.pos.y)
		root.rotation.y = float(member.angle) + PI * 0.5
		var down := pilgrim_down(member, D.pilgrims)
		var sway: Node3D = member.sway
		sway.basis = Basis(member.fall_axis, deg_to_rad(88.0) * down) if member.get("fallen", false) else Basis.IDENTITY
		var quake: Dictionary = D.quake.mannequin
		var hop := quake_at(member.pos, 0.0, quake.hop_tau)
		sway.position.y = float(quake.hop_m) * hop.z * (1.0 - down) - 0.15 * float(member.height) * down - sink * float(member.height)
		set_actor_rate(actor)
		actor.update_pose(delta, distance_m, "walk" if float(member.speed) > 0.015 else "idle", t / 3600.0, false, bool(member.get("fallen", false)))
	synchronization = Vector2(sum_x, sum_y).length() / float(maxi(active, 1))
	if inspection >= 0: update_swarm_view()

func build_spatial_grid() -> void:
	spatial_grid.clear()
	for member in mannequins:
		var key := Vector2i(floori(member.pos.x / 8.0), floori(member.pos.y / 8.0))
		if not spatial_grid.has(key): spatial_grid[key] = []
		# Snapshot positions make yielding independent of update order.
		spatial_grid[key].append({"id": member.root.get_instance_id(), "pos": member.pos,
			"body_r": member.body_r, "angle": member.angle, "speed": member.speed})

func safe_distance(member: Dictionary, requested: float, delta: float) -> float:
	var point: Vector2 = member.pos
	var tangent := Vector2(cos(member.angle), -sin(member.angle))
	var key := Vector2i(floori(point.x / 8.0), floori(point.y / 8.0))
	var allowed := requested
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for other in spatial_grid.get(key + Vector2i(dx, dz), []):
				if other.id == member.root.get_instance_id(): continue
				var velocity := Vector2(cos(other.angle), -sin(other.angle)) * float(other.speed)
				var relative: Vector2 = other.pos + velocity * delta - point
				var ahead := relative.dot(tangent)
				if ahead <= 0.0: continue
				var lateral := (relative - tangent * ahead).length()
				var safe := float(member.body_r) + float(other.body_r) + float(settings.spacing_margin_m)
				if lateral >= safe: continue
				var gap := ahead - sqrt(maxf(0.0, safe * safe - lateral * lateral))
				allowed = minf(allowed, maxf(0.0, gap))
	return allowed

func set_actor_rate(actor: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	var distance := camera.global_position.distance_to(actor.global_position) if camera != null else 0.0
	var rate := float(settings.near_animation_hz) if distance < 120.0 else (float(settings.mid_animation_hz) if distance < 220.0 else float(settings.far_animation_hz))
	if camera != null and not camera.is_position_in_frustum(actor.global_position + Vector3(0, float(actor.size_m) * 0.5, 0)):
		rate = minf(rate, float(settings.offscreen_animation_hz))
	actor.update_interval = 1.0 / rate

func cycle_swarm_view() -> void:
	inspection += 1
	if inspection >= 3:
		inspection = -1
		view_camera.current = false
		director.cam.current = true
		director.set_process(true)
		return
	if view_camera == null:
		view_camera = Camera3D.new()
		view_camera.far = 3500.0
		add_child(view_camera)
	director.set_process(false)
	director.fade.color.a = 0.0
	view_camera.current = true
	update_swarm_view()

func update_swarm_view() -> void:
	view_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if inspection == 0:
		var subject: Dictionary = mannequins[mini(40, mannequins.size() - 1)]
		var point := Vector3(subject.pos.x, sand_height(subject.pos.x, subject.pos.y), subject.pos.y)
		var outward := Vector3(point.x, 0, point.z).normalized()
		view_camera.position = point + outward * 15.0 + Vector3(0, 6.0, 0)
		view_camera.fov = 62.0
		view_camera.look_at(point + Vector3(0, 2.8, 0))
	elif inspection == 1:
		view_camera.position = Vector3(100, 63, 100)
		view_camera.fov = 60.0
		view_camera.look_at(Vector3(0, 18, 0))
	else:
		view_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		view_camera.size = 190.0
		view_camera.position = Vector3(0, 235, 0.1)
		view_camera.fov = 66.0
		view_camera.look_at(Vector3.ZERO, Vector3.FORWARD)

func update_debug_display() -> void:
	super.update_debug_display()
	if debug_label != null and debug_label.visible:
		debug_label.text += "\nSWARM %d  %s  DELAY %.0f%%  COHERENCE %.2f" % [mannequins.size(), phase_stage, phase_spread * 100.0, synchronization]

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		cycle_swarm_view()
