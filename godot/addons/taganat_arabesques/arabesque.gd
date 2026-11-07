@tool
class_name TaganatArabesque
extends Node3D
## Reusable growing botanical geometry. No camera, lights, UI, ground or input hooks.
## Configure exported properties, then press Regenerate or call regenerate().

signal regenerated
signal growth_changed(progress: float)

enum Layout { STRAIGHT, CYLINDER, SQUARE, SHAMSA, SPHERE, SURFACE }
@export var layout: Layout = Layout.SHAMSA
@export var seed_value: int = 34
## -1 mixed, 0 olive, 1 grape, 2 fig, 3 pomegranate, 4 date palm.
@export_range(-1,4,1) var botanical_profile: int = -1
@export_range(1,3,1) var complexity: int = 3
@export_enum("6:6", "8:8", "12:12", "16:16") var shamsa_lobes: int = 8
@export_range(1.0,8.0,0.1) var sphere_radius: float = 3.2
@export_enum("Flowing", "Scalloped", "Flame") var motif_variant: int = 0
@export var complementary_layer: bool = true
@export_range(0.1,1.0,0.05) var infill_density: float = 0.65
## Baked surface guides generated from the target triangle mesh; no support model is instanced here.
@export_file("*.json") var surface_guides: String = ""
@export_enum("Living", "Polished gold", "Antique gold") var finish: int = 0
@export var dense_bush: bool = false
@export_range(0.5,2.0,0.1) var bush_density: float = 1.4
@export_range(0.15,0.85,0.05) var bush_depth: float = 0.45
@export var ornamental_flowers: bool = true
## A finite number of four-metre sections in straight mode.
@export_range(1,128,1) var straight_sections: int = 8
@export var play_growth: bool = false
## Normalized growth per second, independent of layout.
@export_range(0.001,1.0,0.001) var growth_speed: float = 0.08
@export_range(0.0,1.0,0.001) var growth_progress: float = 1.0:
	set(value):
		growth_progress = clampf(value,0.0,1.0)
		if is_instance_valid(stems): _apply_growth()
@export_tool_button("Regenerate geometry") var regenerate_action: Callable = regenerate

const BotanicalForms = preload("res://addons/taganat_arabesques/botanical_forms.gd")
const SquareGarden = preload("res://addons/taganat_arabesques/square_garden.gd")
const ShamsaGarden = preload("res://addons/taganat_arabesques/shamsa_garden.gd")
const GoldForms = preload("res://addons/taganat_arabesques/gold_forms.gd")
const DenseBush = preload("res://addons/taganat_arabesques/dense_bush.gd")
const SurfaceGarden = preload("res://addons/taganat_arabesques/surface_garden.gd")
const Complement = preload("res://addons/taganat_arabesques/complement.gd")
const CYLINDER_REPEATS := 4
const CYLINDER_COURSES := 2
const CYLINDER_RADIUS := 16.0/TAU
const CYLINDER_COURSE_HEIGHT := 4.2
const COURSE_CLIMB_TIME := 0.65
const CYLINDER_END := 9.2
const SQUARE_END := 3.0
const SHAMSA_END := 3.4
var batch_materials: Array[ShaderMaterial] = []
var foliage_instances := 0
var bush_shoots := 0
var bush_outward_reach := 0.0
var plant: Node3D
var stems: ShaderMaterial
var organs: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var tile_count := 0
var current_species := 0
var mesh_vertices := 0
var cylinder_course := 0
var cylindrical := false
var square_garden := false
var shamsa_garden := true
var surface_wrap := false
var organ_frame := Basis.IDENTITY
var spherical := false
var hemisphere := 0
var source_paths: Array[Dictionary] = []
var collecting_paths := true
var infill_count := 0
var growth_end := 0.0
var growth := 0.0
var botany: RefCounted
var stem_tool: SurfaceTool
var leaf_mesh: ArrayMesh
var petal_mesh: ArrayMesh
var flower_materials: Array[StandardMaterial3D] = []
var gold_mat: StandardMaterial3D
var square_paths: Array[PackedVector3Array] = []
var shamsa_paths: Array[PackedVector3Array] = []

func _ready() -> void:
	regenerate()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not play_growth: return
	growth_progress = minf(1.0,growth_progress+delta*growth_speed)
	if growth_progress >= 1.0: play_growth = false

func get_growth_duration() -> float:
	match layout:
		Layout.SURFACE: return maxf(0.1,growth_end)
		Layout.CYLINDER: return maxf(CYLINDER_END,growth_end)
		Layout.SQUARE: return maxf(SQUARE_END,growth_end)
		Layout.SHAMSA, Layout.SPHERE: return maxf(4.2 if complementary_layer else SHAMSA_END,growth_end)
	return maxf(float(straight_sections)+0.5,growth_end)

func regenerate() -> void:
	if not is_inside_tree(): return
	if is_instance_valid(plant):
		remove_child(plant)
		plant.queue_free()
	surface_wrap = layout == Layout.SURFACE
	spherical = layout == Layout.SPHERE
	hemisphere = 0
	source_paths.clear()
	infill_count = 0
	growth_end = 0
	collecting_paths = true
	cylindrical = layout == Layout.CYLINDER
	square_garden = layout == Layout.SQUARE
	shamsa_garden = layout == Layout.SHAMSA
	plant = Node3D.new()
	plant.name = "GeneratedPlants"
	plant.rotation.x = 0.0 if cylindrical or spherical or surface_wrap else -PI/2.0
	add_child(plant)
	organs.clear()
	batch_materials.clear()
	foliage_instances = 0
	bush_shoots = 0
	bush_outward_reach = 0.0
	square_paths.clear()
	shamsa_paths.clear()
	tile_count = 0
	mesh_vertices = 0
	cylinder_course = 0
	rng.seed = seed_value
	petal_mesh = blade_mesh(0.23,0.60,0.16,0.0)
	if finish > 0: petal_mesh = GoldForms.shell(petal_mesh,0.018)
	flower_materials = [material(Color("b7402e")), material(Color("ede1bb")), material(Color("295b6c")), material(Color("c36c38"))]
	gold_mat = material(Color("c99b48"),0.12)
	botany = BotanicalForms.new(self)
	if finish > 0:
		for i in range(botany.leaves.size()): botany.leaves[i] = GoldForms.shell(botany.leaves[i],0.014)
	stems = ShaderMaterial.new()
	stems.shader = load("res://addons/taganat_arabesques/cast_gold.gdshader" if finish > 0 else "res://addons/taganat_arabesques/growth.gdshader")
	if finish > 0: stems.set_shader_parameter("antique",finish == 2)
	if surface_wrap:
		SurfaceGarden.build(self)
		if dense_bush: DenseBush.build(self)
	elif spherical:
		for half in range(2):
			hemisphere = half
			ShamsaGarden.build(self)
			tile_count = shamsa_lobes*2
	elif shamsa_garden:
		ShamsaGarden.build(self)
	elif square_garden:
		SquareGarden.build(self)
	else:
		var count := CYLINDER_REPEATS*CYLINDER_COURSES if cylindrical else straight_sections
		for index in range(count):
			_build_tile(index)
			tile_count += 1
		if cylindrical: _build_climbers()
	if complementary_layer and not surface_wrap: Complement.build(self)
	for organ in organs:
		var delay: float = float(organ.node.get_meta("surface_course",0))*COURSE_CLIMB_TIME if cylindrical else 0.0
		growth_end = maxf(growth_end,float(organ.birth)+delay+0.13)
	if finish > 0: apply_gold(plant)
	_apply_growth()
	regenerated.emit()

func restart_growth() -> void:
	growth_progress = 0.0
	play_growth = true

func finish_growth() -> void:
	play_growth = false
	growth_progress = 1.0

func set_growth(progress: float) -> void:
	growth_progress = progress

func _apply_growth() -> void:
	if not is_instance_valid(stems): return
	growth = growth_progress*get_growth_duration()
	stems.set_shader_parameter("growth",growth)
	for mat in batch_materials: mat.set_shader_parameter("growth",growth)
	for organ in organs:
		var birth := float(organ.birth)
		if cylindrical: birth += float(organ.node.get_meta("surface_course",0))*COURSE_CLIMB_TIME
		var amount := smoothstep(birth,birth+0.12,growth)
		organ.node.visible = amount > 0.001
		organ.node.scale = Vector3.ONE*maxf(0.001,amount*float(organ.size)*(1.45 if spherical else 1.0))
	growth_changed.emit(growth_progress)

func get_geometry_stats() -> Dictionary:
	return {"sections":tile_count,"stem_vertices":mesh_vertices,"organs":organs.size(),"growth":growth_progress,"infill_branches":infill_count,"foliage_instances":foliage_instances,"bush_shoots":bush_shoots,"bush_outward_reach":bush_outward_reach}

func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.48
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func blade_mesh(width: float, length_: float, cup: float, lobes: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 12 if surface_wrap else 24
	var cols := 4 if surface_wrap else 8
	for i in range(rows):
		for j in range(cols):
			for corner in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var t: float = float(corner.x)/rows
				var v: float = float(corner.y)/cols*2.0-1.0
				var w := pow(sin(t*PI),0.8)*width*(1.0+lobes*sin(t*PI*7.0))
				st.set_uv(Vector2((v+1.0)*0.5,t))
				st.add_vertex(Vector3(v*w,t*length_,sin(t*PI)*cup*(1.0-v*v)+0.12*t*t+0.025*sin(t*PI*3.0)*absf(v)))
	st.generate_normals()
	return st.commit()

func motif_point(pos: Vector3) -> Vector3:
	var p := pos
	var phase := float(seed_value)*0.31
	if motif_variant == 1:
		p.x += 0.065*sin(pos.y*5.0+phase)
		p.z += 0.06*sin(pos.x*4.0+pos.y*3.0)
	elif motif_variant == 2:
		p.x *= 1.0+0.09*sin(pos.y*2.8+phase)
		p.z += 0.09*pow(sin(pos.y*2.0),2.0)
	if spherical:
		var fade := sin(PI*clampf(Vector2(pos.x,pos.y).length()/3.0,0,1))
		p = pos.lerp(p,fade)
	return p

func source_to_surface(source: Vector3) -> Vector3:
	var pos := motif_point(source)
	if spherical:
		var r := Vector2(pos.x,pos.y).length()
		var phi := r*PI/6.0
		var angle := atan2(pos.x,pos.y)
		var direction := Vector3(sin(phi)*sin(angle),cos(phi),-sin(phi)*cos(angle))
		if hemisphere == 1: direction = Vector3(direction.x,-direction.y,-direction.z)
		return direction*(sphere_radius+pos.z*0.26)
	if not cylindrical: return pos
	var angle := TAU*(pos.x+float(cylinder_course%2)*2.0)/16.0
	var radius := CYLINDER_RADIUS+maxf(0.025,pos.z*0.55)
	return Vector3(sin(angle)*radius,0.4+(float(cylinder_course)+0.5)*CYLINDER_COURSE_HEIGHT+pos.y*CYLINDER_COURSE_HEIGHT/6.6,cos(angle)*radius)

func surface_frame(pos: Vector3) -> Basis:
	if spherical or motif_variant != 0:
		var x := (source_to_surface(pos+Vector3(0.001,0,0))-source_to_surface(pos-Vector3(0.001,0,0))).normalized()
		var y := (source_to_surface(pos+Vector3(0,0.001,0))-source_to_surface(pos-Vector3(0,0.001,0))).normalized()
		var z := x.cross(y).normalized()
		y = z.cross(x).normalized()
		return Basis(x,y,z)
	var angle := TAU*(pos.x+float(cylinder_course%2)*2.0)/16.0
	return Basis(Vector3(cos(angle),0,-sin(angle)),Vector3.UP,Vector3(sin(angle),0,cos(angle)))

func place_organ(node: Node3D, pos: Vector3, gravity: bool = false) -> void:
	if surface_wrap:
		node.position = pos
		if gravity:
			var down := Vector3.DOWN
			var right := down.cross(organ_frame.z).normalized()
			if right.length_squared() < 0.01: right = Vector3.RIGHT
			node.basis = Basis(right,down,right.cross(down).normalized())
		else:
			node.basis = organ_frame*node.basis
		return
	node.set_meta("source_position",pos)
	node.set_meta("surface_course",cylinder_course)
	node.set_meta("gravity",gravity)
	node.set_meta("hemisphere",hemisphere)
	if not cylindrical and not spherical and motif_variant == 0:
		node.position = pos
		return
	var frame := surface_frame(pos)
	node.position = source_to_surface(pos)
	if gravity:
		node.position += frame.z*0.24
		var down := Vector3.DOWN
		var right := down.cross(frame.z).normalized()
		if right.length_squared() < 0.01: right = Vector3.RIGHT
		var forward := right.cross(down).normalized()
		node.basis = Basis(right,down,forward)
	else:
		node.basis = frame*node.basis

func spine(x: float, side: float) -> Vector3:
	return Vector3(x,side*0.62*sin(TAU*x/4.0),0.42+side*0.19*cos(TAU*x/4.0))

func _build_tile(index: int) -> void:
	cylinder_course = index/CYLINDER_REPEATS
	stem_tool = SurfaceTool.new()
	stem_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := float(index)*4.0
	rng.seed = seed_value*100003+index*97
	for side in [-1.0,1.0]:
		current_species = botanical_profile if botanical_profile >= 0 else (index+(0 if side < 0 else 2)+seed_value)%5
		var turns := 0.95+0.12*(complexity-1)+rng.randf_range(-0.08,0.08)
		var trunk := PackedVector3Array()
		for j in range(81):
			trunk.append(spine(start+float(j)*4.0/80.0,side))
		tube(trunk,0.078,float(index),1.0,1.0)
		var rooted := PackedVector3Array()
		var anchor := spine(start+0.12,side)
		for k in range(16):
			var u := float(k)/15.0
			rooted.append(Vector3(anchor.x-0.20*(1.0-u),anchor.y+side*0.12*(1.0-u),0.04+u*(anchor.z-0.04)))
		tube(rooted,0.061,float(index),0.08,0.85)
		if complexity == 3:
			branch_scroll(spine(start+1.65,side),Vector3.RIGHT,-side,float(index)+0.42,0.44,1.28)
		# Each repeat branches from a continuous running vine into an inward scroll.
		var origin := spine(start+0.70,side)
		var scroll := PackedVector3Array()
		for j in range(81):
			var t := float(j)/80.0
			var q: Vector3
			if t < 0.5:
				var u := t*2.0
				var v := 1.0-u
				q = v*v*v*origin + 3*v*v*u*Vector3(start+1.05,side*1.15,0.65) + 3*v*u*u*Vector3(start+1.75,side*2.48,0.88) + u*u*u*Vector3(start+2.65,side*2.48,0.88)
			else:
				var u := (t-0.5)*2.0
				var theta := -u*TAU*turns
				var r := 0.87*(1.0-u)+0.10
				q = Vector3(start+2.65-r*sin(theta),side*(1.51+r*cos(theta)),0.88+0.24*sin(u*PI))
			scroll.append(q)
		tube(scroll,0.060,float(index)+0.18,0.63)
		for j in ([18,42,66] if complexity == 1 else [10,18,26,34,42,50,58,66,74]):
			var tangent := (scroll[j+1]-scroll[j-1]).normalized()
			var birth := float(index)+0.18+0.63*float(j)/80.0
			add_leaf(scroll[j],tangent,side,birth,rng.randf_range(0.68,0.95))
			if j % 3 != 0:
				add_leaf(scroll[j],tangent,-side,birth+0.025,0.64)
		add_flower(scroll[-1],float(index)+0.82,0.73)
		add_fruit(scroll[68],float(index)+1.0,0.95)
		# Secondary woody branches carry foliage and flower clusters.
		for node in ([40] if complexity == 1 else ([22,58] if complexity == 2 else [16,32,50,66])):
			var twig := PackedVector3Array()
			var origin_: Vector3 = scroll[node]
			var dir := (scroll[node+1]-scroll[node-1]).normalized()
			var outward: Vector3 = Vector3(-dir.y,dir.x,0)*side
			var birth_ := float(index)+0.18+0.63*float(node)/80.0
			for k in range(20):
				var u := float(k)/19.0
				twig.append(origin_+dir*0.6*u+outward*0.62*sin(u*1.6)+Vector3(0,0,0.48*sin(u*PI/2)))
			tube(twig,0.026,birth_,0.15)
			for k in [6,11,16]:
				add_leaf(twig[k],(twig[k+1]-twig[k-1]).normalized(),-side,birth_+k*0.008,0.70)
				add_leaf(twig[k],(twig[k+1]-twig[k-1]).normalized(),side,birth_+k*0.008+0.02,0.52)
			add_flower(twig[-1],birth_+0.17,0.50)
			if node == 32 or node == 58: add_fruit(twig[-1],birth_+0.32,0.85)
			if complexity >= 2:
				branch_scroll(twig[10],dir,side,birth_+0.10,rng.randf_range(0.30,0.53),1.15)
			if complexity == 3 and node == 50:
				branch_scroll(scroll[node],dir,-side,birth_,0.62,1.35)
		# Small branching bud between scrolls, carried by the main vine.
		var bud := PackedVector3Array()
		var root := spine(start+3.45,side)
		for j in range(20):
			var u := float(j)/19.0
			bud.append(root+Vector3(0.45*u,side*(0.85*u+0.15*sin(u*PI)),0.12*u))
		tube(bud,0.025,float(index)+0.86,0.16)
		add_leaf(bud[10],(bud[11]-bud[9]).normalized(),side,float(index)+0.96,0.48)
		add_flower(bud[-1],float(index)+1.02,0.36)
	if ornamental_flowers:
		for k in range(3 if complexity == 3 else 1):
			for side in [-1.0,1.0]:
				var pos := Vector3(start+0.55+k*1.15,side*(2.35+0.28*sin(k*2.0)),0.05)
				var scape := PackedVector3Array()
				for j in range(16):
					var u := float(j)/15.0
					scape.append(pos+Vector3(0.12*sin(u*PI),0.05*u,0.35*u))
				tube(scape,0.012,float(index)+float(k)/4.0+0.25,0.16)
				add_ornamental_flower(scape[-1],float(index)+float(k)/4.0+0.41,0.38+rng.randf()*0.15)
	stem_tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = stem_tool.commit()
	mesh.material_override = stems
	plant.add_child(mesh)

func tube(points: PackedVector3Array, radius: float, birth: float, duration: float, end_scale: float = 0.17, world_space: bool = false) -> void:
	var count := points.size()
	if collecting_paths and not world_space:
		source_paths.append({"points":points,"birth":birth,"duration":duration,"course":cylinder_course,"half":hemisphere,"species":current_species})
	mesh_vertices += (count-1)*48
	for i in range(count-1):
		for j in range(8):
			for corner in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var k: int = corner.x
				var t := float(k)/float(count-1)
				var tangent := (points[mini(k+1,count-1)]-points[maxi(k-1,0)]).normalized()
				var across := tangent.cross(Vector3.BACK).normalized()
				var up := tangent.cross(across).normalized()
				var theta := TAU*float(corner.y)/8.0
				var r := radius*(1.35 if finish > 0 else 1.0)*lerpf(1.0,end_scale,t)*(1.0+0.035*sin(theta*11.0+birth*0.5))
				var delay := float(cylinder_course)*COURSE_CLIMB_TIME if cylindrical and not world_space else 0.0
				stem_tool.set_uv(Vector2(birth+t*duration+delay,theta/TAU))
				stem_tool.set_color(Color("b4a362").lerp(Color("62936a"),t))
				var vertex := points[k]+r*(across*cos(theta)+up*sin(theta))
				stem_tool.add_vertex(vertex if world_space else source_to_surface(vertex))

func _build_climbers() -> void:
	stem_tool = SurfaceTool.new()
	stem_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		var points := PackedVector3Array()
		var radius: float = CYLINDER_RADIUS+(0.42+side*0.19)*0.55
		for j in range(81):
			var u := float(j)/80.0
			var angle := (PI/4.0)*smoothstep(0.0,1.0,u)
			points.append(Vector3(sin(angle)*radius,0.4+CYLINDER_COURSE_HEIGHT*(0.5+u),cos(angle)*radius))
		tube(points,0.064,4.0,COURSE_CLIMB_TIME,1.0,true)
		for j in [12,26,40,54,68]:
			var u := float(j)/80.0
			var angle := (PI/4.0)*smoothstep(0.0,1.0,u)
			var leaf := MeshInstance3D.new()
			var species := botanical_profile if botanical_profile >= 0 else 0
			leaf.mesh = botany.leaves[species]
			leaf.material_override = botany.materials[species]
			leaf.position = points[j]
			leaf.basis = Basis(Vector3(cos(angle),0,-sin(angle)),Vector3.UP,Vector3(sin(angle),0,cos(angle)))*Basis(Vector3(0,0,1),side*0.7)
			plant.add_child(leaf)
			organs.append({"node":leaf,"birth":4.0+u*COURSE_CLIMB_TIME,"size":0.75})
	stem_tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = stem_tool.commit()
	mesh.material_override = stems
	plant.add_child(mesh)

func geometry_signature() -> int:
	var values: Array[int] = []
	for child in plant.get_children():
		if child is MeshInstance3D and child.material_override == stems:
			values.append(hash(child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]))
	return hash(values)

func add_leaf(pos: Vector3, tangent: Vector3, side: float, birth: float, size_: float) -> void:
	var leaf := MeshInstance3D.new()
	leaf.mesh = botany.leaves[current_species]
	leaf.material_override = botany.materials[current_species]
	leaf.rotation = Vector3(rng.randf_range(-0.45,0.45),rng.randf_range(-0.55,0.55),atan2(-tangent.x,tangent.y)+side*0.85)
	if cylindrical:
		leaf.rotation.x *= 0.35
		leaf.rotation.y *= 0.35
	place_organ(leaf,pos)
	plant.add_child(leaf)
	organs.append({"node":leaf,"birth":birth,"size":size_*(0.72 if current_species == 4 else 1.0)})

func branch_scroll(origin: Vector3, tangent: Vector3, side: float, birth: float, radius: float, turns: float) -> void:
	var dir := Vector3(tangent.x,tangent.y,0).normalized()
	var normal := Vector3(-dir.y,dir.x,0)*side
	var points := PackedVector3Array()
	for j in range(49):
		var u := float(j)/48.0
		var theta := u*TAU*turns
		var r := lerpf(radius,0.045,u)
		points.append(origin+dir*r*sin(theta)+normal*(radius-r*cos(theta))+Vector3(0,0,0.22*sin(u*PI)))
	tube(points,0.021,birth,0.24)
	for j in [12,26,38]:
		add_leaf(points[j],(points[j+1]-points[j-1]).normalized(),side,birth+j*0.005,0.45)
	add_flower(points[-1],birth+0.25,0.42)

func add_fruit(pos: Vector3, birth: float, size_: float) -> void:
	var fruit: Node3D = botany.fruits(current_species,rng)
	place_organ(fruit,pos,true)
	plant.add_child(fruit)
	organs.append({"node":fruit,"birth":birth,"size":size_})

func add_flower(pos: Vector3, birth: float, size_: float) -> void:
	if current_species == 2 or current_species == 4: return
	var flower: Node3D = botany.blossom(current_species,petal_mesh,flower_materials[1],flower_materials[0])
	place_organ(flower,pos+Vector3(0,0,0.10))
	plant.add_child(flower)
	organs.append({"node":flower,"birth":birth,"size":size_})

func add_ornamental_flower(pos: Vector3, birth: float, size_: float) -> void:
	var flower := Node3D.new()
	place_organ(flower,pos+Vector3(0,0,0.07))
	plant.add_child(flower)
	var chosen := flower_materials[rng.randi_range(0,flower_materials.size()-1)]
	for tier in range(2):
		for i in range(8):
			var petal := MeshInstance3D.new()
			petal.mesh = petal_mesh
			petal.material_override = chosen if tier == 0 else flower_materials[1]
			petal.rotation = Vector3(-0.18-tier*0.25,0,TAU*i/8.0+tier*PI/8.0)
			petal.scale = Vector3.ONE*(1.0-tier*0.35)
			petal.position.z = tier*0.1
			flower.add_child(petal)
	var center := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	center.mesh = sphere
	center.position.z = 0.22
	center.material_override = gold_mat
	flower.add_child(center)
	organs.append({"node":flower,"birth":birth,"size":size_})

func apply_gold(node: Node) -> void:
	var gold := ShaderMaterial.new()
	gold.shader = load("res://addons/taganat_arabesques/cast_gold.gdshader")
	gold.set_shader_parameter("reveal_stem",false)
	gold.set_shader_parameter("antique",finish == 2)
	apply_gold_recursive(node,gold)

func apply_gold_recursive(node: Node, gold: ShaderMaterial) -> void:
	if node is MeshInstance3D and node.material_override != stems:
		node.material_override = gold
	for child in node.get_children(): apply_gold_recursive(child,gold)
