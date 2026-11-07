@tool
extends RefCounted
## Recognizable botanical motifs for an ornamental garden, not species simulations.
const NAMES := ["Olive / zaytun", "Grapevine / inab", "Fig / tin", "Pomegranate / rumman", "Date palm / nakhl"]
const REFERENCES := ["95:1; 6:99", "6:99", "95:1", "55:68; 6:99", "55:68; 6:99"]
var leaves: Array[ArrayMesh] = []
var materials: Array[ShaderMaterial] = []
var fruit_materials: Array[StandardMaterial3D] = []
var sphere := SphereMesh.new()
var gold: StandardMaterial3D
var wood: StandardMaterial3D

func _init(host: Node) -> void:
	leaves = [host.blade_mesh(0.12,0.86,0.06,0.0), palmate_leaf(false), palmate_leaf(true), host.blade_mesh(0.16,0.73,0.08,0.0), palm_frond()]
	var tones := [Color("738365"),Color("3e773e"),Color("4d793c"),Color("426e45"),Color("657447")]
	for tone in tones:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://addons/taganat_arabesques/leaf.gdshader")
		mat.set_shader_parameter("leaf_tint",tone)
		materials.append(mat)
	for colour in [Color("67712a"),Color("43314f"),Color("6c365a"),Color("a92f21"),Color("b46c26"),Color("c9b779")]:
		fruit_materials.append(host.material(colour))
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 8
	gold = host.material(Color("a4873f"))
	wood = host.material(Color("6d5831"))

func palmate_leaf(fig: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 5
	var sides := 72
	for row in range(rings):
		for j in range(sides):
			for c in [Vector2i(row,j),Vector2i(row+1,j),Vector2i(row+1,j+1),Vector2i(row,j),Vector2i(row+1,j+1),Vector2i(row,j+1)]:
				var angle := TAU*float(c.y)/sides
				var radial := float(c.x)/rings
				var scallop := 0.70+0.26*cos(5.0*(angle-PI/2.0))
				if not fig: scallop *= 1.0+0.055*cos(angle*31.0)
				var x := cos(angle)*scallop*radial*(0.62 if fig else 0.54)
				var y := 0.50+sin(angle)*scallop*radial*0.56
				st.set_uv(Vector2(x/1.2+0.5,y))
				st.add_vertex(Vector3(x,y,0.10*(1.0-radial*radial)+0.045*sin(angle*5.0)*radial))
	# Petiole connects the palmate blade to its supporting twig.
	for point in [Vector3(-0.012,0,0),Vector3(0.012,0,0),Vector3(0.014,0.5,0.10),Vector3(-0.012,0,0),Vector3(0.014,0.5,0.10),Vector3(-0.014,0.5,0.10)]:
		st.set_uv(Vector2(0.5,point.y))
		st.add_vertex(point)
	st.generate_normals()
	return st.commit()

func palm_frond() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Curved rachis and narrow pinnae, merged into one mesh.
	for j in range(19):
		var t := float(j)/19.0
		var center := Vector3(0,t*1.8,0.22*sin(t*PI))
		for side in [-1.0,1.0]:
			var tip := center+Vector3(side*0.56*sin((0.15+t*0.85)*PI),0.26,0.04)
			var mid := center.lerp(tip,0.55)
			var points := [center,mid+Vector3(0,-0.045,0.035),tip,mid+Vector3(0,0.045,0.02)]
			for k in [0,1,2,0,2,3]:
				st.set_uv(Vector2(0.5 if k == 0 or k == 2 else float(k)/3.0,t))
				st.add_vertex(points[k])
		var points := [center+Vector3(-0.013,0,0),center+Vector3(0.013,0,0),Vector3(0.01,(t+1.0/19.0)*1.8,0.22*sin((t+1.0/19.0)*PI)),Vector3(-0.01,(t+1.0/19.0)*1.8,0.22*sin((t+1.0/19.0)*PI))]
		for k in [0,1,2,0,2,3]:
			st.set_uv(Vector2(0.5,t))
			st.add_vertex(points[k])
	st.generate_normals()
	return st.commit()

func ellipsoid(parent: Node3D, pos: Vector3, dimensions: Vector3, mat: Material) -> void:
	var item := MeshInstance3D.new()
	item.mesh = sphere
	item.material_override = mat
	item.position = pos
	item.scale = dimensions
	parent.add_child(item)

func fruits(species: int, random: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	# Local Z is height; fruit hangs below its attachment point.
	ellipsoid(root,Vector3(0,0,-0.10),Vector3(0.012,0.012,0.12),wood)
	match species:
		0:
			for j in range(5):
				ellipsoid(root,Vector3(random.randf_range(-0.12,0.12),random.randf_range(-0.10,0.10),-0.18-random.randf()*0.12),Vector3(0.065,0.055,0.095),fruit_materials[0 if j%2 == 0 else 1])
		1:
			for row in range(5):
				var count := 6-row
				var radius := 0.14*(1.0-float(row)/6.0)
				for j in range(count):
					var a := TAU*float(j)/count+row*0.6
					ellipsoid(root,Vector3(radius*cos(a),radius*sin(a),-0.15-row*0.105),Vector3.ONE*0.083,fruit_materials[1])
		2:
			# Fig flowers are internal; no exposed fig blossoms are generated.
			for j in range(2):
				var pos := Vector3(j*0.22-0.11,0,-0.28-j*0.07)
				ellipsoid(root,pos,Vector3(0.15,0.15,0.19),fruit_materials[2])
				ellipsoid(root,pos+Vector3(0,0,0.16),Vector3(0.07,0.07,0.10),fruit_materials[0])
		3:
			ellipsoid(root,Vector3(0,0,-0.29),Vector3.ONE*0.22,fruit_materials[3])
			for j in range(6):
				var a := TAU*j/6.0
				var tip := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.035
				cone.height = 0.10
				cone.radial_segments = 5
				tip.mesh = cone
				tip.material_override = fruit_materials[3]
				tip.rotation.x = -PI/2.0
				tip.position = Vector3(0.06*cos(a),0.06*sin(a),-0.52)
				root.add_child(tip)
		4:
			for row in range(4):
				for j in range(5-row/2):
					var a := TAU*j/5.0+row*0.7
					ellipsoid(root,Vector3(0.13*cos(a),0.13*sin(a),-0.20-row*0.14),Vector3(0.052,0.047,0.10),fruit_materials[4])
	return root

func blossom(species: int, petal: Mesh, cream: Material, red: Material) -> Node3D:
	var root := Node3D.new()
	if species == 2 or species == 4:
		return root
	if species == 1:
		for j in range(7):
			var a := TAU*float(j)/7.0
			ellipsoid(root,Vector3(0.06*cos(a),0.06*sin(a),0.03),Vector3.ONE*0.022,fruit_materials[0])
		return root
	var count := 6 if species == 3 else 4
	var scale_ := 0.50 if species == 3 else 0.14
	for j in range(count):
		var item := MeshInstance3D.new()
		item.mesh = petal
		item.material_override = red if species == 3 else cream
		item.rotation = Vector3(-0.55,0,TAU*j/count)
		item.scale = Vector3.ONE*scale_
		root.add_child(item)
	ellipsoid(root,Vector3(0,0,0.09),Vector3.ONE*(0.07 if species == 3 else 0.025),gold)
	return root

