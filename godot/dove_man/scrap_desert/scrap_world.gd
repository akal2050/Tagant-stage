extends "res://dove_man/scrap_desert/organised_crowd.gd"
var scrap_field:Node3D
var scrap_hills:Array=[]
var scrap_camera:Camera3D
var scrap_view:=-1
var ruin_routes:Array=[]
var frozen_ruins:Node3D
var aircraft_fleet:Node3D
func _ready()->void:
	super._ready()
	scrap_field=Node3D.new()
	scrap_field.name="WreckageHills"
	scrap_field.set_script(load("res://dove_man/scrap_desert/scrap_field.gd"))
	add_child(scrap_field)
	scrap_field.setup(self)
	scrap_hills=scrap_field.hills
	for hill in scrap_hills:static_discs.append({"position":hill.position,"radius":hill.radius+2.0})
	for index in 3:ruin_routes.append(plan_scrap_route())
	frozen_ruins=Node3D.new()
	frozen_ruins.name="PetrifiedCrowdRuins"
	frozen_ruins.set_script(load("res://dove_man/scrap_desert/frozen_ruins.gd"))
	add_child(frozen_ruins)
	frozen_ruins.setup(self,ruin_routes)

func obstacles(me:Variant=null)->Array:
	var result:=super.obstacles(me)
	for hill in scrap_hills:result.append({"p":hill.position,"r":hill.radius+3.0,"kind":"scrap_hill"})
	return result
func plan_godzilla_route()->Array:
	if ruin_routes.is_empty():return plan_scrap_route()
	var route:Array=ruin_routes[rng.randi_range(0,ruin_routes.size()-1)]
	return [route[1],route[0]] if rng.randf()<0.5 else route.duplicate()
func plan_scrap_route()->Array:
	var best:Array=[]
	var best_score:=-INF
	for attempt in 14:
		var candidate:=super.plan_godzilla_route()
		var clear:=INF
		for hill in scrap_hills:clear=minf(clear,segment_distance(hill.position,candidate[0],candidate[1])-float(hill.radius)-27.0)
		if clear>=0.0:return candidate
		if clear>best_score:
			best=candidate
			best_score=clear
	return best
func show_scrap_view(view:int)->void:
	scrap_view=view
	if scrap_camera==null:
		scrap_camera=Camera3D.new()
		scrap_camera.far=3500.0
		add_child(scrap_camera)
	director.set_process(false)
	director.fade.color.a=0.0
	inspection=-1
	scrap_camera.current=true
	if view==0:
		var hill:Dictionary=scrap_hills[0]
		var point:=Vector3(hill.position.x,dune_height(hill.position.x,hill.position.y)+8.0,hill.position.y)
		scrap_camera.position=point+Vector3(55,25,55)
		scrap_camera.fov=58.0
		scrap_camera.look_at(point)
	elif view==1:
		var member:Dictionary=lost_members[0]
		var point:=Vector3(member.pos.x,sand_height(member.pos.x,member.pos.y)+4.0,member.pos.y)
		scrap_camera.position=point+Vector3(18,8,18)
		scrap_camera.fov=60.0
		scrap_camera.look_at(point)
	else:
		scrap_camera.position=Vector3(540,340,540)
		scrap_camera.fov=65.0
		scrap_camera.look_at(Vector3(0,15,0))
func _unhandled_input(event:InputEvent)->void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_J:show_scrap_view(0)
		if event.keycode==KEY_L:show_scrap_view(1)
		if event.keycode==KEY_K:show_scrap_view(2)
		if event.keycode==KEY_R:show_ruins_view()


func show_ruins_view()->void:
	show_scrap_view(2)
	var site:Dictionary=frozen_ruins.sites[0]
	var point:Vector2=site.center
	var target:=Vector3(point.x,sand_height(point.x,point.y)+0.5,point.y)
	scrap_camera.position=target+Vector3(35,6,40)
	scrap_camera.fov=55.0
	scrap_camera.look_at(target)

func create_boeing()->void:
	super.create_boeing()
	aircraft_fleet=Node3D.new()
	aircraft_fleet.name="SlowAircraftFleet"
	aircraft_fleet.set_script(load("res://dove_man/scrap_desert/aircraft_fleet.gd"))
	add_child(aircraft_fleet)
	aircraft_fleet.setup(self)
func update_boeing(delta:float)->void:
	if aircraft_fleet==null:super.update_boeing(delta)
	else:aircraft_fleet.advance(delta,t,air_level)
func nearest_threat(point:Vector3)->Vector3:
	var nearest:=super.nearest_threat(point)
	if aircraft_fleet!=null:
		for craft in aircraft_fleet.aircraft:
			var position:Vector3=craft.orbit.global_position
			if position.distance_squared_to(point)<nearest.distance_squared_to(point):nearest=position
	return nearest

func create_sand()->void:
	super.create_sand()
	sand_material.shader=load("res://dove_man/scrap_desert/contact_sand.gdshader")
	var plane:PlaneMesh=get_node("Reactive_Dunes").mesh
	plane.subdivide_width=600
	plane.subdivide_depth=600
	var cr:Dictionary=D.cars.crater
	var ck:float=D.cars.scale
	sand_material.set_shader_parameter("crater_radius",float(cr.radius_m)*ck*0.58)
	sand_material.set_shader_parameter("crater_rim_radius",float(cr.radius_m)*ck*0.58*1.18)
	sand_material.set_shader_parameter("crater_rim",float(cr.rim_m)*sqrt(ck)*0.65)
	get_node("Far_Dunes").set_instance_shader_parameter("far_surface",1.0)
func contact_crater(point:Vector2,c:Vector4)->float:
	if c.w<0.5:return 0.0
	var age:=t-c.z
	if age<0.0:return 0.0
	var cr:Dictionary=D.cars.crater
	var ck:float=D.cars.scale
	var radius:=float(cr.radius_m)*ck*0.58
	var rel:=point-Vector2(c.x,c.y)
	if rel.length_squared()>radius*radius*16.0:return 0.0
	var phase:=sin(c.x*0.17+c.y*0.31)*3.1
	var q:=rel.rotated(-phase)
	q.x/=0.83
	q.y/=1.12
	var angle:=atan2(q.y,q.x)
	var d:=q.length()/(1.0+0.075*sin(angle*3.0+phase)+0.045*sin(angle*5.0-phase))
	var bowl:float=-exp(-pow(d/radius,2.4))*float(cr.depth_m)*sqrt(ck)
	var rim:float=exp(-pow((d-radius*1.18)/(radius*0.32),2.0))*float(cr.rim_m)*sqrt(ck)*0.65
	var appear:=smoothstep(0.0,0.13,age)
	return (bowl+rim)*appear*crater_presence(age)
func contact_footprint(point:Vector2,fp:Vector4)->float:
	var age:=t-fp.z
	var settings:Dictionary=D.godzilla.footprint
	var memory:float=settings.memory_s
	if age< -0.07 or age>memory*3.0:return 0.0
	var rel:=point-Vector2(fp.x,fp.y)
	if rel.length_squared()>1600.0:return 0.0
	var forward:=Vector2(sin(fp.w),cos(fp.w))
	var side:=Vector2(forward.y,-forward.x)
	var a:=rel.dot(forward)/float(settings.half_length)
	var b:=rel.dot(side)/float(settings.half_width)
	var radius:=sqrt(a*a+b*b)
	var angle:=atan2(b,a)
	var d:=radius/(1.0+0.10*cos(angle*3.0)*smoothstep(-0.1,0.7,a))
	var dent:float=-exp(-pow(d,2.8))*float(settings.depth)
	var rim:=exp(-pow((d-1.18)/0.30,2.0))*0.32
	return (dent+rim)*smoothstep(-0.07,0.27,age)*exp(-maxf(age,0.0)/memory)
func sand_height(x:float,z:float)->float:
	var point:=Vector2(x,z)
	var height:=dune_height(x,z)
	if maxf(absf(x),absf(z))>450.0:height-=0.8
	if not gz.is_empty() and gz.state!=GZ_WAITING and gz.state!=GZ_WALKING:
		var root:Node3D=gz.root
		var d:=point.distance_to(Vector2(root.position.x,root.position.z))
		height+=-exp(-pow(d/11.0,2.0))*4.2+exp(-pow((d-12.0)/3.5,2.0))*1.5
	for footprint in prints:height+=contact_footprint(point,footprint)
	for crater in craters:height+=contact_crater(point,crater)
	return height
