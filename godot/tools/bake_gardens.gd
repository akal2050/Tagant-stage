extends SceneTree
## Bakes Taganat Arabesques gardens into light, phone-ready scenes:
## every MeshInstance of a generated garden is merged per material, indexed (the library writes
## un-indexed triangles), given automatic LODs, and saved as res://gardens/<name>.scn.
## Run:  godot --headless --path . -s res://tools/bake_gardens.gd
const A = preload("res://addons/taganat_arabesques/arabesque.gd")

# name, layout, profile, lobes, seed, complexity
const VARIANTS := [
	["shamsa_olive", A.Layout.SHAMSA, 0, 7, 11, 2],
	["shamsa_vine", A.Layout.SHAMSA, 1, 7, 12, 2],
	["shamsa_fig", A.Layout.SHAMSA, 2, 7, 13, 2],
	["shamsa_pomegranate", A.Layout.SHAMSA, 3, 7, 14, 2],
	["shamsa_palm", A.Layout.SHAMSA, 4, 7, 15, 2],
	["shamsa_mixed_a", A.Layout.SHAMSA, -1, 7, 16, 2],
	["shamsa_mixed_b", A.Layout.SHAMSA, -1, 5, 17, 2],
	["column_olive", A.Layout.CYLINDER, 0, 7, 21, 1],
	["column_pomegranate", A.Layout.CYLINDER, 3, 7, 22, 1],
	["column_palm", A.Layout.CYLINDER, 4, 7, 23, 1],
	["sphere_olive", A.Layout.SPHERE, 0, 7, 31, 1],
	["sphere_pomegranate", A.Layout.SPHERE, 3, 5, 32, 1],
]

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://gardens")
	var only := OS.get_environment("BAKE_ONLY")
	for v in VARIANTS:
		if only != "" and v[0] != only:
			continue
		var t0 := Time.get_ticks_msec()
		var g = A.new()
		g.layout = v[1]; g.botanical_profile = v[2]; g.shamsa_lobes = v[3]; g.seed_value = v[4]; g.complexity = v[5]
		g.complementary_layer = v[1] != A.Layout.SPHERE
		g.sphere_radius = 1.6
		g.ornamental_flowers = true
		root.add_child(g)
		var groups := {}      # material -> SurfaceTool
		var base_inv: Transform3D = g.global_transform.affine_inverse()
		var verts_in := 0
		for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var xf: Transform3D = base_inv * mi.global_transform
			for s in mi.mesh.get_surface_count():
				var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(s)
				if not groups.has(mat):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					groups[mat] = st
				groups[mat].append_from(mi.mesh, s, xf)
				verts_in += mi.mesh.surface_get_array_len(s) if mi.mesh is ArrayMesh else 0
		var out := Node3D.new()
		out.name = v[0]
		var verts_out := 0
		var k := 0
		for mat in groups:
			var st: SurfaceTool = groups[mat]
			st.index()
			var arrays := st.commit_to_arrays()
			var im := ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mat)
			im.generate_lods(60.0, 25.0, [])
			var am := im.get_mesh()
			verts_out += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var node := MeshInstance3D.new()
			node.name = "part_%d" % k
			node.mesh = am
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if k < 3 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			out.add_child(node)
			node.owner = out
			k += 1
		var ps := PackedScene.new()
		ps.pack(out)
		var err := ResourceSaver.save(ps, "res://gardens/%s.scn" % v[0], ResourceSaver.FLAG_COMPRESS)
		print("baked %s  parts %d  verts %d -> %d  err %d  %d ms" % [v[0], k, verts_in, verts_out, err, Time.get_ticks_msec() - t0])
		g.queue_free()
		out.free()
		await process_frame
	quit()
