extends Node3D
var world:Node3D
var aircraft:Array=[]
func setup(owner_world:Node3D)->void:
	world=owner_world
	var radii:Array=[65.0,105.0,150.0,200.0,255.0,315.0,380.0]
	var heights:Array=[132.0,165.0,105.0,215.0,175.0,245.0,145.0]
	var sizes:Array=[1.0,0.55,0.8,1.25,1.7,0.95,2.1]
	var speeds:Array=[0.0035,0.0027,0.0021,0.0017,0.0013,0.0011,0.00085]
	var pulls:Array=[0.028,0.012,0.035,0.008,0.020,0.006,0.016]
	for index in 7:
		var orbit:Node3D
		var spin:Node3D
		if index==0:
			orbit=world.boeing.orbit
			spin=world.boeing.spin
		else:
			orbit=Node3D.new()
			orbit.name="Aircraft_Ring_%d"%index
			world.add_child(orbit)
			spin=Node3D.new()
			orbit.add_child(spin)
			var vertical:=Node3D.new()
			vertical.rotation.x=PI*0.5
			spin.add_child(vertical)
			var model:Node3D=world.load_model(world.D.models.boeing)
			vertical.add_child(model)
			model.scale*=float(sizes[index])
			var material:=ShaderMaterial.new()
			material.shader=load("res://dove_man/scrap_desert/aircraft_rust.gdshader")
			material.set_shader_parameter("rust_amount",[0.1,0.25,0.5,0.82,0.95,0.42,0.72][index])
			material.set_shader_parameter("variation",float(index)*0.137)
			for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):mesh.material_override=material
		aircraft.append({"orbit":orbit,"spin":spin,"radius":radii[index],"radial":radii[index],"radial_velocity":0.0,"height":heights[index],"size":sizes[index],"speed":speeds[index],"pull":pulls[index],"phase":float(index)*2.39996323,"tilt":float(index%3-1)*0.11})
	advance(0.0,0.0,0.0)
	print("SLOW_AIRCRAFT_FLEET_READY 7 aircraft; independent rings, rust, scales and orbital pull")
func advance(delta:float,clock:float,air:float)->void:
	for craft in aircraft:
		var phase:float=craft.phase
		var angle:=phase+clock*float(craft.speed)
		var altitude:float=craft.height+sin(angle)*float(craft.radius)*float(craft.tilt)+sin(clock*0.009+phase)*4.0
		var safe:float=world.boeing_min_radius(angle,altitude)+maxf(0.0,float(craft.size)-1.0)*32.0
		var desired:=maxf(float(craft.radius)+sin(clock*0.012+phase)*9.0+air*2.0,safe)
		var remaining:=minf(delta,1.0)
		while remaining>0.0:
			var dt:=minf(remaining,0.05)
			craft.radial_velocity+=((desired-float(craft.radial))*float(craft.pull)-float(craft.radial_velocity)*sqrt(float(craft.pull))*1.7)*dt
			craft.radial+=float(craft.radial_velocity)*dt
			remaining-=dt
		craft.radial=maxf(float(craft.radial),safe)
		var radius:float=craft.radial
		craft.orbit.position=Vector3(cos(angle)*radius,altitude,sin(angle)*radius)
		craft.orbit.rotation.y=-angle+PI*0.5
		craft.spin.rotation=Vector3(0.12*sin(clock*0.012+phase),clock*0.003*(0.7+float(craft.size)*0.2)+phase,0.1*sin(clock*0.009+phase))
