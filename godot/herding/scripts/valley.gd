extends Node3D
## TAGANT Herding Karaoke - the Ait Wadu valley, empty of people:
## the valley ground and its river (terrain.glb), the great date palm (palm.glb), the animal mountains
## (hills.glb, with their cedars) and the poppy field scattered on the valley's own poppy mask.
## All meshes come from C:\Users\azoor\Documents\tagant-ait-wadu (same coordinates, metres, Y up).

var env: Environment
var cam_attr: CameraAttributesPractical
var sun: DirectionalLight3D
var flock_target := 0.0          # kept for main.gd (the animal karaoke had a dove flock)
var cicada_anchor: Node3D = null
var places := {}                 # slot -> Vector3
var views := {}                  # slot -> [camera position, look target]
var poppy_mat: ShaderMaterial
var field_c := Vector3.ZERO
var ground_mat: ShaderMaterial
var water_mat: ShaderMaterial
var _t := 0.0

# coarse ground height grid (metres), built from the valley mesh
const GRID := 8.0
const GEXT := 1400.0
var _gn := 0
var _gh := PackedFloat32Array()


func _t2d(path: String) -> Texture2D:
	return load(path) as Texture2D


func build() -> void:
	_env()
	_sun()
	_terrain()
	_hills()
	_palm()
	_places()
	_poppies()


# ------------------------------------------------------------------ sky, light, air

func _env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = _t2d("res://herding/sky/kloofendal_48d_partly_cloudy_puresky_2k.hdr")
	pm.energy_multiplier = 0.95
	sky.sky_material = pm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.sky_rotation = Vector3(0, deg_to_rad(120.0), 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.72
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.80, 0.72, 0.62)
	env.fog_density = 0.00045
	env.fog_aerial_perspective = 0.45
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.02
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.08
	we.environment = env
	cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 400.0
	cam_attr.dof_blur_far_transition = 400.0
	cam_attr.dof_blur_amount = 0.02
	we.camera_attributes = cam_attr
	add_child(we)


func set_focus_distance(d: float) -> void:
	cam_attr.dof_blur_far_distance = lerp(cam_attr.dof_blur_far_distance, d * 1.4 + 20.0, 0.05)
	cam_attr.dof_blur_far_transition = lerp(cam_attr.dof_blur_far_transition, maxf(60.0, d * 2.5), 0.05)


func _sun() -> void:
	sun = DirectionalLight3D.new()
	# late-afternoon sun from the south-west: the palm and the mountains model, long soft shadows
	sun.rotation_degrees = Vector3(-24, 215, 0)
	sun.light_color = Color(1.0, 0.86, 0.70)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 600.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)


func light_singer(_pos: Vector3, _energy: float) -> void:
	pass


func set_voice_levels(_a: float, _b: float) -> void:
	pass


# ------------------------------------------------------------------ the valley ground and the river

func _terrain() -> void:
	var s: Node3D = load("res://herding/assets/world/terrain.glb").instantiate()
	add_child(s)
	var ground := ShaderMaterial.new()
	ground_mat = ground
	ground.shader = load("res://herding/shaders/aw_terrain.gdshader")
	var T := "res://herding/assets/textures/terrain/"
	for k in [["dry_diff", "dry_ground_01_diff_2k.jpg"], ["dry_rough", "dry_ground_01_rough_2k.jpg"],
			["dry_nor", "dry_ground_01_nor_gl_2k.jpg"], ["grass_diff", "withered_grass_diff_2k.jpg"],
			["grass_rough", "withered_grass_rough_2k.jpg"], ["grass_nor", "withered_grass_nor_gl_2k.jpg"]]:
		ground.set_shader_parameter(k[0], _t2d(T + k[1]))
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://herding/shaders/aw_water.gdshader")
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		var water := String(mi.name).begins_with("SEBOU")
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, water_mat if water else ground)
		if water:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_height_grid(s.find_child("VALLEY_TERRAIN", true, false) as MeshInstance3D)


func _height_grid(mi: MeshInstance3D) -> void:
	_gn = int(2.0 * GEXT / GRID) + 1
	_gh.resize(_gn * _gn)
	_gh.fill(-1000.0)
	if mi == null:
		return
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p in v:
		var ix := int((p.x + GEXT) / GRID)
		var iz := int((p.z + GEXT) / GRID)
		if ix < 0 or iz < 0 or ix >= _gn or iz >= _gn:
			continue
		var k := iz * _gn + ix
		if p.y > _gh[k]:
			_gh[k] = p.y


## Ground height at (x, z) from the valley mesh (bilinear on an 8 m grid).
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + GEXT) / GRID, 0.0, _gn - 1.001)
	var fz := clampf((z + GEXT) / GRID, 0.0, _gn - 1.001)
	var ix := int(fx); var iz := int(fz)
	var tx := fx - ix; var tz := fz - iz
	var a := _gh[iz * _gn + ix]; var b := _gh[iz * _gn + ix + 1]
	var c := _gh[(iz + 1) * _gn + ix]; var d := _gh[(iz + 1) * _gn + ix + 1]
	var h := lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)
	return maxf(h, -9.3)          # never under the river surface


# ------------------------------------------------------------------ the animal mountains and their cedars

func _hills() -> void:
	var s: Node3D = load("res://herding/assets/world/hills.glb").instantiate()
	add_child(s)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://herding/shaders/aw_mountain.gdshader")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://herding/data/cedars.json"))
	var hb_all: Dictionary = data.get("hills", {})
	for nm in ["HILL_DONKEY", "HILL_SHEEP", "HILL_DONKEY_NEW"]:
		var m := s.find_child(nm, true, false) as MeshInstance3D
		if m == null:
			continue
		for i in m.mesh.get_surface_count():
			m.set_surface_override_material(i, mat)
		var hb: Array = hb_all.get(nm, [0.0, 100.0])
		m.set_instance_shader_parameter("ybase", float(hb[0]))
		m.set_instance_shader_parameter("ysize", float(hb[1]) - float(hb[0]))
		var box: AABB = m.transform * m.get_aabb()
		if nm == "HILL_SHEEP":
			places["sheep"] = box.get_center()
			places["sheep_size"] = box.size
		elif nm == "HILL_DONKEY":
			places["donkey"] = box.get_center()
			places["donkey_size"] = box.size
	_cedars(data.get("cedars", []))


func _cedars(trees: Array) -> void:
	if trees.is_empty():
		return
	var s: Node = load("res://herding/assets/world/cedar.glb").instantiate()
	var needle := StandardMaterial3D.new()
	needle.albedo_color = Color(0.20, 0.27, 0.19)
	needle.roughness = 0.9
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.26, 0.20, 0.15)
	bark.roughness = 0.95
	var protos := []
	for nm in ["CEDAR_A", "CEDAR_B"]:
		var mi := s.find_child(nm, true, false) as MeshInstance3D
		if mi:
			var mesh: Mesh = mi.mesh.duplicate()
			for i in mesh.get_surface_count():
				var m0: Material = mesh.surface_get_material(i)
				var bk := m0 != null and String(m0.resource_name).contains("BARK")
				mesh.surface_set_material(i, bark if bk else needle)
			protos.append(mesh)
	s.free()
	for v in protos.size():
		var sel := trees.filter(func(e): return int(e[5]) == v)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = protos[v]
		mm.instance_count = sel.size()
		for i in sel.size():
			var e: Array = sel[i]
			var h := float(e[4])
			var b := Basis(Vector3.UP, float(e[3])).scaled(Vector3(h * 1.1, h, h * 1.1))
			if e.size() >= 9:
				var ax := Vector3(e[6], e[7], e[8]).normalized()
				var rot_axis := Vector3.UP.cross(ax)
				if rot_axis.length() > 0.0001:
					b = Basis(rot_axis.normalized(), Vector3.UP.angle_to(ax)) * b
			mm.set_instance_transform(i, Transform3D(b, Vector3(e[0], e[1], e[2])))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


# ------------------------------------------------------------------ the great palm

func _palm() -> void:
	# the textured date palm (same Phoenix dactylifera model as the Ait Wadu giant), raised to the giant's
	# size and standing where the giant stands on the river bank
	const AT := Vector3(435.4682, -6.792964, -181.9329)
	const HEIGHT := 150.0
	var s: Node3D = load("res://herding/assets/world/date_palm.glb").instantiate()
	add_child(s)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = mi.transform * mi.get_aabb()
		var n: Node = mi.get_parent()
		while n != s and n is Node3D:
			bb = (n as Node3D).transform * bb
			n = n.get_parent()
		box = bb if first else box.merge(bb)
		first = false
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m and m.albedo_texture and String(m.resource_name).contains("lft"):
				var mm: BaseMaterial3D = m.duplicate()
				mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mm.alpha_scissor_threshold = 0.4
				mm.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(i, mm)
	var k := HEIGHT / maxf(box.size.y, 0.001)
	s.scale = Vector3.ONE * k
	var c := box.get_center()
	s.position = AT - Vector3(c.x, box.position.y, c.z) * k + Vector3(0, -1.5, 0)
	places["palm"] = AT


# ------------------------------------------------------------------ places and how the camera looks at them

func _places() -> void:
	var palm: Vector3 = places["palm"]
	# the river: the water line nearest the palm, a little upstream
	var rz := palm.z + 120.0
	places["river"] = Vector3(_river_x(rz), -9.3, rz)
	# the poppy field: chosen once the poppies are loaded (see _poppies); provisional spot west of the river
	places["field"] = Vector3(60.0, height_at(60.0, -180.0), -180.0)
	var pr: Vector3 = places["river"]
	views["palm"] = _view_from(palm, Vector3(-1.0, 0, 0.45), 230.0, 18.0, palm + Vector3(0, 70, 0))
	views["river"] = [Vector3(pr.x - 28.0, height_at(pr.x - 28.0, pr.z + 70.0) + 6.0, pr.z + 70.0), pr + Vector3(10, 4, -160)]
	# the winds: high over the valley, looking north along the river to the donkey mountain
	places["sky"] = Vector3(150, 90, 300)
	views["sky"] = [Vector3(220, height_at(220, 520) + 70.0, 520), Vector3(120, 40, -300)]
	for k in ["sheep", "donkey"]:
		var c: Vector3 = places[k]
		var sz: Vector3 = places[k + "_size"]
		var dir := Vector3(-c.x, 0, -c.z).normalized()        # from the valley floor, toward the centre
		views[k] = _view_from(c, dir, maxf(sz.x, sz.z) * 1.15 + 120.0, 20.0, c + Vector3(0, sz.y * 0.1, 0))


func _view_from(p: Vector3, dir: Vector3, dist: float, above_ground: float, look: Vector3) -> Array:
	var c := p + dir.normalized() * dist
	c.y = height_at(c.x, c.z) + above_ground
	return [c, look]


func _river_x(z: float) -> float:
	# middle of the river surface at depth z (from the SEBOU_RIVER vertices)
	for n in find_children("SEBOU_RIVER", "MeshInstance3D", true, false):
		var v: PackedVector3Array = (n as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var lo := INF
		var hi := -INF
		for p in v:
			if absf(p.z - z) < 12.0:
				lo = minf(lo, p.x)
				hi = maxf(hi, p.x)
		if lo < hi:
			return (lo + hi) * 0.5
	return 300.0


# where each wind comes from (degrees clockwise from north; north = -Z, east = +X in the valley)
const WIND_FROM := {"saba": 90.0, "harmattan": 45.0, "chergui": 110.0, "khamsin": 180.0, "simoom": 150.0,
	"shamal": 315.0, "dabur": 270.0, "ajaj": 135.0, "haboob": 200.0}


func _wind_dir(slot: String) -> Vector3:
	var a := deg_to_rad(float(WIND_FROM.get(slot.trim_prefix("sky_"), 0.0)))
	return Vector3(sin(a), 0.0, -cos(a))


func place_position(slot) -> Vector3:
	if typeof(slot) == TYPE_STRING and String(slot).begins_with("sky_"):
		return Vector3(150, 40, 100) + _wind_dir(slot) * 60.0
	return places.get(slot, Vector3.ZERO)


## each wind: the camera stands on the valley floor and faces where the wind comes from
func view(slot) -> Array:
	if typeof(slot) == TYPE_STRING and String(slot).begins_with("sky_"):
		var d := _wind_dir(slot)
		var c := Vector3(150, 0, 100) - d * 40.0
		c.y = height_at(c.x, c.z) + 14.0
		return [c, c + d * 700.0 + Vector3(0, 30, 0)]
	return views.get(slot, [])


# ------------------------------------------------------------------ the poppy field

func _poppy_mesh() -> ArrayMesh:
	# one flower, ~0.5 m: stem, a cup of four petals, a dark core (vertex colours, double-sided)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := Color(0.16, 0.26, 0.08)
	var red := Color(0.62, 0.02, 0.015)
	var core := Color(0.03, 0.02, 0.02)
	var hgt := 0.5
	for k in 2:                                  # stem: two crossed thin quads
		var a := k * PI * 0.5
		var d := Vector3(cos(a), 0, sin(a)) * 0.006
		_quad(st, -d, d, d + Vector3(0, hgt, 0), -d + Vector3(0, hgt, 0), green)
	for k in 4:                                  # petals: tilted outward and up
		var a := k * PI * 0.5 + 0.3
		var o := Vector3(cos(a), 0, sin(a))
		var sd := Vector3(-o.z, 0, o.x) * 0.045
		var base := Vector3(0, hgt, 0)
		var tip := base + o * 0.06 + Vector3(0, 0.05, 0)
		_quad(st, base - sd * 0.4, base + sd * 0.4, tip + sd, tip - sd, red)
	var c0 := Vector3(0, hgt + 0.012, 0)          # core: a small dark tuft
	_quad(st, c0 + Vector3(-0.012, 0, 0), c0 + Vector3(0.012, 0, 0), c0 + Vector3(0.012, 0.02, 0), c0 + Vector3(-0.012, 0.02, 0), core)
	st.generate_normals()
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_color(col)
		st.add_vertex(p)


func _poppies() -> void:
	if not FileAccess.file_exists("res://herding/data/poppies.bin"):
		return
	var raw := FileAccess.get_file_as_bytes("res://herding/data/poppies.bin").to_float32_array()
	var pts: Array = []
	for i in range(0, raw.size(), 6):
		pts.append(Vector3(raw[i], raw[i + 1], raw[i + 2]))
	# the field place: the flower nearest a spot across the river from the palm
	var palm: Vector3 = places["palm"]
	var want := Vector3(palm.x - 330.0, 0, palm.z + 20.0)
	var best: Vector3 = pts[0]
	for p in pts:
		if Vector2(p.x - want.x, p.z - want.z).length() < Vector2(best.x - want.x, best.z - want.z).length():
			best = p
	places["field"] = best
	# camera low in the flowers, looking east across the field and the river to the palm
	var f: Vector3 = best
	var cpos := Vector3(f.x - 40.0, 0, f.z + 8.0)
	cpos.y = height_at(cpos.x, cpos.z) + 1.5
	views["field"] = [cpos, palm + Vector3(0, 55, 0)]
	if ground_mat:
		ground_mat.set_shader_parameter("field_c", f)
	# denser around the field place: each nearby flower brings a small clump with it
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var dense: Array = []
	for p in pts:
		var dd := Vector2(p.x - f.x, p.z - f.z).length()
		if dd < 70.0:
			for k in int(lerpf(10.0, 2.0, dd / 70.0)):
				var q: Vector3 = p + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
				q.y = p.y
				dense.append(q)
	pts.append_array(dense)
	# the field itself: a dense carpet around the field place (thinning toward its edge), on the ground grid
	for i in 70000:
		var r := 130.0 * pow(rng.randf(), 0.75)
		var a := rng.randf() * TAU
		var q := Vector3(f.x + cos(a) * r * 1.4, 0, f.z + sin(a) * r)
		q.y = height_at(q.x, q.z) - 0.03
		if q.y > -9.0:
			pts.append(q)
	field_c = f
	poppy_mat = ShaderMaterial.new()
	poppy_mat.shader = load("res://herding/shaders/poppy.gdshader")
	var mesh := _poppy_mesh()
	mesh.surface_set_material(0, poppy_mat)
	# chunks of 80 m so far chunks are culled; the far field reads from the red tint of the ground
	var chunks := {}
	for p in pts:
		var key := Vector2i(int(floor(p.x / 80.0)), int(floor(p.z / 80.0)))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(p)
	for key in chunks:
		var list: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var s := rng.randf_range(0.75, 1.3)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
			b = Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf_range(0.0, 0.18)) * b
			mm.set_instance_transform(i, Transform3D(b, list[i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 220.0
		mmi.visibility_range_end_margin = 40.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)


func _process(delta: float) -> void:
	_t += delta
	RenderingServer.global_shader_parameter_set("film_clock", _t)


## kept for main.gd: places in the valley carry no block to fit a body on
static func cylinder_radius(_i: int) -> float:
	return 0.0
