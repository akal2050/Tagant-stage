@tool
extends RefCounted
## Render guides baked by tools/generate_surface_garden.py. Geometry remains local
## to the component; source model, camera and materials belong to the demo world.
static func vec(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[1]),float(values[2]))

static func build(host) -> void:
	if host.surface_guides.is_empty() or not FileAccess.file_exists(host.surface_guides):
		push_warning("Select a surface guide JSON for the SURFACE layout.")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(host.surface_guides))
	if not data is Dictionary or data.get("format",0) != 1:
		push_error("Invalid botanical surface guide format.")
		return
	host.collecting_paths = false
	host.stem_tool = SurfaceTool.new()
	host.stem_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var variant: int = host.motif_variant
	var path_index := -1
	var active_paths := {}
	for path in data.paths:
		path_index += 1
		var is_runner: bool = path.get("runner",float(path.radius) > 0.025)
		if int(path.layer) == 1:
			if not host.complementary_layer: continue
			if host.infill_density < 0.5 and path_index%2 == 0: continue
			if host.complexity == 2 and path_index%3 == 0: continue
		if variant == 1 and int(path.layer) == 0 and not is_runner and path_index%3 != 0: continue
		if host.complexity == 1 and path_index%2 == 0 and not is_runner: continue
		if int(path.layer) == 1 and not active_paths.has(int(path.get("parent",path_index-1))): continue
		active_paths[path_index] = true
		var points: Array = path.points
		var count := points.size()
		if int(path.layer) == 1: host.infill_count += 1
		for i in range(count-1):
			for j in range(8):
				for corner in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
					var k: int = corner.x
					var t := float(k)/float(count-1)
					var tangent := (vec(points[mini(k+1,count-1)])-vec(points[maxi(k-1,0)])).normalized()
					var normal := vec(path.normals[k]).normalized()
					var across := tangent.cross(normal).normalized()
					if across.length_squared() < 0.01: across = tangent.cross(Vector3.RIGHT).normalized()
					var up := tangent.cross(across).normalized()
					var angle: float = TAU*corner.y/8.0
					var radius: float = float(path.radius)*lerpf(1.0,0.2,t)*(1.0+0.06*sin(float(host.seed_value)+path_index))
					if is_runner: radius = float(path.radius)
					if host.finish > 0: radius *= 1.4
					host.stem_tool.set_uv(Vector2(float(path.birth)+t*float(path.duration),angle/TAU))
					host.stem_tool.set_color(Color.WHITE)
					host.stem_tool.add_vertex(vec(points[k])+radius*(across*cos(angle)+up*sin(angle)))
			host.mesh_vertices += 48
		host.growth_end = maxf(host.growth_end,float(path.birth)+float(path.duration))
	host.stem_tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "SurfaceFollowingWood"
	mesh.mesh = host.stem_tool.commit()
	mesh.material_override = host.stems
	host.plant.add_child(mesh)
	var flowers: Array[ArrayMesh] = []
	for palette in range(4): flowers.append(flower_mesh(host,palette))
	var index := 0
	for organ in data.organs:
		index += 1
		var is_leaf: bool = organ.kind == "leaf"
		if variant == 1 and index%3 != 0: continue
		if host.complexity == 1 and index%2 == 0: continue
		if int(organ.get("path",-1)) >= 0 and not active_paths.has(int(organ.path)): continue
		var normal := vec(organ.normal).normalized()
		var up := vec(organ.tangent).normalized()
		var right := up.cross(normal).normalized()
		up = normal.cross(right).normalized()
		host.organ_frame = Basis(right,up,normal)
		var pos := vec(organ.position)
		var birth: float = organ.birth
		var size_: float = organ.size
		host.current_species = host.botanical_profile if host.botanical_profile >= 0 else posmod(int(organ.patch)+host.seed_value,4)
		if variant == 1: host.current_species = 0 if index%2 == 0 else 1
		if is_leaf:
			host.add_leaf(pos,Vector3.UP,-1.0 if index%2 == 0 else 1.0,birth,size_*(0.8 if variant == 2 else 1.0))
		elif host.ornamental_flowers:
			var flower := MeshInstance3D.new()
			flower.mesh = flowers[posmod(index+host.seed_value,4)]
			host.place_organ(flower,pos)
			host.plant.add_child(flower)
			host.organs.append({"node":flower,"birth":birth,"size":size_*(1.55 if variant == 2 else 1.0)})
		else:
			host.add_flower(pos-Vector3(0,0,0.10),birth,size_)
	host.tile_count = data.patches.size()


static func flower_mesh(host, palette: int) -> ArrayMesh:
	# Shared three-surface flower meshes keep the dense mantle practical to render.
	var result := ArrayMesh.new()
	for tier in range(2):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(host.flower_materials[palette] if tier == 0 else host.flower_materials[1])
		for i in range(8):
			var rotation_ := Vector3(-0.18-tier*0.25,0,TAU*i/8.0+tier*PI/8.0)
			var frame := Basis.from_euler(rotation_).scaled(Vector3.ONE*(1.0-tier*0.35))
			tool.append_from(host.petal_mesh,0,Transform3D(frame,Vector3(0,0,tier*0.1)))
		tool.commit(result)
	var center := SphereMesh.new()
	center.radius = 0.12
	center.height = 0.24
	center.radial_segments = 8
	center.rings = 4
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(host.gold_mat)
	tool.append_from(center,0,Transform3D(Basis.IDENTITY,Vector3(0,0,0.22)))
	tool.commit(result)
	return result
