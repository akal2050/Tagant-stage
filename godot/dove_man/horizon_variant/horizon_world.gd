extends "res://dove_man/flock_variant/flock_world.gd"
## Ongoing species-pure arrivals; GPU copies of the original walking clips.
const HORIZON_ROOT := "res://dove_man/horizon_variant/"
var arrivals: Array = []
var cohorts: Array = []
var batches: Array = []
var crowd_clock := 0.0
var next_wave := 0.0
var waves := 0
var wave_limit := 30
var wave_interval := 12.0
var crowd_tick := 0.0
var crowd_grid: Dictionary = {}
var terrain_cache: Dictionary = {}
var evacuation: Dictionary = {}
var evacuation_sides: Dictionary = {}
var corridor_active := false
var corridor_normal := Vector2.ZERO
var corridor_start := Vector2.ZERO
var corridor_direction := Vector2.ZERO
var crowd_ready := false

func _ready() -> void:
	super._ready()
	for species in SPECIES:
		var instance := MultiMeshInstance3D.new()
		instance.name = species + "_ArrivingCrowd"
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = load(HORIZON_ROOT + "assets/" + species + "_vat_mesh.res")
		multi.instance_count = wave_limit * 33
		multi.visible_instance_count = 0
		multi.custom_aabb = AABB(Vector3(-650,-100,-650),Vector3(1300,400,1300))
		instance.multimesh = multi
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = load(HORIZON_ROOT + "crowd_walk.gdshader")
		material.set_shader_parameter("pose_positions",load(HORIZON_ROOT + "assets/" + species + "_positions.res"))
		material.set_shader_parameter("pose_normals",load(HORIZON_ROOT + "assets/" + species + "_normals.res"))
		var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HORIZON_ROOT + "assets/" + species + "_motion.json"))
		material.set_shader_parameter("stride",motion.stride)
		instance.material_override = material
		add_child(instance)
		batches.append({"multi":multi,"material":material,"count":0,"stride":float(motion.stride)})
	crowd_ready = true
	print("HORIZON CROWD READY: unchanged walks; 198 initial, capacity 3168; G triggers Godzilla")

func update_mannequins(delta: float) -> void:
	update_corridor()
	var previous_orbits: Dictionary = {}
	for member in mannequins:
		if not member.has("orbit_radius"): continue
		previous_orbits[member.root.get_instance_id()]={"position":Vector2(member.root.position.x,member.root.position.z),"angle":float(member.angle)}
		var nominal: Vector2 = Vector2(sin(member.angle),cos(member.angle))*float(member.orbit_radius)
		var target := Vector2.ZERO
		if corridor_active:
			var id: int = member.root.get_instance_id()
			var side := (nominal-corridor_start).dot(corridor_normal)
			if not evacuation_sides.has(id): evacuation_sides[id]=1.0 if side>=0.0 else -1.0
			var chosen := float(evacuation_sides[id])
			if side*chosen<72.0: target=corridor_normal*(chosen*72.0-side)
		else:
			evacuation_sides.clear()
		var current: Vector2 = evacuation.get(member.root.get_instance_id(),Vector2.ZERO)
		evacuation[member.root.get_instance_id()] = current.move_toward(target,3.5*delta)
	super.update_mannequins(delta)
	for member in mannequins:
		var id: int = member.root.get_instance_id()
		if not previous_orbits.has(id): continue
		var offset: Vector2 = evacuation.get(id,Vector2.ZERO)
		if not corridor_active and offset.length_squared()<0.001: continue
		var previous: Dictionary = previous_orbits[id]
		var actual_motion := Vector2(member.root.position.x,member.root.position.z)-(previous.position as Vector2)
		var orbit_distance := absf(float(member.angle)-float(previous.angle))*float(member.orbit_radius)
		var extra := actual_motion.length()-orbit_distance
		var stride: float = member.actor.strides.walk
		member.cycle=fposmod(float(member.cycle)+extra/stride,1.0)
		member.actor.phase=member.cycle
		member.actor.pending_distance=maxf(0.0,float(member.actor.pending_distance)+extra)
		member.step+=extra/stride*2.0
		if actual_motion.length_squared()>0.000001:
			member.root.rotation.y=atan2(actual_motion.x,actual_motion.y)
	if not crowd_ready or delta <= 0.0: return
	crowd_clock += delta
	if crowd_clock >= next_wave and waves < wave_limit:
		spawn_wave()
		next_wave += wave_interval
	crowd_tick += delta
	if crowd_tick >= 0.5:
		var step := minf(crowd_tick,0.6)
		crowd_tick = 0.0
		advance_arrivals(step)
	for batch in batches: batch.material.set_shader_parameter("clock",crowd_clock)

func orbit_position(member: Dictionary, angle: float) -> Vector2:
	return super.orbit_position(member,angle) + evacuation.get(member.root.get_instance_id(),Vector2.ZERO)

func update_corridor() -> void:
	corridor_active = not gz.is_empty() and int(gz.state) != GZ_WAITING
	if corridor_active:
		corridor_start = gz.start
		corridor_direction = gz.dir
		corridor_normal = Vector2(-corridor_direction.y,corridor_direction.x)

func corridor_offset(point: Vector2) -> Vector2:
	if not corridor_active: return Vector2.ZERO
	var along := (point-corridor_start).dot(corridor_direction)
	if along < -40.0 or along > float(gz.length)+80.0: return Vector2.ZERO
	var side := (point-corridor_start).dot(corridor_normal)
	var clearance := 72.0
	if absf(side) >= clearance: return Vector2.ZERO
	return corridor_normal * (1.0 if side>=0.0 else -1.0) * (clearance-absf(side))

func flock_avoidance(point: Vector2) -> Vector2:
	return corridor_offset(point).limit_length(1.0)*4.0

func spawn_wave() -> void:
	for group_index in 3:
		var angle := float(group_index)*TAU/3.0 + 0.26*sin(float(waves)*1.7)
		var center := Vector2(sin(angle),cos(angle))*460.0
		var cohort := {"center":center,"angle":angle,"radius":90.0+fposmod(float(waves)*37.0+group_index*23.0,120.0),
			"members":[],"species":group_index,"arrived":false}
		for i in 33:
			var spread_angle := float(i)*2.39996323
			var spread_radius := sqrt((float(i)+0.5)/33.0)*10.5
			var position := center+Vector2(cos(spread_angle),sin(spread_angle))*spread_radius
			var batch: Dictionary = batches[group_index]
			var index := int(batch.count)
			batch.count += 1
			var member := {"pos":position,"velocity":Vector2.ZERO,"phase":swarm_rng.randf(),"scale":swarm_rng.randf_range(0.88,1.18),
				"species":group_index,"slot":index,"cohort":cohorts.size(),"joined":false}
			arrivals.append(member)
			cohort.members.append(arrivals.size()-1)
			var palette: Array = settings.palette[(i+waves)%settings.palette.size()]
			var tint := Color(palette[0],palette[1],palette[2])*swarm_rng.randf_range(0.85,1.15)
			tint.a=1.0
			batch.multi.set_instance_color(index,tint)
			write_arrival(member)
			batch.multi.visible_instance_count=batch.count
		cohorts.append(cohort)
	waves += 1

func advance_arrivals(dt: float) -> void:
	crowd_grid.clear()
	# Terrain is sampled on a persistent coarse grid for the distant crowd.
	for i in arrivals.size():
		var member: Dictionary = arrivals[i]
		var key := Vector2i(floori(member.pos.x/4.0),floori(member.pos.y/4.0))
		if not crowd_grid.has(key): crowd_grid[key]={"sum":Vector2.ZERO,"count":0}
		crowd_grid[key].sum += member.pos
		crowd_grid[key].count += 1
	var cohort_velocity: Array = []
	for cohort in cohorts:
		var center: Vector2 = cohort.center
		var radial := center.normalized()
		var tangent := Vector2(radial.y,-radial.x)
		var gap := center.length()-float(cohort.radius)
		var velocity := tangent*1.15-radial*clampf(gap*0.045,-0.25,1.9)
		velocity += corridor_offset(center).limit_length(1.0)*3.2
		cohort.center += velocity*dt
		cohort.arrived = absf(gap)<14.0
		cohort_velocity.append(velocity)
	var new_velocities: Array = []
	for member in arrivals:
		var point: Vector2 = member.pos
		var cohort: Dictionary = cohorts[int(member.cohort)]
		var velocity: Vector2 = cohort_velocity[int(member.cohort)] + ((cohort.center as Vector2)-point)*0.11
		var key := Vector2i(floori(point.x/4.0),floori(point.y/4.0))
		var repulsion := Vector2.ZERO
		for dx in range(-1,2):
			for dz in range(-1,2):
				var cell_key := key+Vector2i(dx,dz)
				if not crowd_grid.has(cell_key): continue
				var cell: Dictionary = crowd_grid[cell_key]
				var count := int(cell.count)-(1 if cell_key==key else 0)
				if count<=0: continue
				var sum: Vector2 = cell.sum-(point if cell_key==key else Vector2.ZERO)
				var offset: Vector2 = point-sum/float(count)
				var distance := offset.length()
				if distance<3.0 and distance>0.001:
					repulsion += offset/distance*(3.0-distance)*minf(sqrt(float(count)),2.5)*0.85
		velocity += repulsion + corridor_offset(point).limit_length(1.0)*4.0
		for obstacle in static_discs:
			var offset: Vector2 = point-obstacle.position
			var safe := float(obstacle.radius)+2.0
			if offset.length_squared()<safe*safe: velocity+=offset.normalized()*(safe-offset.length())
		new_velocities.append((member.velocity as Vector2).lerp(velocity.limit_length(3.5),1.0-exp(-dt*2.5)))
	for i in arrivals.size():
		var member: Dictionary = arrivals[i]
		member.velocity = new_velocities[i]
		var movement: Vector2 = member.velocity*dt
		member.pos += movement
		member.phase = fposmod(float(member.phase)+movement.length()/(float(batches[int(member.species)].stride)*float(member.scale)),1.0)
		member.joined = bool(cohorts[int(member.cohort)].arrived)
		write_arrival(member)
	for batch in batches: batch.material.set_shader_parameter("last_tick",crowd_clock)

func write_arrival(member: Dictionary) -> void:
	var point: Vector2 = member.pos
	var key := Vector2i(roundi(point.x/3.0),roundi(point.y/3.0))
	if not terrain_cache.has(key): terrain_cache[key]=sand_height(point.x,point.y)-0.08
	var velocity: Vector2 = member.velocity
	var yaw := atan2(velocity.x,velocity.y) if velocity.length_squared()>0.0001 else atan2(-point.x,-point.y)
	var scale_factor := float(member.scale)
	var transform := Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_factor),Vector3(point.x,terrain_cache[key],point.y))
	var batch: Dictionary = batches[int(member.species)]
	batch.multi.set_instance_transform(int(member.slot),transform)
	batch.multi.set_instance_custom_data(int(member.slot),Color(member.phase,0.0,velocity.length()/(float(batch.stride)*scale_factor),1.0))

func update_debug_display() -> void:
	super.update_debug_display()
	if debug_label!=null and debug_label.visible:
		debug_label.text+="\nHORIZON %d / 3168 | WAVES %d / 30 | CORRIDOR %s" % [198+arrivals.size(),waves,"OPENING" if corridor_active else "RESTING"]

func set_actor_rate(actor: Node3D) -> void:
	super.set_actor_rate(actor)
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var distant := camera.global_position.distance_to(actor.global_position)>95.0
	if actor.has_meta("horizon_distant") and actor.get_meta("horizon_distant") == distant: return
	actor.set_meta("horizon_distant",distant)
	var mesh: Mesh = load(HORIZON_ROOT+"assets/"+actor.species+".res") if distant else load("res://dove_man/swarm_variant/meshes/"+actor.species+".res")
	for node in actor.meshes: node.mesh=mesh





