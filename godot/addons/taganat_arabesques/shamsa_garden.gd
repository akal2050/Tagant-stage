@tool
extends RefCounted
## A half-sector is reflected, then rotated; all output is genuine 3D plant mesh.

static func build(host) -> void:
	host.stem_tool = SurfaceTool.new()
	host.stem_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	host.shamsa_paths.clear()
	var lobes: int = host.shamsa_lobes
	var tangent_scale := tan(PI/lobes)/tan(PI/8.0)
	var foliage_scale := sqrt(8.0/lobes)
	var pairs := [[3,0],[1,2],[3,4],[0,1]]
	var pair: Array = pairs[posmod(host.seed_value-34,4)]
	# Interwoven inner woody runners. Their height order alternates at crossings.
	for handed in [-1.0,1.0]:
		var ring := PackedVector3Array()
		for j in range(lobes*24+1):
			var angle := TAU*float(j)/float(lobes*24)
			var radius: float = 0.85+handed*0.075*sin(lobes*angle)
			ring.append(Vector3(radius*sin(angle),radius*cos(angle),0.25+handed*0.085*cos(lobes*angle)))
		host.tube(ring,0.040,0.58,0.70,1.0)
	for sector in range(lobes):
		var angle := TAU*float(sector)/lobes
		host.current_species = host.botanical_profile if host.botanical_profile >= 0 else int(pair[sector%2])
		for handed in [-1.0,1.0]:
			# Mirrored instances share the same structural seed; foliage remains organic.
			host.rng.seed = host.seed_value*1009+sector*37+int(handed+1)
			var canonical := PackedVector3Array()
			var path := PackedVector3Array()
			for j in range(97):
				var t := float(j)/96.0
				var p: Vector3
				if t <= 0.5:
					p = bezier(Vector3(0,0.85,0.25),Vector3(0.25,1.18,0.40),Vector3(0.64,1.52,0.68),Vector3(0.52,1.94,0.73),t*2.0)
				else:
					p = bezier(Vector3(0.52,1.94,0.73),Vector3(0.46,2.50,0.98),Vector3(0.13,2.65,0.78),Vector3(0,3.0,0.56),(t-0.5)*2.0)
				canonical.append(p)
				path.append(transform_point(p,handed,angle,tangent_scale))
			host.shamsa_paths.append(path)
			host.tube(path,0.048,0.65,2.00,0.24)
			for j in ([20,44,68] if host.complexity == 1 else [16,28,40,52,64,76]):
				host.add_leaf(path[j],(path[j+1]-path[j-1]).normalized(),handed,0.65+float(j)/96.0*2.0,0.34*foliage_scale)
			var nodes: Array = [44] if host.complexity == 1 else ([30,60] if host.complexity == 2 else [22,44,66])
			for node in nodes:
				var origin: Vector3 = canonical[node]
				var dir: Vector3 = (canonical[node+1]-canonical[node-1]).normalized()
				dir.z = 0
				dir = dir.normalized()
				var normal := Vector3(-dir.y,dir.x,0)
				if node == 66: normal *= -1.0
				var radius: float = 0.17 if node == 22 else 0.24
				var turns: float = 1.10+0.06*host.complexity+0.045*sin(host.seed_value)
				var branch := PackedVector3Array()
				for j in range(49):
					var u := float(j)/48.0
					var theta := u*TAU*turns
					var r := lerpf(radius,0.025,u)
					var p := origin+dir*r*sin(theta)+normal*(radius-r*cos(theta))+Vector3(0,0,0.15*sin(u*PI))
					branch.append(transform_point(p,handed,angle,tangent_scale))
				var birth: float = 0.65+float(node)/96.0*2.0
				host.tube(branch,0.023,birth,0.55)
				for j in [12,27,40]:
					host.add_leaf(branch[j],(branch[j+1]-branch[j-1]).normalized(),-handed,birth+j/48.0*0.55,0.30*foliage_scale)
				host.add_flower(branch[-1],birth+0.59,0.48*foliage_scale)
				if node == 44 or node == 60:
					host.add_fruit(branch[30]+Vector3(0,0,0.15),birth+0.77,0.64*foliage_scale)
				if host.complexity == 3 and node == 44:
					# Nested scroll geometry stays in the authored half-sector before mirroring.
					var sub := PackedVector3Array()
					for j in range(33):
						var u := float(j)/32.0
						var a := u*TAU
						var r := lerpf(0.095,0.012,u)
						var base := origin+normal*0.18
						sub.append(transform_point(base+dir*r*sin(a)+normal*(0.095-r*cos(a))+Vector3(0,0,0.12),handed,angle,tangent_scale))
					host.tube(sub,0.013,birth+0.30,0.30)
		# Rooted spokes connect the seed crown with the interwoven inner runners.
		var root := PackedVector3Array()
		for j in range(25):
			var u := float(j)/24.0
			root.append(transform_point(Vector3(0,lerpf(0.22,0.85,u),0.04+0.21*u),1.0,angle,1.0))
		host.tube(root,0.052,0.0,0.58,0.75)
		# One botanical tip per complete sector, avoiding duplicate mirror-axis blossoms.
		var tip := transform_point(Vector3(0,3.0,0.56),1.0,angle,1.0)
		if not host.spherical or host.hemisphere == 0:
			host.add_flower(tip,2.72,0.64*foliage_scale)
			host.add_leaf(tip,transform_point(Vector3(0,1,0),1.0,angle,1.0),1.0,2.70,0.34*foliage_scale)
		if host.ornamental_flowers:
			host.add_ornamental_flower(transform_point(Vector3(0,1.12,0.37),1.0,angle,1.0),1.30,0.30*foliage_scale)
			if not host.spherical or host.hemisphere == 0:
				host.add_ornamental_flower(tip+Vector3(0,0,0.10),2.78,0.40*foliage_scale)
	# A living scalloped outer runner joins adjacent sectors, rather than a flat border.
	if host.complexity >= 2:
		var rim := PackedVector3Array()
		for j in range(lobes*32+1):
			var angle := TAU*float(j)/float(lobes*32)
			var pulse := pow((1.0+cos(lobes*angle))/2.0,2.0)
			var radius: float = 2.62+0.30*pulse
			rim.append(Vector3(radius*sin(angle),radius*cos(angle),0.56+0.06*sin(lobes*angle)))
		host.tube(rim,0.026,2.67,0.53,1.0)
	if host.ornamental_flowers:
		host.add_ornamental_flower(Vector3(0,0,0.18),0.02,0.72)
	if host.spherical:
		# At radius 3, both charts meet on the same equator. Endpoints coincide.
		var equator := PackedVector3Array()
		for j in range(lobes*24+1):
			var angle := TAU*j/float(lobes*24)
			equator.append(Vector3(3.0*sin(angle),3.0*cos(angle),0.56))
		# Emit the shared equator once, avoiding duplicate coincident geometry.
		if host.hemisphere == 0:
			host.tube(equator,0.022,2.72,0.42,1.0)
			if host.complementary_layer:
				# A fine connecting garland occupies the open equatorial band.
				for handed in [-1.0,1.0]:
					var garland := PackedVector3Array()
					for j in range(lobes*32+1):
						var angle := TAU*j/float(lobes*32)
						var r: float = 3.0+handed*0.20*sin(lobes*angle)
						garland.append(Vector3(r*sin(angle),r*cos(angle),0.68+handed*0.09*cos(lobes*angle)))
					host.tube(garland,0.018,2.78,0.65,1.0)
					for j in range(8,garland.size()-1,16):
						host.add_leaf(garland[j],(garland[j+1]-garland[j-1]).normalized(),handed,2.78+0.65*j/float(garland.size()-1),0.35)
						if j%32 == 8 and host.ornamental_flowers:
							host.add_ornamental_flower(garland[j],3.48,0.23)
	host.stem_tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = host.stem_tool.commit()
	mesh.material_override = host.stems
	host.plant.add_child(mesh)
	host.tile_count = lobes

static func transform_point(pos: Vector3, handed: float, angle: float, tangent_scale: float) -> Vector3:
	return Vector3(pos.x*handed*tangent_scale,pos.y,pos.z).rotated(Vector3.BACK,angle)

static func bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var v := 1.0-t
	return a*v*v*v+b*3.0*v*v*t+c*3.0*v*t*t+d*t*t*t



