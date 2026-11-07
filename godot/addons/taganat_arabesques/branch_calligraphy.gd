class_name TaganatBranchCalligraphy
extends "res://addons/taganat_arabesques/calligraphy.gd"
## Medial-axis letter branches. Ornament is mirrored; Arabic text never is.
@export_enum("Flat", "Sphere", "Cylinder", "Imported surface atlas") var wrap_mode: int = 0
@export_range(1.0,8.0,0.1) var wrap_radius: float = 3.4
@export_range(1,4,1) var wrap_copies: int = 2
@export_range(0.1,1.5,0.05) var foliage_density: float = 0.65
@export_range(0.0,0.7,0.02) var relief_depth: float = 0.18
@export_file("*.json") var branch_guides: String = "res://assets/calligraphy/letter_branches.json"
@export_file("*.json") var surface_atlas: String = "res://assets/calligraphy/buraq_letter_atlas.json"
var reference_visible: bool = false
var glyph_nodes: Array[Node3D] = []
var reference_nodes: Array[Node3D] = []
var letter_path_count: int = 0
var letter_branch_vertices: int = 0
var letter_bud_count: int = 0
var joining_flourishes: int = 0
var guide_rows: Array = []
var atlas: Dictionary = {}
var stroke_shader: Shader

func regenerate() -> void:
	glyph_nodes.clear()
	reference_nodes.clear()
	letter_path_count = 0
	letter_branch_vertices = 0
	letter_bud_count = 0
	joining_flourishes = 0
	if wrap_mode == 3 and not surface_atlas.is_empty():
		atlas = JSON.parse_string(FileAccess.get_file_as_string(surface_atlas))
	super.regenerate()
	for child in generated.get_children():
		if child is MeshInstance3D and child.mesh is TextMesh:
			reference_nodes.append(child)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(branch_guides))
	guide_rows = data.rows
	stroke_shader = load("res://addons/taganat_arabesques/calligraphy_stem.gdshader")
	_build_letters()
	_join_letters_to_ornament()
	_apply_growth()

func _copies() -> int:
	return 1 if wrap_mode == 0 else wrap_copies

func _scale_for_wrap() -> float:
	return 1.0 if wrap_mode == 0 else wrap_radius * TAU / float(wrap_copies) / 12.4

func _map(p: Vector3, sector: int = 0) -> Vector3:
	if wrap_mode == 0: return p
	var angle: float = p.x / 12.4 * TAU / float(wrap_copies) + float(sector)*TAU/float(wrap_copies)
	if wrap_mode == 2:
		return Vector3(sin(angle)*(wrap_radius+p.z*0.35),0.4+p.y*0.8,cos(angle)*(wrap_radius+p.z*0.35))
	var latitude: float = clampf((p.y-5.1)/10.2*PI*0.94,-1.53,1.53)
	var normal := Vector3(sin(angle)*cos(latitude),sin(latitude),cos(angle)*cos(latitude))
	if wrap_mode == 3 and not atlas.is_empty():
		var u: float = fposmod(angle/TAU,1.0)*float(atlas.columns)
		var v: float = clampf(0.5-latitude/PI,0.0,1.0)*float(int(atlas.rows)-1)
		var column: int = int(floor(u))%int(atlas.columns)
		var row: int = mini(int(floor(v)),int(atlas.rows)-2)
		var pos := Vector3.ZERO
		var norm := Vector3.ZERO
		for dy in range(2):
			for dx in range(2):
				var index: int = (row+dy)*int(atlas.columns)+(column+dx)%int(atlas.columns)
				var weight: float = (u-floor(u) if dx == 1 else 1.0-u+floor(u))*(v-float(row) if dy == 1 else 1.0-v+float(row))
				var a: Array = atlas.positions[index]
				var b: Array = atlas.normals[index]
				pos += Vector3(a[0],a[1],a[2])*weight
				norm += Vector3(b[0],b[1],b[2])*weight
		return pos+Vector3(0,float(atlas.center_height),0)+norm.normalized()*(0.04+p.z*0.35)
	return Vector3(0,4.0,0)+normal*(wrap_radius+p.z*0.35)

func _frame(p: Vector3, sector: int) -> Basis:
	if wrap_mode == 0: return Basis.IDENTITY
	var x: Vector3 = (_map(p+Vector3(0.005,0,0),sector)-_map(p-Vector3(0.005,0,0),sector)).normalized()
	var y: Vector3 = (_map(p+Vector3(0,0.005,0),sector)-_map(p-Vector3(0,0.005,0),sector)).normalized()
	var normal: Vector3 = x.cross(y).normalized()
	if normal.length_squared()<0.1: return Basis.IDENTITY
	y = normal.cross(x).normalized()
	return Basis(x,y,normal)

func _tube(points: PackedVector3Array, radius: float, birth: float, duration: float) -> void:
	for sector in range(_copies()):
		var mapped := PackedVector3Array()
		var start_index: int = 0
		for index in range(points.size()):
			var point: Vector3 = _map(points[index],sector)
			if wrap_mode==3 and mapped.size()>0 and mapped[-1].distance_to(point)>0.45:
				if mapped.size()>1:
					super._tube(mapped,radius*_scale_for_wrap(),birth+duration*float(start_index)/float(points.size()),duration*float(mapped.size())/float(points.size()))
				mapped = PackedVector3Array()
				start_index = index
			mapped.append(point)
		if mapped.size()>1:
			super._tube(mapped,radius*_scale_for_wrap(),birth+duration*float(start_index)/float(points.size()),duration*float(mapped.size())/float(points.size()))

func _leaf(position_: Vector3, angle: float, birth: float, size_: float = 1.0) -> void:
	for sector in range(_copies()):
		super._leaf(_map(position_,sector),angle,birth,size_*_scale_for_wrap())
		var node: Node3D = organs.back().node
		node.basis = _frame(position_,sector)*Basis(Vector3.FORWARD,angle)

func _rosette(position_: Vector3, size_: float, birth: float) -> void:
	for sector in range(_copies()):
		super._rosette(_map(position_,sector),size_*_scale_for_wrap(),birth)
		var node: Node3D = organs.back().node
		node.basis = _frame(position_,sector)

func _letter_point(item: Array) -> Vector3:
	return Vector3(float(item[0]),float(item[1]),0.32+relief_depth*(0.5+0.5*sin(float(item[0])*2.1+float(item[1])*1.7)))

func _build_letters() -> void:
	for sector in range(_copies()):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in guide_rows:
			for path in row.paths:
				letter_path_count += 1
				var points: Array = path.points
				for i in range(points.size()-1):
					var a: Vector3 = _map(_letter_point(points[i]),sector)
					var b: Vector3 = _map(_letter_point(points[i+1]),sector)
					if a.distance_squared_to(b)<0.0000001: continue
					if wrap_mode == 3 and a.distance_to(b)>0.65: continue
					var tangent: Vector3 = (b-a).normalized()
					var normal: Vector3 = _frame(_letter_point(points[i]),sector).z
					var side: Vector3 = tangent.cross(normal).normalized()
					if side.length_squared()<0.1: side = tangent.cross(Vector3.UP).normalized()
					var up: Vector3 = tangent.cross(side).normalized()
					for ring in range(8):
						for corner in [Vector2i(0,ring),Vector2i(1,ring),Vector2i(1,ring+1),Vector2i(0,ring),Vector2i(1,ring+1),Vector2i(0,ring+1)]:
							var endpoint: int = i+corner.x
							var angle: float = float(corner.y)*TAU/8.0
							var radius: float = float(points[endpoint][2])*_scale_for_wrap()
							var center: Vector3 = a if corner.x==0 else b
							tool.set_uv(Vector2(float(corner.y)/8.0,float(points[endpoint][3])))
							tool.add_vertex(center+(side*cos(angle)+up*sin(angle))*radius)
							letter_branch_vertices += 1
				# Seal terminals, preserving their measured stroke widths.
				for endpoint in [0,points.size()-1]:
					var other: int = 1 if endpoint==0 else points.size()-2
					var center: Vector3 = _map(_letter_point(points[endpoint]),sector)
					var tangent: Vector3 = (_map(_letter_point(points[other]),sector)-center).normalized()
					var side: Vector3 = tangent.cross(_frame(_letter_point(points[endpoint]),sector).z).normalized()
					var up: Vector3 = tangent.cross(side).normalized()
					var radius: float = float(points[endpoint][2])*_scale_for_wrap()
					for ring in range(8):
						for v in [Vector3.ZERO,side*cos(float(ring)*TAU/8.0)+up*sin(float(ring)*TAU/8.0),side*cos(float(ring+1)*TAU/8.0)+up*sin(float(ring+1)*TAU/8.0)]:
							tool.set_uv(Vector2(0,float(points[endpoint][3])))
							tool.add_vertex(center+v*radius)
							letter_branch_vertices += 1
			for bud in row.buds:
				var item: Array = bud.points[0]
				var node := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = float(item[2])*_scale_for_wrap()
				sphere.height = sphere.radius*2.0
				sphere.radial_segments = 8
				sphere.rings = 4
				node.mesh = sphere
				node.material_override = gold if finish==1 else wood
				node.position = _map(_letter_point(item),sector)
				generated.add_child(node)
				organs.append({"node":node,"birth":float(item[3]),"size":1.0})
				glyph_nodes.append(node)
				letter_bud_count += 1
		tool.generate_normals()
		var node := MeshInstance3D.new()
		node.name = "ActualLetterBranches_%d" % sector
		node.mesh = tool.commit()
		var mat := ShaderMaterial.new()
		mat.shader = stroke_shader
		mat.set_shader_parameter("cast_gold",finish==1)
		node.material_override = mat
		generated.add_child(node)
		glyph_nodes.append(node)
		stems.append({"node":node,"material":mat,"birth":0.0,"duration":1.0})

func _join_letters_to_ornament() -> void:
	for row in guide_rows:
		for anchor in row.anchors:
			var a: Array = anchor.point
			var start := Vector3(a[0],a[1],0.40)
			var side: float = float(anchor.side)
			var gap: float = maxf(0.3,4.75-absf(start.x))
			for mirror_ in [-1.0,1.0]:
				var path := PackedVector3Array()
				for i in range(57):
					var t: float = float(i)/56.0
					var phase: float = t*TAU*1.5
					var envelope: float = sin(t*PI)
					path.append(Vector3(start.x+side*gap*t,start.y+sin(phase)*mirror_*0.20*envelope,0.40+cos(phase)*mirror_*0.12*envelope))
				var birth: float = minf(float(anchor.birth),0.76)
				_tube(path,0.021,birth,0.12)
				joining_flourishes += 1
				for leaf_index in range(3):
					var t: float = 0.30+float(leaf_index)*0.23
					var p: Vector3 = path[int(t*56.0)]
					_leaf(p,side*mirror_*(0.6+float(leaf_index)*0.35),birth+t*0.12+0.02,0.32+foliage_density*0.20)
				if mirror_>0:
					_rosette(path[34],0.09+foliage_density*0.035,birth+0.13)
		# Leaves originate on actual main letter strokes, with a density cap per line.
		var count: int = 0
		for path in row.paths:
			if not path.main or path.points.size()<6 or count>=int(2+foliage_density*3): continue
			if rng.randf()>0.23: continue
			var item: Array = path.points[int(path.points.size()/2)]
			var p: Vector3 = _letter_point(item)
			var shoot := PackedVector3Array()
			var sign_: float = -1.0 if count%2==0 else 1.0
			for i in range(17):
				var t: float = float(i)/16.0
				shoot.append(p+Vector3(sign_*0.07*sin(t*PI*0.7),0.15*t,0.09*t))
			var birth: float = float(item[3])+0.035
			_tube(shoot,0.009,birth,0.075)
			_leaf(shoot[16],sign_*0.6,birth+0.075,0.24+foliage_density*0.12)
			count += 1

func set_reference_visible(value: bool) -> void:
	reference_visible = value and wrap_mode==0
	_apply_growth()

func _apply_growth() -> void:
	super._apply_growth()
	for node in reference_nodes:
		if is_instance_valid(node): node.visible = reference_visible and wrap_mode==0
	for node in glyph_nodes:
		if is_instance_valid(node): node.visible = not reference_visible

func get_stats() -> Dictionary:
	var data: Dictionary = super.get_stats()
	data.merge({"letter_branch_paths":letter_path_count,"letter_branch_vertices":letter_branch_vertices,"letter_buds":letter_bud_count,"joining_flourishes":joining_flourishes,"wrap_mode":wrap_mode,"wrapped_copies":_copies(),"mirrored_ornament":true,"mirrored_text":false})
	return data
