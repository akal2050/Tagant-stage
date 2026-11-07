class_name TaganatCalligraphy
extends Node3D
## Reusable Maghribi lettering and botanical frame. Geometry stays in 3D.
@export_range(0.0, 1.0, 0.001) var growth_progress: float = 1.0:
	set(value):
		growth_progress = clampf(value, 0.0, 1.0)
		if is_inside_tree(): _apply_growth()
@export var play_growth: bool = false
@export var growth_speed: float = 0.035
@export_enum("Gold lettering / living garden", "Entirely cast gold") var finish: int = 0
@export var variation: int = 12
@export var font_path: String = "res://assets/calligraphy/BouazziMaghribi-Regular.ttf"
@export var text_path: String = "res://assets/calligraphy/fatiha.json"
var lettering: Array[Dictionary] = []
var stems: Array[Dictionary] = []
var organs: Array[Dictionary] = []
var verse_texts: Array[String] = []
var generated: Node3D
var font: Font
var gold: StandardMaterial3D
var wood: StandardMaterial3D
var leaf_mat: StandardMaterial3D
var ivory: StandardMaterial3D
var red: StandardMaterial3D
var leaf_mesh: ArrayMesh
var rng := RandomNumberGenerator.new()
var full_mesh_vertices: int = 0

func _ready() -> void:
	regenerate()

func _process(delta: float) -> void:
	if play_growth:
		growth_progress = minf(1.0, growth_progress + delta * growth_speed)
		if growth_progress >= 1.0: play_growth = false

func material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.28 if metal > 0.0 else 0.66
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func regenerate() -> void:
	if is_instance_valid(generated):
		remove_child(generated)
		generated.queue_free()
	generated = Node3D.new()
	generated.name = "CalligraphyGeometry"
	add_child(generated)
	lettering.clear()
	stems.clear()
	organs.clear()
	verse_texts.clear()
	full_mesh_vertices = 0
	rng.seed = variation
	font = load(font_path) as Font
	assert(font != null, "Maghribi font is missing")
	if ResourceLoader.exists("res://assets/calligraphy/Amiri-Regular.ttf"):
		font.fallbacks = [load("res://assets/calligraphy/Amiri-Regular.ttf")]
	gold = material(Color("d4a453"), 0.92)
	wood = material(Color("65442c"))
	leaf_mat = material(Color("376a43"))
	ivory = material(Color("f4e5bc"))
	red = material(Color("a93336"))
	leaf_mesh = _blade()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(text_path))
	assert(data.has("verses") and data.verses.size() == 7, "Expected seven verified verses")
	var lines: Array[Dictionary] = []
	for index in range(7):
		var text: String = str(data.verses[index].text)
		verse_texts.append(text)
		if index == 6:
			var words := text.split(" ", false)
			var split_at: int = 4
			lines.append({"text": " ".join(words.slice(0, split_at)), "verse": index, "end": false})
			lines.append({"text": " ".join(words.slice(split_at)), "verse": index, "end": true})
		else:
			lines.append({"text": text, "verse": index, "end": true})
	# Fit every complete shaped line at a common font size, without stretching letters.
	var measures: Array[TextMesh] = []
	var max_width: float = 0.001
	for line in lines:
		var mesh := TextMesh.new()
		mesh.font = font
		mesh.font_size = 140
		mesh.pixel_size = 0.008
		mesh.depth = 0.055
		mesh.curve_step = 1.0
		mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mesh.text_direction = TextServer.DIRECTION_RTL
		mesh.language = "ar"
		mesh.text = line.text
		measures.append(mesh)
		max_width = maxf(max_width, mesh.get_aabb().size.x)
	var fit: float = minf(1.0, 7.6 / max_width)
	for i in range(lines.size()):
		var item := MeshInstance3D.new()
		item.name = "Ayah_%d_Line_%d" % [lines[i].verse + 1, i + 1]
		item.mesh = measures[i]
		item.scale = Vector3.ONE * fit
		item.position = Vector3(0, 7.8 - float(i) * 0.81, 0.25)
		generated.add_child(item)
		var bounds := measures[i].get_aabb()
		full_mesh_vertices += measures[i].get_faces().size()
		var reveal := ShaderMaterial.new()
		reveal.shader = load("res://addons/taganat_arabesques/calligraphy_reveal.gdshader")
		reveal.set_shader_parameter("left_edge", bounds.position.x)
		reveal.set_shader_parameter("right_edge", bounds.end.x)
		reveal.set_shader_parameter("gold_color", Color("d4a453"))
		item.material_override = reveal
		lettering.append({"node": item, "material": reveal, "birth": 0.06 + float(i) * 0.072})
		if lines[i].end:
			_rosette(Vector3(-4.17, item.position.y, 0.24), 0.18, 0.10 + float(i) * 0.072)
	_title()
	_border()
	_apply_growth()

func _title() -> void:
	var mesh := TextMesh.new()
	mesh.font = font
	mesh.font_size = 150
	mesh.pixel_size = 0.006
	mesh.depth = 0.04
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mesh.text_direction = TextServer.DIRECTION_RTL
	mesh.language = "ar"
	mesh.text = "سورة الفاتحة"
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = gold
	node.position = Vector3(0, 9.15, 0.24)
	generated.add_child(node)

func _blade() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(12):
		for col in range(4):
			for corner in [Vector2i(row,col),Vector2i(row+1,col),Vector2i(row+1,col+1),Vector2i(row,col),Vector2i(row+1,col+1),Vector2i(row,col+1)]:
				var t: float = float(corner.x) / 12.0
				var v: float = float(corner.y) / 4.0 * 2.0 - 1.0
				var width: float = pow(sin(t * PI), 0.8) * 0.105 * (1.0 + 0.1 * sin(t * PI * 6.0))
				tool.set_uv(Vector2((v+1.0)*0.5, t))
				tool.add_vertex(Vector3(v * width, t * 0.48, 0.07 * sin(t*PI) * (1.0-v*v) + 0.05*t*t))
	tool.generate_normals()
	return tool.commit()

func _tube(points: PackedVector3Array, radius: float, birth: float, duration: float) -> void:
	if points.size() < 2: return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var tangent: Vector3 = (points[i+1]-points[i]).normalized()
		var axis: Vector3 = Vector3.FORWARD if absf(tangent.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
		var side: Vector3 = tangent.cross(axis).normalized()
		var up: Vector3 = tangent.cross(side).normalized()
		for j in range(8):
			for c in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,j+1), Vector2i(i,j), Vector2i(i+1,j+1), Vector2i(i,j+1)]:
				var angle: float = float(c.y) / 8.0 * TAU
				var t: float = float(c.x) / float(points.size()-1)
				var width: float = radius * lerpf(1.0, 0.22, t)
				tool.set_uv(Vector2(float(c.y)/8.0,t))
				tool.add_vertex(points[c.x] + (side*cos(angle)+up*sin(angle))*width)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/taganat_arabesques/calligraphy_stem.gdshader")
	mat.set_shader_parameter("cast_gold", finish == 1)
	node.material_override = mat
	generated.add_child(node)
	stems.append({"node":node,"material":mat,"birth":birth,"duration":duration})

func _leaf(position_: Vector3, angle: float, birth: float, size_: float = 1.0) -> void:
	var node := MeshInstance3D.new()
	node.mesh = leaf_mesh
	node.material_override = gold if finish == 1 else leaf_mat
	node.position = position_
	node.rotation = Vector3(rng.randf_range(-0.3,0.3),rng.randf_range(-0.4,0.4),angle)
	generated.add_child(node)
	organs.append({"node":node,"birth":birth,"size":size_})

func _rosette(position_: Vector3, size_: float, birth: float) -> void:
	var flower := Node3D.new()
	flower.position = position_
	generated.add_child(flower)
	for i in range(8):
		var petal := MeshInstance3D.new()
		petal.mesh = leaf_mesh
		petal.rotation.z = float(i)*TAU/8.0
		petal.scale = Vector3(0.62,0.62,0.65)
		petal.material_override = gold if finish == 1 else (ivory if i%2 == 0 else red)
		flower.add_child(petal)
	var center := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.065
	ball.height = 0.13
	center.mesh = ball
	center.position.z = 0.04
	center.material_override = gold
	flower.add_child(center)
	organs.append({"node":flower,"birth":birth,"size":size_/0.22})

func _border() -> void:
	for side in [-1.0, 1.0]:
		for strand in range(2):
			var vine := PackedVector3Array()
			for i in range(181):
				var t: float = float(i) / 180.0
				var phase: float = t * TAU * 5.0 + float(strand)*PI
				vine.append(Vector3(side*(4.7+0.24*sin(phase)),0.7+t*8.0,0.32+0.15*cos(phase)))
			_tube(vine,0.052,0.0,0.80)
		for tier in range(10):
			var cy: float = 1.0+float(tier)*0.78
			var radius: float = 0.36+rng.randf_range(-0.04,0.04)
			var scroll := PackedVector3Array()
			for i in range(65):
				var t: float = float(i)/64.0
				var angle: float = t*TAU*1.16
				var r: float = radius*(1.0-t*0.80)
				scroll.append(Vector3(side*(5.0+sin(angle)*r),cy+radius-cos(angle)*r,0.40+sin(t*PI)*0.12))
			var birth: float = 0.12+float(tier)*0.056
			_tube(scroll,0.035,birth,0.18)
			for k in range(5):
				var p: Vector3 = scroll[8+k*9]
				_leaf(p,side*(-0.8+float(k)*0.46),birth+0.10+float(k)*0.014,rng.randf_range(0.75,1.15))
			if tier%2 == 0:
				_rosette(Vector3(side*5.1,cy+0.4,0.6),0.25,birth+0.23)
	# Mirrored botanical crowns sit above and below the inscription.
	for side in [-1.0,1.0]:
		for end in range(2):
			var y: float = 0.56 if end == 0 else 9.75
			var path := PackedVector3Array()
			for i in range(101):
				var t: float = float(i)/100.0
				path.append(Vector3(side*t*4.75,y+sin(t*PI*3.0)*0.18,0.32+0.1*cos(t*TAU*3.0)))
			_tube(path,0.047,0.05,0.78)
			for k in range(11):
				var p: Vector3 = path[5+k*9]
				_leaf(p,side*(0.6 if k%2 == 0 else 2.3),0.35+float(k)*0.035,0.9)
			_rosette(Vector3(side*2.3,y,0.47),0.27,0.82)

func _apply_growth() -> void:
	for item in lettering:
		var amount: float = clampf((growth_progress-float(item.birth))/0.12,0.0,1.0)
		item.node.visible = amount > 0.0
		item.material.set_shader_parameter("progress", amount)
	for stem in stems:
		stem.material.set_shader_parameter("progress",clampf((growth_progress-float(stem.birth))/float(stem.duration),0.0,1.0))
	for organ in organs:
		var amount: float = smoothstep(float(organ.birth),float(organ.birth)+0.10,growth_progress)
		organ.node.visible = amount > 0.001
		organ.node.scale = Vector3.ONE * maxf(0.001,amount*float(organ.size))

func get_stats() -> Dictionary:
	return {"verses":verse_texts.size(),"text_lines":lettering.size(),"letter_vertices":full_mesh_vertices,"stem_paths":stems.size(),"organs":organs.size(),"finish":finish,"growth":growth_progress}
