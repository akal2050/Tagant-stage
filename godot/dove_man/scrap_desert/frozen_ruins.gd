extends Node3D
const ROOT="res://dove_man/scrap_desert/"
const VAT="res://dove_man/horizon_variant/assets/"
var members:Array=[]
var sites:Array=[]
var batches:Array=[]
func setup(world:Node3D,routes:Array)->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=917331
	# Dove Man is the origin: uneven archaeological deposits across the desert.
	for site_index in 24:
		var center:=Vector2.ZERO
		for attempt in 4000:
			var angle:=rng.randf()*TAU
			var radius:=rng.randf_range(300.0,850.0)
			if site_index<6 and attempt<500:
				var hill:Dictionary=world.scrap_hills[site_index]
				angle=atan2(hill.position.x,hill.position.y)+rng.randf_range(-0.35,0.35)
				radius=float(hill.position.length())+rng.randf_range(95.0,190.0)
			center=Vector2(sin(angle),cos(angle))*radius
			var clear:=true
			for route in routes:
				if world.segment_distance(center,route[0],route[1])<115.0:clear=false;break
			for other in sites:
				if center.distance_to(other.center)<70.0:clear=false;break
			if clear:break
		var axes:=Vector2(rng.randf_range(24.0,110.0),rng.randf_range(18.0,72.0))
		sites.append({"center":center,"count":0,"axes":axes,"angle":rng.randf()*TAU,"bend":rng.randf_range(-0.6,0.6),"weight":rng.randf_range(0.25,2.4)})
	for species_index in 3:
		var species:String=world.SPECIES[species_index]
		var multi:=MultiMesh.new()
		multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.use_colors=true
		multi.use_custom_data=true
		multi.mesh=load(VAT+species+"_vat_mesh.res")
		multi.instance_count=1059
		multi.custom_aabb=AABB(Vector3(-1100,-150,-1100),Vector3(2200,600,2200))
		var material:=ShaderMaterial.new()
		material.shader=load(ROOT+"frozen_stone.gdshader")
		material.set_shader_parameter("pose_positions",load(VAT+species+"_positions.res"))
		material.set_shader_parameter("pose_normals",load(VAT+species+"_normals.res"))
		var instance:=MultiMeshInstance3D.new()
		instance.name=species+"_Petrified"
		instance.multimesh=multi
		instance.material_override=material
		add_child(instance)
		batches.append(multi)
		for index in 1059:
			var scale_factor:=rng.randf_range(0.55,1.15) if rng.randf()<0.35 else rng.randf_range(1.15,2.6)
			if rng.randf()<0.065:scale_factor=rng.randf_range(3.0,4.5)
			var site_index:=rng.randi_range(0,sites.size()-1)
			# Weight sites independently so population and density are not repeated.
			for choice in 6:
				if rng.randf()*2.4<float(sites[site_index].weight):break
				site_index=rng.randi_range(0,sites.size()-1)
			var site:Dictionary=sites[site_index]
			var point:=Vector2.ZERO
			var found:=false
			var isolated:=rng.randf()<0.30
			for attempt in 8000:
				var theta:=rng.randf()*TAU
				if isolated or attempt>600:
					point=Vector2(sin(theta),cos(theta))*sqrt(rng.randf_range(260.0*260.0,940.0*940.0))
				else:
					var axes:Vector2=site.axes
					var offset:=Vector2(cos(theta)*axes.x,sin(theta)*axes.y)*sqrt(rng.randf())
					offset.x+=float(site.bend)*axes.x*sin(offset.y/axes.y*2.0)
					point=(site.center as Vector2)+offset.rotated(float(site.angle))
				var clear:=point.length()>255.0
				for route in routes:
					if world.segment_distance(point,route[0],route[1])<82.0+scale_factor*1.8:clear=false;break
				if not clear:continue
				for hill in world.scrap_hills:
					if point.distance_to(hill.position)<float(hill.radius)+12.0:clear=false;break
				if not clear:continue
				for other in members:
					var gap:=maxf(2.5,(scale_factor+float(other.scale))*0.85)
					if point.distance_squared_to(other.point)<gap*gap:clear=false;break
				if clear:found=true;break
			assert(found,"No safe scattered ruin position")
			var burial:=rng.randf_range(0.48,0.90)
			var height:float=world.sand_height(point.x,point.y)-4.0*scale_factor*burial
			var yaw:=atan2(-point.x,-point.y)+rng.randf_range(-0.85,0.85)
			var basis:=(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,rng.randf_range(-0.12,0.12))).scaled(Vector3(scale_factor*rng.randf_range(0.88,1.12),scale_factor,scale_factor))
			multi.set_instance_transform(index,Transform3D(basis,Vector3(point.x,height,point.y)))
			multi.set_instance_custom_data(index,Color(rng.randf(),rng.randf(),burial,1.0))
			multi.set_instance_color(index,Color(0.40,0.31,0.21)*rng.randf_range(0.82,1.23))
			members.append({"point":point,"burial":burial,"species":species_index,"site":site_index,"scale":scale_factor,"isolated":isolated})
			site.count+=1
	print("PETRIFIED_RUINS_READY ",members.size()," figures in ",sites.size()," varied deposits plus solitary fragments; clear crossing lanes")

