extends Node3D
## Beyond the seventh circle: Qur'anic gardens grown with AZ OOR's Taganat Arabesques library
## (olive / zaytun, grapevine / inab, pomegranate / rumman, date palm / nakhl, mixed).
## Seven shamsa gardens of seven lobes on a heptagon, five arabesque-wrapped rammed-earth towers
## on a pentagon (the 5 / 7 system). Gardens are pre-baked by tools/bake_gardens.gd.

const SHAMSA := ["shamsa_olive", "shamsa_vine", "shamsa_pomegranate", "shamsa_palm", "shamsa_mixed_a", "shamsa_olive", "shamsa_vine"]
const COLUMNS := ["column_olive", "column_palm", "column_olive", "column_palm", "column_olive"]
const SHAMSA_R := 90.0
const COLUMN_R := 112.0
const COLUMN_SCALE := 1.35

var cicada_anchor: Node3D
var _cache := {}
var _t := 0.0
var _shimmer := 0.0
var _pieces: Array = []


func _scene(name: String) -> PackedScene:
	if not _cache.has(name):
		_cache[name] = load("res://gardens/%s.scn" % name)
	return _cache[name]


func _palm(pos: Vector3, h: float, rot: float) -> void:
	if OS.get_environment("AK_TEST_NO_PALMS") == "1":
		return
	var p: Node3D = _scene_glb("res://models/date_palm.glb").instantiate()
	add_child(p)
	_natural_palm(p)
	var box := _aabb(p)
	if box.size.y > 0.001:
		p.scale = Vector3.ONE * (h / box.size.y)
	p.position = pos - Vector3(0, box.position.y * p.scale.y, 0)
	p.rotation.y = rot


## The palm comes from the City of Salt and Blood: drop its salt-crust overlay so it reads as a living
## nakhl, and use alpha-scissor fronds (cheaper and stable on phones) instead of depth-prepass blending.
func _natural_palm(p: Node3D) -> void:
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("SALT_"):
			mi.visible = false
			continue
		for s in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(s)
			if m is BaseMaterial3D and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				if not _cache.has(m):
					var c: BaseMaterial3D = m.duplicate()
					c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					c.alpha_scissor_threshold = 0.45
					_cache[m] = c
				mi.set_surface_override_material(s, _cache[m])


func _scene_glb(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


func _aabb(n: Node3D) -> AABB:
	var first := true
	var box := AABB()
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = n.global_transform.affine_inverse() * mi.global_transform
		var a: AABB = xf * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box


func build(ground_y: float) -> void:
	var soil := ShaderMaterial.new()
	soil.shader = load("res://shaders/garden_soil.gdshader")
	for i in 7:
		var a := TAU * float(i) / 7.0 + PI * 0.5
		var p := Vector3(cos(a) * SHAMSA_R, ground_y, sin(a) * SHAMSA_R)
		var bed := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 10.6
		cm.bottom_radius = 11.0
		cm.height = 0.5
		cm.radial_segments = 70
		bed.mesh = cm
		bed.material_override = soil
		bed.position = p + Vector3(0, 0.25, 0)
		add_child(bed)
		var gnode: Node3D = _scene(SHAMSA[i]).instantiate()
		gnode.position = p + Vector3(0, 0.5, 0)
		gnode.rotation.y = -a + PI * 0.5 + float(i) * 0.3
		gnode.scale = Vector3.ONE * 2.6
		add_child(gnode)
		_pieces.append(gnode)
		if i == 0:
			cicada_anchor = gnode
		# date palms (nakhl) standing behind each garden, and an arabesque bush between gardens
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + i
		for k in 3:
			var off := Vector3(cos(a + (k - 1) * 0.16), 0, sin(a + (k - 1) * 0.16)) * (SHAMSA_R + 13.0 + rng.randf() * 4.0)
			_palm(Vector3(off.x, ground_y, off.z), rng.randf_range(8.0, 12.5), rng.randf() * TAU)
		var b := a + TAU / 14.0
		var bush: Node3D = _scene("sphere_olive" if i % 2 == 0 else "sphere_pomegranate").instantiate()
		bush.position = Vector3(cos(b) * (SHAMSA_R - 2.0), ground_y + 1.5, sin(b) * (SHAMSA_R - 2.0))
		bush.rotation.y = float(i)
		bush.scale = Vector3.ONE * 1.3
		add_child(bush)
		_pieces.append(bush)
	var earth := ShaderMaterial.new()
	earth.shader = load("res://shaders/rammed_earth.gdshader")
	earth.set_shader_parameter("nor", load("res://textures/earth/red_laterite_soil_stones_nor_gl_2k.jpg"))
	earth.set_shader_parameter("grit", load("res://textures/earth/red_laterite_soil_stones_diff_2k.jpg"))
	var core_r := 16.0 / TAU * COLUMN_SCALE - 0.08
	var core_h := 8.4 * COLUMN_SCALE + 0.6
	earth.set_shader_parameter("radius", core_r)
	earth.set_shader_parameter("height", core_h)
	earth.set_shader_parameter("seed", 41.0)
	for i in 5:
		var a := TAU * float(i) / 5.0 + PI * 0.5 + TAU / 10.0
		var p := Vector3(cos(a) * COLUMN_R, ground_y, sin(a) * COLUMN_R)
		var core := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = core_r
		cm.bottom_radius = core_r * 1.03
		cm.height = core_h
		cm.radial_segments = 64
		core.mesh = cm
		core.material_override = earth
		core.position = p + Vector3(0, core_h * 0.5, 0)
		add_child(core)
		var col: Node3D = _scene(COLUMNS[i]).instantiate()
		col.position = p
		col.rotation.y = float(i) * 1.1
		col.scale = Vector3.ONE * COLUMN_SCALE
		add_child(col)
		_pieces.append(col)


func set_shimmer(level: float) -> void:
	_shimmer = lerp(_shimmer, level, 0.1)


func _process(delta: float) -> void:
	_t += delta
	# a breath of wind through the gardens, stronger while the cicadas sing
	var k := 0
	for p: Node3D in _pieces:
		p.rotation.z = sin(_t * 0.6 + k) * (0.004 + 0.01 * _shimmer)
		k += 1
