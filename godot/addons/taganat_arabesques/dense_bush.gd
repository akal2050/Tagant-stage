@tool
extends RefCounted
## The mesh is a growth scaffold: shoots leave its surface and fill a real volume.
static func build(host) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(host.surface_guides))
	if not data is Dictionary: return
	var rng := RandomNumberGenerator.new()
	rng.seed = host.seed_value*7919
	var leaf_groups: Array = [[],[],[],[],[]]
	var flower_groups: Array = [[],[],[],[]]
	host.stem_tool = SurfaceTool.new()
	host.stem_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anchor_index := 0
	var step := 3 if host.bush_density < 1.0 else 2
	var forks := 3 if host.bush_density > 1.5 else 2
	for organ in data.organs:
		if organ.kind != "leaf": continue
		anchor_index += 1
		if anchor_index%step != 0: continue
		var origin := Vector3(float(organ.position[0]),float(organ.position[1]),float(organ.position[2]))
		var normal := Vector3(float(organ.normal[0]),float(organ.normal[1]),float(organ.normal[2])).normalized()
		var axis := Vector3(float(organ.tangent[0]),float(organ.tangent[1]),float(organ.tangent[2])).normalized()
		var across := axis.cross(normal).normalized()
		var profile: int = host.botanical_profile if host.botanical_profile >= 0 else (0 if anchor_index%3 == 0 else 3)
		var depth: float = host.bush_depth*rng.randf_range(0.65,1.15)
		var adaptive: bool = data.get("adaptive",false)
		var local_scale: float = clampf(float(organ.get("local_scale",1.0)),0.28,1.3)
		if adaptive:
			depth *= local_scale
		else:
			if origin.y < -1.0: depth *= 0.55
			if origin.x < -2.1 and origin.y > 0.7: depth *= 0.55
		var birth: float = float(organ.birth)
		for fork in range(forks):
			var angle := TAU*fork/float(forks)+rng.randf_range(-0.7,0.7)
			var side := across*cos(angle)+axis*sin(angle)
			var points := PackedVector3Array()
			for k in range(17):
				var t := float(k)/16.0
				points.append(origin+normal*depth*t+side*depth*(0.18*t+0.45*sin(t*PI/2.0))+Vector3.UP*depth*0.15*t*t)
			host.tube(points,0.014,birth,0.46,0.12,true)
			host.bush_shoots += 1
			host.bush_outward_reach = maxf(host.bush_outward_reach,(points[-1]-origin).dot(normal))
			for k in [4,7,10,13,16]:
				var tangent := (points[mini(k+1,16)]-points[maxi(k-1,0)]).normalized()
				for hand in [-1.0,1.0]:
					var aim: Vector3 = (tangent*0.35+side*hand*0.8+normal*0.25).normalized()
					var z: Vector3 = aim.cross(across).normalized()
					if z.length_squared() < 0.01: z = normal
					var x: Vector3 = aim.cross(z).normalized()
					z = x.cross(aim).normalized()
					var size_: float = rng.randf_range(0.40,0.66)*(local_scale if adaptive else (0.8 if origin.y < -1.0 else 1.0))
					leaf_groups[profile].append({"transform":Transform3D(Basis(x,aim,z).scaled(Vector3.ONE*size_),points[k]),"birth":birth+0.46*k/16.0})
			if host.ornamental_flowers and rng.randf() < 0.8:
				var up := (axis*0.3+normal).normalized()
				var x: Vector3 = up.cross(normal).normalized()
				if x.length_squared() < 0.01: x = across
				var y := normal.cross(x).normalized()
				var size_: float = rng.randf_range(0.24,0.40)
				flower_groups[rng.randi_range(0,3)].append({"transform":Transform3D(Basis(x,y,normal).scaled(Vector3.ONE*size_),points[-1]+normal*0.04),"birth":birth+0.55})
			host.growth_end = maxf(host.growth_end,birth+0.75)
	host.stem_tool.generate_normals()
	var woody := MeshInstance3D.new()
	woody.name = "VolumetricBushShoots"
	woody.mesh = host.stem_tool.commit()
	woody.material_override = host.stems
	host.plant.add_child(woody)
	var tones := [Color("42662d"),Color("326b32"),Color("38632b"),Color("2d5e32"),Color("596b34")]
	for i in range(5):
		if leaf_groups[i].is_empty(): continue
		var mat := instance_material(host,tones[i],true)
		batch(host,host.botany.leaves[i],leaf_groups[i],"BushLeaves",mat)
	for i in range(4):
		if flower_groups[i].is_empty(): continue
		var mesh: ArrayMesh = host.SurfaceGarden.flower_mesh(host,i)
		for surface in range(mesh.get_surface_count()):
			var old := mesh.surface_get_material(surface) as StandardMaterial3D
			mesh.surface_set_material(surface,instance_material(host,old.albedo_color,false))
		batch(host,mesh,flower_groups[i],"BushFlowers",null)

static func instance_material(host, color: Color, is_leaf: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/taganat_arabesques/instanced_flora.gdshader")
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("leaf",is_leaf)
	mat.set_shader_parameter("finish",host.finish)
	host.batch_materials.append(mat)
	return mat

static func batch(host, mesh: Mesh, entries: Array, name_: String, mat: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	var bounds := AABB(Vector3(-6,-4,-4),Vector3(12,9,8))
	multimesh.custom_aabb = bounds
	for i in range(entries.size()):
		multimesh.set_instance_transform(i,entries[i].transform)
		multimesh.set_instance_custom_data(i,Color(float(entries[i].birth),0,0,1))
	var node := MultiMeshInstance3D.new()
	node.name = name_
	node.multimesh = multimesh
	node.material_override = mat
	host.plant.add_child(node)
	host.foliage_instances += entries.size()
