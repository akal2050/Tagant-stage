extends "res://dove_man/scrap_desert/scrap_world.gd"
## CROWD FIX (24 Oct 2026) - an additive layer on top of the scrap desert (nothing underneath is edited).
## AZ: "can you fix these problems?" after the crowd check
## (dove_man/scrap_desert/checks/DOVE_MAN_CROWD_CHECK_2026-10-24.md). What this layer changes:
##  1. one shared collision step for every crowd (orbit walkers, flocks, arrivals, injured giants) against each other
##     and against everything solid (hills, loose wrecks, petrified figures, landed cars, palms, rock camels, camels,
##     dinosaurs, Godzilla, the base of Dove Man);
##  2. during a Godzilla crossing the crowd steps aside into a band 72-130 m from his path, keeping its order
##     (no more single file), and the walkers turn smoothly instead of snapping;
##  3. the arriving crowd casts shadows and wears darker skin tones;
##  4. the arriving crowd is drawn one tick behind its simulation, so it glides instead of jumping, and its ground
##     height is exact wherever a crater, a footprint or Godzilla's pit is changing the sand;
##  5. step rate stays within 10 % of the real walking speed (no skating), very slow figures stand instead of
##     stepping on the spot;
##  6. the injured giants stay inside 400 m, turn before they walk (no backwards walking) and animate at 30 fps
##     when the camera is near;
##  7. the near/far mesh swap has a margin (switches at 110 m going away, 82 m coming back), animation rate follows
##     the figure's size on screen;
##  8. the step at the edge of the 900 m sand plane is gone;
##  9. the aircraft keep their wings clear of the Dove Man body;
## 10. Godzilla's crossings and everything drawn after loading follow a fixed seed. What the base world draws while
##     loading (it calls rng.randomize() itself) still differs run to run; making that fixed needs a one-line change
##     in dove_man_world.gd, which this layer does not touch.
## 11. Godzilla's three routes are moved out so they pass at least 165 m from Dove Man, outside the walkers' ring.
const LANE_IN := 72.0
const LANE_OUT := 250.0          # groups: the whole band out to 250 m makes room, so nobody is squeezed
const LANE_OUT_RING := 100.0     # the ring walkers near Dove Man
const WINDOW := 150.0            # only the stretch of his path near Godzilla is cleared (ahead and behind him)
const ROUTE_MIN_R := 165.0       # Godzilla's path keeps this far from Dove Man, outside the walkers' ring
const DOVE_CLEAR := 36.0
const DOVE_BODY := 31.0
const CELL := 6.0
const ACELL := 1.6
var lane_offset: Dictionary = {}
var lane_side: Dictionary = {}
var nudge: Dictionary = {}
var prev_yaw: Dictionary = {}
var solid_grid: Dictionary = {}      # static solids: Vector2i -> Array of {p, r}
var resolve_clock := 0.0
var static_ground: Dictionary = {}  # Vector2i (3 m cell) -> dune height, never changes
var live_cells: Dictionary = {}     # 40 m cells where craters / footprints / the pit are reshaping the sand
var fix_ready := false
var fix_stats := {"pushes": 0}
var arrival_iterations := 1
var parity := 0
var body_iterations := 2
var ar: Dictionary = {}             # the arrival collision pass in progress

func _ready() -> void:
	super._ready()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arrival_iterations="): arrival_iterations = int(a.split("=")[1])
	rng.seed = 20261024                                   # the same hour every run
	if not gz.is_empty() and gz.has("schedule"): gz["schedule"] = gz_schedule()
	for node in find_children("*_ArrivingCrowd", "MultiMeshInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var far := get_node_or_null("Far_Dunes")
	if far: (far as Node3D).position.y = -0.05
	shift_routes()
	build_solids()
	fix_ready = true
	print("CROWD FIX READY: shared collision, evacuation band, arrival shadows + darker skins, gliding arrivals, live ground, seeded hour")

# ------------------------------------------------------------------ ground: no step at the edge of the sand plane
func sand_height(x: float, z: float) -> float:
	var h := super.sand_height(x, z)
	if maxf(absf(x), absf(z)) > 450.0: h += 0.75
	return h

# ------------------------------------------------------------------ aircraft keep their wings off Dove Man
func boeing_min_radius(angle: float, alt: float) -> float:
	return super.boeing_min_radius(angle, alt) + 30.0

# ------------------------------------------------------------------ darker skins for the arriving waves
func spawn_wave() -> void:
	var first := arrivals.size()
	super.spawn_wave()
	var tones := [Color(0.16, 0.11, 0.07), Color(0.22, 0.15, 0.09), Color(0.12, 0.10, 0.08), Color(0.27, 0.19, 0.12), Color(0.19, 0.15, 0.11), Color(0.25, 0.15, 0.08)]
	for i in range(first, arrivals.size()):
		var m: Dictionary = arrivals[i]
		var c: Color = tones[(i * 7 + waves) % tones.size()] * swarm_rng.randf_range(0.85, 1.15)
		c.a = 1.0
		(batches[int(m.species)].multi as MultiMesh).set_instance_color(int(m.slot), c)

# ------------------------------------------------------------------ the evacuation band (replaces the 72 m line)
func band_offset(point: Vector2, chosen: float, outer := LANE_OUT) -> Vector2:
	var along := (point - corridor_start).dot(corridor_direction)
	if along < -60.0 or along > float(gz.get("length", 1400.0)) + 100.0: return Vector2.ZERO
	var g := 0.0
	if gz.has("root"): g = (Vector2(gz.root.position.x, gz.root.position.z) - corridor_start).dot(corridor_direction)
	var window := 1.0 - smoothstep(WINDOW, WINDOW + 40.0, absf(along - g))
	if window <= 0.0: return Vector2.ZERO
	var s := maxf((point - corridor_start).dot(corridor_normal) * chosen, -LANE_IN)
	if s >= outer: return Vector2.ZERO
	var f := LANE_IN + (s + LANE_IN) * (outer - LANE_IN) / (outer + LANE_IN)
	return corridor_normal * chosen * (f - s) * window

func group_corridor_offset(point: Vector2, group: Dictionary) -> Vector2:
	if not corridor_active:
		group.erase("evac_side")
		return Vector2.ZERO
	if not group.has("evac_side"):
		var side: float = ((group.center as Vector2) - corridor_start).dot(corridor_normal)
		group["evac_side"] = 1.0 if side >= 0.0 else -1.0
	return band_offset(point, float(group.evac_side))

func orbit_position(member: Dictionary, angle: float) -> Vector2:
	var p := super.orbit_position(member, angle)
	if not fix_ready: return p
	var id: int = member.root.get_instance_id()
	p -= evacuation.get(id, Vector2.ZERO)
	p += lane_offset.get(id, Vector2.ZERO) + nudge.get(id, Vector2.ZERO)
	if p.length() < DOVE_CLEAR: p = p.normalized() * DOVE_CLEAR
	return p

func update_mannequins(delta: float) -> void:
	if delta <= 0.0 or not fix_ready:
		super.update_mannequins(delta)
		return
	update_corridor()
	for m in mannequins:
		if not m.has("orbit_radius"): continue
		var id: int = m.root.get_instance_id()
		var target := Vector2.ZERO
		if corridor_active:
			var nominal := Vector2(sin(m.angle), cos(m.angle)) * float(m.orbit_radius)
			if not lane_side.has(id): lane_side[id] = 1.0 if (nominal - corridor_start).dot(corridor_normal) >= 0.0 else -1.0
			target = band_offset(nominal, float(lane_side[id]), LANE_OUT_RING)
		else:
			lane_side.erase(id)
		lane_offset[id] = (lane_offset.get(id, Vector2.ZERO) as Vector2).move_toward(target, 3.0 * delta)
		prev_yaw[id] = (m.root as Node3D).rotation.y
	super.update_mannequins(delta)
	for m in mannequins:
		var id: int = m.root.get_instance_id()
		if prev_yaw.has(id): (m.root as Node3D).rotation.y = lerp_angle(float(prev_yaw[id]), (m.root as Node3D).rotation.y, 1.0 - exp(-delta * 3.0))
	resolve_arrival_slice(ceili(arrivals.size() / 8.0) + 1)
	resolve_clock += delta
	if resolve_clock >= 0.1:
		resolve_bodies(resolve_clock)
		resolve_clock = 0.0

# ------------------------------------------------------------------ arrivals: step rate locked to speed, shared collision
func advance_arrivals(dt: float) -> void:
	if arrivals.is_empty(): return
	var velocities: Array = []
	for group in cohorts:
		var velocity := guide_velocity(group, dt)
		group.center += velocity * dt
		group.arrived = absf((group.center as Vector2).length() - float(group.radius)) < 15.0
		velocities.append(velocity)
	var sum_x := 0.0
	var sum_y := 0.0
	for member in arrivals:
		var group: Dictionary = cohorts[int(member.cohort)]
		var guide: Vector2 = velocities[int(member.cohort)]
		var desired: Vector2 = guide + (formation_target(group, member) - (member.pos as Vector2)) * 0.35
		desired += group_corridor_offset(member.pos, group).limit_length(1.0) * 3.8
		member.velocity = (member.velocity as Vector2).lerp(desired.limit_length(3.8), 1.0 - exp(-dt * 2.0))
		var movement: Vector2 = member.velocity * dt
		member.pos += movement
		var gait: float = member.get("gait", member.phase)
		var stride_m := float(batches[int(member.species)].stride) * float(member.scale)
		var f_dist := movement.length() / (maxf(dt, 0.001) * stride_m)
		var frequency := 0.0
		if movement.length() > 0.12 * dt:
			frequency = f_dist
			if not corridor_active and (group.center as Vector2).length() < float(group.radius) + 35.0:
				frequency = clampf(gait_frequency(gait, float(member.get("delay", 0.0)), dt), f_dist * 0.9, f_dist * 1.1)
		gait = fposmod(gait + frequency * dt, 1.0)
		member.gait = gait
		member.frequency = frequency
		var contact := 0.0 if int(member.species) == 0 else 0.1875
		member.phase = fposmod(gait + contact, 1.0)
		member.joined = group.arrived
		sum_x += cos(gait * TAU)
		sum_y += sin(gait * TAU)
	resolve_arrival_slice(1 << 30)     # finish any pass still open
	resolve_arrivals()
	mark_live_ground()
	for member in arrivals:
		member["tick_dt"] = dt
		write_arrival(member)
	moving_coherence = Vector2(sum_x, sum_y).length() / float(arrivals.size())
	for batch in batches: batch.material.set_shader_parameter("last_tick", crowd_clock)

func advance_flocks(dt: float) -> void:
	if not revision_ready or not fix_ready:
		super.advance_flocks(dt)
		return
	for group in flocks:
		var guide := guide_velocity(group, dt)
		group.center += guide * dt
		for member in group.members:
			var desired: Vector2 = guide + (formation_target(group, member) - (member.pos as Vector2)) * 0.35 + group_corridor_offset(member.pos, group).limit_length(1.0) * 3.8
			member.velocity = (member.velocity as Vector2).lerp(desired.limit_length(3.8), 1.0 - exp(-dt * 2.0))
			var motion: Vector2 = member.velocity * dt
			member.pos += motion
			member.root.position = Vector3(member.pos.x, sand_height(member.pos.x, member.pos.y) - 0.08, member.pos.y)
			if motion.length_squared() > 0.000001: member.root.rotation.y = lerp_angle(member.root.rotation.y, atan2(motion.x, motion.y), 1.0 - exp(-dt * 4.0))
			var stride := float(member.actor.strides.walk)
			var f_dist := motion.length() / (maxf(dt, 0.001) * stride)
			var frequency := 0.0
			if motion.length() > 0.12 * dt:
				frequency = f_dist if corridor_active else clampf(gait_frequency(member.gait, member.delay, dt), f_dist * 0.9, f_dist * 1.1)
			member.gait = fposmod(float(member.gait) + frequency * dt, 1.0)
			member.actor.phase = fposmod(float(member.gait) + float(member.actor.contact_phase) - (float(member.actor.pending_distance) + motion.length()) / stride, 1.0)
			if not skip_flock_pose:
				set_actor_rate(member.actor)
				member.actor.update_pose(dt, motion.length(), "walk" if frequency > 0.0 else "idle", t / 3600.0)

# ------------------------------------------------------------------ the injured giants
func update_lost(member: Dictionary, delta: float) -> void:
	var point: Vector2 = member.pos
	if crowd_clock >= float(member.choose_at):
		var outward := atan2(point.x, point.y)
		var wrong := injured_rng.randf() < 0.65
		var angle := outward + injured_rng.randf_range(-0.8, 0.8) if wrong else injured_rng.randf() * TAU
		member.target = Vector2(sin(angle), cos(angle)) * injured_rng.randf_range(250.0, 395.0)
		member.choose_at = crowd_clock + injured_rng.randf_range(30.0, 65.0)
		member.idle_until = crowd_clock + (injured_rng.randf_range(3.0, 12.0) if injured_rng.randf() < 0.6 else 0.0)
		member.rest_clip = "watch" if injured_rng.randf() < 0.45 else "idle"
		member.mode = "toward_horizon" if wrong else "wrong_turn"
	var desired := Vector2.ZERO
	if crowd_clock > float(member.idle_until): desired = (member.target - point).normalized() * float(member.cruise_speed)
	for obstacle in static_discs:
		var offset: Vector2 = point - obstacle.position
		var safe := float(obstacle.radius) + 6.0
		if offset.length() < safe: desired += offset.normalized() * (safe - offset.length()) * 0.6
	desired += corridor_offset(point).limit_length(1.0) * 3.0
	if point.length() > 400.0: desired -= point.normalized() * 1.2
	# turn first, then walk: no walking backwards
	var facing := Vector2(sin((member.root as Node3D).rotation.y), cos((member.root as Node3D).rotation.y))
	if desired.length() > 0.05 and facing.dot(desired.normalized()) < 0.2: desired *= 0.15
	member.velocity = (member.velocity as Vector2).lerp(desired.limit_length(3.0), 1.0 - exp(-delta * 1.5))
	var motion: Vector2 = member.velocity * delta
	member.pos += motion
	member.root.position = Vector3(member.pos.x, sand_height(member.pos.x, member.pos.y) - 0.08, member.pos.y)
	var heading := desired if desired.length() > 0.05 else (member.velocity as Vector2)
	if heading.length_squared() > 0.0001: member.root.rotation.y = lerp_angle(member.root.rotation.y, atan2(heading.x, heading.y), 1.0 - exp(-delta * 3.5))
	var camera := get_viewport().get_camera_3d()
	var near := camera != null and camera.global_position.distance_to(member.root.global_position) < 160.0
	member.actor.update_interval = 1.0 / (30.0 if near else 12.0)
	member.actor.update_pose(delta, motion.length(), "walk" if (member.velocity as Vector2).length() > 0.04 else String(member.rest_clip), t / 3600.0)

# ------------------------------------------------------------------ animation rate by size on screen, mesh swap with a margin
func set_actor_rate(actor: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var d := camera.global_position.distance_to(actor.global_position)
	var size := maxf(float(actor.get("size_m")), 1.0)
	var k := d / size
	var rate := float(settings.near_animation_hz) if k < 30.0 else (float(settings.mid_animation_hz) if k < 55.0 else float(settings.far_animation_hz))
	var seen := false
	for h in [0.05, 0.5, 0.95]:
		if camera.is_position_in_frustum(actor.global_position + Vector3(0, size * h, 0)): seen = true; break
	if not seen: rate = minf(rate, float(settings.offscreen_animation_hz))
	actor.update_interval = 1.0 / rate
	if not ("meshes" in actor) or not ("species" in actor): return
	var distant: bool = actor.get_meta("horizon_distant", false)
	var want := distant
	if distant and d < 82.0: want = false
	elif not distant and d > 110.0: want = true
	if actor.has_meta("horizon_distant") and want == distant: return
	actor.set_meta("horizon_distant", want)
	var mesh: Mesh = load(HORIZON_ROOT + "assets/" + actor.species + ".res") if want else load("res://dove_man/swarm_variant/meshes/" + actor.species + ".res")
	for node in actor.meshes: node.mesh = mesh

# ------------------------------------------------------------------ shared collision
func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

func grid_insert(grid: Dictionary, p: Vector2, r: float, item: Dictionary) -> void:
	var a := cell_of(p - Vector2(r, r)); var b := cell_of(p + Vector2(r, r))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var k := Vector2i(x, y)
			if not solid_grid_has(grid, k): grid[k] = []
			grid[k].append(item)

func solid_grid_has(grid: Dictionary, k: Vector2i) -> bool:
	return grid.has(k)

# Godzilla's three crossing lines ran 100-120 m from Dove Man, right through the walkers' ring (35-122 m), so the
# ring had to be squeezed against the monument. Each line is moved outward, parallel, to the first offset that keeps
# 165 m from Dove Man and still clears the wreck hills and the petrified deposits.
func shift_routes() -> void:
	var moved := 0
	for i in range(ruin_routes.size()):
		var r: Array = ruin_routes[i]
		var a: Vector2 = r[0]; var b: Vector2 = r[1]
		var dir := (b - a).normalized(); var nrm := Vector2(-dir.y, dir.x)
		var away := 1.0 if (Vector2.ZERO - a).dot(nrm) < 0.0 else -1.0       # the normal pointing away from the centre
		var best: Array = []
		for k in range(0, 31):
			var off := nrm * away * float(k) * 6.0
			var a2 := a + off; var b2 := b + off
			if segment_distance(Vector2.ZERO, a2, b2) < ROUTE_MIN_R: continue
			var clear := true
			for hill in scrap_hills:
				if segment_distance(hill.position, a2, b2) < float(hill.radius) + 27.0: clear = false; break
			if clear and frozen_ruins != null:
				for site in frozen_ruins.sites:
					var ax: Vector2 = site.axes
					if segment_distance(site.center, a2, b2) < maxf(ax.x, ax.y) + 30.0: clear = false; break
			if clear: best = [a2, b2]; break
		if not best.is_empty(): ruin_routes[i] = best; moved += 1
	print("CROWD FIX routes moved ", moved, " / ", ruin_routes.size())

func build_solids() -> void:
	solid_grid.clear()
	var n := 0
	# loose wrecks (outside the hills) and the hills themselves
	if scrap_field != null and "batches" in scrap_field:
		for key in scrap_field.batches:
			for item in scrap_field.batches[key].items:
				var o: Vector3 = (item.transform as Transform3D).origin
				var p := Vector2(o.x, o.z)
				var in_hill := false
				for hill in scrap_hills:
					if p.distance_to(hill.position) < float(hill.radius) + 3.0: in_hill = true; break
				if not in_hill: grid_insert(solid_grid, p, 2.6, {"p": p, "r": 2.6}); n += 1
	for hill in scrap_hills: grid_insert(solid_grid, hill.position, float(hill.radius), {"p": hill.position, "r": float(hill.radius)}); n += 1
	# petrified figures
	if frozen_ruins != null and "members" in frozen_ruins:
		for m in frozen_ruins.members:
			var r := 0.6 * float(m.get("scale", 1.0))
			grid_insert(solid_grid, m.point, r, {"p": m.point, "r": r}); n += 1
	# palms (trunk), rock camels, the base of Dove Man
	for o in obstacles():
		var kind := String(o.kind)
		if kind == "palm": grid_insert(solid_grid, o.p, 1.4, {"p": o.p, "r": 1.4}); n += 1
		elif kind == "rock_camel": grid_insert(solid_grid, o.p, float(o.r), {"p": o.p, "r": float(o.r)}); n += 1
	grid_insert(solid_grid, Vector2.ZERO, DOVE_BODY, {"p": Vector2.ZERO, "r": DOVE_BODY})
	print("CROWD FIX solids ", n)

func moving_solids() -> Dictionary:
	var grid := {}
	for o in obstacles():
		var kind := String(o.kind)
		var r := 0.0
		match kind:
			"wreck": r = float(o.r) * 0.75
			"camel": r = float(o.r) * 0.8
			"dino": r = float(o.r) * 0.8
			"godzilla": r = 20.0
			_: continue
		grid_insert(grid, o.p, r, {"p": o.p, "r": r})
	return grid

func push_from(p: Vector2, r: float, grid: Dictionary) -> Vector2:
	var push := Vector2.ZERO
	for item in grid.get(cell_of(p), []):
		var off: Vector2 = p - (item.p as Vector2)
		var need: float = float(item.r) + r
		var d := off.length()
		if d < need:
			push += (off / d if d > 0.001 else Vector2(1, 0)) * (need - d)
	return push

func body_list(include_arrivals: bool) -> Array:
	var B := []
	for m in mannequins:
		if not m.has("orbit_radius") or m.get("fallen", false): continue
		B.append({"kind": 0, "m": m, "p": Vector2(m.root.position.x, m.root.position.z), "r": float(m.get("body_r", 0.6))})
	for g in flocks:
		for m in g.members: B.append({"kind": 1, "m": m, "p": m.pos, "r": maxf(0.13 * float(m.actor.size_m), 0.5)})
	for m in lost_members: B.append({"kind": 2, "m": m, "p": m.pos, "r": 1.15})
	if include_arrivals:
		for m in arrivals: B.append({"kind": 3, "m": m, "p": m.pos, "r": 0.55 * float(m.scale)})
	return B

func peers_push(B: Array) -> Array:
	var grid := {}
	for i in range(B.size()):
		var k := cell_of(B[i].p)
		if not grid.has(k): grid[k] = []
		grid[k].append(i)
	var out := []
	out.resize(B.size())
	for i in range(B.size()): out[i] = Vector2.ZERO
	for i in range(B.size()):
		var k := cell_of(B[i].p)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for j in grid.get(k + Vector2i(dx, dy), []):
					if j <= i: continue
					var off: Vector2 = B[i].p - B[j].p
					var need: float = float(B[i].r) + float(B[j].r) + 0.15
					var d := off.length()
					if d >= need: continue
					var dir := off / d if d > 0.001 else Vector2(cos(i), sin(i))
					var share := (need - d) * 0.5
					out[i] += dir * share
					out[j] -= dir * share
	return out

func relax(B: Array, movable: int, iterations: int, cap: float, moving: Dictionary) -> Array:
	# a few rounds of pushing apart; only the first `movable` bodies move, the rest are neighbours that hold
	var total := []
	total.resize(movable)
	for i in range(movable): total[i] = Vector2.ZERO
	for it in range(iterations):
		var peer := peers_push(B)
		for i in range(movable):
			var b: Dictionary = B[i]
			var push: Vector2 = peer[i] + push_from(b.p, b.r, solid_grid) + push_from(b.p, b.r, moving)
			push = push.limit_length(cap)
			b.p += push
			total[i] += push
	return total

func resolve_bodies(dt: float) -> void:
	var B := body_list(false)
	var n := B.size()
	var moves := relax(B, n, body_iterations, 0.8, moving_solids())
	var decay := exp(-dt * 0.12)
	for i in range(n):
		var b: Dictionary = B[i]
		var push: Vector2 = moves[i]
		var m: Dictionary = b.m
		match int(b.kind):
			0:
				var id: int = m.root.get_instance_id()
				nudge[id] = ((nudge.get(id, Vector2.ZERO) as Vector2) * decay + push).limit_length(18.0)
				if push.length_squared() > 0.0: (m.root as Node3D).position += Vector3(push.x, 0, push.y); fix_stats.pushes += 1
			1, 2:
				if push.length_squared() > 0.0:
					m.pos += push
					m.root.position = Vector3(m.pos.x, sand_height(m.pos.x, m.pos.y) - 0.08, m.pos.y)
					fix_stats.pushes += 1

func resolve_arrivals() -> void:
	# one pass per crowd tick, half of the arriving crowd each time (alternating). Arrivals against arrivals use a
	# fine 1.6 m grid on packed arrays (they are at most 1.45 m apart when touching); the other crowds, which are
	# few and some of them big, go in a coarse grid with the moving solids.
	# The work is spread over the frames after a crowd tick (a quarter of it per frame), so the tick itself costs
	# no more than before.
	if arrival_iterations <= 0 or arrivals.is_empty(): return
	var n := arrivals.size()
	var P := PackedVector2Array(); P.resize(n)
	var R := PackedFloat32Array(); R.resize(n)
	var grid := {}
	for i in range(n):
		var q: Vector2 = arrivals[i].pos
		P[i] = q; R[i] = 0.55 * float(arrivals[i].scale)
		var k := (floori(q.x / ACELL) + 4096) * 8192 + (floori(q.y / ACELL) + 4096)
		if grid.has(k): grid[k].append(i)
		else: grid[k] = PackedInt32Array([i])
	var moving := moving_solids()
	for o in body_list(false): grid_insert(moving, o.p, float(o.r) + 0.8, {"p": o.p, "r": float(o.r)})
	parity = 1 - parity
	ar = {"P": P, "R": R, "grid": grid, "moving": moving, "next": parity, "n": n}

func resolve_arrival_slice(count: int) -> void:
	if ar.is_empty(): return
	var P: PackedVector2Array = ar.P; var R: PackedFloat32Array = ar.R
	var grid: Dictionary = ar.grid; var moving: Dictionary = ar.moving
	var n: int = mini(int(ar.n), arrivals.size())
	var start: int = ar.next
	var stop: int = mini(start + count * 2, n)
	ar.next = stop
	if stop >= n: ar = {}
	for i in range(start, stop, 2):
		var p: Vector2 = P[i]
		var ri: float = R[i]
		var cx := floori(p.x / ACELL) + 4096; var cy := floori(p.y / ACELL) + 4096
		var push := Vector2.ZERO
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var lst = grid.get((cx + dx) * 8192 + cy + dy)
				if lst == null: continue
				for j in lst:
					if j == i: continue
					var off: Vector2 = p - P[j]
					var need: float = ri + R[j] + 0.15
					var d2 := off.length_squared()
					if d2 >= need * need: continue
					var d := sqrt(d2)
					push += (off / d if d > 0.001 else Vector2(1, 0)) * (need - d) * 0.5
		# neighbours push gently (at most 1.2 m a pass); solid things push the figure all the way out
		push = push.limit_length(1.2) + (push_from(p, ri, solid_grid) + push_from(p, ri, moving)).limit_length(6.0)
		if push.length_squared() == 0.0: continue
		var m: Dictionary = arrivals[i]
		m.pos += push
		var v: Vector2 = m.velocity
		var nn := push.normalized()
		var into := v.dot(-nn)
		if into > 0.0: m.velocity = v + nn * into

# The arriving crowd is drawn one crowd tick behind its simulation: each instance starts where it was at the last
# tick and travels exactly to where it is now over the next 0.5 s, so the picture never jumps (the shader used to
# guess ahead along the old heading and snap at the next tick).
func write_arrival(member: Dictionary) -> void:
	var point: Vector2 = member.pos
	var dt := maxf(float(member.get("tick_dt", 0.5)), 0.05)
	var start: Vector2 = member.get("render_pos", point)
	var travel := point - start
	member["render_pos"] = point
	var yaw: float = atan2(travel.x, travel.y) if travel.length_squared() > 0.0004 else float(member.get("render_yaw", atan2(-point.x, -point.y)))
	member["render_yaw"] = yaw
	var scale_factor := float(member.scale)
	var transform := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor), Vector3(start.x, crowd_ground(start), start.y))
	var rp: float = member.get("render_phase", float(member.phase))
	var freq := float(member.get("frequency", 0.0))
	var corr := wrapf(float(member.phase) - fposmod(rp + freq * dt, 1.0), -0.5, 0.5) / dt
	var f_render := maxf(freq + corr * 0.5, 0.0) if freq > 0.0 else 0.0
	member["render_phase"] = fposmod(rp + f_render * dt, 1.0)
	var batch: Dictionary = batches[int(member.species)]
	batch.multi.set_instance_transform(int(member.slot), transform)
	batch.multi.set_instance_custom_data(int(member.slot), Color(rp, travel.length() / dt / scale_factor, f_render, 1.0))

# ------------------------------------------------------------------ ground under the arriving crowd
# The dunes never change, so they are cached for good; only where a crater, a footprint or Godzilla's pit is live is
# the full sand height read again (it changes with their age).
func mark_live_ground() -> void:
	live_cells.clear()
	var cr: Dictionary = D.cars.crater
	var crater_reach := float(cr.radius_m) * float(D.cars.scale) * 0.58 * 4.0
	for c in craters:
		if c.w >= 0.5 and t - c.z >= 0.0: stamp_live(Vector2(c.x, c.y), crater_reach)
	var memory := float(D.godzilla.footprint.memory_s) * 3.0
	for fp in prints:
		var age: float = t - fp.z
		if age >= -0.6 and age <= memory: stamp_live(Vector2(fp.x, fp.y), 40.0)
	if not gz.is_empty() and gz.state != GZ_WAITING and gz.state != GZ_WALKING and gz.has("root"):
		stamp_live(Vector2(gz.root.position.x, gz.root.position.z), 45.0)

func stamp_live(p: Vector2, r: float) -> void:
	for x in range(floori((p.x - r) / 40.0), floori((p.x + r) / 40.0) + 1):
		for y in range(floori((p.y - r) / 40.0), floori((p.y + r) / 40.0) + 1):
			live_cells[Vector2i(x, y)] = true

func crowd_ground(p: Vector2) -> float:
	if live_cells.has(Vector2i(floori(p.x / 40.0), floori(p.y / 40.0))): return sand_height(p.x, p.y) - 0.08
	var key := Vector2i(roundi(p.x / 3.0), roundi(p.y / 3.0))
	if not static_ground.has(key):
		var h := dune_height(p.x, p.y)
		if maxf(absf(p.x), absf(p.y)) > 450.0: h -= 0.05
		static_ground[key] = h - 0.08
	return static_ground[key]
