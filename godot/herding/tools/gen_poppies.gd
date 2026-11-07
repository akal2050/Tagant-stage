extends SceneTree
## Scatters the poppy field where the Ait Wadu valley ground carries its poppy mask (UV2.x),
## writes data/poppies.bin: float32 x,y,z,nx,ny,nz per flower (world metres).
const N := 90000
func _initialize() -> void:
	var s: Node3D = load("res://herding/assets/world/terrain.glb").instantiate()
	root.add_child(s)
	var mi: MeshInstance3D = s.find_child("VALLEY_TERRAIN", true, false)
	var xf := mi.global_transform
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv2 = arr[Mesh.ARRAY_TEX_UV2]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	print("verts ", v.size(), " tris ", idx.size() / 3, " uv2 ", uv2 != null)
	var tris := []
	var area := []
	var tot := 0.0
	var bb := AABB()
	var first := true
	for t in range(0, idx.size(), 3):
		var a := idx[t]; var b := idx[t + 1]; var c := idx[t + 2]
		var p: float = (uv2[a].x + uv2[b].x + uv2[c].x) / 3.0
		if p < 0.35:
			continue
		var A := xf * v[a]; var B := xf * v[b]; var C := xf * v[c]
		var ar: float = (B - A).cross(C - A).length() * 0.5 * p
		tot += ar
		tris.append([A, B, C, xf.basis * nrm[a]])
		area.append(tot)
		if first: bb = AABB(A, Vector3.ZERO); first = false
		bb = bb.expand(A)
	print("poppy tris ", tris.size(), " area ", tot, " bounds ", bb)
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in N:
		var r := rng.randf() * tot
		var k := area.bsearch(r)
		k = clampi(k, 0, tris.size() - 1)
		var T: Array = tris[k]
		var u := rng.randf(); var w := rng.randf()
		if u + w > 1.0: u = 1.0 - u; w = 1.0 - w
		var P: Vector3 = T[0] + (T[1] - T[0]) * u + (T[2] - T[0]) * w
		var Nn: Vector3 = (T[3] as Vector3).normalized()
		out.append_array([P.x, P.y, P.z, Nn.x, Nn.y, Nn.z])
	var f := FileAccess.open("res://herding/data/poppies.bin", FileAccess.WRITE)
	f.store_buffer(out.to_byte_array())
	f.close()
	print("wrote ", N)
	quit()
