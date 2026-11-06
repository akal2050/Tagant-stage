extends "res://dove_man/swarm_variant/swarm_world.gd"
## Three species-pure, deformable flocks surrounding the retained procession.
var flocks: Array = []
var flock_members: Array = []
var flock_time := 0.0
var skip_flock_pose := false

func _ready() -> void:
	super._ready()
	for group_index in 3:
		var heading := float(group_index) * TAU / 3.0
		var center := Vector2(sin(heading), cos(heading)) * 170.0
		var flock := {"species": SPECIES[group_index], "members": [], "center": center,
			"heading": heading + PI * 0.5, "leader": 0, "next_leader": 24.0 + group_index * 7.0,
			"leader_changes": 0}
		for index in 33:
			var angle := float(index) * 2.39996323
			var radius := sqrt((float(index) + 0.5) / 33.0) * 14.0
			var point := center + Vector2(cos(angle) * 1.15, sin(angle) * 0.85) * radius
			var holder := Node3D.new()
			holder.name = "%s_Flock_%02d" % [flock.species, index]
			add_child(holder)
			var actor := Node3D.new()
			actor.set_script(ACTOR)
			holder.add_child(actor)
			var palette: Array = settings.palette[(index + group_index) % settings.palette.size()]
			var tint := Color(palette[0], palette[1], palette[2]) * swarm_rng.randf_range(0.88, 1.12)
			tint.a = 1.0
			actor.setup(flock.species, swarm_rng.randf_range(3.7, 5.2), 19800 + group_index * 100 + index, tint)
			actor.phase = swarm_rng.randf()
			var member := {"root": holder, "actor": actor, "pos": point, "velocity": Vector2.ZERO,
				"index": index, "species": flock.species, "travel": 0.0}
			flock.members.append(member)
			flock_members.append(member)
			holder.position = Vector3(point.x, sand_height(point.x, point.y), point.y)
		flocks.append(flock)
	print("ORGANIC FLOCKS READY: 99 circling + 3 species-pure flocks of 33 = 198")

func update_mannequins(delta: float) -> void:
	super.update_mannequins(delta)
	if delta <= 0.0 or flocks.is_empty(): return
	flock_time += delta
	# Bounded integration keeps separation stable after a slow rendered frame.
	var steps := maxi(1, ceili(delta / 0.05))
	for substep in steps:
		advance_flocks(delta / float(steps))

func advance_flocks(dt: float) -> void:
	var outer_pilgrims: Array = []
	for pilgrim in mannequins:
		if float(pilgrim.ring)>95.0: outer_pilgrims.append(pilgrim)
	for group_index in flocks.size():
		var flock: Dictionary = flocks[group_index]
		var center := Vector2.ZERO
		var mean_velocity := Vector2.ZERO
		for member in flock.members:
			center += member.pos
			mean_velocity += member.velocity
		center /= 33.0
		mean_velocity /= 33.0
		flock.center = center
		var radial := center.normalized()
		var tangent := Vector2(radial.y, -radial.x)
		# Broad circulation with meandering radius, well outside the personal rings.
		var desired_radius := 170.0 + 10.0 * sin(flock_time * 0.026 + group_index * 2.1)
		var direction := (tangent + radial * clampf((desired_radius - center.length()) * 0.05, -0.65, 0.65)).normalized()
		if flock_time >= float(flock.next_leader):
			var best := -INF
			for member in flock.members:
				var front := (member.pos as Vector2).dot(direction) + 2.0 * sin(float(member.index) * 3.7 + flock_time)
				if front > best and int(member.index) != int(flock.leader):
					best = front
					flock.leader = member.index
			flock.next_leader = flock_time + 26.0 + group_index * 4.0
			flock.leader_changes += 1
		var leader: Dictionary = flock.members[int(flock.leader)]
		var snapshot: Array = []
		for member in flock.members: snapshot.append(member.pos)
		var velocities: Array = []
		for member in flock.members:
			var point: Vector2 = member.pos
			var separation := Vector2.ZERO
			var local_center := Vector2.ZERO
			var neighbors := 0
			for other_index in snapshot.size():
				if other_index == int(member.index): continue
				var offset: Vector2 = point - snapshot[other_index]
				var distance := offset.length()
				if distance < 9.0:
					local_center += snapshot[other_index]
					neighbors += 1
				if distance < 3.2 and distance > 0.001:
					separation += offset / distance * (3.2 - distance) * 1.5
			var cohesion := (center - point) * 0.075
			if neighbors > 0: cohesion += (local_center / float(neighbors) - point) * 0.035
			var leadership := (leader.pos as Vector2) - point
			leadership = leadership.limit_length(12.0) * 0.025
			if int(member.index) == int(flock.leader): leadership = direction * 0.22
			var sway := Vector2(-direction.y, direction.x) * sin(flock_time * 0.31 + float(member.index) * 1.71) * 0.13
			var desired := direction * 0.94 + cohesion + separation + leadership + mean_velocity * 0.12 + sway
			desired += flock_avoidance(point)
			for obstacle in static_discs:
				var offset: Vector2 = point - obstacle.position
				var safe := float(obstacle.radius) + 4.0
				if offset.length() < safe: desired += offset.normalized() * (safe - offset.length()) * 0.8
			# Yield to retained outer procession if local scenery pushes a flock inward.
			for pilgrim in outer_pilgrims:
				var offset: Vector2 = point - pilgrim.pos
				if offset.length_squared() < 16.0: desired += offset.normalized() * (4.0 - offset.length())
			velocities.append((member.velocity as Vector2).lerp(desired.limit_length(1.65), 1.0 - exp(-dt * 2.2)))
		for index in flock.members.size():
			var member: Dictionary = flock.members[index]
			member.velocity = velocities[index]
			var displacement: Vector2 = member.velocity * dt
			member.pos += displacement
			member.travel += displacement.length()
			var holder: Node3D = member.root
			holder.position = Vector3(member.pos.x, sand_height(member.pos.x, member.pos.y) - 0.08, member.pos.y)
			if displacement.length_squared() > 0.000001:
				holder.rotation.y = lerp_angle(holder.rotation.y, atan2(displacement.x, displacement.y), 1.0 - exp(-dt * 4.0))
			if not skip_flock_pose:
				set_actor_rate(member.actor)
				member.actor.update_pose(dt, displacement.length(), "walk" if displacement.length() > dt * 0.04 else "idle", t / 3600.0)

func update_debug_display() -> void:
	super.update_debug_display()
	if debug_label != null and debug_label.visible:
		debug_label.text += "\nFLOCKS: 3 x 33 | TOTAL: 198 | species stay together"

func update_swarm_view() -> void:
	if flocks.is_empty():
		super.update_swarm_view()
		return
	view_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if inspection == 0:
		var center: Vector2 = flocks[0].center
		var target := Vector3(center.x, sand_height(center.x, center.y) + 2.0, center.y)
		view_camera.position = target + Vector3(25, 15, 25)
		view_camera.fov = 65.0
		view_camera.look_at(target)
	elif inspection == 1:
		view_camera.position = Vector3(310, 215, 310)
		view_camera.fov = 65.0
		view_camera.look_at(Vector3(0, 10, 0))
	else:
		view_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		view_camera.size = 440.0
		view_camera.position = Vector3(0, 450, 0.1)
		view_camera.look_at(Vector3.ZERO, Vector3.FORWARD)

func flock_avoidance(_point: Vector2) -> Vector2:
	return Vector2.ZERO


