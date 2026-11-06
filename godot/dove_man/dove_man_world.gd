extends Node3D

# ============================================================
# TAGANT — DOVE MAN
#
# Live version of the "dove man" Blender scene (Desktop/webcore/dove man.blend).
# Everything that was measured or tuned in Blender is read from
#   res://dove_man/data/dove_man_world.json
# so this script only holds behaviour, not magic numbers.
#
# - Dove Man: eroded mountain with snow (geometry baked in Blender)
# - Godzilla: stride-locked walk, feet 1.9 m into his own fresh footprint,
#   footprints in the sand, every step shakes the world and
#   sheds rock and sand from Dove Man
# - 2 rigged camels: idle + pace (walk written in Blender), feet 20 cm in the sand,
#   they flee Godzilla's path
# - 6 rock-and-sand camels
# - 4 sauropods circling Dove Man (circumambulation), each on its own ring
# - Boeing as junk satellite skimming Dove Man (clearance measured against the rock)
# - desert cars falling from the sky, craters, dust, shake; old wrecks get swallowed
# - pigeons (boids), palms, mannequins, sound-reactive climate, autonomous cameras
#
# Coordinates: Godot Y-up. Blender (x, y, z) == Godot (x, z, -y).
# ============================================================

const DATA_PATH: String = "res://dove_man/data/dove_man_world.json"
const MODELS: String = "res://dove_man/models/"
const SHADERS: String = "res://dove_man/shaders/"

const GZ_WAITING: int = 0
const GZ_RISING: int = 1
const GZ_WALKING: int = 2
const GZ_SINKING: int = 3

var D: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var t: float = 0.0

# ---------------- sound ----------------
var spectrum: AudioEffectSpectrumAnalyzerInstance = null
var sub_level: float = 0.0
var low_level: float = 0.0
var mid_level: float = 0.0
var air_level: float = 0.0
var climate_memory: float = 0.0

# ---------------- world ----------------
var sand_material: ShaderMaterial = null
var environment_resource: Environment = null
var skin_shader: Shader = null
var skin_cache: Dictionary = {}
var dust_material: StandardMaterial3D = null
var debug_label: Label = null

# quake events: {t, pos: Vector2, s, reach}
var quakes: Array = []

# footprints ring buffer (x, z, birth, heading) and craters
var prints: PackedVector4Array = PackedVector4Array()
var print_head: int = 0
var craters: PackedVector4Array = PackedVector4Array()
var crater_head: int = 0

# ---------------- props ----------------
var palms: Array = []        # {root, sway, phase, height}
var mannequins: Array = []
var rock_camels: Array = []

# ---------------- creatures ----------------
var camels: Array = []
var dinos: Array = []


var gz: Dictionary = {}
var boeing: Dictionary = {}
var cars: Array = []
var car_timer: float = 10.0

# ---------------- fx pools ----------------
var pool_step_dust: Array = []
var falling_rocks: Node = null
var pool_sand: Array = []
var pool_impact_dust: Array = []
var pool_impact_spray: Array = []
var debris_point_texture: ImageTexture = null
var rise_dust: GPUParticles3D = null

# ---------------- cameras ----------------
const BIRDS_SCRIPT: String = "res://dove_man/characters/birds.gd"
const DIRECTOR_SCRIPT: String = "res://dove_man/characters/director.gd"
const SCORE_SCRIPT: String = "res://dove_man/characters/score_recorder.gd"
var birds: Node3D = null
var director: Node = null
var sun: DirectionalLight3D = null
var sky_material: ProceduralSkyMaterial = null
var TL: Dictionary = {}        # current timeline values
var next_drop: Dictionary = {} # {pos, at}
var ending: bool = false
var fog_view_scale: float = 1.0  # the director thins the haze for views from high above


# ============================================================
# READY / PROCESS
# ============================================================

func _ready() -> void:
	rng.randomize()
	D = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if D == null or D.is_empty():
		push_error("Dove Man: cannot read " + DATA_PATH)
		return
	skin_shader = load(SHADERS + "desert_skin.gdshader")
	dust_material = make_dust_material()
	prints.resize(32)
	for i in 32:
		prints[i] = Vector4(1e5, 1e5, -1e5, 0.0)
	craters.resize(12)
	for i in 12:
		craters[i] = Vector4(1e5, 1e5, -1e5, 0.0)

	create_environment()
	create_sand()
	create_dove_man()
	create_palms()
	create_mannequins()
	create_rock_camels()
	create_camels()
	create_dinos()
	create_boeing()
	create_godzilla()
	create_fx_pools()
	car_timer = float(D["cars"]["first_s"])
	apply_timeline()
	create_stage_front()
	setup_microphone()
	birds = Node3D.new()
	birds.set_script(load(BIRDS_SCRIPT))
	add_child(birds)
	birds.setup(self, D["birds"])
	director = Node.new()
	director.set_script(load(DIRECTOR_SCRIPT))
	add_child(director)
	director.setup(self)
	# the hour is written down as it happens, to be read back as a score
	if bool(D.get("score", {}).get("record", true)):
		var rec: Node = Node.new()
		rec.name = "ScoreRecorder"
		rec.set_script(load(SCORE_SCRIPT))
		add_child(rec)
		rec.setup(self)
	create_debug_display()
	debug_label.visible = false


func _process(delta: float) -> void:
	if D.is_empty():
		return
	t += delta
	apply_timeline()
	sand_material.set_shader_parameter("world_time", t)
	connect_spectrum_if_ready()
	read_microphone(delta)
	update_climate(delta)
	prune_quakes()

	update_godzilla(delta)
	update_palms()
	update_mannequins(delta)
	update_camels(delta)
	update_dinos(delta)
	update_boeing(delta)
	update_cars(delta)

	pass
	update_debug_display()
	if t >= float(D["timeline"]["duration_s"]):
		end_of_world()


# ============================================================
# HELPERS
# ============================================================

func dune_height(x: float, z: float) -> float:
	var u: float = x * 0.82 + z * 0.24
	var v: float = -x * 0.15 + z * 0.95
	return sin(u * 0.010 + 0.7) * 6.0 + sin(u * 0.004 - 0.4) * 8.0 + sin(v * 0.006 + 1.2) * 3.0 + sin(u * 0.045 + v * 0.012) * 0.45


func v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func xform(a: Array) -> Transform3D:
	# [bx(3), by(3), bz(3), origin(3)]
	return Transform3D(Basis(v3(a.slice(0, 3)), v3(a.slice(3, 6)), v3(a.slice(6, 9))), v3(a.slice(9, 12)))


func load_model(file_name: String) -> Node3D:
	var res: Resource = load(MODELS + file_name)
	var scene: PackedScene = res as PackedScene
	if scene == null:
		push_warning("Dove Man: missing model " + file_name)
		return Node3D.new()
	return scene.instantiate() as Node3D


func find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var p: AnimationPlayer = find_player(c)
		if p != null:
			return p
	return null


func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s: Skeleton3D = find_skeleton(c)
		if s != null:
			return s
	return null


func loop_animation(player: AnimationPlayer, anim_name: String) -> void:
	if player != null and player.has_animation(anim_name):
		player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


func each_geometry(n: Node, out: Array) -> Array:
	if n is GeometryInstance3D:
		out.append(n)
	for c in n.get_children():
		each_geometry(c, out)
	return out


func set_instance_param(root: Node, param: String, value: Variant) -> void:
	for g in each_geometry(root, []):
		(g as GeometryInstance3D).set_instance_shader_parameter(param, value)


# The shared desert skin: every imported StandardMaterial3D becomes the desert_skin shader,
# keeping its own textures.
func apply_desert_skin(root: Node, cake: float, dust_amount: float) -> void:
	for g in each_geometry(root, []):
		if not (g is MeshInstance3D):
			continue
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.get_active_material(s)
			var sm: StandardMaterial3D = m as StandardMaterial3D
			if sm == null or sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var key: String = str(sm.get_instance_id()) + "_" + str(cake) + "_" + str(dust_amount)
			if not skin_cache.has(key):
				var mat: ShaderMaterial = ShaderMaterial.new()
				mat.shader = skin_shader
				mat.set_shader_parameter("albedo_color", sm.albedo_color)
				mat.set_shader_parameter("has_albedo_tex", sm.albedo_texture != null)
				if sm.albedo_texture != null:
					mat.set_shader_parameter("albedo_tex", sm.albedo_texture)
				var has_n: bool = sm.normal_enabled and sm.normal_texture != null
				mat.set_shader_parameter("has_normal_tex", has_n)
				if has_n:
					mat.set_shader_parameter("normal_tex", sm.normal_texture)
				mat.set_shader_parameter("base_roughness", sm.roughness)
				mat.set_shader_parameter("base_metallic", sm.metallic)
				mat.set_shader_parameter("cake_height", cake)
				mat.set_shader_parameter("dust", dust_amount)
				skin_cache[key] = mat
			mi.set_surface_override_material(s, skin_cache[key])


func make_dust_material() -> StandardMaterial3D:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.albedo_color = Color(0.6, 0.43, 0.27, 0.32)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


# ============================================================
# QUAKE — one model for footsteps and car impacts
# ============================================================

func add_quake(pos: Vector2, strength: float, reach: float) -> void:
	quakes.append({"t": t, "pos": pos, "s": strength, "reach": reach})
	if birds != null:
		birds.disturb(Vector3(pos.x, dune_height(pos.x, pos.y), pos.y), reach * 1.4, 7.0 * strength)


func prune_quakes() -> void:
	var keep: Array = []
	for q in quakes:
		if t - q["t"] < 12.0:
			keep.append(q)
	quakes = keep


# returns Vector3(push_x, push_z, envelope): oscillation directed away from each impact
func quake_at(p: Vector2, freq: float, tau: float, reach_scale: float = 1.0) -> Vector3:
	var out: Vector3 = Vector3.ZERO
	for q in quakes:
		var age: float = t - q["t"]
		if age < 0.0 or age > 7.0:
			continue
		var d: Vector2 = p - q["pos"]
		var dist: float = d.length() + 0.001
		var a: float = q["s"] / (1.0 + pow(dist / (q["reach"] * reach_scale), 2.0)) * exp(-age / tau)
		var osc: float = sin(TAU * freq * age)
		out.x += a * osc * d.x / dist
		out.y += a * osc * d.y / dist
		out.z += a
	return out


# ============================================================
# ENVIRONMENT, SAND, DOVE MAN
# ============================================================

func create_environment() -> void:
	var e: Dictionary = D["environment"]
	var env_node: WorldEnvironment = WorldEnvironment.new()
	environment_resource = Environment.new()
	environment_resource.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material = sky_mat
	sky_mat.sky_top_color = Color(e["sky_top"][0], e["sky_top"][1], e["sky_top"][2])
	sky_mat.sky_horizon_color = Color(e["sky_horizon"][0], e["sky_horizon"][1], e["sky_horizon"][2])
	sky_mat.ground_horizon_color = Color(e["ground_horizon"][0], e["ground_horizon"][1], e["ground_horizon"][2])
	sky_mat.ground_bottom_color = Color(e["ground_bottom"][0], e["ground_bottom"][1], e["ground_bottom"][2])
	sky.sky_material = sky_mat
	environment_resource.sky = sky
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment_resource.ambient_light_energy = 0.72
	environment_resource.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment_resource.fog_enabled = true
	environment_resource.fog_light_color = Color(e["fog_color"][0], e["fog_color"][1], e["fog_color"][2])
	environment_resource.fog_density = e["fog_density"]
	environment_resource.fog_sky_affect = 0.58
	environment_resource.ssao_enabled = true
	environment_resource.volumetric_fog_enabled = true
	environment_resource.volumetric_fog_density = 0.006
	environment_resource.volumetric_fog_albedo = Color(e["fog_color"][0], e["fog_color"][1], e["fog_color"][2])
	environment_resource.volumetric_fog_length = 420.0
	environment_resource.volumetric_fog_detail_spread = 2.0
	environment_resource.volumetric_fog_sky_affect = 0.5
	environment_resource.volumetric_fog_ambient_inject = 0.2
	environment_resource.adjustment_enabled = true
	environment_resource.adjustment_contrast = 1.12
	environment_resource.adjustment_saturation = 1.08
	environment_resource.glow_enabled = true
	environment_resource.glow_intensity = 0.35
	environment_resource.glow_bloom = 0.04
	env_node.environment = environment_resource
	add_child(env_node)

	sun = DirectionalLight3D.new()
	sun.light_volumetric_fog_energy = 1.2
	sun.name = "Sun"
	var dir: Vector3 = v3(e["sun_direction"]).normalized()
	sun.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	sun.light_color = Color(e["sun_color"][0], e["sun_color"][1], e["sun_color"][2])
	sun.light_energy = e["sun_energy"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	add_child(sun)


func create_sand() -> void:
	var sand: MeshInstance3D = MeshInstance3D.new()
	sand.name = "Reactive_Dunes"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(900.0, 900.0)
	plane.subdivide_width = 360
	plane.subdivide_depth = 360
	sand.mesh = plane
	sand_material = ShaderMaterial.new()
	sand_material.shader = load(SHADERS + "sand.gdshader")
	var fp: Dictionary = D["godzilla"]["footprint"]
	sand_material.set_shader_parameter("print_depth", fp["depth"])
	sand_material.set_shader_parameter("print_half_width", fp["half_width"])
	sand_material.set_shader_parameter("print_half_length", fp["half_length"])
	sand_material.set_shader_parameter("print_memory", fp["memory_s"])
	var cr: Dictionary = D["cars"]["crater"]
	var ck: float = float(D["cars"]["scale"])
	sand_material.set_shader_parameter("crater_depth", float(cr["depth_m"]) * sqrt(ck))
	sand_material.set_shader_parameter("crater_radius", float(cr["radius_m"]) * ck)
	sand_material.set_shader_parameter("crater_rim", float(cr["rim_m"]) * sqrt(ck))
	sand_material.set_shader_parameter("crater_rim_radius", float(cr["rim_radius_m"]) * ck)
	sand_material.set_shader_parameter("crater_fill_delay", float(cr["fill_delay_s"]))
	sand_material.set_shader_parameter("crater_fill_s", float(cr["fill_s"]))
	sand.material_override = sand_material
	# the vertex shader moves the surface; keep it from being culled
	sand.extra_cull_margin = 30.0
	sand.layers = 3          # layer 2: only the sand takes the dinosaurs' footprints
	add_child(sand)
	# beyond the stage: a wide, coarse continuation of the dunes, just below the stage sand
	var outer: MeshInstance3D = MeshInstance3D.new()
	outer.name = "Far_Dunes"
	var big: PlaneMesh = PlaneMesh.new()
	big.size = Vector2(4000.0, 4000.0)
	big.subdivide_width = 220
	big.subdivide_depth = 220
	outer.mesh = big
	outer.material_override = sand_material
	outer.position.y = -0.8
	outer.extra_cull_margin = 30.0
	outer.layers = 3
	add_child(outer)


func push_footprint(pos: Vector2, heading: float) -> void:
	prints[print_head] = Vector4(pos.x, pos.y, t, heading)
	print_head = (print_head + 1) % 32
	sand_material.set_shader_parameter("prints", prints)
	sand_material.set_shader_parameter("print_count", 32)


# 1 = fresh hole, 0 = the wind has filled it level again
func crater_presence(age: float) -> float:
	var cr: Dictionary = D["cars"]["crater"]
	var u: float = clampf((age - float(cr["fill_delay_s"])) / float(cr["fill_s"]), 0.0, 1.0)
	return 1.0 - u * u * (3.0 - 2.0 * u)


func push_crater(pos: Vector2) -> int:
	var slot: int = crater_head
	craters[slot] = Vector4(pos.x, pos.y, t, 1.0)
	crater_head = (crater_head + 1) % craters.size()
	sand_material.set_shader_parameter("craters", craters)
	sand_material.set_shader_parameter("crater_count", craters.size())
	return slot


func clear_crater(slot: int) -> void:
	craters[slot] = Vector4(1e5, 1e5, -1e5, 0.0)
	sand_material.set_shader_parameter("craters", craters)


func create_dove_man() -> void:
	var d: Dictionary = D["dove"]
	var dove: Node3D = load_model(d["model"])
	dove.name = "Dove_Man"
	add_child(dove)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(SHADERS + "dove_mountain.gdshader")
	mat.set_shader_parameter("object_center", v3(d["center"]))
	mat.set_shader_parameter("object_scale", d["scale"])
	for g in each_geometry(dove, []):
		(g as GeometryInstance3D).material_override = mat
	# emission points for the falling debris (shoulders, head, hands)
	var pts: Array = d["debris_points"]
	var img: Image = Image.create_empty(pts.size(), 1, false, Image.FORMAT_RGBF)
	for i in pts.size():
		img.set_pixel(i, 0, Color(pts[i][0], pts[i][1], pts[i][2]))
	debris_point_texture = ImageTexture.create_from_image(img)


# ============================================================
# RELATIONSHIPS — who is where, how big, and who must avoid whom
#
# Every body in the world is a disc on the sand (centre + radius).
# Walkers (camels, dinosaurs) steer around all of them; Godzilla plans
# a route in front of Dove Man that clears them; cars only land on free sand.
# ============================================================

var front_dir: Vector2 = Vector2(0.0, 1.0)   # the side of the stage the cameras look from
var camera_spots: Array = []                 # Vector2 of fixed cameras


func obstacles(me: Variant = null) -> Array:
	# walkers keep well clear of Dove Man; the mannequins' tawaf hugs his base
	var dove_r: float = 52.0
	if me is Dictionary and (me as Dictionary).has("group"):
		dove_r = float(D["pilgrims"]["dove_r"])
	var out: Array = [{"p": Vector2.ZERO, "r": dove_r, "kind": "dove"}]
	for rc in rock_camels:
		out.append({"p": Vector2(rc.position.x, rc.position.z), "r": float(rc.get_meta("height")) * 0.55, "kind": "rock_camel"})
	for pm in palms:
		out.append({"p": Vector2(pm["root"].position.x, pm["root"].position.z), "r": 3.0, "kind": "palm"})
	for mq in mannequins:
		if not is_same(mq, me):
			out.append({"p": Vector2(mq["root"].position.x, mq["root"].position.z), "r": maxf(1.2, mq["height"] * 0.3), "kind": "mannequin"})
	for cs in camera_spots:
		out.append({"p": cs, "r": 8.0, "kind": "camera"})
	for c in cars:
		if c["impacted"] and c["sinking"] < 0.0:
			out.append({"p": c["pos"], "r": c["h"] * 1.6, "kind": "wreck"})
	for c in camels:
		if not is_same(c, me):
			out.append({"p": c.pos, "r": c.height * 0.45, "kind": "camel"})
	for d in dinos:
		if not is_same(d, me):
			out.append({"p": d["pos"], "r": d["h"] * 0.9, "kind": "dino"})
	if not gz.is_empty() and gz["state"] != GZ_WAITING:
		out.append({"p": Vector2(gz["root"].position.x, gz["root"].position.z), "r": 20.0, "kind": "godzilla"})
	return out


# Bend a wished-for direction around everything nearby (look-ahead + personal space).
func steer(pos: Vector2, dir: Vector2, radius: float, me: Variant) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for o in obstacles(me):
		var rel: Vector2 = pos - o["p"]
		var dist: float = rel.length()
		var reach: float = radius + o["r"] + 6.0
		if dist < 0.001:
			continue
		if dist < reach:
			push += rel / dist * ((reach - dist) / reach) * 6.0
		if dir != Vector2.ZERO:
			var to_o: Vector2 = o["p"] - pos
			var ahead: float = to_o.dot(dir)
			if ahead > 0.0 and ahead < reach * 2.5:
				var lateral: Vector2 = to_o - dir * ahead
				var ll: float = lateral.length()
				if ll < reach:
					var away: Vector2 = -lateral.normalized() if ll > 0.001 else Vector2(-dir.y, dir.x)
					push += away * (1.0 - ll / reach) * 1.5 * (1.0 - ahead / (reach * 2.5))
	if dir == Vector2.ZERO:
		return push.limit_length(1.0)
	return (dir + push).normalized()


# Hard rule after every move: nobody ends up inside anything solid.
func resolve(pos: Vector2, radius: float, me: Variant) -> Vector2:
	for o in obstacles(me):
		var rel: Vector2 = pos - o["p"]
		var dist: float = rel.length()
		var min_d: float = radius + o["r"]
		if dist < min_d:
			var n: Vector2 = rel / dist if dist > 0.001 else Vector2.RIGHT
			pos = o["p"] + n * min_d
	return pos


func spot_is_free(p: Vector2, radius: float, extra: float = 6.0) -> bool:
	for o in obstacles(null):
		if p.distance_to(o["p"]) < radius + o["r"] + extra:
			return false
	return true


func random_free_target(r: RandomNumberGenerator, radius: float, rmin: float, rmax: float) -> Vector2:
	for i in 40:
		var a: float = r.randf_range(0.0, TAU)
		var p: Vector2 = Vector2(cos(a), sin(a)) * r.randf_range(rmin, rmax)
		if spot_is_free(p, radius):
			return p
	return Vector2(cos(r.randf() * TAU), sin(r.randf() * TAU)) * rmax


func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var u: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * u)


# CPU twin of the sand shader: dunes + Godzilla's bowl + footprints + craters
func sand_height(x: float, z: float) -> float:
	var p: Vector2 = Vector2(x, z)
	var h: float = dune_height(x, z)
	if maxf(absf(x), absf(z)) > 450.0:
		h -= 0.8          # beyond the stage: the far-dunes plane sits a little lower
	if not gz.is_empty() and gz["state"] != GZ_WAITING and gz["state"] != GZ_WALKING:
		var d: float = p.distance_to(Vector2(gz["root"].position.x, gz["root"].position.z))
		h += -exp(-pow(d / 11.0, 2.0)) * 4.2 + exp(-pow((d - 12.0) / 3.5, 2.0)) * 1.5
	var ck: float = float(D["cars"]["scale"])
	var cr: Dictionary = D["cars"]["crater"]
	var rad: float = float(cr["radius_m"]) * ck
	var rim_r: float = float(cr["rim_radius_m"]) * ck
	for c in craters:
		if c.w < 0.5:
			continue
		var fill: float = crater_presence(t - c.z)
		if fill <= 0.0:
			continue
		var dc: float = p.distance_to(Vector2(c.x, c.y))
		h += fill * -exp(-pow(dc / rad, 2.0)) * float(cr["depth_m"]) * sqrt(ck) + exp(-pow((dc - rim_r) / (rad * 0.4), 2.0)) * float(cr["rim_m"]) * sqrt(ck)
	return h


# Something fell over: palms flattened by a foot, mannequins toppled by an impact.
func topple(prop: Dictionary, from: Vector2) -> void:
	if prop.get("fallen", false):
		return
	var root: Node3D = prop["root"]
	var d: Vector2 = Vector2(root.position.x, root.position.z) - from
	var dir3: Vector3 = Vector3(d.x, 0.0, d.y).normalized()
	var axis_world: Vector3 = Vector3.UP.cross(dir3).normalized()
	prop["fall_axis"] = (root.basis.orthonormalized().inverse() * axis_world).normalized()
	prop["fall_t"] = t
	prop["fallen"] = true
	prop["down_t"] = 0.0
	prop["rising"] = false


func fall_basis(prop: Dictionary, max_angle: float) -> Basis:
	if not prop.get("fallen", false):
		return Basis.IDENTITY
	var u: float = clampf((t - prop["fall_t"]) / 1.3, 0.0, 1.0)
	var ease: float = u * u * (3.0 - 2.0 * u)
	var bounce: float = sin(clampf((t - prop["fall_t"] - 1.3) / 0.5, 0.0, 1.0) * PI) * 0.06
	return Basis(prop["fall_axis"], max_angle * ease - bounce)


# Every impact on the sand asks the world to react around it.
func react_to_impact(p: Vector2, kind: String) -> void:
	if kind == "step":
		for pm in palms:
			if Vector2(pm["root"].position.x, pm["root"].position.z).distance_to(p) < 9.0:
				topple(pm, p)
		for mq in mannequins:
			if Vector2(mq["root"].position.x, mq["root"].position.z).distance_to(p) < 12.0:
				topple(mq, p)
		for c in cars:
			if c["impacted"] and c["pos"].distance_to(p) < c["h"] * 2.5:
				c["jolt_t"] = t
	elif kind == "car":
		for mq in mannequins:
			if Vector2(mq["root"].position.x, mq["root"].position.z).distance_to(p) < 16.0:
				topple(mq, p)
		for pm in palms:
			if Vector2(pm["root"].position.x, pm["root"].position.z).distance_to(p) < 8.0:
				topple(pm, p)
	for c in camels:
		if c.pos.distance_to(p) < (30.0 if kind == "car" else 22.0):
			c.startle(p)


# ============================================================
# PALMS & MANNEQUINS (placed and grounded in Blender)
# ============================================================

func place_prop(model_file: String, entry: Dictionary, skin: bool) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.transform = xform(entry["xform"])
	add_child(root)
	var sway: Node3D = Node3D.new()
	root.add_child(sway)
	var model: Node3D = load_model(model_file)
	model.scale = Vector3.ONE * float(entry["height"])
	sway.add_child(model)
	if skin:
		apply_desert_skin(model, 0.12, 0.6)
		set_instance_param(model, "root_y", root.position.y)
		set_instance_param(model, "body_height", float(entry["height"]))
	return {"root": root, "sway": sway, "phase": float(entry.get("phase", 0.0)), "height": float(entry["height"])}


func create_palms() -> void:
	for e in D["palms"]:
		palms.append(place_prop(D["models"]["palm"], e, false))


func create_mannequins() -> void:
	var PG: Dictionary = D["pilgrims"]
	var k: int = 0
	for e in D["mannequins"]:
		var m: Dictionary = place_prop(D["models"]["mannequin"], e, true)
		var G: Dictionary = PG["groups"][e.get("group", "inner")]
		var r: RandomNumberGenerator = RandomNumberGenerator.new()
		r.seed = 7100 + k * 31
		k += 1
		var p: Vector2 = Vector2(m["root"].position.x, m["root"].position.z)
		var out: Vector2 = p.normalized()
		var tang: Vector2 = Vector2(out.y, -out.x)      # counter-clockwise seen from above: Dove Man on the left
		var h: float = m["height"]
		m["group"] = e.get("group", "inner")
		m["rng"] = r
		m["pos"] = p
		m["ring"] = float(G["ring"]) + r.randf_range(-1.0, 1.0) * float(G["spread"])
		m["breath"] = r.randf_range(0.0, TAU)
		m["yaw"] = atan2(tang.x, tang.y)                  # the model faces +Z: forward = (sin yaw, cos yaw)
		m["yaw_rate"] = 0.0
		m["wish"] = tang
		m["walk"] = float(G["speed_per_h"]) * h * r.randf_range(0.8, 1.2)
		m["speed"] = 0.0
		m["step"] = r.randf_range(0.0, 2.0)                # step phase: one unit per step, left/right alternate
		m["lean"] = deg_to_rad(r.randf_range(PG["lean_deg"][0], PG["lean_deg"][1]))
		m["roll"] = deg_to_rad(r.randf_range(PG["roll_deg"][0], PG["roll_deg"][1]))
		m["limp"] = deg_to_rad(r.randf_range(PG["limp_deg"][0], PG["limp_deg"][1]))
		m["stall"] = r.randf_range(0.0, 6.0)               # some start standing, dazed
		m["stall_in"] = r.randf_range(PG["stall_every_s"][0], PG["stall_every_s"][1])
		m["slump"] = 0.0
		m["rise_after"] = r.randf_range(PG["rise_after_s"][0], PG["rise_after_s"][1])
		mannequins.append(m)


func update_palms() -> void:
	var Q: Dictionary = D["quake"]["palm"]
	var pressure: float = sub_level * 0.45 + low_level * 0.75 + climate_memory * 0.30
	var sway_amp: float = deg_to_rad(0.35 + pressure * 8.5)
	for p in palms:
		var root: Node3D = p["root"]
		var q: Vector3 = quake_at(Vector2(root.position.x, root.position.z), Q["freq"], Q["tau"])
		var a: float = deg_to_rad(Q["deg"])
		var sw: Node3D = p["sway"]
		var alive: float = 0.25 if p.get("fallen", false) else 1.0
		var sway_b: Basis = Basis.from_euler(Vector3(cos(t * 0.17 + p["phase"]) * sway_amp * 0.35 + q.y * a, 0.0, sin(t * 0.25 + p["phase"]) * sway_amp - q.x * a) * alive)
		sw.basis = fall_basis(p, deg_to_rad(78.0)) * sway_b


# ------------------------------------------------------------ the mannequins' tawaf
# Seven around Dove Man's feet, seven further out between them and the dinosaurs. All walk
# counter-clockwise around him, with him on their left, like the circling at the Kaaba, but
# they walk like the undead: a forward slump, short dragged steps, the body rolling from one
# side to the other, a surge on every step and a drag between, now and then a dazed stand.
# Knocked down by a car or a step, they lie still a while, then jerk themselves upright and
# rejoin the circle (except in the burial phase).
func update_mannequins(delta: float) -> void:
	var Q: Dictionary = D["quake"]["mannequin"]
	var PG: Dictionary = D["pilgrims"]
	var response: float = low_level * 0.75 + mid_level * 0.45 + climate_memory * 0.20
	var sway_amp: float = deg_to_rad(0.8 + response * 17.0)
	var sink: float = timeline_value("mannequin_sink")
	for m in mannequins:
		walk_pilgrim(m, delta, sink, PG)
		var root: Node3D = m["root"]
		var p2: Vector2 = m["pos"]
		var h: float = m["height"]
		var q: Vector3 = quake_at(p2, Q["freq"], Q["tau"])
		var hop: Vector3 = quake_at(p2, 0.0, Q["hop_tau"])
		var a: float = deg_to_rad(Q["deg"])
		var sw: Node3D = m["sway"]
		var down: float = pilgrim_down(m, PG)
		var alive: float = 1.0 - down
		var amt: float = clampf(m["speed"] / maxf(m["walk"], 0.01), 0.0, 1.0)
		# the sound still moves them, less while they walk
		var sa: float = sway_amp * (1.0 - 0.5 * amt)
		var sway_b: Basis = Basis.from_euler(Vector3(sin(t * 0.29 + m["phase"] * 1.4) * sa * 0.42 + q.y * a, 0.0, sin(t * 0.42 + m["phase"]) * sa - q.x * a) * alive)
		# the shamble
		var u: float = fposmod(m["step"], 1.0)
		var side: float = 1.0 if int(floor(m["step"])) % 2 == 0 else -1.0
		var sv: float = sin(u * PI)
		var lean: float = m["lean"] * (0.55 + 0.45 * amt) + m["slump"] + deg_to_rad(2.5) * sin(TAU * u) * amt
		var roll: float = side * m["roll"] * sv * amt + m["limp"]
		var wob: float = side * deg_to_rad(3.0) * sv * amt
		var gait_b: Basis = Basis.from_euler(Vector3(lean, wob, -roll) * alive)
		var fall_b: Basis = Basis.IDENTITY
		if m.get("fallen", false):
			fall_b = Basis(m["fall_axis"], deg_to_rad(88.0) * down)
		sw.basis = fall_b * gait_b * sway_b
		var bob: float = -h * 0.02 * (1.0 - sv) * amt
		sw.position.y = Q["hop_m"] * hop.z * alive + bob * alive - 0.15 * h * down - sink * h
		set_instance_param(sw.get_child(0), "root_y", root.position.y)


# 0 standing .. 1 lying flat (falls in 1.3 s with a small bounce; rises in jerks)
func pilgrim_down(m: Dictionary, PG: Dictionary) -> float:
	if not m.get("fallen", false):
		return 0.0
	var u: float = clampf((t - m["fall_t"]) / 1.3, 0.0, 1.0)
	var f: float = u * u * (3.0 - 2.0 * u) - sin(clampf((t - m["fall_t"] - 1.3) / 0.5, 0.0, 1.0) * PI) * 0.07
	if m.get("rising", false):
		var ru: float = clampf((t - m["rise_t"]) / float(PG["rise_s"]), 0.0, 1.0)
		# not a smooth getting-up: three heaves, slipping back a little after each
		var heaves: float = (floor(ru * 3.0) + smoothstep(0.0, 0.55, fposmod(ru * 3.0, 1.0)) - 0.25 * smoothstep(0.55, 1.0, fposmod(ru * 3.0, 1.0))) / 3.0
		f *= 1.0 - clampf(maxf(heaves, ru * ru), 0.0, 1.0)
	return clampf(f, 0.0, 1.0)


func walk_pilgrim(m: Dictionary, delta: float, sink: float, PG: Dictionary) -> void:
	var r: RandomNumberGenerator = m["rng"]
	var h: float = m["height"]
	var root: Node3D = m["root"]
	if m.get("fallen", false):
		m["speed"] = 0.0
		m["down_t"] += delta
		if not m["rising"] and m["down_t"] > m["rise_after"] and sink < float(PG["stay_down_when_sink"]):
			m["rising"] = true
			m["rise_t"] = t
		if m["rising"] and t - m["rise_t"] > float(PG["rise_s"]):
			m["fallen"] = false
			m["rising"] = false
			m["stall"] = r.randf_range(4.0, 9.0)          # stands dazed before walking on
			m["rise_after"] = r.randf_range(PG["rise_after_s"][0], PG["rise_after_s"][1])
		return
	var G: Dictionary = PG["groups"][m["group"]]
	# now and then they stop and stand, slumping a little further
	m["stall_in"] -= delta
	if m["stall_in"] <= 0.0:
		m["stall"] = r.randf_range(PG["stall_s"][0], PG["stall_s"][1])
		m["stall_in"] = r.randf_range(PG["stall_every_s"][0], PG["stall_every_s"][1])
	var stalled: bool = m["stall"] > 0.0
	if stalled:
		m["stall"] -= delta
	m["slump"] = move_toward(m["slump"], deg_to_rad(5.0) if stalled else 0.0, delta * deg_to_rad(4.0))
	var p: Vector2 = m["pos"]
	var rad: float = maxf(p.length(), 1.0)
	var out: Vector2 = p / rad
	var tang: Vector2 = Vector2(out.y, -out.x)
	var ring: float = m["ring"] + sin(t * 0.01 + m["breath"]) * float(G["breath"])
	var want: Vector2 = (tang + out * clampf((ring - rad) / 10.0, -0.7, 0.7)).normalized()
	var body_r: float = h * float(PG["body_r_per_h"])
	want = steer(p, want, body_r, m)
	var want_speed: float = 0.0 if stalled else m["walk"] * (1.0 - 0.6 * sink)
	m["wish"] = (m["wish"] as Vector2).lerp(want, 1.0 - exp(-delta * 0.8))
	m["speed"] += (want_speed - m["speed"]) * (1.0 - exp(-delta * (0.6 if want_speed > m["speed"] else 1.2)))
	var w: Vector2 = m["wish"]
	var err: float = 0.0
	if w.length() > 0.05:
		err = wrapf(atan2(w.x, w.y) - m["yaw"], -PI, PI)
	var max_rate: float = m["speed"] / (h * 1.2)
	var target_rate: float = clampf(err * 0.8, -max_rate, max_rate)
	m["yaw_rate"] += (target_rate - m["yaw_rate"]) * (1.0 - exp(-delta * 1.2))
	m["yaw"] += m["yaw_rate"] * delta
	# a surge on each step, a drag between: the distance and the step phase stay locked
	var u: float = fposmod(m["step"], 1.0)
	var v: float = m["speed"] * (0.3 + 1.4 * pow(sin(u * PI), 2.0))
	m["step"] += v * delta / (float(PG["stride_per_height"]) * h)
	p += Vector2(sin(m["yaw"]), cos(m["yaw"])) * v * delta
	p = resolve(p, body_r, m)
	m["pos"] = p
	root.basis = Basis(Vector3.UP, m["yaw"])
	root.position = Vector3(p.x, sand_height(p.x, p.y) - float(PG["foot_depth"]), p.y)


func create_rock_camels() -> void:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(SHADERS + "rock_sand.gdshader")
	for e in D["rock_camels"]:
		var root: Node3D = Node3D.new()
		root.transform = xform(e["xform"])
		add_child(root)
		var model: Node3D = load_model(D["models"]["rock_camel"])
		root.add_child(model)
		for g in each_geometry(model, []):
			(g as GeometryInstance3D).material_override = mat
		set_instance_param(model, "root_y", float(e["root_y"]))
		set_instance_param(model, "body_height", float(e["height"]))
		root.set_meta("height", float(e["height"]))
		rock_camels.append(root)


# ============================================================
# LIVING CAMELS — each one is its own character (characters/camel.gd)
# ============================================================

const CAMEL_SCRIPT: String = "res://dove_man/characters/camel.gd"
const ROCKS_SCRIPT: String = "res://dove_man/characters/falling_rocks.gd"


func create_camels() -> void:
	var C: Dictionary = D["camels"]
	var scene: PackedScene = load(MODELS + C["model"])
	for e in C["list"]:
		var c: Node3D = (load(CAMEL_SCRIPT) as GDScript).new()
		c.name = e["name"]
		add_child(c)
		c.setup(self, scene, e, C["gait"], int(e["seed"]) * 7919 + rng.randi_range(0, 100000))
		apply_desert_skin(c.model, C["gait"]["cake"], C["gait"]["dust"])
		set_instance_param(c.model, "body_height", float(e["height"]))
		camels.append(c)


# Finds the four soles on the camel's own mesh (rest pose) and stores each one in the frame
# of its lower-leg bone, so the sole can be followed through any animation.
func calibrate_soles(model: Node3D, sk: Skeleton3D, bones: Array) -> Array:
	var bone_world: Array = []
	for bi in bones:
		bone_world.append(sk.global_transform * sk.get_bone_global_rest(bi) if bi >= 0 else Transform3D())
	var pts: Array = []
	for g in each_geometry(model, []):
		if not (g is MeshInstance3D):
			continue
		var mi: MeshInstance3D = g as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if verts.size() < 2000:
			continue
		var step: int = maxi(1, verts.size() / 20000)
		for i in range(0, verts.size(), step):
			pts.append(mi.global_transform * verts[i])
	if pts.is_empty():
		return []
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	var low: Array = pts.slice(0, maxi(40, pts.size() / 30))
	var sums: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var counts: Array = [0, 0, 0, 0]
	for p in low:
		var best: int = 0
		var bd: float = 1e18
		for i in 4:
			var o: Vector3 = (bone_world[i] as Transform3D).origin
			var d: float = Vector2(p.x - o.x, p.z - o.z).length_squared()
			if d < bd:
				bd = d
				best = i
		sums[best] += p
		counts[best] += 1
	var out: Array = []
	for i in 4:
		if counts[i] == 0:
			return []
		var sole_world: Vector3 = sums[i] / float(counts[i])
		out.append((bone_world[i] as Transform3D).affine_inverse() * sole_world)
	return out


func godzilla_threat(p: Vector2) -> Dictionary:
	# Returns the direction to flee (or Vector2.ZERO) and whether it is urgent.
	if gz.is_empty() or gz["state"] == GZ_WAITING:
		return {"dir": Vector2.ZERO}
	var g2: Vector2 = Vector2(gz["root"].position.x, gz["root"].position.z)
	var rel: Vector2 = p - g2
	var dist: float = rel.length()
	var pdir: Vector2 = gz["dir"]
	var along: float = (p - gz["start"]).dot(pdir)
	var side: float = (p - gz["start"]).dot(Vector2(-pdir.y, pdir.x))
	var g_along: float = (g2 - gz["start"]).dot(pdir)
	if dist < 120.0 or (along > g_along - 20.0 and absf(side) < 55.0):
		var s: float = 1.0 if side >= 0.0 else -1.0
		var f: Vector2 = Vector2(-pdir.y, pdir.x) * s
		if dist < 120.0:
			f += rel / maxf(dist, 0.01) * 0.8
		return {"dir": f.normalized()}
	return {"dir": Vector2.ZERO}


func update_camels(delta: float) -> void:
	var Q: Dictionary = D["quake"]["camel"]
	var hesitation: float = clampf(sub_level * 0.65 + climate_memory * 0.20, 0.0, 0.88)
	for c in camels:
		var threat: Dictionary = godzilla_threat(c.pos)
		c.tick(delta, threat["dir"], hesitation, quake_at(c.pos, Q["freq"], Q["tau"]), Q)


# ============================================================
# DINOSAURS — a slow circumambulation around Dove Man
#
# Few of them, each on its own ring (one close, one far at the edge of the haze),
# all walking counter-clockwise around Dove Man as the axis, like a procession.
# They pause now and then, stand aside when Godzilla crosses their ring, step round
# rock camels and wrecks, and turn only along a wide turning circle.
# ============================================================

func create_dinos() -> void:
	var DD: Dictionary = D["dinos"]
	for e in DD["list"]:
		var root: Node3D = Node3D.new()
		root.name = e["name"]
		add_child(root)
		var model: Node3D = load_model(DD["model"])
		var h: float = e["height"]
		model.scale = Vector3.ONE * h
		root.add_child(model)
		apply_desert_skin(model, DD["cake"], 1.0)
		set_instance_param(model, "body_height", h)
		var player: AnimationPlayer = find_player(model)
		if player != null:
			loop_animation(player, DD["anim"])
			player.play(DD["anim"])
			player.speed_scale = DD["anim_speed"]
			player.seek(float(e["offset_s"]), true)
		var r: RandomNumberGenerator = RandomNumberGenerator.new()
		r.seed = int(e["seed"])
		var a0: float = float(e["angle0"])
		var ring: float = float(e["ring"])
		var p: Vector2 = Vector2(cos(a0), sin(a0)) * ring
		var tang: Vector2 = Vector2(sin(a0), -cos(a0))          # counter-clockwise seen from above
		root.position = Vector3(p.x, sand_height(p.x, p.y) - float(DD["foot_depth"]), p.y)   # standing in the sand from the first frame
		dinos.append({"root": root, "model": model, "player": player, "h": h, "pos": p, "ring": ring,
			"yaw": atan2(tang.y, tang.x), "yaw_rate": 0.0, "wish": tang, "speed": 0.0,
			"walk": float(e["speed"]) * r.randf_range(0.9, 1.1), "pause": r.randf_range(60.0, 160.0), "paused": false, "rng": r,
			"breath": r.randf_range(0.0, TAU), "lobe": r.randf_range(0.0, TAU), "step": r.randf_range(0.0, 1.0),
			"next_print": 0.0, "pair": 0, "prints": [], "print_head": 0})


func update_dinos(delta: float) -> void:
	var DD: Dictionary = D["dinos"]
	var pads: Array = DD["pads"]
	for d in dinos:
		var r: RandomNumberGenerator = d["rng"]
		var p: Vector2 = d["pos"]
		var h: float = d["h"]
		# walking, then standing a while, then walking on
		d["pause"] -= delta
		if d["pause"] <= 0.0:
			d["paused"] = not d["paused"]
			d["pause"] = r.randf_range(DD["pause_s"][0], DD["pause_s"][1]) if d["paused"] else r.randf_range(DD["walk_s"][0], DD["walk_s"][1])
		var rad: float = maxf(p.length(), 1.0)
		var out: Vector2 = p / rad
		var tang: Vector2 = Vector2(out.y, -out.x)       # counter-clockwise around Dove Man
		# not a perfect circle: the track swells and dips around the world (lobes fixed in space)
		# and drifts in and out slowly over the hour; Godzilla nearby pushes it outward
		var ang: float = atan2(p.y, p.x)
		var ring: float = d["ring"] + sin(ang * 3.0 + d["lobe"]) * float(DD["lobe_m"]) \
			+ sin(ang * 5.0 + d["lobe"] * 1.7) * float(DD["lobe_m"]) * 0.35 \
			+ sin(t * 0.0021 + d["breath"]) * float(DD["wander_m"])
		var want_speed: float = 0.0 if d["paused"] else d["walk"]
		if not gz.is_empty() and gz["state"] != GZ_WAITING:
			var g2: Vector2 = Vector2(gz["root"].position.x, gz["root"].position.z)
			var gd: float = p.distance_to(g2)
			if gd < 130.0:
				ring += (130.0 - gd) * 0.8
				want_speed = maxf(want_speed, d["walk"] * 0.6) if gd < 80.0 else want_speed * 0.4
		var want: Vector2 = (tang + out * clampf((ring - rad) / 30.0, -0.8, 0.8)).normalized()
		want = steer(p, want, h * 0.9, d)
		# smoothed desire, eased speed, turning circle of about one and a half body heights
		d["wish"] = (d["wish"] as Vector2).lerp(want, 1.0 - exp(-delta * 0.5))
		d["speed"] += (want_speed - d["speed"]) * (1.0 - exp(-delta * 0.35))
		var err: float = wrapf(atan2(d["wish"].y, d["wish"].x) - d["yaw"], -PI, PI)
		var max_rate: float = d["speed"] / (h * 1.5)
		var target_rate: float = clampf(err * 0.5, -max_rate, max_rate)
		d["yaw_rate"] += (target_rate - d["yaw_rate"]) * (1.0 - exp(-delta * 0.9))
		d["yaw"] += d["yaw_rate"] * delta
		# heading angle is measured in the XZ plane with +X forward (the model's head)
		var moved: float = d["speed"] * delta
		p += Vector2(cos(d["yaw"]), sin(d["yaw"])) * moved
		p = resolve(p, h * 0.9, d)
		d["pos"] = p
		var root: Node3D = d["root"]
		root.rotation.y = -d["yaw"]
		# the walk shows in the body: one heave per step, a roll from side to side
		var stride: float = float(DD["stride_per_height"]) * h
		d["step"] += moved / stride
		var amt: float = clampf(d["speed"] / maxf(d["walk"], 0.01), 0.0, 1.0)
		var ph: float = TAU * d["step"]
		var model: Node3D = d["model"]
		model.rotation = Vector3(sin(ph) * deg_to_rad(1.6) * amt, 0.0, sin(ph * 2.0 + 0.6) * deg_to_rad(0.9) * amt)
		model.position.y = -absf(sin(ph)) * h * 0.006 * amt
		# footprints: diagonal pairs, every half stride, fading after a few minutes
		d["next_print"] -= moved
		if d["next_print"] <= 0.0:
			d["next_print"] += stride * 0.5
			var pr: Array = [[0, 3], [2, 1]][d["pair"]]
			d["pair"] = 1 - d["pair"]
			for i in pr:
				var local: Vector3 = Vector3(pads[i][0], 0.0, pads[i][2]) * h
				var wp: Vector3 = Basis(Vector3.UP, -d["yaw"]) * local + Vector3(p.x, 0.0, p.y)
				place_dino_print(d, Vector2(wp.x, wp.z), -d["yaw"], h)
		fade_dino_prints(d)
		var lowest: float = 1e9
		for pad in pads:
			var local: Vector3 = Vector3(pad[0], pad[1], pad[2]) * h
			var w: Vector3 = Basis(Vector3.UP, -d["yaw"]) * local + Vector3(p.x, 0.0, p.y)
			lowest = minf(lowest, sand_height(w.x, w.z))
		root.position = Vector3(p.x, lowest - DD["foot_depth"], p.y)
		set_instance_param(d["model"], "root_y", root.position.y)
		# the grazing clip slows down when the animal stands still
		if d["player"] != null:
			(d["player"] as AnimationPlayer).speed_scale = float(DD["anim_speed"]) * (0.45 + 0.55 * clampf(d["speed"] / d["walk"], 0.0, 1.0))


# ------------------------------------------------------------ dinosaur footprints
var print_albedo: ImageTexture
var print_normal: ImageTexture


# a pressed oval of churned sand with a soft pushed-up rim (made once, in code)
func make_print_textures() -> void:
	var n: int = 128
	var hgt: PackedFloat32Array = PackedFloat32Array()
	hgt.resize(n * n)
	var alb: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u: float = (float(x) + 0.5) / n * 2.0 - 1.0
			var v: float = (float(y) + 0.5) / n * 2.0 - 1.0
			var rr: float = sqrt(u * u / 0.55 + v * v)          # oval, longer along the walk
			var grain: float = fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)
			var bowl: float = -exp(-pow(rr / 0.55, 4.0))
			var rim: float = exp(-pow((rr - 0.72) / 0.14, 2.0)) * 0.35
			hgt[y * n + x] = bowl + rim + (grain - 0.5) * 0.06 * clampf(1.0 - rr, 0.0, 1.0)
			var a: float = clampf(1.0 - smoothstep(0.75, 1.0, rr), 0.0, 1.0)
			var shade: float = 0.78 + 0.22 * clampf(1.0 + bowl, 0.0, 1.0) + rim * 0.3 + (grain - 0.5) * 0.05
			alb.set_pixel(x, y, Color(0.70 * shade, 0.55 * shade, 0.40 * shade, a * 0.85))
	var nor: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var hx: float = hgt[y * n + mini(x + 1, n - 1)] - hgt[y * n + maxi(x - 1, 0)]
			var hy: float = hgt[mini(y + 1, n - 1) * n + x] - hgt[maxi(y - 1, 0) * n + x]
			var nv: Vector3 = Vector3(-hx * 6.0, -hy * 6.0, 1.0).normalized()
			nor.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5, 1.0))
	alb.generate_mipmaps()
	nor.generate_mipmaps()
	print_albedo = ImageTexture.create_from_image(alb)
	print_normal = ImageTexture.create_from_image(nor)


func place_dino_print(d: Dictionary, p: Vector2, yaw: float, h: float) -> void:
	var DD: Dictionary = D["dinos"]
	if print_albedo == null:
		make_print_textures()
	var prints: Array = d["prints"]
	var slot: Dictionary
	if prints.size() < int(DD["prints_per_dino"]):
		var nd: Decal = Decal.new()
		nd.texture_albedo = print_albedo
		nd.texture_normal = print_normal
		nd.cull_mask = 2
		nd.normal_fade = 0.3
		add_child(nd)
		slot = {"decal": nd, "born": t}
		prints.append(slot)
	else:
		slot = prints[d["print_head"]]
		d["print_head"] = (d["print_head"] + 1) % prints.size()
	var dec: Decal = slot["decal"]
	slot["born"] = t
	var size: float = float(DD["print_size_per_h"]) * h
	dec.size = Vector3(size, 8.0, size * 1.35)
	dec.global_transform = Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), Vector3(p.x, sand_height(p.x, p.y), p.y))
	dec.modulate = Color(1, 1, 1, 1)
	dec.visible = true


func fade_dino_prints(d: Dictionary) -> void:
	var life: float = float(D["dinos"]["print_life_s"])
	for slot in d["prints"]:
		var age: float = t - slot["born"]
		var dec: Decal = slot["decal"]
		if age > life:
			dec.visible = false
		else:
			# fresh and sharp for a while, then the wind takes them
			dec.modulate.a = 1.0 - smoothstep(life * 0.35, life, age)


# ============================================================
# GODZILLA — rises, walks stride-locked, every step is an event, sinks
# ============================================================

func create_godzilla() -> void:
	var G: Dictionary = D["godzilla"]
	var root: Node3D = Node3D.new()
	root.name = "Godzilla"
	add_child(root)
	var model: Node3D = (load(G["model_path"]) as PackedScene).instantiate()
	model.scale = Vector3.ONE * float(G["model_scale"])
	model.position.y = float(G["model_offset_y"])
	root.add_child(model)
	apply_desert_skin(model, G["cake"], 1.0)
	set_instance_param(model, "body_height", float(G["height"]))
	var player: AnimationPlayer = find_player(model)
	if player != null:
		loop_animation(player, G["anim"])
		player.play(G["anim"])
		player.speed_scale = 0.0   # driven by seek() so feet stay locked to the ground
	root.visible = false
	gz = {"root": root, "model": model, "player": player, "state": GZ_WAITING,
		"state_t": 0.0, "wait": 1e9, "schedule": gz_schedule(), "next": 0,
		"start": Vector2.ZERO, "end": Vector2.ZERO, "dir": Vector2.RIGHT, "length": 0.0,
		"phase": 0.0, "cycles": 0, "y_walk": 0.0, "speed": float(G["speed"]),
		"anim_len": player.get_animation(G["anim"]).length if player != null else 1.6}
	rise_dust = make_burst(Color(0.6, 0.43, 0.27, 0.3), 260, 3.8, 3.0, 0.0)
	rise_dust.one_shot = false
	rise_dust.explosiveness = 0.0
	(rise_dust.process_material as ParticleProcessMaterial).emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	(rise_dust.process_material as ParticleProcessMaterial).emission_ring_axis = Vector3.UP
	(rise_dust.process_material as ParticleProcessMaterial).emission_ring_radius = 11.0
	(rise_dust.process_material as ParticleProcessMaterial).emission_ring_inner_radius = 2.0
	(rise_dust.process_material as ParticleProcessMaterial).emission_ring_height = 1.0


func gz_foot(frame: float, left: bool) -> Vector3:
	# foot sole in Godzilla's local metres, interpolated from the Blender measurement
	var feet: Array = D["godzilla"]["feet"]
	var i: int = int(floor(frame)) % 48
	var j: int = (i + 1) % 49
	var u: float = frame - floor(frame)
	var o: int = 0 if left else 3
	var a: Vector3 = Vector3(feet[i][o], feet[i][o + 1], feet[i][o + 2])
	var b: Vector3 = Vector3(feet[j][o], feet[j][o + 1], feet[j][o + 2])
	return a.lerp(b, u)


func gz_travel(frame: float) -> float:
	var cum: Array = D["godzilla"]["cum"]
	var i: int = int(floor(frame))
	var u: float = frame - float(i)
	return lerpf(cum[i], cum[mini(i + 1, 48)], u)


func plan_godzilla_route() -> Array:
	# A straight crossing on the camera side of Dove Man, never closer than 80 m to him,
	# clear of rock camels, cameras and wrecks. Direction alternates randomly.
	var best: Array = []
	var best_score: float = -1e9
	for attempt in 80:
		var offset: float = rng.randf_range(85.0, 140.0)
		var tilt: float = rng.randf_range(-0.35, 0.35)
		var across: Vector2 = Vector2(-front_dir.y, front_dir.x).rotated(tilt)
		if rng.randf() < 0.5:
			across = -across
		var centre: Vector2 = front_dir.rotated(rng.randf_range(-0.5, 0.5)) * offset
		var span: float = float(D["godzilla"]["cross_half_length"])
		var a: Vector2 = centre - across * span
		var b: Vector2 = centre + across * span
		var clear: float = segment_distance(Vector2.ZERO, a, b) - 80.0
		for rc in rock_camels:
			clear = minf(clear, segment_distance(Vector2(rc.position.x, rc.position.z), a, b) - (float(rc.get_meta("height")) * 0.55 + 22.0))
		for cs in camera_spots:
			clear = minf(clear, segment_distance(cs, a, b) - 30.0)
		for c in cars:
			if c["impacted"] and c["sinking"] < 0.0:
				clear = minf(clear, segment_distance(c["pos"], a, b) - (c["h"] * 1.6 + 20.0))
		if clear >= 0.0:
			return [a, b]
		if clear > best_score:
			best_score = clear
			best = [a, b]
	return best


func begin_godzilla() -> void:
	var route: Array = plan_godzilla_route()
	gz["start"] = route[0]
	gz["end"] = route[1]
	var d: Vector2 = gz["end"] - gz["start"]
	gz["length"] = d.length() - 8.0
	gz["dir"] = d.normalized()
	gz["phase"] = 0.0
	gz["cycles"] = 0
	gz["speed"] = rng.randf_range(D["godzilla"]["speed_range"][0], D["godzilla"]["speed_range"][1]) * timeline_value("gz_speed")
	var root: Node3D = gz["root"]
	root.rotation.y = atan2(gz["dir"].x, gz["dir"].y)
	root.visible = true
	set_instance_param(gz["model"], "fade", 0.0)
	gz["state"] = GZ_WALKING
	gz["state_t"] = 0.0


func gz_walk_height(pos2: Vector2, frame: float) -> float:
	# stance foot = the lower one; it rests 1.9 m down, in its own fresh footprint
	var root: Node3D = gz["root"]
	var l: Vector3 = gz_foot(frame, true)
	var r: Vector3 = gz_foot(frame, false)
	var stance: Vector3 = l if l.y < r.y else r
	var basis: Basis = Basis(Vector3.UP, root.rotation.y)
	var w: Vector3 = basis * stance + Vector3(pos2.x, 0.0, pos2.y)
	return dune_height(w.x, w.z) - float(D["godzilla"]["foot_depth"]) - stance.y


# the crossing start times for this hour (seconds), each nudged a little so no two hours are alike
func gz_schedule() -> Array:
	var G: Dictionary = D["godzilla"]
	var out: Array = []
	for m in G["crossings_min"]:
		out.append((float(m) + rng.randf_range(-1.0, 1.0) * float(G["crossings_jitter_min"])) * 60.0)
	return out


func update_godzilla(delta: float) -> void:
	var G: Dictionary = D["godzilla"]
	var root: Node3D = gz["root"]
	gz["state_t"] += delta
	var pos2: Vector2 = Vector2(root.position.x, root.position.z)
	var hidden: float = float(G["hidden_depth"])
	match gz["state"]:
		GZ_WAITING:
			sand_material.set_shader_parameter("beast_strength", 0.0)
			rise_dust.emitting = false
			# three crossings an hour, at the minutes in godzilla → crossings_min (G key: one now)
			gz["wait"] -= delta
			var sched: Array = gz["schedule"]
			var due: bool = gz["next"] < sched.size() and t >= float(sched[gz["next"]])
			if gz["wait"] <= 0.0 or due:
				if due:
					gz["next"] += 1
				gz["wait"] = 1e9
				begin_godzilla()
		GZ_RISING:
			pos2 = gz["start"]
			var y_top: float = gz_walk_height(pos2, 0.0)
			var u: float = smoothstep(0.0, 1.0, gz["state_t"] / float(G["rise_s"]))
			root.position = Vector3(pos2.x, lerpf(dune_height(pos2.x, pos2.y) - hidden, y_top, u), pos2.y)
			sand_material.set_shader_parameter("beast_pos", pos2)
			sand_material.set_shader_parameter("beast_strength", 1.0)
			emit_ring_dust(pos2)
			if gz["state_t"] >= float(G["rise_s"]):
				gz["state"] = GZ_WALKING
				gz["state_t"] = 0.0
		GZ_WALKING:
			sand_material.set_shader_parameter("beast_strength", 0.0)
			rise_dust.emitting = false
			var frames_per_s: float = 48.0 * float(gz["speed"]) / float(G["travel_per_cycle"])
			var old_phase: float = gz["phase"]
			var ph: float = old_phase + frames_per_s * delta
			if ph >= 48.0:
				ph -= 48.0
				gz["cycles"] += 1
			gz["phase"] = ph
			var s: float = gz["cycles"] * float(G["travel_per_cycle"]) + gz_travel(ph)
			pos2 = gz["start"] + gz["dir"] * s
			root.position = Vector3(pos2.x, gz_walk_height(pos2, ph), pos2.y)
			var player: AnimationPlayer = gz["player"]
			if player != null:
				player.seek(ph / 48.0 * float(gz["anim_len"]), true)
			# footstep contacts measured in Blender
			for foot in G["contacts"]:
				var cf: float = float(G["contacts"][foot])
				var crossed: bool = (old_phase < cf and ph >= cf) or (ph < old_phase and (old_phase < cf or ph >= cf))
				if crossed:
					godzilla_step(foot == "L", ph)
			# he comes out of the haze and goes back into it: a dithered dissolve by distance
			var F: Dictionary = G["fade"]
			var fade: float = 1.0 - smoothstep(float(F["full_m"]), float(F["gone_m"]), pos2.length())
			set_instance_param(gz["model"], "fade", fade)
			if s >= gz["length"]:
				gz["state"] = GZ_WAITING
				gz["wait"] = 1e9
				root.visible = false
		GZ_SINKING:
			var u2: float = smoothstep(0.0, 1.0, gz["state_t"] / float(G["sink_s"]))
			root.position.y = lerpf(gz["y_walk"], dune_height(pos2.x, pos2.y) - hidden, u2)
			sand_material.set_shader_parameter("beast_pos", pos2)
			sand_material.set_shader_parameter("beast_strength", 1.0 - smoothstep(0.85, 1.0, u2))
			emit_ring_dust(pos2)
			if gz["state_t"] >= float(G["sink_s"]):
				gz["state"] = GZ_WAITING
				gz["wait"] = 1e9
				root.visible = false
	set_instance_param(gz["model"], "root_y", root.position.y - 2.0)


func emit_ring_dust(p: Vector2) -> void:
	rise_dust.global_position = Vector3(p.x, dune_height(p.x, p.y) + 0.5, p.y)
	rise_dust.emitting = true


func godzilla_step(left: bool, frame: float) -> void:
	var root: Node3D = gz["root"]
	if Vector2(root.position.x, root.position.z).length() > float(D["godzilla"]["fade"]["full_m"]) + 20.0:
		return
	var foot: Vector3 = Basis(Vector3.UP, root.rotation.y) * gz_foot(frame, left) + root.position
	var p2: Vector2 = Vector2(foot.x, foot.z)
	push_footprint(p2, root.rotation.y)
	add_quake(p2, D["quake"]["step"]["strength"], D["quake"]["step"]["reach"])
	react_to_impact(p2, "step")
	var gy: float = dune_height(p2.x, p2.y)
	fire(pool_step_dust, Vector3(p2.x, gy + 0.3, p2.y))
	# Dove Man sheds rock and sand, more when the step is close
	var A: float = 1.0 / (1.0 + pow(p2.length() / float(D["dove"]["debris"]["reach"]), 2.0))
	if A >= 0.12:
		get_tree().create_timer(float(D["dove"]["debris"]["delay_s"])).timeout.connect(shed_debris.bind(A))


func shed_debris(A: float) -> void:
	var dm: float = timeline_value("debris")
	if dm <= 0.01:
		return
	falling_rocks.shed(int(float(D["dove"]["debris"]["rocks"]) * A * dm), float(D["dove"]["debris"]["spread_s"]))
	fire(pool_sand, Vector3.ZERO, int(float(D["dove"]["debris"]["sand"]) * A * dm))


# ============================================================
# PARTICLE FX — one-shot bursts drawn from small pools
# ============================================================

func make_burst(col: Color, amount: int, life: float, size: float, gravity: float) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.85
	p.randomness = 0.6
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 80, 120))
	var m: ParticleProcessMaterial = ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 6.0
	m.direction = Vector3.UP
	m.spread = 60.0
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 5.0
	m.gravity = Vector3(0.0, -gravity, 0.0)
	m.damping_min = 0.3
	m.damping_max = 1.0
	m.scale_min = size * 0.5
	m.scale_max = size * 1.5
	m.color = col
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	var quad: QuadMesh = QuadMesh.new()
	quad.material = dust_material
	p.draw_pass_1 = quad
	add_child(p)
	return p


func create_fx_pools() -> void:
	var F: Dictionary = D["fx"]
	for i in 4:
		var s: GPUParticles3D = make_burst(Color(0.6, 0.43, 0.27, 0.32), int(F["step_dust"]["count"]), float(F["step_dust"]["life_s"]), float(F["step_dust"]["size"]), 0.3)
		(s.process_material as ParticleProcessMaterial).emission_sphere_radius = F["step_dust"]["radius"]
		(s.process_material as ParticleProcessMaterial).initial_velocity_max = F["step_dust"]["speed"]
		pool_step_dust.append(s)
	for i in 3:
		var dmp: GPUParticles3D = make_burst(Color(0.6, 0.43, 0.27, 0.32), int(F["impact_dust"]["count"]), float(F["impact_dust"]["life_s"]), float(F["impact_dust"]["size"]), 0.4)
		var dm: ParticleProcessMaterial = dmp.process_material
		dm.initial_velocity_min = 4.0
		dm.initial_velocity_max = F["impact_dust"]["speed"]
		dm.emission_sphere_radius = 4.0
		pool_impact_dust.append(dmp)
		var sp: GPUParticles3D = make_burst(Color(0.55, 0.36, 0.17, 0.9), int(F["impact_spray"]["count"]), float(F["impact_spray"]["life_s"]), float(F["impact_spray"]["size"]), 9.8)
		var spm: ParticleProcessMaterial = sp.process_material
		spm.initial_velocity_min = 8.0
		spm.initial_velocity_max = F["impact_spray"]["speed"]
		spm.spread = 50.0
		spm.emission_sphere_radius = 2.5
		pool_impact_spray.append(sp)

	# Dove Man debris: rocks that fall and stay, plus trickling sand
	var rock_mesh: Mesh = null
	var rocks_scene: Node3D = load_model(D["models"]["debris_rocks"])
	for g in each_geometry(rocks_scene, []):
		if g is MeshInstance3D:
			rock_mesh = (g as MeshInstance3D).mesh
			break
	if rock_mesh == null:
		var sph: SphereMesh = SphereMesh.new()
		sph.radial_segments = 7
		sph.rings = 4
		rock_mesh = sph
	falling_rocks = (load(ROCKS_SCRIPT) as GDScript).new()
	add_child(falling_rocks)
	falling_rocks.setup(self, rock_mesh, D["dove"]["debris_points"])
	var Dd: Dictionary = D["dove"]["debris"]
	for i in 3:
		var s2: GPUParticles3D = make_burst(Color(0.55, 0.38, 0.2, 0.28), int(Dd["sand"]), float(Dd["sand_life_s"]), float(Dd["sand_size"]), 9.8)
		var sm: ParticleProcessMaterial = s2.process_material
		sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
		sm.emission_point_texture = debris_point_texture
		sm.emission_point_count = debris_point_texture.get_width()
		sm.direction = Vector3.DOWN
		sm.spread = 20.0
		sm.initial_velocity_min = 0.0
		sm.initial_velocity_max = 2.0
		sm.damping_min = 1.5
		sm.damping_max = 3.0
		s2.explosiveness = 0.0
		s2.visibility_aabb = AABB(Vector3(-120, -20, -120), Vector3(240, 220, 240))
		pool_sand.append(s2)


func fire(pool: Array, pos: Vector3, amount: int = -1) -> void:
	var pick: GPUParticles3D = null
	for p in pool:
		if not (p as GPUParticles3D).emitting:
			pick = p
			break
	if pick == null:
		pick = pool[0]
	if amount > 0:
		pick.amount = maxi(amount, 4)
	pick.global_position = pos
	pick.restart()
	pick.emitting = true


# ============================================================
# BOEING — junk satellite skimming Dove Man
# ============================================================

func create_boeing() -> void:
	var B: Dictionary = D["boeing"]
	var orbit: Node3D = Node3D.new()
	orbit.name = "Boeing_Satellite"
	add_child(orbit)
	var spin: Node3D = Node3D.new()
	orbit.add_child(spin)
	var vertical: Node3D = Node3D.new()
	vertical.rotation.x = deg_to_rad(90.0)
	spin.add_child(vertical)
	var model: Node3D = load_model(D["models"]["boeing"])
	vertical.add_child(model)
	apply_desert_skin(model, 0.0, 0.5)
	set_instance_param(model, "body_height", 30.0)
	boeing = {"orbit": orbit, "spin": spin}


func boeing_min_radius(angle: float, alt: float) -> float:
	var g: Dictionary = D["boeing"]["grid"]
	var ab: int = int(g["angle_bins"])
	var i: int = posmod(int(round(fposmod(angle, TAU) / TAU * ab)), ab)
	var j: int = clampi(int(round((alt - float(g["alt_min"])) / float(g["alt_step"]))), 0, int(g["alt_bins"]) - 1)
	return g["min_radius"][i][j]


func update_boeing(delta: float) -> void:
	var B: Dictionary = D["boeing"]
	var a: float = float(B["angle0"]) + float(B["angular_speed"]) * t * (1.0 + air_level * 0.2)
	var alt: float = 132.0 + 14.0 * sin(t * 0.027) + 5.0 * sin(t * 0.11 + 1.3) + timeline_value("boeing_alt") if not TL.is_empty() else 132.0
	var r: float = 56.0 + 7.0 * sin(t * 0.033 + 0.4) + 3.0 * sin(t * 0.13)
	r = maxf(r, boeing_min_radius(a, alt))
	var orbit: Node3D = boeing["orbit"]
	var target: Vector3 = Vector3(cos(a) * r, alt, sin(a) * r)
	orbit.position = orbit.position.lerp(target, minf(1.0, delta * 2.0)) if t > 0.5 else target
	orbit.rotation.y = -a + PI * 0.5
	var spin: Node3D = boeing["spin"]
	spin.rotation = Vector3(0.22 * sin(t * 0.07), 0.06 * t, 0.18 * sin(t * 0.05 + 1.0))


# ============================================================
# CARS — falling from the sky, craters, wrecks swallowed by the sand
# ============================================================

func pick_car_spot(car_r: float) -> Vector2:
	for attempt in 300:
		var a: float = rng.randf_range(0.0, TAU)
		var r: float = rng.randf_range(65.0, 235.0)
		var p: Vector2 = Vector2(cos(a), sin(a)) * r
		if not spot_is_free(p, car_r, 14.0):
			continue
		var ok: bool = true
		for cs in camera_spots:
			if p.distance_to(cs) < 40.0:
				ok = false
		if ok and not gz.is_empty() and gz["state"] != GZ_WAITING:
			if segment_distance(p, gz["start"], gz["end"]) < 45.0:
				ok = false
		if ok:
			return p
	return Vector2(150.0, -150.0)


func drop_car(planned: Vector2 = Vector2(INF, INF)) -> void:
	var CD: Dictionary = D["cars"]
	var models: Array = CD["models"]
	var md: Dictionary = models[rng.randi_range(0, models.size() - 1)]
	var k: float = float(CD["scale"])
	var root: Node3D = Node3D.new()
	add_child(root)
	var model: Node3D = load_model(md["file"])
	model.scale = Vector3.ONE * k
	model.position.y = -float(md["height"]) * k * 0.5
	root.add_child(model)
	apply_desert_skin(model, 0.0, 0.7)
	set_instance_param(model, "body_height", float(md["height"]) * k)
	var p: Vector2 = planned
	if p.x == INF or not spot_is_free(p, float(md["height"]) * k * 1.6, 8.0):
		p = pick_car_spot(float(md["height"]) * k * 1.6)
	var g: float = dune_height(p.x, p.y)
	var axis: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	var flip: bool = rng.randf() < 0.2
	var rest: Basis = Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-28, 28)), rng.randf_range(0, TAU), deg_to_rad(180.0 if flip else rng.randf_range(-22, 22))))
	cars.append({"root": root, "model": model, "pos": p, "ground": g, "h": float(md["height"]) * k, "t0": t,
		"q0": Quaternion(Basis.from_euler(Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU)))),
		"axis": axis, "w": rng.randf_range(0.7, 1.5), "drift": Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)),
		"rest": Quaternion(rest), "impacted": false, "q_imp": Quaternion.IDENTITY, "crater": -1, "sinking": -1.0})


func update_cars(delta: float) -> void:
	var CD: Dictionary = D["cars"]
	var ci: Array = TL.get("car_interval", [0.0, 0.0])
	if ci[1] <= 0.0:
		next_drop = {}
		car_timer = 30.0
	else:
		if next_drop.is_empty():
			car_timer = maxf(20.0, rng.randf_range(ci[0], ci[1]))
			next_drop = {"pos": pick_car_spot(1.58 * float(CD["scale"]) * 1.6)}
		car_timer -= delta
	if not next_drop.is_empty() and car_timer <= 0.0:
		drop_car(next_drop["pos"])
		next_drop = {}
		# keep only the newest wrecks; the oldest one is swallowed by the dune
		var resting: Array = []
		for c in cars:
			if c["impacted"] and c["sinking"] < 0.0:
				resting.append(c)
		if resting.size() >= int(CD["max_resting"]):
			resting[0]["sinking"] = t
	var G: float = CD["gravity"]
	var H0: float = CD["drop_height"]
	var T: float = sqrt(2.0 * H0 / G)
	var keep: Array = []
	for c in cars:
		var root: Node3D = c["root"]
		var age: float = t - c["t0"]
		var hc: float = c["h"]
		var ks: float = float(CD["scale"])
		var rest_y: float = c["ground"] + hc * 0.5 - float(CD["rest_below"]) * ks
		if age < T:
			var rem: float = T - age
			var p: Vector2 = c["pos"] + c["drift"] * rem
			root.position = Vector3(p.x, c["ground"] + hc * 0.5 + H0 - 0.5 * G * age * age, p.y)
			var q: Quaternion = Quaternion(c["axis"], c["w"] * age) * c["q0"]
			root.quaternion = q
			c["q_imp"] = q
		else:
			if not c["impacted"]:
				c["impacted"] = true
				var p2: Vector2 = c["pos"]
				c["crater"] = push_crater(p2)
				add_quake(p2, CD["quake"]["strength"], CD["quake"]["reach"])
				fire(pool_impact_dust, Vector3(p2.x, c["ground"] + 0.3, p2.y))
				fire(pool_impact_spray, Vector3(p2.x, c["ground"] + 0.3, p2.y))
				react_to_impact(p2, "car")
			var ia: float = age - T
			var seq: Array = CD["impact_sequence"]   # [dt, y relative to rest, rotation blend]
			var y: float = rest_y
			var blend: float = 1.0
			for k in range(seq.size() - 1):
				var a0: Array = seq[k]
				var a1: Array = seq[k + 1]
				if ia >= a0[0] and ia < a1[0]:
					var u: float = (ia - a0[0]) / (a1[0] - a0[0])
					u = u * u * (3.0 - 2.0 * u)
					y = rest_y + lerpf(a0[1], a1[1], u) * ks
					blend = lerpf(a0[2], a1[2], u)
			if ia < seq[0][0]:
				y = rest_y + seq[0][1] * ks
				blend = seq[0][2]
			if c["sinking"] >= 0.0:
				var su: float = clampf((t - c["sinking"]) / float(CD["swallow_s"]), 0.0, 1.0)
				y -= su * (hc + 3.0)
				if su >= 1.0:
					root.queue_free()
					continue
			var jolt: float = 0.0
			if c.has("jolt_t"):
				var ja: float = t - c["jolt_t"]
				if ja >= 0.0 and ja < 0.8:
					jolt = sin(ja / 0.8 * PI) * 0.12 * c["h"]
			root.position = Vector3(c["pos"].x, y + jolt, c["pos"].y)
			root.quaternion = c["q_imp"].slerp(c["rest"], blend) * Quaternion(Vector3.UP, jolt * 0.05)
		set_instance_param(c["model"], "root_y", c["ground"] - 1.5)
		keep.append(c)
	cars = keep


# ============================================================
# STAGE FRONT — the side of Dove Man the story is told from
# ============================================================

func create_stage_front() -> void:
	var acc: Vector2 = Vector2.ZERO
	for e in D["cameras"]:
		if e.get("kind", "static") == "static":
			acc += Vector2(e["pos"][0], e["pos"][2]).normalized()
	if acc.length() > 0.01:
		front_dir = acc.normalized()


# ============================================================
# THE HOUR — light, haze and the rhythm of events change across 60 minutes
# ============================================================

func timeline_value(key: String) -> float:
	return float(TL.get(key, 1.0))


func apply_timeline() -> void:
	var keys: Array = D["timeline"]["keys"]
	var m: float = t / 60.0
	var a: Dictionary = keys[0]
	var b: Dictionary = keys[keys.size() - 1]
	for i in range(keys.size() - 1):
		if m >= float(keys[i]["min"]) and m <= float(keys[i + 1]["min"]):
			a = keys[i]
			b = keys[i + 1]
			break
	var span: float = maxf(float(b["min"]) - float(a["min"]), 0.001)
	var u: float = clampf((m - float(a["min"])) / span, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	TL = {"name": a["name"] if u < 0.5 else b["name"]}
	for k in a:
		if k == "min" or k == "name":
			continue
		var va: Variant = a[k]
		var vb: Variant = b[k]
		if k == "car_interval" or k == "gz_wait":
			TL[k] = va          # event rhythms switch with the phase, they don't blend
			continue
		if va is Array:
			var out: Array = []
			for j in va.size():
				out.append(lerpf(va[j], vb[j], u))
			TL[k] = out
		else:
			TL[k] = lerpf(va, vb, u)
	if sun == null:
		return
	var el: float = deg_to_rad(TL["sun_elev"])
	var az: float = deg_to_rad(TL["sun_azim"])
	var to_sun: Vector3 = Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
	sun.transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	sun.light_energy = TL["sun_energy"]
	sun.light_color = Color(TL["sun_color"][0], TL["sun_color"][1], TL["sun_color"][2])
	var fc: Color = Color(TL["fog_color"][0], TL["fog_color"][1], TL["fog_color"][2])
	environment_resource.fog_light_color = fc
	environment_resource.fog_density = (TL["fog_density"] + climate_memory * 0.0012 + air_level * 0.0006) * fog_view_scale
	environment_resource.volumetric_fog_albedo = fc
	environment_resource.volumetric_fog_density = (TL["vol_density"] + climate_memory * 0.0015) * fog_view_scale
	sky_material.sky_top_color = Color(TL["sky_top"][0], TL["sky_top"][1], TL["sky_top"][2])
	sky_material.sky_horizon_color = Color(TL["sky_horizon"][0], TL["sky_horizon"][1], TL["sky_horizon"][2])
	sky_material.ground_horizon_color = Color(TL["ground_horizon"][0], TL["ground_horizon"][1], TL["ground_horizon"][2])


func end_of_world() -> void:
	if ending:
		return
	ending = true
	director.fade.color = Color(0.96, 0.92, 0.84, 0.0)
	director.fade_dir = 0
	var tw: Tween = create_tween()
	tw.tween_property(director.fade, "color:a", 1.0, 6.0)
	tw.tween_callback(func() -> void: get_tree().reload_current_scene())


# Godzilla's head and the plane: things birds flee from
func nearest_threat(p: Vector3) -> Vector3:
	var best: Vector3 = Vector3(1e9, 1e9, 1e9)
	if not gz.is_empty() and gz["state"] != GZ_WAITING:
		var g: Node3D = gz["root"]
		best = g.position + Vector3(0.0, 40.0, 0.0)
	if not boeing.is_empty():
		var bp: Vector3 = (boeing["orbit"] as Node3D).global_position
		if bp.distance_to(p) < best.distance_to(p):
			best = bp
	return best


func threat_near(p: Vector3, radius: float) -> bool:
	return nearest_threat(p).distance_to(p) < radius


# The next car is chosen when it is scheduled, so the director can be there to see it.
func next_car_drop() -> Dictionary:
	if next_drop.is_empty():
		return {}
	var T: float = sqrt(2.0 * float(D["cars"]["drop_height"]) / float(D["cars"]["gravity"]))
	return {"pos": next_drop["pos"], "eta": car_timer + T}


# ============================================================
# SOUND — microphone drives the climate (same bands as world_000)
# ============================================================

func setup_microphone() -> void:
	var bus: int = AudioServer.get_bus_index("Reactive")
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Reactive")
	while AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.remove_bus_effect(bus, 0)
	var analyzer: AudioEffectSpectrumAnalyzer = AudioEffectSpectrumAnalyzer.new()
	analyzer.buffer_length = 2.0
	analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
	AudioServer.add_bus_effect(bus, analyzer, 0)
	AudioServer.set_bus_volume_db(bus, -80.0)
	var mic: AudioStreamPlayer = AudioStreamPlayer.new()
	mic.stream = AudioStreamMicrophone.new()
	mic.bus = "Reactive"
	add_child(mic)
	mic.play()


func connect_spectrum_if_ready() -> void:
	if spectrum != null:
		return
	var bus: int = AudioServer.get_bus_index("Reactive")
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		spectrum = AudioServer.get_bus_effect_instance(bus, 0) as AudioEffectSpectrumAnalyzerInstance


func band(lo: float, hi: float, floor_db: float, ceil_db: float) -> float:
	var m: Vector2 = spectrum.get_magnitude_for_frequency_range(lo, hi)
	var db: float = linear_to_db(maxf(m.x, m.y) + 0.0000001)
	return clampf((db - floor_db) / (ceil_db - floor_db), 0.0, 1.0)


func read_microphone(delta: float) -> void:
	if spectrum == null:
		return
	var k: float = 1.0 - exp(-delta * 5.0)
	sub_level = lerpf(sub_level, band(25.0, 100.0, -62.0, -10.0), k)
	low_level = lerpf(low_level, band(100.0, 350.0, -62.0, -10.0), k)
	mid_level = lerpf(mid_level, band(350.0, 2500.0, -64.0, -12.0), k)
	air_level = lerpf(air_level, band(2500.0, 12000.0, -68.0, -14.0), k)


func update_climate(delta: float) -> void:
	var incoming: float = sub_level * 0.30 + low_level * 0.30 + mid_level * 0.20 + air_level * 0.20
	if incoming > climate_memory:
		climate_memory = lerpf(climate_memory, incoming, 1.0 - exp(-delta * 0.65))
	else:
		climate_memory = lerpf(climate_memory, incoming * 0.35, 1.0 - exp(-delta * 0.028))


# ============================================================
# DEBUG
# ============================================================

func create_debug_display() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	debug_label = Label.new()
	debug_label.position = Vector2(16, 16)
	debug_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(debug_label)


func update_debug_display() -> void:
	if debug_label == null or not debug_label.visible:
		return
	var names: Array = ["UNDER SAND", "RISING", "WALKING", "SINKING"]
	debug_label.text = "MIN %.1f  %s   SHOT %s   GODZILLA %s   CARS %d   BIRDS %d\nSUB %.2f  LOW %.2f  MID %.2f  AIR %.2f  MEMORY %.2f" % [
		t / 60.0, TL.get("name", ""), director.shot_name(), names[gz.get("state", 0)], cars.size(), birds.birds.size(),
		sub_level, low_level, mid_level, air_level, climate_memory]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_D:
				debug_label.visible = not debug_label.visible
			KEY_C:
				director.shot_t = 1e9
			KEY_G:
				if gz["state"] == GZ_WAITING:
					gz["wait"] = 0.0
			KEY_V:
				car_timer = 0.0
