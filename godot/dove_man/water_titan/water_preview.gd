extends Node3D
var titan: Node3D
var player: AnimationPlayer
var surface: Node3D
var camera: Camera3D
var clock:=0.0
func _ready():
	var environment=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.34,0.30,0.23)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.55,0.65,0.7)
	env.ambient_light_energy=0.7
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	add_child(environment)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-36,-32,0)
	sun.light_energy=2.4
	sun.shadow_enabled=true
	add_child(sun)
	var rim=DirectionalLight3D.new()
	rim.rotation_degrees=Vector3(-24,135,0)
	rim.light_color=Color(0.55,0.78,0.85)
	rim.light_energy=1.5
	add_child(rim)
	var plane=MeshInstance3D.new()
	var ground=PlaneMesh.new()
	ground.size=Vector2(1000,1000)
	plane.mesh=ground
	var mat=StandardMaterial3D.new()
	mat.albedo_color=Color(0.38,0.29,0.18)
	mat.roughness=1.0
	plane.material_override=mat
	add_child(plane)
	titan=Node3D.new()
	add_child(titan)
	var model=load("res://assets/godzilla/scene.gltf").instantiate()
	model.scale=Vector3.ONE*0.0736957
	model.position.y=2.9171
	titan.add_child(model)
	player=find_player(model)
	player.play("Armature|ArmatureAction")
	player.speed_scale=0.0
	player.seek(0.0,true)
	surface=Node3D.new()
	surface.set_script(load("res://dove_man/water_titan/water_surface.gd"))
	titan.add_child(surface)
	surface.setup(model,52.0)
	camera=Camera3D.new()
	camera.far=1500.0
	camera.position=Vector3(49,30,49)
	add_child(camera)
	camera.look_at(Vector3(0,26,-4))
	camera.current=true
func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found=find_player(child)
		if found!=null: return found
	return null
func _process(delta):
	if player==null or surface==null: return
	clock+=delta
	var length=player.get_animation("Armature|ArmatureAction").length
	player.seek(fposmod(clock,length),true)
	surface.update_surface(delta,1.0)
func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_1: camera.position=Vector3(49,30,49)
		if event.keycode==KEY_2: camera.position=Vector3(46,45,-55)
		if event.keycode==KEY_3: camera.position=Vector3(25,40,-32)
		camera.look_at(Vector3(0,26,-4))
