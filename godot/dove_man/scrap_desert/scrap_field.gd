extends Node3D
const ROOT="res://dove_man/scrap_desert/"
var hills:Array=[]
var batches:Dictionary={}
var random:=RandomNumberGenerator.new()
var counts:Dictionary={"wrecks":0,"tyres":0,"barrels":0,"sheets":0,"beams":0}
var world:Node3D
func setup(owner_world:Node3D):
	world=owner_world
	random.seed=440733
	var material:=ShaderMaterial.new()
	material.shader=load(ROOT+"scrap_skin.gdshader")
	for species in ["car_peugeot504","car_pickup","car_landcruiser"]:
		for variant in 3: add_batch(species+str(variant),load(ROOT+"meshes/"+species+"_wreck_%d.res"%variant),material)
	var tyre:=TorusMesh.new()
	tyre.inner_radius=0.32
	tyre.outer_radius=0.62
	tyre.rings=12
	tyre.ring_segments=8
	add_batch("tyres",tyre,material)
	var barrel:=CylinderMesh.new()
	barrel.top_radius=0.43
	barrel.bottom_radius=0.46
	barrel.height=1.25
	barrel.radial_segments=12
	add_batch("barrels",barrel,material)
	var sheet:=BoxMesh.new()
	sheet.size=Vector3(2.5,0.07,1.6)
	add_batch("sheets",sheet,material)
	var beam:=BoxMesh.new()
	beam.size=Vector3(0.16,0.2,3.5)
	add_batch("beams",beam,material)
	for hill_index in 6:
		var angle:=1.12+float(hill_index/2)*TAU/3.0+float(hill_index%2)*0.48
		var radius:=320.0+float(hill_index%2)*55.0
		var center:=Vector2(sin(angle),cos(angle))*radius
		var hill:Dictionary={"position":center,"radius":36.0,"height":15.5,"index":hill_index}
		hills.append(hill)
		for layer in 7:
			var layer_radius:=31.0-float(layer)*3.8
			var number:=maxi(4,34-layer*5)
			for index in number:
				var a:=float(index)*2.39996323+random.randf_range(-0.15,0.15)
				var r:=sqrt((float(index)+0.5)/float(number))*layer_radius
				var position:=center+Vector2(sin(a)*1.05,cos(a)*0.88)*r
				var height:float=world.dune_height(position.x,position.y)+float(layer)*1.9-random.randf_range(0.1,0.65)
				place_wreck(position,height,layer>2)
		for item in 110:
			var a:=random.randf()*TAU
			var r:=sqrt(random.randf())*36.0
			var point:=center+Vector2(sin(a),cos(a))*r
			var mound:=maxf(0.0,1.0-pow(r/35.0,2.0))*10.0
			place_trash(point,world.dune_height(point.x,point.y)+mound*random.randf_range(0.3,1.0))
	for item in 72:
		var angle:=random.randf()*TAU
		# Preserve the three incoming crowd corridors.
		var gate:=fposmod(angle,TAU/3.0)
		if gate<0.86: continue
		var point:=Vector2(sin(angle),cos(angle))*random.randf_range(245.0,425.0)
		place_wreck(point,world.dune_height(point.x,point.y)-random.randf_range(0.4,1.3),false)
	for hill in hills:
		for item in 45:
			var a:=random.randf()*TAU
			var point:Vector2=hill.position+Vector2(sin(a),cos(a))*random.randf_range(33.0,53.0)
			place_trash(point,world.dune_height(point.x,point.y)-0.1)
	flush_batches()
	print("SCRAP_DESERT_READY ",counts," in ",hills.size()," hills")
func add_batch(key:String,mesh:Mesh,material:Material):
	batches[key]={"mesh":mesh,"material":material,"items":[]}
func place_wreck(point:Vector2,height:float,stacked:bool):
	var species:Array=["car_peugeot504","car_pickup","car_landcruiser"]
	var key:String=species[random.randi_range(0,2)]+str(random.randi_range(0,2))
	var tilt:=random.randf_range(-0.23,0.23)
	var roll:=random.randf_range(-0.25,0.25)
	if random.randf()<0.18: roll+=PI
	var scale_factor:=random.randf_range(1.75,2.35)
	var basis:=Basis.from_euler(Vector3(tilt,random.randf()*TAU,roll)).scaled(Vector3.ONE*scale_factor)
	var mesh:Mesh=batches[key].mesh
	var bounds:AABB=Transform3D(basis,Vector3.ZERO)*mesh.get_aabb()
	var offset:=maxf(-bounds.position.y,0.0)
	var position:=Vector3(point.x,height+offset,point.y)
	batches[key].items.append({"transform":Transform3D(basis,position),"color":Color(random.randf_range(0.6,1.0),random.randf_range(0.6,0.9),random.randf_range(0.5,0.8)),"wear":Color(random.randf(),random.randf_range(0.55,0.95),random.randf_range(0.15,0.55),1)})
	counts.wrecks+=1
func place_trash(point:Vector2,height:float):
	var kinds:Array=["tyres","barrels","sheets","beams"]
	var kind:String=kinds[random.randi_range(0,3)]
	var basis:=Basis.from_euler(Vector3(random.randf_range(-1.2,1.2),random.randf()*TAU,random.randf_range(-1.2,1.2))).scaled(Vector3.ONE*random.randf_range(1.0,2.0))
	var color:=Color(0.14,0.12,0.095) if kind=="tyres" else Color(0.38,0.23,0.12)
	batches[kind].items.append({"transform":Transform3D(basis,Vector3(point.x,height+0.4,point.y)),"color":color,"wear":Color(random.randf(),0.7,0.35,1)})
	counts[kind]+=1
func flush_batches():
	for key in batches:
		var batch:Dictionary=batches[key]
		var node:=MultiMeshInstance3D.new()
		node.name="Scrap_"+key
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.use_colors=true
		multi.use_custom_data=true
		multi.mesh=batch.mesh
		multi.instance_count=batch.items.size()
		for i in batch.items.size():
			multi.set_instance_transform(i,batch.items[i].transform)
			multi.set_instance_color(i,batch.items[i].color)
			multi.set_instance_custom_data(i,batch.items[i].wear)
		node.multimesh=multi
		node.material_override=batch.material
		add_child(node)

