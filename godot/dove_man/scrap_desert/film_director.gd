extends "res://dove_man/characters/director.gd"
## Patient hour-long film coverage; close bodies are framed against the existing sun.
func plan_one()->Dictionary:
	var choice:=r.randf()
	if choice<0.14:
		return {"kind":"zenith","len":r.randf_range(65.0,105.0),"height":r.randf_range(620.0,850.0),"fov":62.0,"a0":0.0,"spin":0.0}
	if choice<0.40 and not world.flocks.is_empty():
		return {"kind":"contre_jour","len":r.randf_range(48.0,85.0),"group":r.randi_range(0,world.flocks.size()-1),"distance":r.randf_range(20.0,28.0),"side":r.randf_range(-5.0,5.0),"height":r.randf_range(1.3,2.0),"fov":r.randf_range(40.0,52.0)}
	var result:=super.plan_one()
	result.len=clampf(float(result.len)*1.6,40.0,105.0)
	if result.has("spin"):result.spin*=0.55
	return result
func frame_shot(s:Dictionary,st:float)->Transform3D:
	if s.kind=="contre_jour":
		var group:Dictionary=world.flocks[int(s.group)]
		var center:Vector2=group.center
		var to_sun:Vector3=world.sun.global_basis.z.normalized()
		var light_side:=Vector2(to_sun.x,to_sun.z).normalized()
		var lateral:=Vector2(-light_side.y,light_side.x)
		var point:=center-light_side*float(s.distance)+lateral*(float(s.side)+sin(st*0.017)*1.1)
		var position:=Vector3(point.x,0.0,point.y)
		position.y=ground_clear(position,float(s.height))
		var target:=Vector3(center.x,world.sand_height(center.x,center.y)+2.3,center.y)
		return Transform3D(Basis.looking_at(target-position,Vector3.UP),position)
	var transform:=super.frame_shot(s,st)
	if s.kind!="zenith":
		# Restrained mechanical drift rather than conspicuous handheld shake.
		transform.origin+=transform.basis.x*sin(st*0.23)*0.009
		transform.basis*=Basis(Vector3.FORWARD,sin(st*0.11)*0.00045)
	return transform
func shot_is_bad(s:Dictionary,tr:Transform3D,strict:bool=false)->bool:
	if s.kind!="contre_jour":return super.shot_is_bad(s,tr,strict)
	var point:=Vector2(tr.origin.x,tr.origin.z)
	if point.length()<80.0:return true
	if not world.gz.is_empty() and world.gz.state!=0:
		var position:Vector3=world.gz.root.position
		if point.distance_to(Vector2(position.x,position.z))<90.0:return true
	for group in world.flocks:
		for member in group.members:
			if point.distance_to(member.pos)<2.6:return true
	for camel in world.camels:
		if point.distance_to(camel.pos)<float(camel.height)*1.4:return true
	for dino in world.dinos:
		if point.distance_to(dino.pos)<float(dino.h)*1.0:return true
	return false
