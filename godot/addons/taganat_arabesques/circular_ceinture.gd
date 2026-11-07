extends "res://addons/taganat_arabesques/calligraphy.gd"
@export var repeats: int = 6
@export_enum("DecoType Thuluth", "Diwani Bent", "Diwani Letter", "Amiri", "Bouazzi Maghribi") var font_style: int = 0
var active_font: String = ""
var font_warning: String = ""
@export var upright_height: float = 1.1
@export var leafy: bool = false
@export_enum("Calligraphy only","From letter strokes","Woven floral overlay","Both botanical layers") var botanical_mode: int = 1
@export_range(0.5,1.5,0.25) var foliage_richness: float = 1.0
var letter_shoots: int = 0
var overlay_paths: int = 0
var attachment_error: float = 0.0
@export var tier_step: float = 0.85
@export var radius: float = 3.6
var phrase: String = "لا غالب إلا الله"
var mesh_count: int = 0

func regenerate() -> void:
	if is_instance_valid(generated):
		remove_child(generated)
		generated.queue_free()
	generated = Node3D.new()
	add_child(generated)
	stems.clear()
	organs.clear()
	lettering.clear()
	verse_texts.assign([phrase])
	full_mesh_vertices = 0
	mesh_count = 0
	letter_shoots = 0
	overlay_paths = 0
	attachment_error = 0.0
	rng.seed = variation
	gold = material(Color("d4ab61"),0.9)
	wood = material(Color("966a41"))
	leaf_mat = material(Color("326449"))
	ivory = material(Color("efddbb"))
	red = material(Color("a93645"))
	leaf_mesh = _blade()
	font = _selected_font()
	var text_mesh := TextMesh.new()
	text_mesh.font = font
	text_mesh.font_size = 180
	text_mesh.pixel_size = 0.01
	text_mesh.depth = 0.10
	text_mesh.curve_step = 0.22
	text_mesh.text_direction = TextServer.DIRECTION_RTL
	text_mesh.language = "ar"
	text_mesh.text = phrase
	var box: AABB = text_mesh.get_aabb()
	var faces: PackedVector3Array = text_mesh.get_faces()
	# Staggered bands retain joined Arabic shaping and complete phrase order.
	for tier in range(2):
		for repeat_index in range(repeats):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p in faces:
				var u: float = (p.x-box.position.x)/box.size.x
				var v: float = (p.y-box.position.y)/box.size.y
				# Upper space stretches independently to emphasize the vertical scaffold.
				var fitted_y: float = v if v<0.48 else 0.48+(v-0.48)*upright_height
				fitted_y /= 0.48+0.52*upright_height
				var angle: float = (float(repeat_index)+u*0.96+float(tier)*0.5)*TAU/float(repeats)
				var y: float = 2.8+float(tier)*tier_step+fitted_y*(3.55-tier_step)
				# Alternate depth between upright/return strokes and between tiers.
				var relief: float = 0.09*sin(u*TAU*2.0+float(tier)*PI)
				var r: float = radius+p.z+relief+float(tier)*0.045
				var birth: float = 0.04+float(repeat_index)*0.018+float(tier)*0.15+((1.0-u)*0.48+v*0.22)
				tool.set_uv(Vector2(u,birth))
				tool.add_vertex(Vector3(sin(angle)*r,y,cos(angle)*r))
			tool.index()
			tool.generate_normals()
			var item := MeshInstance3D.new()
			item.name = "JoinedPhrase_%d_%d" % [tier,repeat_index]
			item.mesh = tool.commit()
			var mat := ShaderMaterial.new()
			mat.shader = load("res://addons/taganat_arabesques/ceinture_stroke.gdshader")
			mat.set_shader_parameter("cast_gold",finish==1)
			item.material_override = mat
			generated.add_child(item)
			stems.append({"node":item,"material":mat,"birth":0.0,"duration":1.0})
			mesh_count += 1
			full_mesh_vertices += faces.size()
			if botanical_mode==1 or botanical_mode==3:
				_letter_garden(faces,box,tier,repeat_index)
	if botanical_mode==2 or botanical_mode==3:
		_floral_overlay()
	for y in [2.63,6.62]:
		var ring := PackedVector3Array()
		for j in range(257):
			var a: float = float(j)*TAU/256.0
			ring.append(Vector3(sin(a)*radius,y,cos(a)*radius))
		_tube(ring,0.04,0.0,0.8)
	_apply_growth()

func get_stats() -> Dictionary:
	var stats: Dictionary = super.get_stats()
	stats.merge({"phrase":phrase,"shaped_phrase_meshes":mesh_count,"font":active_font,"font_warning":font_warning,"upright_height":upright_height,"leafy":botanical_mode>0,"botanical_mode":botanical_mode,"letter_shoots":letter_shoots,"overlay_paths":overlay_paths,"attachment_error":attachment_error})
	return stats

func _selected_font() -> Font:
	font_warning = ""
	if font_style==1:
		font_style=2
		font_warning = "Diwani Bent outlines unsupported; using Diwani Letter."
	var names := ["DecoType Thuluth","Diwani Bent","Diwani Letter","Amiri","Bouazzi Maghribi"]
	var paths := ["C:/Windows/Fonts/DTHULUTH.TTF","C:/Windows/Fonts/DIWANBNT.TTF","C:/Windows/Fonts/DIWANLTR.TTF","res://assets/calligraphy/Amiri-Regular.ttf",font_path]
	active_font = names[font_style]
	if font_style<3:
		var local_font := FontFile.new()
		var error: Error = local_font.load_dynamic_font(paths[font_style])
		if error==OK:
			var missing: String = ""
			for character in phrase:
				if character!=" " and not local_font.has_char(character.unicode_at(0)): missing += character
			if missing.is_empty():
				local_font.fallbacks = [load("res://assets/calligraphy/Amiri-Regular.ttf")]
				return local_font
			font_warning = "Missing characters: "+missing
		else:
			font_warning = "Local font unavailable; using Amiri."
		active_font = "Amiri (fallback)"
		return load("res://assets/calligraphy/Amiri-Regular.ttf")
	return load(paths[font_style])

func _letter_surface(u: float, v: float, z: float, tier: int, repeat_index: int) -> Vector3:
	var fitted_y: float = v if v<0.48 else 0.48+(v-0.48)*upright_height
	fitted_y /= 0.48+0.52*upright_height
	var angle: float = (float(repeat_index)+u*0.96+float(tier)*0.5)*TAU/float(repeats)
	var y: float = 2.8+float(tier)*tier_step+fitted_y*(3.55-tier_step)
	var r: float = radius+z+0.09*sin(u*TAU*2.0+float(tier)*PI)+float(tier)*0.045
	return Vector3(sin(angle)*r,y,cos(angle)*r)

func _letter_garden(faces: PackedVector3Array, bounds: AABB, tier: int, repeat_index: int) -> void:
	# Find actual front-face vertices near chosen positions in the shaped phrase.
	# Each shoot's first point coincides with a real letter surface vertex.
	for anchor_index in range(3):
		var target_uv := Vector2(0.18+float(anchor_index)*0.31,0.3+float(anchor_index%2)*0.3)
		var best: float = INF
		var anchor := Vector3.ZERO
		var uv := Vector2.ZERO
		for p in faces:
			if absf(p.z-bounds.end.z)>0.0001: continue
			var candidate := Vector2((p.x-bounds.position.x)/bounds.size.x,(p.y-bounds.position.y)/bounds.size.y)
			var score: float = candidate.distance_squared_to(target_uv)
			if score<best:
				best=score
				anchor=p
				uv=candidate
		var origin: Vector3 = _letter_surface(uv.x,uv.y,anchor.z,tier,repeat_index)
		var angle: float = atan2(origin.x,origin.z)
		var sign_: float = -1.0 if (anchor_index+tier)%2==0 else 1.0
		var birth: float = 0.04+float(repeat_index)*0.018+float(tier)*0.15+((1.0-uv.x)*0.48+uv.y*0.22)
		var path := PackedVector3Array()
		var curl_scale: float = 0.85+rng.randf()*0.18
		for j in range(65):
			var t: float = float(j)/64.0
			var phase: float = t*TAU*1.1
			var dx: float = sign_*curl_scale*sin(phase)*(1.0-t*0.6)
			var dy: float = curl_scale*(1.0-cos(phase))*(1.0-t*0.55)
			var a: float = angle+dx/radius
			var r: float = Vector2(origin.x,origin.z).length()+0.10*sin(t*TAU*2.0)
			path.append(Vector3(sin(a)*r,clampf(origin.y+dy,2.8,6.38),cos(a)*r))
		path[0]=origin
		attachment_error=maxf(attachment_error,path[0].distance_to(origin))
		_tube(path,0.026,birth+0.025,0.19)
		letter_shoots+=1
		var count: int = int(8*foliage_richness)
		for j in range(count):
			var t: float = float(j+1)/float(count+1)
			var index: int = int(t*64.0)
			_leaf(path[index],sign_*(0.65 if j%2==0 else -0.65),birth+0.025+t*0.19,0.68+rng.randf()*0.25)
		_rosette(path[54],0.17+rng.randf()*0.05,birth+0.22)

func _floral_overlay() -> void:
	for strand in range(2):
		var path := PackedVector3Array()
		for j in range(721):
			var t: float = float(j)/720.0
			var a: float = t*TAU
			var phase: float = a*float(repeats)+float(strand)*PI
			var r: float = radius+0.14+0.20*cos(phase)
			path.append(Vector3(sin(a)*r,4.65+1.20*sin(phase),cos(a)*r))
		_tube(path,0.034,0.16+float(strand)*0.09,0.58)
		overlay_paths+=1
		var count: int = int(float(repeats)*18.0*foliage_richness)
		for j in range(count):
			var t: float = float(j)/float(count)
			var index: int = int(t*720.0)
			_leaf(path[index],0.85 if j%2==0 else -0.85,0.20+float(strand)*0.09+t*0.58,0.78)
		for j in range(repeats*2):
			var index: int = int((float(j)+0.28)/float(repeats*2)*720.0)
			_rosette(path[index],0.23,0.26+float(strand)*0.09+float(index)/720.0*0.58)

func _surface_frame(position_: Vector3) -> Basis:
	var angle: float = atan2(position_.x,position_.z)
	return Basis(Vector3(cos(angle),0,-sin(angle)),Vector3.UP,Vector3(sin(angle),0,cos(angle)))

func _leaf(position_: Vector3, angle: float, birth: float, size_: float = 1.0) -> void:
	super._leaf(position_,angle,birth,size_)
	var node: Node3D = organs.back().node
	node.basis = _surface_frame(position_)*Basis(Vector3.BACK,angle)

func _rosette(position_: Vector3, size_: float, birth: float) -> void:
	super._rosette(position_,size_,birth)
	var node: Node3D = organs.back().node
	node.basis = _surface_frame(position_)
