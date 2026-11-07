extends "res://addons/taganat_arabesques/calligraphy.gd"
## Architectural frieze study: shaped inscription over a continuous vegetal field.
func regenerate() -> void:
	if is_instance_valid(generated):
		remove_child(generated)
		generated.queue_free()
	generated = Node3D.new()
	add_child(generated)
	lettering.clear()
	stems.clear()
	organs.clear()
	verse_texts.clear()
	rng.seed = variation
	font = load(font_path)
	font.fallbacks = [load("res://assets/calligraphy/Amiri-Regular.ttf")]
	gold = material(Color("d8ad60"),0.85)
	wood = material(Color("987047"))
	leaf_mat = material(Color("61794e"))
	ivory = material(Color("ebd8ad"))
	red = material(Color("9e4242"))
	leaf_mesh = _blade()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(text_path))
	var text: String = data.verses[0].text
	verse_texts.append(text)
	_build_living_letters(text)
	# Paired boundary stems alternate front/back at crossings.
	for edge in [-1.0,1.0]:
		for strand in [-1.0,1.0]:
			var path := PackedVector3Array()
			for j in range(241):
				var t: float = float(j)/240.0
				path.append(Vector3(-5.7+t*11.4,5.0+edge*1.9+strand*0.10*sin(t*TAU*12),0.24+strand*0.065*cos(t*TAU*12)))
			_tube(path,0.035,0.0,0.8)
		for k in range(25):
			_leaf(Vector3(-5.5+float(k)*0.46,5.0+edge*1.88,0.25),edge*PI*0.5,0.3+float(k)*0.016,0.65)
	_apply_growth()

func _build_living_letters(text: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/calligraphy/letter_branches.json"))
	var row: Dictionary = {}
	for candidate in data.rows:
		if candidate.text == text:
			row = candidate
			break
	assert(not row.is_empty(), "Bismillah branch guides missing")
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	var first: float = INF
	var last: float = -INF
	for path in row.paths:
		for q in path.points:
			low = low.min(Vector2(q[0]-q[2],q[1]-q[2]))
			high = high.max(Vector2(q[0]+q[2],q[1]+q[2]))
			first = minf(first,float(q[3]))
			last = maxf(last,float(q[3]))
	var scale_xy := Vector2(10.0/(high.x-low.x),2.8/(high.y-low.y))
	var center: Vector2 = (low+high)*0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoots: int = 0
	for path in row.paths:
		var points: Array = path.points
		for i in range(points.size()-1):
			var a: Vector3 = _stroke_point(points[i],center,scale_xy)
			var b: Vector3 = _stroke_point(points[i+1],center,scale_xy)
			var tangent: Vector3 = (b-a).normalized()
			var side := Vector3(-tangent.y,tangent.x,0).normalized()
			for ring in range(10):
				for corner in [Vector2i(0,ring),Vector2i(1,ring),Vector2i(1,ring+1),Vector2i(0,ring),Vector2i(1,ring+1),Vector2i(0,ring+1)]:
					var q: Array = points[i+corner.x]
					var angle: float = float(corner.y)*TAU/10.0
					var radius: float = float(q[2])
					var planar: Vector3 = side*cos(angle)*radius
					planar.x *= scale_xy.x
					planar.y *= scale_xy.y
					tool.set_uv(Vector2(float(corner.y)/10.0,0.05+0.67*(float(q[3])-first)/maxf(0.001,last-first)))
					tool.add_vertex((a if corner.x==0 else b)+planar+Vector3(0,0,sin(angle)*maxf(0.025,radius*scale_xy.x*0.65)))
		if path.main and points.size()>18 and shoots<18:
			shoots += 1
			var vine := PackedVector3Array()
			var start_index: int = int(points.size()*0.2)
			var end_index: int = int(points.size()*0.8)
			var birth: float = 0.05+0.67*(float(points[start_index][3])-first)/maxf(0.001,last-first)
			for j in range(65):
				var t: float = float(j)/64.0
				var index: int = int(lerpf(start_index,end_index,t))
				var base: Vector3 = _stroke_point(points[index],center,scale_xy)
				var phase: float = t*TAU*2.0
				var envelope: float = sin(t*PI)
				vine.append(base+Vector3(0.28*sin(phase)*envelope,0.21*sin(phase)*envelope,0.22*cos(phase)*envelope))
			_tube(vine,0.023,birth+0.035,0.20)
			for k in range(4):
				var index: int = 12+k*12
				_leaf(vine[index],(-0.8 if k%2==0 else 0.9),birth+0.035+float(index)/64.0*0.20,0.55)
			_rosette(vine[48]+Vector3(0,0,0.03),0.14,birth+0.23)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "GrowingLetterStrokes"
	node.mesh = tool.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/taganat_arabesques/calligraphy_stem.gdshader")
	mat.set_shader_parameter("cast_gold",finish==1)
	node.material_override = mat
	generated.add_child(node)
	stems.append({"node":node,"material":mat,"birth":0.0,"duration":1.0})
	full_mesh_vertices = node.mesh.get_faces().size()
	print("LIVING_LETTERS_READY paths=",row.paths.size()," joined_vines=",shoots)
	for bud in row.buds:
		var q: Array = bud.points[0]
		var mark := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = maxf(0.02,float(q[2])*scale_xy.x)
		ball.height = ball.radius*2.0
		mark.mesh = ball
		mark.material_override = gold if finish==1 else wood
		mark.position = _stroke_point(q,center,scale_xy)
		generated.add_child(mark)
		organs.append({"node":mark,"birth":0.05+0.67*(float(q[3])-first)/maxf(0.001,last-first),"size":1.0})

func _stroke_point(q: Array, center: Vector2, scale_xy: Vector2) -> Vector3:
	return Vector3((float(q[0])-center.x)*scale_xy.x,5.0+(float(q[1])-center.y)*scale_xy.y,0.42)
