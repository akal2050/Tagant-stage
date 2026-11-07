@tool
extends RefCounted
## Four mirrored planted quarters in a 7 m square; one Godot unit = one metre.

static func build(host) -> void:
	host.stem_tool = SurfaceTool.new()
	host.stem_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	host.square_paths.clear()
	var quarter := 0
	for sx in [-1.0,1.0]:
		for sy in [-1.0,1.0]:
			host.rng.seed = host.seed_value*1009+quarter*31
			for handed in [-1.0,1.0]:
				host.current_species = host.botanical_profile if host.botanical_profile >= 0 else (quarter+(2 if handed > 0 else 0)+host.seed_value)%5
				var path := PackedVector3Array()
				var canonical := PackedVector3Array()
				var start := Vector3(0.58,0.58,0)
				var end := Vector3(2.65,2.65,0)
				var normal := Vector3(-1,1,0).normalized()
				for j in range(81):
					var u := float(j)/80.0
					var p: Vector3 = start.lerp(end,u)+normal*handed*0.34*sin(u*TAU*1.5)*sin(u*PI)
					p.z = 0.20+handed*0.075*cos(u*TAU*1.5)+0.10*sin(u*PI)
					canonical.append(p)
					path.append(reflect(p,sx,sy))
				host.square_paths.append(path)
				host.tube(path,0.040,0.0,2.1,0.50)
				var root := PackedVector3Array()
				for j in range(12):
					var u := float(j)/11.0
					root.append(path[0]+Vector3(-sx*0.09*(1.0-u),-sy*0.04*(1.0-u),-(1.0-u)*(path[0].z-0.05)))
				host.tube(root,0.032,0.0,0.10,0.85)
				for j in [14,24,34,44,54,64]:
					host.add_leaf(path[j],(path[j+1]-path[j-1]).normalized(),handed*sx*sy,float(j)/80.0*2.1,0.40)
				var nodes: Array = [40] if host.complexity == 1 else ([24,56] if host.complexity == 2 else [18,36,54,68])
				for node in nodes:
					var origin: Vector3 = canonical[node]
					var dir: Vector3 = (canonical[node+1]-canonical[node-1]).normalized()
					dir.z = 0
					dir = dir.normalized()
					var outward: float = handed*signf(sin(float(node)/80.0*TAU*1.5))
					var across: Vector3 = Vector3(-dir.y,dir.x,0)*outward
					var radius: float = 0.23+0.04*host.rng.randf()
					if node == 18: radius = 0.36+0.03*host.rng.randf()
					if node == 36 or node == 40: radius = 0.49+0.03*host.rng.randf()
					if node == 68: radius = 0.17+0.03*host.rng.randf()
					var turns: float = 1.0+0.12*host.complexity+0.04*sin(host.seed_value)
					var branch := PackedVector3Array()
					for j in range(49):
						var u := float(j)/48.0
						var phase := u*TAU*turns
						var r := lerpf(radius,0.03,u)
						var p: Vector3 = origin+dir*r*sin(phase)+across*(radius-r*cos(phase))+Vector3(0,0,0.28*sin(u*PI/2.0))
						branch.append(reflect(p,sx,sy))
					var birth: float = float(node)/80.0*2.1
					host.tube(branch,0.023,birth,0.55)
					for j in ([8,16,24,32,40] if radius > 0.4 else [12,28,40]):
						host.add_leaf(branch[j],(branch[j+1]-branch[j-1]).normalized(),-handed*sx*sy,birth+j/48.0*0.55,0.34)
					host.add_flower(branch[-1],birth+0.59,0.44)
					if node == 36 or node == 40 or node == 56:
						host.add_fruit(branch[-1]+Vector3(0,0,0.16),birth+0.78,0.57)
					host.add_leaf(branch[-1],Vector3(sx,sy,0).normalized(),handed*sx*sy,birth+0.58,0.33)
					if host.complexity == 3 and node == 36:
						host.branch_scroll(branch[24],(branch[25]-branch[23]).normalized(),handed*sx*sy,birth+0.30,0.16,1.1)
				host.add_flower(path[-1],2.18,0.44)
				host.add_fruit(path[62]+Vector3(0,0,0.26),2.28,0.52)
			if host.ornamental_flowers:
				for corner in [Vector2(0.72,2.70),Vector2(2.70,0.72),Vector2(1.24,2.46),Vector2(2.46,1.24)]:
					var root := reflect(Vector3(corner.x,corner.y,0.05),sx,sy)
					var scape := PackedVector3Array()
					for j in range(12):
						var u := float(j)/11.0
						scape.append(root+Vector3(0.04*sx*sin(u*PI),0.03*sy*u,0.24*u))
					host.tube(scape,0.010,0.8,0.7)
					host.add_ornamental_flower(scape[-1],1.55,0.34)
			quarter += 1
	host.stem_tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = host.stem_tool.commit()
	mesh.material_override = host.stems
	host.plant.add_child(mesh)
	host.tile_count = 4

static func reflect(pos: Vector3, sx: float, sy: float) -> Vector3:
	return Vector3(pos.x*sx,pos.y*sy,pos.z)


