@tool
extends RefCounted
## Back faces and boundary walls give cast leaves/petals a small physical thickness.
## This is a visual shell, not a welded manufacturing solid.
static func shell(mesh: ArrayMesh, thickness: float) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in range(vertices.size()): indices.append(i)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := {}
	for i in range(0,indices.size(),3):
		for sign_ in [1.0,-1.0]:
			for corner in ([0,1,2] if sign_ > 0 else [0,2,1]):
				var k: int = indices[i+corner]
				tool.set_normal(normals[k]*sign_)
				tool.set_uv(uvs[k])
				tool.add_vertex(vertices[k]+normals[k]*thickness*sign_*0.5)
		for edge in [Vector2i(0,1),Vector2i(1,2),Vector2i(2,0)]:
			var first: int = indices[i+edge.x]
			var last: int = indices[i+edge.y]
			var x := str(vertices[first].snapped(Vector3.ONE*0.00001))
			var y := str(vertices[last].snapped(Vector3.ONE*0.00001))
			var key := x+"/"+y if x < y else y+"/"+x
			if edges.has(key): edges[key].count += 1
			else: edges[key] = {"first":first,"last":last,"count":1}
	for edge in edges.values():
		if edge.count != 1: continue
		var first: int = edge.first
		var last: int = edge.last
		var pts := [vertices[first]+normals[first]*thickness*0.5,vertices[last]+normals[last]*thickness*0.5,vertices[last]-normals[last]*thickness*0.5,vertices[first]-normals[first]*thickness*0.5]
		var normal: Vector3 = (pts[1]-pts[0]).cross(pts[2]-pts[0]).normalized()
		for k in [0,1,2,0,2,3]:
			tool.set_normal(normal)
			tool.set_uv(Vector2(float(k%2),0.5))
			tool.add_vertex(pts[k])
	return tool.commit()
