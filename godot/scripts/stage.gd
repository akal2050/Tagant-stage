extends Node3D
## TAGANT karaoke stage, v2: the Gallery 3 floor as a geological stage.
## Layout = "tagant_gallery 3_FINAL_C3_seven worlds spiral_ring 3.3m.blend" (Desktop\TAGANT 1_...\flutes),
## positions enlarged x5 (space between the circles), cylinders and salt lines x3 so the animals stand life-size:
##  - terracotta earth floor slab (the 7.5 x 12 m room, long axis toward the screen), strata on its cut edges
##  - seven salt-crust circles, each rammed-earth cylinder centred on its own circle (heptagonal spiral)
##  - the seven lime-wash circles on each cylinder top, the clay lines of the 5 / 7 speaker figures
##  - the oil lake of the frogs at the centre listening point
##  - Saharan sand band, then the Qur'anic gardens (Taganat Arabesques), dunes and mountains under a real sky

const S := 10.0                                  # gallery positions -> stage metres (spacious layout)
const SZ := 3.0                                  # gallery sizes -> stage metres (cylinders, ring width)
# Blender (x, y) centre, diameter, height of the seven cylinders, from the FINAL_C3 file
const CYL := [
	[-0.059, -0.748, 0.606, 0.243], [-1.012, 0.317, 0.702, 0.282], [0.690, 1.183, 0.849, 0.453],
	[1.227, -1.148, 0.973, 0.269], [-1.649, -1.114, 1.106, 0.500], [-0.831, 2.145, 1.204, 0.320],
	[2.583, 0.378, 1.295, 0.359]]
const RINGS := [[0.710, 0.790], [1.020, 1.099], [1.329, 1.408], [1.639, 1.718], [1.948, 2.027], [2.257, 2.336], [2.566, 2.645]]
const HEPT := [[-2.409, 2.255], [0.26, 3.29], [2.734, 1.848], [3.149, -0.986], [1.192, -3.077], [-1.663, -2.85], [-3.265, -0.478]]
const PENT := [[-1.968, 2.649], [1.911, 2.69], [3.149, -0.986], [0.035, -3.3], [-3.127, -1.053]]
const FLOOR_CENTRE := [0.049, -0.015]
const FLOOR_SIZE := Vector2(12.0, 7.5)           # long axis, short axis (gallery metres)
const FLOOR_DIR := Vector2(0.954, -0.299)        # long axis toward the screen (Blender xy)
const SLAB := 0.7                                # thickness of the earth slab (stage metres)
const POOL_R := 5.0

var oil_mat: ShaderMaterial
var dust: CPUParticles3D
var flock: Array = []
var flock_target := 3.0
var _flock_n := 3.0
var _t := 0.0
var spot: SpotLight3D
var sun: DirectionalLight3D
var env: Environment
var cam_attr: CameraAttributesPractical
var gardens: Node3D
var cicada_anchor: Node3D
var _tex := {}
const GARDEN_R := 76.0            # the garden circle: grass inside around the square, gardens beyond
const OUTER_R := 128.0
var drones: Array = []


static func g(x: float, y: float, h: float = 0.0) -> Vector3:
	return Vector3(x * S, h, -y * S)


static func cylinder_top(i: int) -> Vector3:
	var c: Array = CYL[i]
	return g(c[0], c[1], c[3] * SZ)


static func cylinder_radius(i: int) -> float:
	return CYL[i][2] * SZ * 0.5


static func slot_position(slot) -> Vector3:
	if typeof(slot) == TYPE_INT:
		return cylinder_top(slot)
	return Vector3.ZERO


func _t2d(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


func _mat(shader_path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	return m


## Each piece is noted before it is built; one that made the iPad stop is left out next time (Diag).
func _piece(n: String) -> void:
	var d = get_node_or_null("/root/Diag")
	if d:
		if d.skipped(n):
			return
		d.mark("build " + n)
	call(n)


func build() -> void:
	_piece("_env")
	_piece("_lights")
	_piece("_floor")
	_piece("_rings")
	_piece("_clay_lines")
	_piece("_oil")
	_piece("_cylinders")
	_piece("_sand_and_dunes")
	_piece("_lawn")
	_piece("_gardens")
	_piece("_grass_tufts")
	_piece("_backstage")
	_dust()
	_flock()


func _env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = _t2d("res://sky/kloofendal_48d_partly_cloudy_puresky_2k.hdr")
	pm.energy_multiplier = 0.9
	sky.sky_material = pm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.sky_rotation = Vector3(0, deg_to_rad(200.0), 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.83, 0.70, 0.58)
	env.fog_density = 0.0018
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.25
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.03
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.12
	we.environment = env
	cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 40.0
	cam_attr.dof_blur_far_transition = 30.0
	cam_attr.dof_blur_amount = 0.035
	we.camera_attributes = cam_attr
	add_child(we)


## Depth of field follows the singer: sharp on the animal, the gardens and dunes go soft.
func set_focus_distance(d: float) -> void:
	cam_attr.dof_blur_far_distance = lerp(cam_attr.dof_blur_far_distance, d + 9.0, 0.05)
	cam_attr.dof_blur_far_transition = lerp(cam_attr.dof_blur_far_transition, max(8.0, d * 1.6), 0.05)


func _lights() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 152, 0)
	sun.light_color = Color(1.0, 0.89, 0.76)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	spot = SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.88)
	spot.light_energy = 0.0
	spot.spot_range = 16.0
	spot.spot_angle = 24.0
	add_child(spot)


func light_singer(pos: Vector3, energy: float) -> void:
	spot.global_position = pos + Vector3(0, 9.0, 0) + Vector3(pos.x, 0, pos.z).normalized() * 2.0
	if spot.global_position.distance_to(pos) > 0.5:
		spot.look_at(pos + Vector3(0, 0.8, 0), Vector3.FORWARD)
	spot.light_energy = lerp(spot.light_energy, energy, 0.06)


# ------------------------------------------------------------------ the floor slab

func _floor() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(FLOOR_SIZE.x * S, SLAB, FLOOR_SIZE.y * S)
	var top := _mat("res://shaders/terracotta_floor.gdshader")
	top.set_shader_parameter("diff", _t2d("res://textures/floor/cracked_red_ground_diff_2k.jpg"))
	top.set_shader_parameter("nor", _t2d("res://textures/floor/cracked_red_ground_nor_gl_2k.jpg"))
	top.set_shader_parameter("rough", _t2d("res://textures/floor/cracked_red_ground_rough_2k.jpg"))
	var sides := _mat("res://shaders/strata.gdshader")
	sides.set_shader_parameter("nor", _t2d("res://textures/terrain/dry_ground_01_nor_gl_2k.jpg"))
	# the box gives the cut strata, a plane on top carries the clay floor
	var slab := MeshInstance3D.new()
	slab.mesh = box
	slab.material_override = sides
	slab.position = Vector3(0, -SLAB * 0.5 - 0.005, 0)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(FLOOR_SIZE.x * S, FLOOR_SIZE.y * S)
	plane.mesh = pm
	plane.material_override = top
	var holder := Node3D.new()
	holder.position = g(FLOOR_CENTRE[0], FLOOR_CENTRE[1])
	holder.rotation.y = atan2(FLOOR_DIR.y, FLOOR_DIR.x)     # Blender y -> Godot -z
	holder.add_child(slab)
	holder.add_child(plane)
	add_child(holder)


## A flat crust ring with irregular edges and a soft raised profile; UV.x = across the band.
func _annulus(r0: float, r1: float, seg: int, wobble: float, h: float, seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var across := 6
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var rows: Array = []
	for i in seg + 1:
		var a := TAU * float(i) / seg
		var e0: float = wobble * (sin(a * 23.0 + ph[0]) * 0.5 + sin(a * 57.0 + ph[1]) * 0.3 + sin(a * 131.0 + ph[2]) * 0.2)
		var e1: float = wobble * (sin(a * 29.0 + ph[1]) * 0.5 + sin(a * 61.0 + ph[2]) * 0.3 + sin(a * 127.0 + ph[0]) * 0.2)
		var row: Array = []
		for j in across + 1:
			var u := float(j) / across
			var r: float = lerp(r0 + e0, r1 + e1, u)
			var y := h * sin(u * PI) * (0.8 + 0.2 * sin(a * 41.0 + u * 9.0))
			row.append([Vector3(cos(a) * r, y, sin(a) * r), Vector2(u, float(i) / seg)])
		rows.append(row)
	for i in seg:
		for j in across:
			var q := [rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_uv(q[idx][1])
				st.add_vertex(q[idx][0])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _salt_material() -> ShaderMaterial:
	var m := _mat("res://shaders/salt_crust.gdshader")
	m.set_shader_parameter("nor", _t2d("res://textures/terrain/dry_ground_01_nor_gl_2k.jpg"))
	m.set_shader_parameter("diff", _t2d("res://textures/terrain/dry_ground_01_diff_2k.jpg"))
	return m


func _rings() -> void:
	var m := _salt_material()
	for i in RINGS.size():
		var mi := MeshInstance3D.new()
		var rc: float = (RINGS[i][0] + RINGS[i][1]) * 0.5 * S
		var hw: float = (RINGS[i][1] - RINGS[i][0]) * 0.5 * SZ * 1.25
		mi.mesh = _annulus(rc - hw, rc + hw, 260 + i * 50, 0.035, 0.06, 70 + i)
		mi.material_override = m
		mi.position.y = 0.004
		add_child(mi)


func _clay_lines() -> void:
	# the pentagon and heptagon of the speakers, drawn as darker clay pigment lines
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.12, 0.06, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	for poly in [HEPT, PENT]:
		for i in poly.size():
			var a: Vector3 = g(poly[i][0], poly[i][1], 0.012)
			var b: Vector3 = g(poly[(i + 1) % poly.size()][0], poly[(i + 1) % poly.size()][1], 0.012)
			var mi := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(a.distance_to(b), 0.17)
			mi.mesh = pm
			mi.material_override = m
			mi.position = (a + b) * 0.5
			mi.rotation.y = -atan2(b.z - a.z, b.x - a.x)
			add_child(mi)


func _oil() -> void:
	var c := CylinderMesh.new()
	c.top_radius = POOL_R
	c.bottom_radius = POOL_R
	c.height = 0.08
	c.radial_segments = 96
	var mi := MeshInstance3D.new()
	mi.mesh = c
	oil_mat = _mat("res://shaders/oil.gdshader")
	mi.material_override = oil_mat
	add_child(mi)
	var lip := MeshInstance3D.new()          # a thin salt lip around the lake
	lip.mesh = _annulus(POOL_R - 0.05, POOL_R + 0.22, 160, 0.04, 0.07, 9)
	lip.material_override = _salt_material()
	add_child(lip)
	add_child(_tap_body("frogs", Vector3(0, 0.2, 0), Vector3(POOL_R * 2.0, 0.6, POOL_R * 2.0)))


func _cylinders() -> void:
	var nor := _t2d("res://textures/terrain/dry_ground_01_nor_gl_2k.jpg")
	for i in CYL.size():
		var r := cylinder_radius(i)
		var h: float = CYL[i][3] * SZ
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r * 1.015
		cm.height = h
		cm.radial_segments = 96
		cm.rings = 12
		var m := _mat("res://shaders/rammed_earth.gdshader")
		m.set_shader_parameter("nor", _t2d("res://textures/earth/red_laterite_soil_stones_nor_gl_2k.jpg"))
		m.set_shader_parameter("grit", _t2d("res://textures/earth/red_laterite_soil_stones_diff_2k.jpg"))
		m.set_shader_parameter("radius", r)
		m.set_shader_parameter("height", h)
		m.set_shader_parameter("seed", float(i) * 3.7)
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = m
		mi.position = g(CYL[i][0], CYL[i][1], h * 0.5)
		add_child(mi)


# ------------------------------------------------------------------ beyond the floor

func _sand_and_dunes() -> void:
	var sand := _mat("res://shaders/sand.gdshader")
	sand.set_shader_parameter("tex", _t2d("res://textures/sand/sand_01_diff_2k.jpg"))
	sand.set_shader_parameter("tnor", _t2d("res://textures/sand/sand_01_nor_gl_2k.jpg"))
	var plain := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	plain.mesh = pm
	plain.material_override = sand
	plain.position.y = -SLAB - 0.25
	add_child(plain)
	# dunes rising beyond the gardens, mountains on the horizon
	var n := 150
	var span := 1100.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = 77
	ridge.frequency = 0.0035
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 5
	var hts := PackedFloat32Array()
	hts.resize((n + 1) * (n + 1))
	for zi in n + 1:
		for xi in n + 1:
			var x := -span * 0.5 + span * xi / n
			var z := -span * 0.5 + span * zi / n
			var d := Vector2(x, z).length()
			var w := Vector2(x, z).rotated(0.35)
			var dune: float = (0.5 + 0.5 * sin(w.x * 0.045 + noise.get_noise_2d(x, z) * 4.0)) * 14.0 + noise.get_noise_2d(x * 0.5, z * 0.5) * 10.0
			var rise := smoothstep(150.0, 260.0, d)
			var mount := (ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 160.0 * smoothstep(380.0, 520.0, d)
			hts[zi * (n + 1) + xi] = -SLAB - 1.25 + maxf(0.0, dune) * rise + mount
	for zi in n:
		for xi in n:
			var ids := [zi * (n + 1) + xi, zi * (n + 1) + xi + 1, (zi + 1) * (n + 1) + xi + 1, (zi + 1) * (n + 1) + xi]
			var pts: Array = []
			for id: int in ids:
				var xi2: int = id % (n + 1)
				var zi2: int = id / (n + 1)
				pts.append(Vector3(-span * 0.5 + span * xi2 / n, hts[id], -span * 0.5 + span * zi2 / n))
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(pts[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = sand
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _lawn() -> void:
	var m := _mat("res://shaders/lawn.gdshader")
	m.set_shader_parameter("lawn", _t2d("res://textures/grass/forrest_ground_01_diff_2k.jpg"))
	m.set_shader_parameter("lawn_nor", _t2d("res://textures/grass/forrest_ground_01_nor_gl_2k.jpg"))
	m.set_shader_parameter("garden", _t2d("res://textures/grass/aerial_grass_rock_diff_2k.jpg"))
	m.set_shader_parameter("garden_nor", _t2d("res://textures/grass/aerial_grass_rock_nor_gl_2k.jpg"))
	m.set_shader_parameter("garden_r", GARDEN_R)
	m.set_shader_parameter("outer_r", OUTER_R)
	var pm := PlaneMesh.new()
	pm.size = Vector2(OUTER_R * 2.0 + 14.0, OUTER_R * 2.0 + 14.0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position.y = -SLAB + 0.02
	add_child(mi)
	# the garden circle: a low rammed-earth curb where the garden begins
	var curb := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = GARDEN_R - 0.45
	t.outer_radius = GARDEN_R + 0.45
	t.rings = 256
	t.ring_segments = 10
	curb.mesh = t
	curb.scale = Vector3(1, 0.7, 1)
	var em := _mat("res://shaders/rammed_earth.gdshader")
	em.set_shader_parameter("nor", _t2d("res://textures/earth/red_laterite_soil_stones_nor_gl_2k.jpg"))
	em.set_shader_parameter("grit", _t2d("res://textures/earth/red_laterite_soil_stones_diff_2k.jpg"))
	em.set_shader_parameter("radius", GARDEN_R)
	em.set_shader_parameter("height", 0.6)
	curb.material_override = em
	curb.position.y = -SLAB + 0.05
	add_child(curb)


func _in_floor(p: Vector3, margin: float) -> bool:
	var c := g(FLOOR_CENTRE[0], FLOOR_CENTRE[1])
	var ang := atan2(FLOOR_DIR.y, FLOOR_DIR.x)
	var q := Vector2(p.x - c.x, p.z - c.z).rotated(ang)
	return absf(q.x) < FLOOR_SIZE.x * S * 0.5 + margin and absf(q.y) < FLOOR_SIZE.y * S * 0.5 + margin


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for b in 7:
		var a := rng.randf() * TAU
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.22)
		var h := rng.randf_range(0.35, 0.75)
		var w := rng.randf_range(0.025, 0.045)
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var base := Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * rng.randf_range(0.0, 0.08)
		var tip := base + Vector3(0, h, 0) + lean
		var shade := rng.randf()
		for v in [[base - side, 0.0], [base + side, 0.0], [tip, 1.0]]:
			st.set_color(Color(shade, shade, shade))
			st.set_uv(Vector2(0.5, v[1]))
			st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


func _grass_tufts() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tuft_mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var xf: Array = []
	var tries := 0
	while xf.size() < 22000 and tries < 120000:
		tries += 1
		var r := sqrt(rng.randf()) * (OUTER_R - 3.0)
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * r, -SLAB + 0.02, sin(a) * r)
		if _in_floor(p, 0.4):
			continue
		if r > GARDEN_R and rng.randf() > 0.45:      # sparser in the garden ring (gardens and beds there)
			continue
		if absf(r - GARDEN_R) < 0.7:
			continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.5)), p)
		xf.append(t)
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat("res://shaders/grass_blades.gdshader")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ------------------------------------------------------------------ backstage: machines of the other worlds

func _prop(path: String, size_m: float, pos: Vector3, yaw: float, tilt: Vector3 = Vector3.ZERO, sink: float = 0.0) -> Node3D:
	var ps: PackedScene = load(path)
	var n: Node3D = ps.instantiate()
	add_child(n)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	# untextured machines (desertcore tank, excavator, dragline) get weathered, rusted steel
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var sm = mi.mesh.surface_get_material(si)
			var bare: bool = sm == null
			if sm is BaseMaterial3D and sm.albedo_texture == null and sm.albedo_color.get_luminance() > 0.6:
				bare = true
			if bare:
				mi.set_surface_override_material(si, _rust())
	var big: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var k := size_m / maxf(big, 0.001)
	n.scale = Vector3.ONE * k
	n.rotation = Vector3(tilt.x, yaw, tilt.z)
	n.position = pos - Vector3(0, box.position.y * k + sink, 0)
	return n


var _rust_mat: StandardMaterial3D
func _rust() -> StandardMaterial3D:
	if _rust_mat == null:
		_rust_mat = StandardMaterial3D.new()
		_rust_mat.albedo_color = Color(0.36, 0.22, 0.14)
		_rust_mat.metallic = 0.55
		_rust_mat.roughness = 0.72
		_rust_mat.albedo_texture = _t2d("res://textures/earth/red_laterite_soil_stones_diff_2k.jpg")
		_rust_mat.uv1_triplanar = true
		_rust_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return _rust_mat


func _backstage() -> void:
	# behind the screen end of the room: Ait Wadu machines, a dragline and a crane of the Developmentocene
	var fwd := Vector3(FLOOR_DIR.x, 0, -FLOOR_DIR.y).normalized()
	var side := Vector3(-fwd.z, 0, fwd.x)
	var y := -SLAB
	var at := func(d: float, s: float) -> Vector3: return fwd * d + side * s + Vector3(0, y, 0)
	var face := atan2(-fwd.x, -fwd.z)          # turned toward the stage
	_prop("res://models/backstage/dragline.glb", 34.0, at.call(200.0, -50.0), face + 0.6, Vector3.ZERO, 0.5)
	_prop("res://models/backstage/tower_crane.glb", 38.0, at.call(180.0, 58.0), face - 0.3)
	_prop("res://models/backstage/excavator.glb", 10.0, at.call(156.0, -17.0), face + 1.1, Vector3(0, 0, 0.05), 0.3)
	_prop("res://models/backstage/ft17_renault.glb", 5.5, at.call(146.0, 10.0), face + 0.2)
	_prop("res://models/backstage/ft17_b.glb", 5.5, at.call(154.0, 22.0), face - 0.5, Vector3(0.04, 0, -0.05), 0.2)
	_prop("res://models/backstage/tank.glb", 7.5, at.call(168.0, -2.0), face + 2.6)
	_prop("res://models/backstage/tractor_mf.glb", 4.2, at.call(143.0, -29.0), face + 0.9)
	_prop("res://models/backstage/tractor_te20.glb", 3.6, at.call(138.0, 36.0), face - 1.2)
	_prop("res://models/backstage/miners_set.glb", 5.0, at.call(150.0, -4.0), face)
	# half-swallowed cars and a fallen airliner in the dunes around
	_prop("res://models/backstage/car_landcruiser.glb", 5.0, Vector3(cos(3.5), 0, sin(3.5)) * 156.0 + Vector3(0, y, 0), 1.0, Vector3(0.12, 0, 0.18), 0.7)
	_prop("res://models/backstage/car_pickup.glb", 5.2, Vector3(cos(4.2), 0, sin(4.2)) * 166.0 + Vector3(0, y, 0), 2.3, Vector3(-0.1, 0, 0.25), 0.8)
	_prop("res://models/backstage/car_peugeot504.glb", 4.5, Vector3(cos(2.6), 0, sin(2.6)) * 150.0 + Vector3(0, y, 0), 0.4, Vector3(0.2, 0, -0.1), 0.6)
	_prop("res://models/backstage/boeing.glb", 45.0, Vector3(cos(5.3), 0, sin(5.3)) * 290.0 + Vector3(0, y, 0), 1.9, Vector3(0.1, 0, 0.22), 3.0)
	# two drones (City of Salt and Blood) circling high and far
	drones.append(_prop("res://models/backstage/mq9.glb", 20.0, Vector3(230, 60, 0), 0.0))
	drones.append(_prop("res://models/backstage/shahed136.glb", 7.0, Vector3(-190, 45, 0), 0.0))


func _gardens() -> void:
	gardens = preload("res://scripts/gardens.gd").new()
	add_child(gardens)
	gardens.build(-SLAB)
	cicada_anchor = gardens.cicada_anchor
	if cicada_anchor:
		cicada_anchor.add_child(_tap_body("cicadas", Vector3(0, 1.0, 0), Vector3(12, 3, 12)))


func _tap_body(id: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.set_meta("animal_id", id)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = pos
	return b


func _dust() -> void:
	dust = CPUParticles3D.new()
	dust.amount = 220
	dust.lifetime = 16.0
	dust.preprocess = 16.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(80, 6, 80)
	dust.position.y = 3.0
	dust.direction = Vector3(1, 0.1, 0.3)
	dust.spread = 30.0
	dust.initial_velocity_min = 0.2
	dust.initial_velocity_max = 0.7
	dust.gravity = Vector3(0, -0.02, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 0.93, 0.85, 0.3)
	q.material = m
	dust.mesh = q
	add_child(dust)


func _flock() -> void:
	var ps: PackedScene = load("res://models/dove.glb")
	for i in 7:
		var d: Node3D = ps.instantiate()
		add_child(d)
		d.scale = Vector3.ONE * 0.3
		var ap := _find_anim(d)
		if ap and ap.has_animation("BirdRig|Flapping"):
			ap.get_animation("BirdRig|Flapping").loop_mode = Animation.LOOP_LINEAR
			ap.play("BirdRig|Flapping")
			ap.seek(randf() * 0.5, true)
			ap.speed_scale = randf_range(0.9, 1.2)
		d.visible = false
		flock.append(d)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func set_voice_levels(frogs: float, cicadas: float) -> void:
	oil_mat.set_shader_parameter("ripple", frogs * 0.5)
	dust.speed_scale = 1.0 + cicadas * 2.0
	if gardens:
		gardens.set_shimmer(cicadas)


func _process(delta: float) -> void:
	_t += delta
	for i in drones.size():
		var dn: Node3D = drones[i]
		var rr := 230.0 if i == 0 else 190.0
		var ph := _t * (0.02 if i == 0 else -0.03) + i * 2.0
		var p := Vector3(cos(ph) * rr, dn.position.y, sin(ph) * rr)
		var ahead := Vector3(cos(ph + signf(0.5 - i) * 0.05) * rr, p.y, sin(ph + signf(0.5 - i) * 0.05) * rr)
		dn.position = p
		dn.look_at(ahead, Vector3.UP, true)
	_flock_n = lerp(_flock_n, flock_target, 1.0 - exp(-delta * 0.6))
	for i in flock.size():
		var d: Node3D = flock[i]
		d.visible = float(i) < _flock_n - 0.2
		if not d.visible:
			continue
		var ph := _t * (0.16 + 0.015 * i) + TAU * i / 7.0
		var r := 24.0 + 8.0 * sin(_t * 0.07 + i)
		var p := Vector3(cos(ph) * r, 16.0 + 2.0 * sin(_t * 0.3 + i * 1.7), sin(ph) * r)
		var ahead := Vector3(cos(ph + 0.05) * r, p.y, sin(ph + 0.05) * r)
		d.position = p
		d.look_at(ahead, Vector3.UP, true)
