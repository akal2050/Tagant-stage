extends "res://dove_man/dove_man_world.gd"
## THE ASSEMBLY — the creatures of the Dove Man world gather in front of the water titan
## and claim water from it, as a choir. Built from the latest Dove Man set (crowd_fix):
## the desert, Dove Man, the palms, the rock camels, the wreckage hills, the petrified crowds,
## the doves. Nobody walks here: everyone stands, faces the titan, and sings.
## Settings: res://dove_man/assembly/assembly.json

const ASM := "res://dove_man/assembly/"
const SPECIES := ["myna", "longear", "hyena"]          # read by the petrified ruins
const HYBRID = preload("res://dove_man/swarm_variant/swarm_actor.gd")
const INJURED = preload("res://dove_man/scrap_desert/injured_actor.gd")
const SINGING = preload("res://dove_man/assembly/singing_bones.gd")
const PALETTE := [[0.24, 0.16, 0.10], [0.35, 0.27, 0.18], [0.16, 0.15, 0.13], [0.43, 0.35, 0.25], [0.29, 0.25, 0.21], [0.37, 0.23, 0.12]]

var A: Dictionary = {}
var scrap_field: Node3D
var scrap_hills: Array = []
var frozen_ruins: Node3D
var water_surface: Node3D
var titan_pos := Vector2.ZERO
var titan_frame := 23.0
var camera_rig_ready := false
var titan_lean := 0.0
var titan_phase := 0.0
var members: Array = []        # every singer: {root, sway, kind, group, actor?, model?, bones?, player?, h, delay, seed}
var choir: Node
var camera_rig: Node
var hud: Label
var arng := RandomNumberGenerator.new()
var leaders: Array = []        # one leader per protest song (hidden unless its song is on)
var song_index := -1
var karaoke_ui: Control
var jet: GPUParticles3D
var spray: GPUParticles3D
var jet_on := false
var jet_target := Vector3.ZERO
var titan_aim := 0.0           # yaw offset while the titan points its water
var head_bone := -1
var jet_tube: MeshInstance3D
var titan_idle: SkeletonModifier3D
var titan_off := 0.0           # metres the titan has walked toward the crowd
var titan_goal := 0.0
var walk_frame := 23.0
var titan_walking := false
var walk_dir := 1.0
var titan_arrived := false
var walk_start := 0.0
var titan_rest := 23.0
var grid: Dictionary = {}


func _ready() -> void:
	A = JSON.parse_string(FileAccess.get_file_as_string(ASM + "assembly.json"))
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if A == null or D == null:
		push_error("Assembly: cannot read the settings")
		return
	rng.seed = 2611
	arng.seed = 1977
	skin_shader = load(SHADERS + "desert_skin.gdshader")
	dust_material = make_dust_material()
	prints.resize(32)
	for i in 32:
		prints[i] = Vector4(1e5, 1e5, -1e5, 0.0)
	craters.resize(12)
	for i in 12:
		craters[i] = Vector4(1e5, 1e5, -1e5, 0.0)
	titan_pos = Vector2(A.titan.position[0], A.titan.position[1])

	create_environment()
	environment_resource.volumetric_fog_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 520.0
	get_viewport().mesh_lod_threshold = 4.0
	create_sand()
	create_dove_man()
	create_palms()
	create_rock_camels()
	create_wreckage()
	create_godzilla()
	stand_titan()
	t = float(A.day_min) * 60.0
	apply_timeline()

	create_hybrid_rows()
	create_giants()
	create_camel_singers()
	create_dino_singers()

	birds = Node3D.new()
	birds.set_script(load(BIRDS_SCRIPT))
	add_child(birds)
	birds.setup(self, D["birds"])

	create_leaders()
	create_jet()
	camera_rig = Node3D.new()
	camera_rig.name = "AssemblyCamera"
	camera_rig.set_script(load(ASM + "assembly_camera.gd"))
	add_child(camera_rig)
	camera_rig.setup(self)
	create_hud()
	var layer := CanvasLayer.new()
	add_child(layer)
	karaoke_ui = Control.new()
	karaoke_ui.set_script(load(ASM + "karaoke_ui.gd"))
	layer.add_child(karaoke_ui)
	karaoke_ui.setup(self)
	start_song(int(OS.get_environment("ASM_SONG")) if OS.has_environment("ASM_SONG") else 0)
	print("ASSEMBLY READY: ", members.size(), " singers facing the water titan")


func _process(delta: float) -> void:
	if D.is_empty():
		return
	t += delta * 0.05            # the day moves, slowly
	apply_timeline()
	sand_material.set_shader_parameter("world_time", t)
	update_palms()
	update_opening(delta)
	update_titan(delta)
	update_movement(delta)
	update_singers(delta)
	update_jet(delta)


# ------------------------------------------------------------ the set

func create_sand() -> void:
	super.create_sand()
	sand_material.shader = load("res://dove_man/scrap_desert/contact_sand.gdshader")
	get_node("Far_Dunes").set_instance_shader_parameter("far_surface", 1.0)


func create_wreckage() -> void:
	scrap_field = Node3D.new()
	scrap_field.name = "WreckageHills"
	scrap_field.set_script(load("res://dove_man/scrap_desert/scrap_field.gd"))
	add_child(scrap_field)
	scrap_field.setup(self)
	scrap_hills = scrap_field.hills
	# the petrified crowds keep away from the line Dove Man -> titan, so the assembly stands on open sand
	var lane: Array = [Vector2(0.0, 40.0), titan_pos + titan_pos.normalized() * 260.0]
	frozen_ruins = Node3D.new()
	frozen_ruins.name = "PetrifiedCrowdRuins"
	frozen_ruins.set_script(load("res://dove_man/scrap_desert/frozen_ruins.gd"))
	add_child(frozen_ruins)
	frozen_ruins.setup(self, [lane])


# The water titan stands still, both feet planted, facing Dove Man and the assembly.
func stand_titan() -> void:
	var root: Node3D = gz.root
	root.visible = true
	root.rotation.y = atan2(-titan_pos.x, -titan_pos.y)      # the model faces +Z
	gz.state = GZ_WALKING                                    # no pit in the sand: it is standing, not rising
	water_surface = Node3D.new()
	water_surface.set_script(load("res://dove_man/water_titan/water_surface.gd"))
	root.add_child(water_surface)
	titan_frame = float(A.titan.frame)
	pose_titan()
	water_surface.setup(gz.model, float(D.godzilla.height))
	var sk: Skeleton3D = find_skeleton(gz.model)
	if sk != null:
		titan_idle = SkeletonModifier3D.new()
		titan_idle.set_script(load(ASM + "titan_idle.gd"))
		sk.add_child(titan_idle)
		titan_idle.root_ref = gz.root


func titan_now() -> Vector2:
	return titan_pos - titan_pos.normalized() * titan_off


func pose_titan() -> void:
	var root: Node3D = gz.root
	if gz.player != null:
		gz.player.seek(fposmod(titan_frame, 48.0) / 48.0 * float(gz.anim_len), true)
	var p := titan_now()
	root.position = Vector3(p.x, gz_walk_height(p, fposmod(titan_frame, 48.0)), p.y)


var step_dust: Array = []

# metres of ground covered from frame f to the next frame where both feet are down
func travel_to_next_rest(f: float, dirn: float) -> float:
	var cyc: float = float(D.godzilla.travel_per_cycle)
	var a: float = fposmod(f, 48.0)
	var best := INF
	for r in [23.0, 48.5, 71.0, 96.5]:
		var target: float = r if dirn > 0.0 else r - 48.0 * 2.0
		var df: float = target - a
		if (dirn > 0.0 and df > 0.0) or (dirn < 0.0 and df < 0.0):
			var t0: float = gz_travel(a)
			var t1: float = gz_travel(fposmod(target, 48.0)) + floor(target / 48.0) * cyc
			best = minf(best, absf(t1 - t0))
	return best if best < INF else 0.0

func titan_step(left: bool, frame: float) -> void:
	var root: Node3D = gz.root
	var foot: Vector3 = Basis(Vector3.UP, root.rotation.y) * gz_foot(frame, left) + root.position
	var p2 := Vector2(foot.x, foot.z)
	push_footprint(p2, root.rotation.y)
	if step_dust.is_empty():
		for i in 3:
			var b: GPUParticles3D = make_burst(Color(0.6, 0.43, 0.27, 0.32), 160, 2.6, 2.4, 0.3)
			(b.process_material as ParticleProcessMaterial).emission_sphere_radius = 4.0
			(b.process_material as ParticleProcessMaterial).initial_velocity_max = 6.0
			step_dust.append(b)
	fire(step_dust, Vector3(p2.x, dune_height(p2.x, p2.y) + 0.3, p2.y))


# The titan walks toward the crowd before it turns its water on them, and back afterwards.
# Its real walk cycle is used, with the ground travel measured per frame, so the feet stay put.
func titan_walk_to(metres: float) -> void:
	titan_goal = metres


func walk_titan(delta: float) -> bool:
	var gap: float = titan_goal - titan_off
	if not titan_walking and absf(gap) < 0.5:
		return false
	if not titan_walking:
		titan_walking = true
		titan_arrived = false
		walk_start = titan_off
		walk_dir = signf(gap)
		walk_frame = fposmod(titan_frame, 48.0)
	# head for the goal; once there (or past it) keep going the same way until the feet are planted
	if not titan_arrived and (signf(gap) != walk_dir or absf(absf(gap) - travel_to_next_rest(walk_frame, walk_dir)) <= 9.0):
		titan_arrived = true     # the next planted stance is the closest one to the goal
	var dirn: float = walk_dir
	var cyc: float = float(D.godzilla.travel_per_cycle)
	var fps: float = 48.0 * 5.5 / cyc * (1.0 if dirn > 0.0 else 0.8)       # 5.5 m/s forward, slower backing off
	var old: float = walk_frame
	walk_frame += dirn * delta * fps
	var t_old: float = gz_travel(fposmod(old, 48.0)) + floor(old / 48.0) * cyc
	var t_new: float = gz_travel(fposmod(walk_frame, 48.0)) + floor(walk_frame / 48.0) * cyc
	titan_off += t_new - t_old
	titan_frame = walk_frame
	# footprints and dust where a foot comes down
	for foot in D.godzilla.contacts:
		var cf: float = float(D.godzilla.contacts[foot])
		var a: float = fposmod(old, 48.0)
		var b: float = fposmod(walk_frame, 48.0)
		var lo: float = minf(a, b)
		var hi: float = maxf(a, b)
		if absf(b - a) < 24.0 and cf > lo and cf <= hi:
			titan_step(foot == "L", cf)
	# stop only when both feet are down: just after either foot lands (R at 22, L at 47)
	var f: float = fposmod(walk_frame, 48.0)
	var after_r: float = f - 23.0
	var after_l: float = wrapf(f - 48.5, -24.0, 24.0)
	if titan_arrived and absf(titan_off - walk_start) > 2.0 and (absf(after_r) < 1.2 or absf(after_l) < 1.2):
		titan_walking = false
		titan_goal = titan_off
		titan_rest = 23.0 if absf(after_r) < 1.2 else 48.5
		titan_phase = asin(clampf((after_r if titan_rest == 23.0 else after_l) / 2.0, -1.0, 1.0))
	return true


# The entrance: it comes out of the haze with two steps (one walk cycle of its own clip,
# feet locked to the sand), then stands firm. The camera waits on the sand in front of it.
var entering := false
var entry_frame := 0.0

func titan_entrance() -> void:
	entering = true
	entry_frame = float(A.titan.frame) - 48.0
	titan_off = -float(D.godzilla.travel_per_cycle)


func update_titan(delta: float) -> void:
	if entering:
		var old: float = entry_frame
		entry_frame = minf(entry_frame + delta * 48.0 / 7.5, float(A.titan.frame))     # two steps in 7.5 s
		var cyc: float = float(D.godzilla.travel_per_cycle)
		var rest: float = float(A.titan.frame)
		titan_off = (gz_travel(fposmod(entry_frame, 48.0)) + floor(entry_frame / 48.0) * cyc) - gz_travel(rest)
		titan_frame = entry_frame
		for foot in D.godzilla.contacts:
			var cf: float = float(D.godzilla.contacts[foot])
			for wrap in [-48.0, 0.0]:
				if old < cf + wrap and entry_frame >= cf + wrap:
					titan_step(foot == "L", cf)
					if camera_rig != null:
						camera_rig.kick(1.0)
		if entry_frame >= rest:
			entering = false
			titan_off = 0.0
	else:
		# it stands planted on both feet (the legs are never moved); only the upper body lives (titan_idle.gd)
		titan_frame = float(A.titan.frame)
	pose_titan()
	# it leans a little into its water, and the stream's recoil shakes it
	var lean_to: float = (0.035 + 0.008 * sin(Time.get_ticks_msec() * 0.013)) if water_landed() else 0.0
	titan_lean = lerpf(titan_lean, lean_to, 1.0 - exp(-delta * 2.0))
	(gz.model as Node3D).rotation.x = titan_lean
	if (gz.root as Node3D).visible:
		titan_fade = minf(1.0, titan_fade + delta / 2.0)
	set_instance_param(gz.model, "fade", titan_fade)
	water_surface.update_surface(delta, titan_fade)
	if titan_idle != null:
		titan_idle.idle = 1.0
		titan_idle.spray = lerpf(titan_idle.spray, 1.0 if water_landed() else 0.0, 1.0 - exp(-delta * 3.0))
	update_attack(delta)


# ------------------------------------------------------------ the attack (like a police water cannon)
# The titan does not speak: it only attacks. Its water sweeps through the crowd; whoever is hit
# is knocked down, gets up and runs; the whole crowd breaks and spreads away from it. When the
# water stops they walk back to their places (faster when the singer keeps singing).

var attack_on := false
var attack_t := 0.0
var attack_len := 11.0
var attack_n := 0
var attack_sweep: Array = [0.0, 0.0]
var hit_clock := 0.0
var regroup_voice := 0.3      # set by the karaoke while the singer sings
var water_sound: AudioStreamPlayer3D


func start_attack(duration: float) -> void:
	if attack_on:
		return
	attack_on = true
	attack_t = 0.0
	attack_len = duration
	attack_n += 1
	var J: Dictionary = A.jet
	attack_sweep = [float(J.sweep_deg[0]), float(J.sweep_deg[1])] if attack_n % 2 == 1 else [float(J.sweep_deg[1]), float(J.sweep_deg[0])]
	crowd_breaks()


func attack_done() -> bool:
	return not attack_on


func update_attack(delta: float) -> void:
	if water_sound == null:
		water_sound = AudioStreamPlayer3D.new()
		var path: String = ASM + "voices/wind_haboob.ogg"
		var st: AudioStream = load(path) if ResourceLoader.exists(path) else AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
		if st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		water_sound.stream = st
		water_sound.pitch_scale = 1.35          # the roar of the water, not a voice
		water_sound.unit_size = 120.0
		water_sound.max_db = 6.0
		water_sound.volume_db = -80.0
		add_child(water_sound)
		water_sound.play()
	var target_db: float = 2.0 if water_landed() else (-12.0 if jet_on else -80.0)
	water_sound.volume_db = lerpf(water_sound.volume_db, target_db, 1.0 - exp(-delta * 4.0))
	water_sound.position = jet_target if jet_on else water_sound.position
	if not attack_on:
		regroup(regroup_voice)
		return
	attack_t += delta
	var u: float = clampf((attack_t - 1.0) / attack_len, 0.0, 1.0)
	if attack_t > 1.0 and u < 1.0:
		var J: Dictionary = A.jet
		var ang: float = lerpf(attack_sweep[0], attack_sweep[1], u * u * (3.0 - 2.0 * u)) + sin(attack_t * 2.3) * 4.0
		# it hunts the densest part of the crowd: the radius follows where they are now
		var rad: float = lerpf(J.sweep_radius[0], J.sweep_radius[1], 0.5 + 0.5 * sin(attack_t * 0.9 + attack_n))
		var p2: Vector2 = arc_point(rad, ang)
		set_jet(true, Vector3(p2.x, sand_height(p2.x, p2.y), p2.y))
		hit_clock -= delta
		if hit_clock <= 0.0 and water_landed():
			hit_clock = 0.08
			hit_by_water(p2)
	elif u >= 1.0:
		set_jet(false, Vector3.ZERO)
		attack_on = false
		for m in members:
			if m.state == "wait":
				m.wait = arng.randf_range(0.5, 3.0)


# When the titan turns toward them, the whole crowd breaks: everyone backs away from it.
func crowd_breaks() -> void:
	var J: Dictionary = A.jet
	for m in members:
		if not m.mobile or m.state == "flee" or m.state == "down":
			continue
		var away: Vector2 = ((m.pos as Vector2) - titan_pos).normalized().rotated(arng.randf_range(-0.5, 0.5))
		m.target = (m.pos as Vector2) + away * arng.randf_range(12.0, 30.0)
		m.state = "flee"
		m.speed = arng.randf_range(J.walk_speed[0], J.walk_speed[1]) * 1.4


# ------------------------------------------------------------ the assembly

func toward_titan(p: Vector2) -> float:
	var f: Vector2 = (titan_pos - p).normalized()
	return atan2(f.x, f.y)


func arc_point(radius: float, angle_deg: float) -> Vector2:
	# angle 0 = straight between the titan and Dove Man; the crescent opens around the titan
	var back: Vector2 = -titan_pos.normalized()
	return titan_pos + back.rotated(deg_to_rad(angle_deg)) * radius


func add_member(p: Vector2, sink: float) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(p.x, sand_height(p.x, p.y) - sink, p.y)
	root.rotation.y = toward_titan(p)
	var sway := Node3D.new()
	root.add_child(sway)
	var m := {"root": root, "sway": sway, "pos": p, "home": p, "seed": members.size() * 37 + 11,
		"delay": p.distance_to(arc_point(60.0, 0.0)) / 120.0, "breath": arng.randf_range(0.0, TAU),
		"state": "home", "target": p, "speed": 0.0, "moved": 0.0, "wait": 0.0, "sink": sink,
		"yaw": root.rotation.y, "home_yaw": root.rotation.y, "yaw_offset": 0.0, "mobile": true, "radius": 1.0,
		"fall_dir": Vector2.ZERO, "fallen": 0.0}
	members.append(m)
	return m


func hybrid_bones(actor: Node3D) -> Node:
	var sk: Skeleton3D = actor.skeleton
	var mod: SkeletonModifier3D = SINGING.new()
	sk.add_child(mod)
	if actor.species == "myna":
		mod.configure(sk, ["neck_01", "head"], Vector3.RIGHT, -0.42, "", 0.0)
	else:
		mod.configure(sk, ["mixamorig_Neck", "mixamorig_Head", "mixamorig_Spine2"], Vector3.RIGHT, -0.38, "", 0.0)
	return mod


# One family of skin for every creature: the same earth, a little lighter or darker, never another colour.
func family_tint() -> Color:
	var base := Color(0.30, 0.22, 0.14)
	var k: float = arng.randf_range(0.82, 1.14)
	var warm: float = arng.randf_range(-0.018, 0.018)
	return Color((base.r + warm) * k, base.g * k, (base.b - warm) * k, 1.0)


const ANIMAL = preload("res://dove_man/assembly/animal_actor.gd")

# Not rows: herds. Clumps of different sizes, each with a kind that dominates it and others mixed in,
# denser at their hearts, loosely facing the titan.
func create_hybrid_rows() -> void:
	var H: Dictionary = A.herds
	var thin: float = float(OS.get_environment("ASM_ROWS_SCALE")) if OS.has_environment("ASM_ROWS_SCALE") else 1.0
	var herds: Array = []
	var arc: float = float(H.arc_deg)
	for i in int(H.count):
		var c := Vector2.ZERO
		for attempt in 200:
			c = arc_point(arng.randf_range(H.radius[0], H.radius[1]), arng.randf_range(-arc * 0.5, arc * 0.5))
			var ok := true
			for o in herds:
				if c.distance_to(o.c) < float(H.herd_gap):
					ok = false
					break
			if ok:
				break
		herds.append({"c": c, "spread": arng.randf_range(H.spread_m[0], H.spread_m[1]), "lead": i % 4})
	# everyone who will stand in the herds: [kind, species, group, height]
	var pool: Array = []
	for sp in H.hybrids:
		var e: Dictionary = H.hybrids[sp]
		for k in maxi(1, int(round(float(e.n) * thin))):
			pool.append(["hybrid", sp, e.group, arng.randf_range(e.h[0], e.h[1])])
	for sp in H.animals:
		var e: Dictionary = H.animals[sp]
		for k in maxi(1, int(round(float(e.n) * thin))):
			pool.append(["animal", sp, e.group, arng.randf_range(e.h[0], e.h[1])])
	# 0 mynas, 1 snake-heads, 2 hyenas, 3 mixed: most of a kind gather in "their" herds
	var family := {"myna": 0, "longear": 1, "hyena": 2}
	var placed: Array = []
	var k := 0
	for item in pool:
		var fam: int = family.get(item[1], 3)
		var choices: Array = []
		for h in herds:
			if int(h.lead) == fam:
				choices.append(h)
		var herd: Dictionary = choices[arng.randi() % choices.size()] if (not choices.is_empty() and arng.randf() < 0.7) else herds[arng.randi() % herds.size()]
		var r_body: float = maxf(0.6, float(item[3]) * (0.17 if item[0] == "hybrid" else 0.3))
		var p := Vector2.ZERO
		var spread: float = float(herd.spread)
		for attempt in 60:
			p = herd.c + Vector2(arng.randfn(0.0, spread), arng.randfn(0.0, spread * 0.8)).rotated(arng.randf() * 0.4)
			var ok := true
			for q in placed:
				if p.distance_to(q[0]) < r_body + float(q[1]) + float(H.min_gap) * 0.5:
					ok = false
					break
			if ok:
				break
			spread *= 1.03
		placed.append([p, r_body])
		var m := add_member(p, 0.08)
		m.home_yaw = toward_titan(p) + arng.randf_range(-0.55, 0.55)
		m.yaw = m.home_yaw
		(m.root as Node3D).rotation.y = m.yaw
		var h: float = item[3]
		m["h"] = h
		m["group"] = item[2]
		m["radius"] = r_body
		if item[0] == "hybrid":
			var actor := Node3D.new()
			actor.set_script(HYBRID)
			m.sway.add_child(actor)
			actor.setup(item[1], h, 733 + k * 23, family_tint())
			actor.update_interval = 1.0 / 15.0
			m["kind"] = "hybrid"
			m["actor"] = actor
			m["bones"] = hybrid_bones(actor)
			m["rest"] = "watch" if k % 3 == 0 else "idle"
		else:
			var actor := Node3D.new()
			actor.set_script(ANIMAL)
			m.sway.add_child(actor)
			actor.setup(item[1], h, 5100 + k * 17, family_tint())
			m["kind"] = "animal"
			m["actor"] = actor
			m["bird"] = item[1] == "dove"
			m["alt"] = 0.0
			m["sink"] = 0.02
		k += 1


func create_giants() -> void:
	var G: Dictionary = A.giants
	var kinds := ["lost_myna", "lost_hyena", "lost_longear"]
	var n: int = int(G.count)
	for i in n:
		var a: float = lerpf(-float(G.arc_deg) * 0.5, float(G.arc_deg) * 0.5, (float(i) + 0.5) / float(n))
		var p: Vector2 = arc_point(float(G.radius) + arng.randf_range(-3.0, 3.0), a)
		var m := add_member(p, 0.1)
		var actor := Node3D.new()
		actor.set_script(INJURED)
		m.sway.add_child(actor)
		actor.setup(kinds[i % 3], float(G.height), 9900 + i * 17, family_tint())
		actor.update_interval = 1.0 / 15.0
		m["kind"] = "hybrid"
		m["group"] = G.group
		m["actor"] = actor
		m["h"] = float(G.height)
		m["bones"] = hybrid_bones(actor)
		m["rest"] = "idle"
		m["radius"] = 1.9


func family_skin(model: Node3D, h: float, ry: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://dove_man/swarm_variant/swarm_skin.gdshader")
	var tint := family_tint()
	for g in each_geometry(model, []):
		if String(g.name) in ["Object_116", "CamelCoat"]:
			(g as Node3D).visible = false
			continue
		var gi: GeometryInstance3D = g
		gi.material_override = mat
		gi.set_instance_shader_parameter("body_tint", tint)
		gi.set_instance_shader_parameter("body_height", h)
		gi.set_instance_shader_parameter("root_y", ry)


func create_camel_singers() -> void:
	var C: Dictionary = A.camels
	var scene: PackedScene = load(MODELS + D.camels.model)
	var gait: Dictionary = D.camels.gait
	for i in C.places_deg.size():
		var h: float = float(C.heights[i])
		var p: Vector2 = arc_point(float(C.radius), float(C.places_deg[i]))
		var m := add_member(p, float(gait.foot_depth))
		(m.root as Node3D).rotation.y += PI                # this model looks down -Z
		m["yaw"] = (m.root as Node3D).rotation.y
		m["home_yaw"] = m["yaw"]
		m["yaw_offset"] = PI
		var model: Node3D = scene.instantiate()
		model.scale = Vector3.ONE * h
		m.sway.add_child(model)
		family_skin(model, h, (m.root as Node3D).position.y)
		var player := find_player(model)
		var clip := "Idle_01" if i % 2 == 0 else "Idle_02"
		if player != null:
			loop_animation(player, clip)
			loop_animation(player, "Walk")
			player.play(clip)
			player.seek(arng.randf_range(0.0, 3.0), true)
		var sk := find_skeleton(model)
		var mod: SkeletonModifier3D = SINGING.new()
		sk.add_child(mod)
		mod.configure(sk, ["Neck.001_00", "Neck.002_013", "Neck.003_014", "Neck.004_015", "Head_018"], Vector3.RIGHT, 0.55, "Jaw_019", -0.45)
		m["kind"] = "camel"
		m["group"] = C.group
		m["model"] = model
		m["player"] = player
		m["h"] = h
		m["bones"] = mod
		m["radius"] = h * 0.28
		m["walk_clip"] = "Walk"
		m["idle_clip"] = clip


func create_dino_singers() -> void:
	var C: Dictionary = A.dinos
	var DD: Dictionary = D.dinos
	for i in C.places_deg.size():
		var h: float = float(C.heights[i])
		var p: Vector2 = arc_point(float(C.radius), float(C.places_deg[i]))
		var m := add_member(p, float(DD.foot_depth))
		var f: Vector2 = (titan_pos - p).normalized()
		(m.root as Node3D).rotation.y = -atan2(f.y, f.x)    # this model's head is on +X (checked on the mesh: eyes and teeth at +X)
		var model := load_model(DD.model)
		model.scale = Vector3.ONE * h
		m.sway.add_child(model)
		apply_desert_skin(model, DD.cake, 1.0)
		set_instance_param(model, "body_height", h)
		set_instance_param(model, "root_y", (m.root as Node3D).position.y)
		var player := find_player(model)
		if player != null:
			loop_animation(player, DD.anim)
			player.play(DD.anim)
			player.speed_scale = 0.16
			player.seek(float(i) * 3.1, true)
		m["kind"] = "dino"
		m["mobile"] = false
		m["radius"] = h * 0.4
		m["group"] = C.group
		m["model"] = model
		m["player"] = player
		m["h"] = h


# ------------------------------------------------------------ the leaders of the protest songs
# Each protest song has its own leader, standing in front of the crowd, between it and the titan,
# turned toward the crowd. Only the leader of the song being sung is there.

func create_leaders() -> void:
	var spot: Vector2 = arc_point(42.0, 0.0)
	for song in A.songs:
		if song.mode != "protest":
			leaders.append({})
			continue
		var L: Dictionary = song.leader
		var m := add_member(spot, 0.1)
		var root: Node3D = m.root
		var face_crowd: float = toward_titan(spot) + PI
		var h: float = float(L.height)
		m["group"] = "leader"
		m["h"] = h
		m["radius"] = h * 0.25
		if L.kind == "camel":
			var scene: PackedScene = load(MODELS + D.camels.model)
			var model: Node3D = scene.instantiate()
			model.scale = Vector3.ONE * h
			m.sway.add_child(model)
			family_skin(model, h, root.position.y)
			var player := find_player(model)
			loop_animation(player, "Idle_02")
			loop_animation(player, "Walk")
			player.play("Idle_02")
			var sk := find_skeleton(model)
			var mod: SkeletonModifier3D = SINGING.new()
			sk.add_child(mod)
			mod.configure(sk, ["Neck.001_00", "Neck.002_013", "Neck.003_014", "Neck.004_015", "Head_018"], Vector3.RIGHT, 0.7, "Jaw_019", -0.5)
			m["kind"] = "camel"
			m["model"] = model
			m["player"] = player
			m["bones"] = mod
			m["walk_clip"] = "Walk"
			m["idle_clip"] = "Idle_02"
			m["yaw_offset"] = PI
		else:
			var actor := Node3D.new()
			actor.set_script(HYBRID)
			m.sway.add_child(actor)
			actor.setup(L.species, h, 4242, family_tint())
			actor.update_interval = 1.0 / 24.0
			m["kind"] = "hybrid"
			m["actor"] = actor
			m["bones"] = hybrid_bones(actor)
			m["rest"] = "idle"
		m.home_yaw = face_crowd + float(m.yaw_offset)
		m.yaw = m.home_yaw
		root.rotation.y = m.yaw
		root.visible = false
		m["mobile"] = false
		leaders.append(m)


func leader() -> Dictionary:
	return leaders[song_index] if song_index >= 0 and song_index < leaders.size() else {}


# ------------------------------------------------------------ songs

# ------------------------------------------------------------ the opening
# First the world, slowly: the desert, the petrified crowds, Dove Man. The titan is not there yet.
# Then it comes, two steps, seen from the sand in front of it. Then the counter view: from the titan,
# the crowd coming across the desert. Only then the song starts. (Next songs: entrance + counter view only.)
var hold_crowd := false
var opening_t := -1.0
var opening_plan: Array = []     # [time_s, what]
var titan_fade := 1.0
var first_song := true


func opening_done() -> bool:
	return opening_t < 0.0


func start_opening(full: bool) -> void:
	opening_t = 0.0
	hold_crowd = true
	var root: Node3D = gz.root
	root.visible = false
	titan_fade = 0.0
	var t0: float = 24.0 if full else 0.5
	opening_plan = [[t0, "titan"], [t0 + 8.0, "crowd"], [t0 + 22.0, "end"]]
	if camera_rig != null:
		camera_rig.play_opening(full, t0)


func update_opening(delta: float) -> void:
	if opening_t < 0.0:
		return
	opening_t += delta
	while not opening_plan.is_empty() and opening_t >= float(opening_plan[0][0]):
		var what: String = opening_plan[0][1]
		opening_plan.pop_front()
		match what:
			"titan":
				(gz.root as Node3D).visible = true
				titan_entrance()
			"crowd":
				hold_crowd = false
				for m in members:
					if m.state == "return" and m.wait > 1e8:
						m.wait = arng.randf_range(0.0, 4.0)
			"end":
				opening_t = -1.0
				if choir != null and choir.has_method("enter"):
					choir.enter("gather")       # now the song begins: show its title


func start_song(i: int) -> void:
	i = clampi(i, 0, A.songs.size() - 1)
	song_index = i
	set_jet(false, Vector3.ZERO)
	for k in leaders.size():
		var L: Dictionary = leaders[k]
		if L.is_empty():
			continue
		(L.root as Node3D).visible = k == i
		L.mobile = k == i
		L.pos = L.home
		L.state = "home"
	if choir != null:
		choir.queue_free()
	var song: Dictionary = A.songs[i]
	choir = Node.new()
	choir.name = "Conductor"
	choir.set_script(load(ASM + ("protest.gd" if song.mode == "protest" else "choir.gd")))
	add_child(choir)
	choir.setup(self, A)
	choir.section_changed.connect(camera_rig.on_section)
	choir.section_changed.connect(on_section)
	karaoke_ui.set_song(i)
	start_opening(first_song)
	first_song = false
	if song.mode == "protest":
		scatter_crowd()
	else:
		for m in members:
			if m.mobile and m.state != "home":
				m.state = "return"


# The crowd starts spread over the desert and walks in to gather.
func scatter_crowd() -> void:
	var J: Dictionary = A.jet
	for m in members:
		if not m.mobile or m.group == "leader":
			continue
		var away: Vector2 = (m.home - titan_pos).normalized().rotated(arng.randf_range(-1.1, 1.1))
		var p: Vector2 = m.home + away * arng.randf_range(70.0, 170.0)
		if p.length() < 45.0:
			p = p.normalized() * 45.0
		m.pos = p
		m.state = "return"
		m.wait = 1e9 if hold_crowd else arng.randf_range(0.0, 6.0)      # held in the desert until the titan has come
		m.speed = arng.randf_range(J.walk_speed[0], J.walk_speed[1]) * (1.3 if m.kind == "camel" else 1.0) * 1.45
		var root: Node3D = m.root
		root.position = Vector3(p.x, sand_height(p.x, p.y) - float(m.sink), p.y)


func home_fraction() -> float:
	var n := 0
	var at := 0
	for m in members:
		if m.mobile and m.group != "leader":
			n += 1
			if m.state == "home":
				at += 1
	return float(at) / float(maxi(n, 1))


# Whoever the water hits is knocked down, then gets up and runs; those near it run.
func hit_by_water(p: Vector2) -> void:
	var J: Dictionary = A.jet
	var panic: float = float(J.panic_radius)
	for m in members:
		if not m.mobile or m.state == "down":
			continue
		var d: float = (m.pos as Vector2).distance_to(p)
		if d > panic or (m.state == "flee" and d > float(J.hit_radius)):
			continue
		var away: Vector2 = ((m.pos as Vector2) - p).normalized() if d > 0.5 else Vector2.from_angle(arng.randf() * TAU)
		away = (away + ((m.pos as Vector2) - titan_pos).normalized() * 0.7).normalized().rotated(arng.randf_range(-0.4, 0.4))
		var reach: float = arng.randf_range(J.flee_m[0], J.flee_m[1]) * (1.0 if d < float(J.hit_radius) else 0.7)
		m.target = (m.pos as Vector2) + away * reach
		m.speed = arng.randf_range(J.run_speed[0], J.run_speed[1]) * (0.7 if m.kind == "camel" else 1.0)
		if d < float(J.hit_radius) and m.kind == "hybrid":
			m.state = "down"
			m.wait = arng.randf_range(1.2, 2.6)
			m.fall_dir = away
		else:
			m.state = "flee"


# The singer's voice brings them back faster.
func regroup(voice: float) -> void:
	var J: Dictionary = A.jet
	for m in members:
		if m.state == "wait" and m.wait <= 0.0:
			m.state = "return"
			m.speed = arng.randf_range(J.walk_speed[0], J.walk_speed[1]) * (1.0 + voice)


func cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 6.0), floori(p.y / 6.0))


func update_movement(delta: float) -> void:
	delta = minf(delta, 0.1)
	grid.clear()
	for i in members.size():
		var m: Dictionary = members[i]
		var c := cell(m.pos)
		if not grid.has(c):
			grid[c] = []
		grid[c].append(i)
	for i in members.size():
		var m: Dictionary = members[i]
		if not m.mobile or m.state == "home":
			continue
		var root: Node3D = m.root
		var p: Vector2 = m.pos
		if m.state == "wait":
			m.wait -= delta
			continue
		if m.state == "down":
			m.wait -= delta
			var slide: Vector2 = (m.fall_dir as Vector2) * maxf(m.wait, 0.0) * 3.0 * delta
			p += slide
			m.pos = p
			root.position = Vector3(p.x, sand_height(p.x, p.y) - float(m.sink), p.y)
			if m.wait <= 0.0:
				m.state = "flee"
			continue
		var goal: Vector2 = m.target if m.state == "flee" else m.home
		var to_goal: Vector2 = goal - p
		var dist: float = to_goal.length()
		if m.state == "return" and m.wait > 0.0:
			m.wait -= delta
			continue
		if dist < 0.6:
			if m.state == "flee":
				m.state = "wait"
				m.wait = arng.randf_range(1.5, 5.0)
			else:
				m.state = "home"
				p = m.home
				if m.get("bird", false):
					m.alt = 0.0
					root.position = Vector3(p.x, sand_height(p.x, p.y) - float(m.sink), p.y)
			m.pos = p
			continue
		var v: Vector2 = to_goal / dist * minf(float(m.speed), dist / maxf(delta, 0.001))
		# keep a body's width from the others
		var c := cell(p)
		var push := Vector2.ZERO
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for j in grid.get(c + Vector2i(dx, dy), []):
					if j == i:
						continue
					var o: Dictionary = members[j]
					var off: Vector2 = p - (o.pos as Vector2)
					var need: float = float(m.radius) + float(o.radius)
					var l: float = off.length()
					if l < need and l > 0.001:
						push += off / l * (need - l)
		if dist < 3.0:
			push *= 0.2
		v += push * 3.0
		var step: Vector2 = v * delta
		p += step
		m.pos = p
		m.moved = float(m.moved) + step.length()
		root.position = Vector3(p.x, sand_height(p.x, p.y) - float(m.sink), p.y)
		if m.get("bird", false):
			var up: float = 0.0 if (m.state == "return" and dist < 9.0) else 9.0 + float(m.seed % 7)
			m.alt = lerpf(float(m.alt), up, 1.0 - exp(-delta * 1.5))
			root.position.y += float(m.alt)
		var want: float = (atan2(v.x, v.y) + float(m.yaw_offset)) if v.length() > 0.3 else float(m.home_yaw)
		if m.state == "return" and dist < 4.0:
			want = float(m.home_yaw)
		m.yaw = lerp_angle(float(m.yaw), want, 1.0 - exp(-delta * 4.0))
		root.rotation.y = m.yaw
	for m in members:
		if m.mobile and m.state == "home" and absf(angle_difference(float(m.yaw), float(m.home_yaw))) > 0.01:
			m.yaw = lerp_angle(float(m.yaw), float(m.home_yaw), 1.0 - exp(-delta * 3.0))
			(m.root as Node3D).rotation.y = m.yaw


# ------------------------------------------------------------ the water cannon
# The titan points its water at the crowd: a heavy jet from its head, falling on the sand
# in an arc, and a spray where it lands.

func water_material(alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.82, 0.92, 0.98, alpha)
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	mat.albedo_texture = tex
	return mat


func create_jet() -> void:
	jet = GPUParticles3D.new()
	jet.name = "WaterJet"
	jet.amount = 1800
	jet.lifetime = 2.6
	jet.local_coords = false
	jet.emitting = false
	jet.visibility_aabb = AABB(Vector3(-200, -80, -200), Vector3(400, 200, 400))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 3.5
	pm.gravity = Vector3(0, -9.8, 0)
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 31.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var sc := CurveTexture.new()
	var cv := Curve.new()
	cv.add_point(Vector2(0, 0.5))
	cv.add_point(Vector2(1, 3.0))
	sc.curve = cv
	pm.scale_curve = sc
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.4
	jet.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	q.material = water_material(0.3)
	jet.draw_pass_1 = q
	add_child(jet)
	spray = GPUParticles3D.new()
	spray.name = "WaterSpray"
	spray.amount = 1400
	spray.lifetime = 1.6
	spray.local_coords = false
	spray.emitting = false
	spray.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 60, 120))
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 65.0
	sm.gravity = Vector3(0, -9.8, 0)
	sm.initial_velocity_min = 5.0
	sm.initial_velocity_max = 15.0
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 3.0
	sm.scale_min = 1.0
	sm.scale_max = 2.6
	sm.scale_curve = sc
	spray.process_material = sm
	var q2 := QuadMesh.new()
	q2.size = Vector2(3.0, 3.0)
	q2.material = water_material(0.42)
	spray.draw_pass_1 = q2
	add_child(spray)
	jet_tube = MeshInstance3D.new()
	jet_tube.name = "WaterStream"
	jet_tube.set_script(load(ASM + "water_jet.gd"))
	add_child(jet_tube)


func water_landed() -> bool:
	return jet_on and jet_tube.head >= jet_tube.flight * 0.92


func set_jet(on: bool, target: Vector3) -> void:
	jet_on = on
	jet_target = target
	if jet != null:
		jet.emitting = on
		if not on:
			spray.emitting = false
		jet_tube.set_on(on)


func titan_head() -> Vector3:
	# the mouth: between the upper snout (bones 23 and 26, left and right) and the lower jaw tip (bone 21),
	# checked on a close render of the head with each bone marked
	var sk: Skeleton3D = find_skeleton(gz.model)
	if sk == null or sk.get_bone_count() < 27:
		return (gz.root as Node3D).global_position + Vector3(0, 46, 0)
	var g := func(b: int) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(b).origin
	# AZ marked the mouth on that render: the slit below and behind bone 21, toward bone 20
	var tip: Vector3 = g.call(21)
	var back: Vector3 = g.call(20)
	var up: Vector3 = (gz.root as Node3D).global_basis.y.normalized()
	return tip.lerp(back, 0.35) - up * tip.distance_to(back) * 0.3


func update_jet(delta: float) -> void:
	var want_aim := 0.0
	if jet_on:
		var to_t := Vector2(jet_target.x, jet_target.z) - titan_now()
		want_aim = angle_difference(atan2(-titan_pos.x, -titan_pos.y), atan2(to_t.x, to_t.y))
	titan_aim = lerp_angle(titan_aim, want_aim, 1.0 - exp(-delta * 2.5))
	(gz.root as Node3D).rotation.y = atan2(-titan_pos.x, -titan_pos.y) + titan_aim
	if not jet_on:
		return
	var o: Vector3 = titan_head()
	var d3: Vector3 = jet_target - o
	var flat := Vector2(d3.x, d3.z)
	var d: float = flat.length()
	var drop: float = -d3.y
	var th := deg_to_rad(-20.0)        # a flat, hard stream, aimed at them
	var v2: float = 9.8 * d * d / (2.0 * cos(th) * cos(th) * maxf(drop + d * tan(th), 2.0))
	var v: float = sqrt(maxf(v2, 1.0))
	var dir_flat: Vector2 = flat / maxf(d, 0.001)
	var dir := Vector3(dir_flat.x * cos(th), sin(th), dir_flat.y * cos(th)).normalized()
	jet.global_position = o
	jet.global_basis = Basis.looking_at(dir, Vector3.UP)
	var pm: ParticleProcessMaterial = jet.process_material
	pm.initial_velocity_min = v * 0.97
	pm.initial_velocity_max = v * 1.03
	jet_tube.aim(o, dir * v, d / maxf(v * cos(th), 0.1))
	spray.global_position = jet_target + Vector3(0, 0.5, 0)
	spray.emitting = water_landed()


# ------------------------------------------------------------ singing moves the bodies

func update_singers(delta: float) -> void:
	var titan_voice: float = choir.env.get("titan", 0.0)
	var clock: float = Time.get_ticks_msec() * 0.001
	for m in members:
		var g: String = m.group
		var e: float = choir.env.get(g, 0.0)
		var l: float = choir.loud_at(g, m.delay)
		var sing: float = e * (0.55 + 0.45 * l)
		var sway: Node3D = m.sway
		var breath: float = sin(clock * 1.3 + float(m.breath))
		match m.kind:
			"hybrid":
				var clip: String = m.rest
				var down: bool = m.state == "down"
				m.fallen = lerpf(float(m.fallen), 1.0 if down else 0.0, 1.0 - exp(-delta * (9.0 if down else 3.0)))
				if down:
					clip = "idle"
				elif m.state == "flee":
					clip = "run"
				elif m.state == "return":
					clip = "walk"
				elif e > 0.3:
					clip = "gesture" if m.actor.species == "myna" else "idle"
				elif titan_voice > 0.4:
					clip = "crouch" if m.actor.species == "myna" else "watch"
				m.actor.update_pose(delta, float(m.moved), clip, 0.25, false, float(m.fallen) > 0.5)
				m.moved = 0.0
				m.bones.amount = sing
				# lean back into the voice; pushed back further when the titan answers
				sway.rotation.x = -(sing * 0.07 + titan_voice * 0.06) + breath * 0.008 - float(m.fallen) * 1.45
				sway.position.z = -float(m.fallen) * float(m.h) * 0.15
				sway.position.y = sing * 0.04 * float(m.h) * (0.5 + 0.5 * sin(clock * 5.0 + float(m.breath)))
			"animal":
				m.actor.pose(m.state, float(m.speed) if m.state == "flee" or m.state == "return" else 0.0, sing)
				m.moved = 0.0
				sway.rotation.x = -sing * 0.04 + breath * 0.006
			"camel":
				if m.player != null:
					var want: String = m.walk_clip if m.state != "home" and m.state != "wait" else m.idle_clip
					if m.player.current_animation != want:
						m.player.play(want, 0.4)
					m.player.speed_scale = clampf(float(m.speed) / (float(m.h) * 0.35), 0.6, 2.4) if want == m.walk_clip else 1.0
				m.moved = 0.0
				m.bones.amount = sing
				m.bones.mouth = e * l
				sway.rotation.x = (sing * 0.03 + titan_voice * 0.03) + breath * 0.004
			"dino":
				if m.player != null:
					m.player.speed_scale = lerpf(0.16, 0.05, e)
				# the head comes up out of the grazing and the chest swells
				(m.model as Node3D).rotation.z = sing * 0.075 + breath * 0.006 - titan_voice * 0.02
				(m.model as Node3D).scale = Vector3.ONE * float(m.h) * (1.0 + sing * 0.018 * (0.5 + 0.5 * breath))


# ------------------------------------------------------------ what is being sung

func create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(28, 24)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86, 0.92))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	hud.add_theme_constant_override("shadow_offset_x", 1)
	hud.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(hud)


func on_section(section_name: String, _groups: Array) -> void:
	if hud != null and opening_done():
		hud.text = section_name


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W:
			if choir != null and choir.has_method("enter"):
				choir.enter("attack")      # W = the titan's water, now
			else:
				start_attack(11.0)
		elif event.keycode == KEY_TAB:
			start_song((song_index + 1) % A.songs.size())
		elif event.keycode == KEY_H and hud != null:
			hud.visible = not hud.visible
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()
		else:
			camera_rig.key(event.keycode)
