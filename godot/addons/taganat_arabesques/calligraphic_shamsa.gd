extends "res://addons/taganat_arabesques/calligraphy.gd"
## Eightfold growing phrase study, not a historical calligrapher's composition.
var sector: int = 0
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
	full_mesh_vertices = 0
	rng.seed = variation
	gold = material(Color("d8ad60"),0.85)
	wood = material(Color("987047"))
	leaf_mat = material(Color("387541"))
	ivory = material(Color("ebd8ad"))
	red = material(Color("b9434c"))
	leaf_mesh = _blade()
	verse_texts.append("لا غالب إلا الله")
	for index in range(8):
		sector = index
		_build_living_letters(verse_texts[0])
		var axis: float = float(index)*TAU/8.0
		for mirror_ in [-1.0,1.0]:
			var curl := PackedVector3Array()
			for j in range(81):
				var t: float = float(j)/80.0
				var r: float = lerpf(2.75,0.8,t)
				var a: float = axis+mirror_*0.30*sin(t*PI*2)
				curl.append(Vector3(sin(a)*r,5.0+cos(a)*r,0.30+mirror_*0.13*sin(t*TAU*2)))
			_tube(curl,0.036,0.12,0.55)
			for j in range(12):
				var p: Vector3 = curl[5+j*6]
				_leaf(p,-axis+mirror_*0.75,0.17+float(j)*0.045,1.15)
			_rosette(curl[58],0.25,0.68)
	# The perimeter echoes a lobed sun, rather than a rectangular frame.
	var outline := PackedVector3Array()
	for j in range(513):
		var a: float = float(j)/512.0*TAU
		var r: float = 4.55+0.40*cos(a*8.0)
		outline.append(Vector3(sin(a)*r,5.0+cos(a)*r,0.22))
	_tube(outline,0.042,0.0,0.85)
	_rosette(Vector3(0,5,0.5),0.65,0.78)
	_apply_growth()

func _build_living_letters(text: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/calligraphy/shamsa_phrase_branches.json"))
	var row: Dictionary = {}
	for candidate in data.rows:
		if candidate.text == text:
			row = candidate
			break
	assert(not row.is_empty(), "Shamsa phrase guides missing")
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
			var local_delta := Vector2(float(points[i+1][0])-float(points[i][0]),float(points[i+1][1])-float(points[i][1])).normalized()
			var side := Vector3(-local_delta.y,local_delta.x,0).normalized()
			for ring in range(10):
				for corner in [Vector2i(0,ring),Vector2i(1,ring),Vector2i(1,ring+1),Vector2i(0,ring),Vector2i(1,ring+1),Vector2i(0,ring+1)]:
					var q: Array = points[i+corner.x]
					var angle: float = float(corner.y)*TAU/10.0
					var radius: float = float(q[2])
					var offset_q: Array = q.duplicate()
					offset_q[0] = float(q[0])+side.x*cos(angle)*radius
					offset_q[1] = float(q[1])+side.y*cos(angle)*radius
					var planar: Vector3 = _stroke_point(offset_q,center,scale_xy)-_stroke_point(q,center,scale_xy)
					tool.set_uv(Vector2(float(corner.y)/10.0,0.05+0.67*(float(q[3])-first)/maxf(0.001,last-first)))
					tool.add_vertex((a if corner.x==0 else b)+planar+Vector3(0,0,sin(angle)*maxf(0.025,radius*scale_xy.x*0.65)))
		if path.main and points.size()>18 and shoots<12:
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
				vine.append(base+Vector3(0.18*sin(phase)*envelope,0.16*sin(phase)*envelope,0.22*cos(phase)*envelope))
			_tube(vine,0.023,birth+0.035,0.20)
			for k in range(8):
				var index: int = 7+k*7
				_leaf(vine[index],(-0.8 if k%2==0 else 0.9),birth+0.035+float(index)/64.0*0.20,0.85)
			_rosette(vine[48]+Vector3(0,0,0.03),0.14,birth+0.23)
	tool.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "GrowingLetterStrokes"
	node.mesh = tool.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/taganat_arabesques/shamsa_stroke.gdshader")
	mat.set_shader_parameter("cast_gold",finish==1)
	node.material_override = mat
	generated.add_child(node)
	stems.append({"node":node,"material":mat,"birth":0.0,"duration":1.0})
	full_mesh_vertices += node.mesh.get_faces().size()
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
	var x: float = (float(q[0])-center.x)*scale_xy.x/10.0
	var y: float = (float(q[1])-center.y)*scale_xy.y/2.8
	var angle: float = float(sector)*TAU/8.0+x*TAU/8.0*0.90
	var radius: float = 3.4+y*1.65
	return Vector3(sin(angle)*radius,5.0+cos(angle)*radius,0.42)

func get_stats() -> Dictionary:
	var result: Dictionary = super.get_stats()
	result["phrase"] = "لا غالب إلا الله"
	result["repeats"] = 8
	result["mirrored_text"] = false
	return result

func _leaf(position_: Vector3, angle: float, birth: float, size_: float = 1.0) -> void:
	# Foliage stays rich but behind the raised writing.
	super._leaf(position_-Vector3(0,0,0.28),angle,birth,size_*0.82)
