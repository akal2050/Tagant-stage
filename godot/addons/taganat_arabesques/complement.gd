@tool
extends RefCounted
## Gap-seeking branches attach to an existing parent, never a duplicated full pattern.
static func build(host) -> void:
	host.collecting_paths = false
	host.stem_tool = SurfaceTool.new()
	host.stem_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples: Array[Dictionary] = []
	for path in host.source_paths:
		var pts: PackedVector3Array = path.points
		for j in range(0,pts.size(),6):
			samples.append({"p":pts[j],"course":path.course,"half":path.half})
	var stride := 3 if host.infill_density < 0.5 else 2
	for index in range(0,host.source_paths.size(),stride):
		var path: Dictionary = host.source_paths[index]
		var pts: PackedVector3Array = path.points
		if pts.size() < 35: continue
		var j := int(pts.size()*0.53)
		var origin: Vector3 = pts[j]
		var tangent := (pts[j+1]-pts[j-1]).normalized()
		var normal := Vector3(-tangent.y,tangent.x,0).normalized()
		var best := Vector3.ZERO
		var clearance := 0.0
		# Deterministic candidate selection lets the small network occupy negative space.
		for side in [-1.0,1.0]:
			for reach in [0.30,0.48,0.66]:
				var target: Vector3 = origin+normal*side*reach+tangent*0.16
				if (host.shamsa_garden or host.spherical) and Vector2(target.x,target.y).length() > 2.88: continue
				var gap := 10.0
				for sample in samples:
					if sample.course != path.course or sample.half != path.half: continue
					var delta: Vector3 = sample.p-target
					gap = minf(gap,Vector2(delta.x,delta.y).length())
				if gap > clearance:
					clearance = gap
					best = target
		if clearance < 0.14: continue
		host.cylinder_course = path.course
		host.hemisphere = path.half
		host.current_species = path.species
		var birth: float = path.birth+path.duration*float(j)/float(pts.size()-1)
		var duration := 0.62 if host.shamsa_garden or host.spherical else 0.22
		var radius := minf(0.16,clearance*0.38)
		var dir := (best-origin).normalized()
		var perpendicular := Vector3(-dir.y,dir.x,0)
		var branch := PackedVector3Array()
		for k in range(49):
			var u := float(k)/48.0
			var q: Vector3
			if u < 0.65:
				var t := u/0.65
				q = origin.lerp(best,t)+perpendicular*sin(t*PI)*radius
			else:
				var t := (u-0.65)/0.35
				var angle := t*TAU*1.1
				var r := radius*(1.0-t)
				q = best+dir*r*sin(angle)+perpendicular*(radius-r*cos(angle))
			q.z += 0.10*sin(u*PI)
			branch.append(q)
		host.tube(branch,0.017,birth,duration,0.12)
		for k in [16,28,39]:
			host.add_leaf(branch[k],(branch[k+1]-branch[k-1]).normalized(),-1.0 if k%2 == 0 else 1.0,birth+duration*k/48.0,minf(0.30,clearance*0.8))
		if host.ornamental_flowers:
			host.add_ornamental_flower(branch[-1],birth+duration+0.04,minf(0.30,clearance*0.75))
		host.infill_count += 1
		for k in range(8,49,6): samples.append({"p":branch[k],"course":path.course,"half":path.half})
	if host.infill_count > 0:
		host.stem_tool.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = "ComplementaryBranches"
		mesh.mesh = host.stem_tool.commit()
		mesh.material_override = host.stems
		host.plant.add_child(mesh)
