extends "res://dove_man/water_titan/water_world.gd"
## Moving, spaced cohorts with continuous delay -> sync -> delay gait oscillators.
const REVISION_ROOT="res://dove_man/scrap_desert/"
var revision_ready:=false
var lost_members:Array=[]
var injured_rng:=RandomNumberGenerator.new()
var moving_coherence:=0.0
func _ready()->void:
	var pacing:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REVISION_ROOT+"world_pacing.json"))
	wave_interval=float(pacing.arrival_wave_interval_s)
	next_wave=float(pacing.first_arrival_wave_s)
	super._ready()
	for batch in batches: batch.material.shader=load(REVISION_ROOT+"organised_walk.gdshader")
	for group_index in flocks.size():
		var group:Dictionary=flocks[group_index]
		group["radius"]=170.0
		group["guide_velocity"]=Vector2.ZERO
		configure_organic_group(group,group.members,4100+group_index*97)
		for member in group.members:
			member["formation_offset"]=(member.pos as Vector2)-(group.center as Vector2)
			member["delay"]=fposmod(float(member.index)*0.61803398875,1.0)
			member["gait"]=float(member.actor.phase)
	revision_ready=true
	injured_rng.seed=887733
	create_lost_members()
func create_lost_members()->void:
	for species_index in 3:
		for index in 3:
			var root_node:=Node3D.new()
			root_node.name="LostInjured_%d_%d"%[species_index,index]
			add_child(root_node)
			var actor:=Node3D.new()
			actor.set_script(load(REVISION_ROOT+"injured_actor.gd"))
			root_node.add_child(actor)
			var which:String=["lost_myna","lost_longear","lost_hyena"][species_index]
			actor.setup(which,8.8,9900+species_index*13+index*5,Color(0.27,0.22,0.15)*injured_rng.randf_range(0.8,1.15))
			var angle:=float(species_index)*TAU/3.0+0.35+float(index)*0.22
			var point:=Vector2(sin(angle),cos(angle))*(215.0+index*16.0)
			lost_members.append({"root":root_node,"actor":actor,"pos":point,"velocity":Vector2.ZERO,"heading":angle,"target":point.normalized()*injured_rng.randf_range(340.0,445.0),"choose_at":injured_rng.randf_range(15.0,70.0),"idle_until":-1.0,"mode":"lost","rest_clip":"watch" if index%2==0 else "idle","cruise_speed":injured_rng.randf_range(0.42,0.76)})
func update_mannequins(delta:float)->void:
	super.update_mannequins(delta)
	if not revision_ready or delta<=0.0:return
	for member in lost_members: update_lost(member,delta)
func update_lost(member:Dictionary,delta:float)->void:
	var point:Vector2=member.pos
	if crowd_clock>=float(member.choose_at):
		var outward:=atan2(point.x,point.y)
		var wrong:=injured_rng.randf()<0.65
		var angle:=outward+injured_rng.randf_range(-0.8,0.8) if wrong else injured_rng.randf()*TAU
		member.target=Vector2(sin(angle),cos(angle))*injured_rng.randf_range(310.0,450.0)
		member.choose_at=crowd_clock+injured_rng.randf_range(30.0,65.0)
		member.idle_until=crowd_clock+(injured_rng.randf_range(3.0,12.0) if injured_rng.randf()<0.6 else 0.0)
		member.rest_clip="watch" if injured_rng.randf()<0.45 else "idle"
		member.mode="toward_horizon" if wrong else "wrong_turn"
	var desired:=Vector2.ZERO
	if crowd_clock>float(member.idle_until): desired=(member.target-point).normalized()*float(member.cruise_speed)
	for obstacle in static_discs:
		var offset:Vector2=point-obstacle.position
		var safe:=float(obstacle.radius)+6.0
		if offset.length()<safe: desired+=offset.normalized()*(safe-offset.length())*0.6
	desired+=corridor_offset(point).limit_length(1.0)*3.0
	if point.length()>455.0: desired-=point.normalized()*1.2
	member.velocity=(member.velocity as Vector2).lerp(desired.limit_length(3.0),1.0-exp(-delta*1.5))
	var motion:Vector2=member.velocity*delta
	member.pos+=motion
	member.root.position=Vector3(member.pos.x,sand_height(member.pos.x,member.pos.y)-0.08,member.pos.y)
	if motion.length_squared()>0.000001:member.root.rotation.y=lerp_angle(member.root.rotation.y,atan2(motion.x,motion.y),1.0-exp(-delta*1.8))
	member.actor.update_interval=1.0/12.0
	member.actor.update_pose(delta,motion.length(),"walk" if member.velocity.length()>0.04 else String(member.rest_clip),t/3600.0)
func spawn_wave()->void:
	var previous:=arrivals.size()
	var first_group:=cohorts.size()
	super.spawn_wave()
	for group_index in range(first_group,cohorts.size()):
		var members:Array=[]
		for index in cohorts[group_index].members:members.append(arrivals[index])
		configure_organic_group(cohorts[group_index],members,8100+group_index*137)
	for i in range(previous,arrivals.size()):
		var member:Dictionary=arrivals[i]
		var group:Dictionary=cohorts[int(member.cohort)]
		member["formation_offset"]=(member.pos as Vector2)-(group.center as Vector2)
		member["delay"]=fposmod(float(member.slot%33)*0.61803398875,1.0)
		member["gait"]=float(member.phase)
		member["frequency"]=0.0
		group["guide_velocity"]=Vector2.ZERO
func guide_velocity(group:Dictionary,dt:float)->Vector2:
	var center:Vector2=group.center
	var radial:=center.normalized()
	var tangent:=Vector2(radial.y,-radial.x)
	var gap:=center.length()-float(group.radius)
	var velocity:=tangent*0.92-radial*clampf(gap*0.045,-0.2,1.6)
	# Anticipate solid scenery as a whole group, including the group's footprint.
	for obstacle in static_discs:
		var relative:Vector2=center-obstacle.position
		var safe:=float(obstacle.radius)+float(group.get("footprint",17.0))
		var forward:=velocity.normalized()
		var ahead:float=(-relative).dot(forward)
		if relative.length()<safe+12.0 and ahead> -safe*0.4:
			var normal:=relative.normalized()
			var side:=Vector2(-normal.y,normal.x)
			if side.dot(velocity)<0.0:side=-side
			velocity+=side*1.2+normal*maxf(0.0,safe-relative.length())*0.18
	velocity+=group_corridor_offset(center,group).limit_length(1.0)*3.4
	# Keep cohort centers separated; individual members keep their organic offsets.
	for other in cohorts:
		if is_same(group,other):continue
		var offset:Vector2=center-other.center
		var distance:=offset.length()
		var clearance:=float(group.get("footprint",14.0))+float(other.get("footprint",14.0))+3.0
		if distance<clearance and distance>0.01:velocity+=offset/distance*(clearance-distance)*0.30
	if not corridor_active and velocity.dot(tangent)<0.26:velocity+=tangent*(0.26-velocity.dot(tangent))
	var smoothed:Vector2=(group.get("guide_velocity",Vector2.ZERO) as Vector2).lerp(velocity.limit_length(3.2),1.0-exp(-dt*1.8))
	group.guide_velocity=smoothed
	return smoothed
func formation_target(group:Dictionary,member:Dictionary)->Vector2:
	var offset:Vector2=member.formation_offset
	# Each group breathes around its own uneven layout.
	var phase:=float(group.get("shape_phase",0.0))
	var breathing:=1.04+0.025*sin(crowd_clock*0.055+phase)
	var sway:=0.025*sin(crowd_clock*0.037+phase)
	var target:Vector2=(group.center as Vector2)+offset.rotated(sway)*breathing
	target+=group_corridor_offset(target,group)
	return target
func gait_frequency(current:float,delay:float,dt:float)->float:
	var frequency:=1.0/3.8
	var spread:=spread_at(crowd_clock)
	var rate:float=(spread-spread_at(maxf(0.0,crowd_clock-dt)))/maxf(dt,0.001)
	var desired:=fposmod(crowd_clock*frequency-delay*spread,1.0)
	var feed:=frequency-delay*rate
	var error:=wrapf(desired-fposmod(current+feed*dt,1.0),-0.5,0.5)
	return clampf(feed+error*0.8,frequency*0.6,frequency*1.4)
func advance_arrivals(dt:float)->void:
	if arrivals.is_empty():return
	var velocities:Array=[]
	for group in cohorts:
		var velocity:=guide_velocity(group,dt)
		group.center+=velocity*dt
		group.arrived=absf((group.center as Vector2).length()-float(group.radius))<15.0
		velocities.append(velocity)
	var sum_x:=0.0
	var sum_y:=0.0
	for member in arrivals:
		var group:Dictionary=cohorts[int(member.cohort)]
		var guide:Vector2=velocities[int(member.cohort)]
		var desired:=guide+(formation_target(group,member)-(member.pos as Vector2))*0.35
		desired+=group_corridor_offset(member.pos,group).limit_length(1.0)*3.8
		member.velocity=(member.velocity as Vector2).lerp(desired.limit_length(3.8),1.0-exp(-dt*2.0))
		var movement:Vector2=member.velocity*dt
		member.pos+=movement
		var gait:float=member.get("gait",member.phase)
		var frequency:=0.0
		if movement.length()>0.025*dt:
			frequency=gait_frequency(gait,float(member.get("delay",0.0)),dt) if not corridor_active and (group.center as Vector2).length()<float(group.radius)+35.0 else movement.length()/(dt*float(batches[int(member.species)].stride)*float(member.scale))
		gait=fposmod(gait+frequency*dt,1.0)
		member.gait=gait
		member.frequency=frequency
		var contact:=0.0 if int(member.species)==0 else 0.1875
		member.phase=fposmod(gait+contact,1.0)
		member.joined=group.arrived
		sum_x+=cos(gait*TAU)
		sum_y+=sin(gait*TAU)
		write_arrival(member)
	moving_coherence=Vector2(sum_x,sum_y).length()/float(arrivals.size())
	for batch in batches:batch.material.set_shader_parameter("last_tick",crowd_clock)
func write_arrival(member:Dictionary)->void:
	var point:Vector2=member.pos
	var key:=Vector2i(roundi(point.x/3.0),roundi(point.y/3.0))
	if not terrain_cache.has(key):terrain_cache[key]=sand_height(point.x,point.y)-0.08
	var velocity:Vector2=member.velocity
	var yaw:=atan2(velocity.x,velocity.y) if velocity.length_squared()>0.0001 else atan2(-point.x,-point.y)
	var scale_factor:=float(member.scale)
	var transform:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_factor),Vector3(point.x,terrain_cache[key],point.y))
	var batch:Dictionary=batches[int(member.species)]
	batch.multi.set_instance_transform(int(member.slot),transform)
	batch.multi.set_instance_custom_data(int(member.slot),Color(member.phase,velocity.length()/scale_factor,float(member.get("frequency",0.0)),1.0))
func advance_flocks(dt:float)->void:
	if not revision_ready:
		super.advance_flocks(dt)
		return
	for group in flocks:
		var guide:=guide_velocity(group,dt)
		group.center+=guide*dt
		for member in group.members:
			var desired:=guide+(formation_target(group,member)-(member.pos as Vector2))*0.35+group_corridor_offset(member.pos,group).limit_length(1.0)*3.8
			member.velocity=(member.velocity as Vector2).lerp(desired.limit_length(3.8),1.0-exp(-dt*2.0))
			var motion:Vector2=member.velocity*dt
			member.pos+=motion
			member.root.position=Vector3(member.pos.x,sand_height(member.pos.x,member.pos.y)-0.08,member.pos.y)
			if motion.length_squared()>0.000001:member.root.rotation.y=lerp_angle(member.root.rotation.y,atan2(motion.x,motion.y),1.0-exp(-dt*4.0))
			var frequency:=gait_frequency(member.gait,member.delay,dt) if motion.length()>0.025*dt else 0.0
			if corridor_active:frequency=motion.length()/(maxf(dt,0.001)*float(member.actor.strides.walk))
			member.gait=fposmod(float(member.gait)+frequency*dt,1.0)
			member.actor.phase=fposmod(float(member.gait)+float(member.actor.contact_phase)-(float(member.actor.pending_distance)+motion.length())/float(member.actor.strides.walk),1.0)
			if not skip_flock_pose:
				set_actor_rate(member.actor)
				member.actor.update_pose(dt,motion.length(),"walk" if frequency>0.0 else "idle",t/3600.0)
func update_debug_display()->void:
	super.update_debug_display()
	if debug_label!=null and debug_label.visible:debug_label.text+="\nSPACED COHORTS | GAIT COHERENCE %.2f | 9 LOST INJURED FIGURES"%moving_coherence




func group_corridor_offset(point:Vector2,group:Dictionary)->Vector2:
	if not corridor_active:
		group.erase("evac_side")
		return Vector2.ZERO
	if not group.has("evac_side"):
		var side:float=((group.center as Vector2)-corridor_start).dot(corridor_normal)
		group["evac_side"]=1.0 if side>=0.0 else -1.0
	var chosen:float=group.evac_side
	var side:float=(point-corridor_start).dot(corridor_normal)
	if side*chosen>=72.0:return Vector2.ZERO
	return corridor_normal*(chosen*72.0-side)



func configure_organic_group(group:Dictionary,members:Array,seed_value:int)->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var axis:=Vector2(rng.randf_range(12.5,19.5),rng.randf_range(10.5,16.5))
	var angle:=rng.randf()*TAU
	var phase:=rng.randf()*TAU
	var bend:=rng.randf_range(-0.65,0.65)
	var lobe:=rng.randf_range(0.08,0.30)
	var points:Array[Vector2]=[]
	group["shape_phase"]=phase
	group["footprint"]=0.0
	for member in members:
		var chosen:=Vector2.ZERO
		var accepted:=false
		var personal_gap:=rng.randf_range(2.35,3.7)
		for attempt in 1800:
			var theta:=rng.randf()*TAU
			var radius:=sqrt(rng.randf())*(1.0+0.0003*float(attempt))
			var edge:=1.0+lobe*sin(theta*3.0+phase)
			var candidate:=Vector2(cos(theta)*axis.x,sin(theta)*axis.y)*radius*edge
			candidate.x+=bend*axis.x*pow(candidate.y/axis.y,2.0)
			candidate=candidate.rotated(angle)
			var gap:=INF
			for point in points:gap=minf(gap,candidate.distance_to(point))
			if gap>=personal_gap:
				chosen=candidate
				accepted=true
				break
		assert(accepted,"Organic crowd sampling exhausted")
		points.append(chosen)
		member["formation_offset"]=chosen
		member.pos=(group.center as Vector2)+chosen
		group.footprint=maxf(float(group.footprint),chosen.length()+2.0)

