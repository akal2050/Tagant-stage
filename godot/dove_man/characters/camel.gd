extends Node3D

# ============================================================
# One living camel (model: models/camel_v2.glb — rigged, with Walk / Idle_01 / Idle_02).
#
# Every camel has its own clock and temperament:
#   - its own pace and its own idle habits (graze with the head down = Idle_01,
#     stand and chew = Idle_02), each clip started at its own moment
#   - walk is stride-locked: the clip advances exactly by the distance covered
#     (1.82 x height per cycle, measured in Blender), so hooves do not slide
#   - it walks around everything in the world (world.steer), picks free spots
#     to go to, flees Godzilla's path and startles at impacts
#   - the lowest hoof stays 20 cm under the sand
# ============================================================

const FEET: Array = ["FrontFoot_L_012", "FrontFoot_R_07", "BackFoot_L_062", "BackFoot_R_066"]

var world: Node3D
var model: Node3D
var shake: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var tree: AnimationTree
var r: RandomNumberGenerator = RandomNumberGenerator.new()

var height: float = 10.0
var walk_speed: float = 1.5
var flee_speed: float = 3.0
var foot_depth: float = 0.2
var stride: float = 18.0
var cycle_s: float = 1.625
var yaw_offset: float = PI

var pos: Vector2
var yaw: float = 0.0
var yaw_rate: float = 0.0           # rad/s, eased — the body never snaps round
var wish: Vector2 = Vector2.ZERO    # smoothed desire to go somewhere
var speed: float = 0.0
var mood: String = "wander"
var mood_timer: float = 10.0
var target: Vector2
var graze: float = 0.0
var walk_amt: float = 0.0
var startle_from: Vector2 = Vector2.ZERO
var startle_t: float = -100.0
var pads: Array = []


func setup(w: Node3D, model_scene: PackedScene, e: Dictionary, g: Dictionary, seed_value: int) -> void:
	world = w
	r.seed = seed_value
	height = float(e["height"])
	walk_speed = float(e["walk"]) * r.randf_range(0.88, 1.12)
	flee_speed = float(e["flee"]) * r.randf_range(0.9, 1.1)
	foot_depth = float(g["foot_depth"])
	stride = float(g["stride_per_height"]) * height
	cycle_s = float(g["walk_cycle_s"])
	yaw_offset = PI if g.get("model_forward", "-z") == "-z" else 0.0
	pos = Vector2(e["start"][0], e["start"][1])
	if not world.spot_is_free(pos, height * 0.45, 4.0):
		pos = world.random_free_target(r, height * 0.45, 60.0, 130.0)
	yaw = r.randf_range(0.0, TAU)
	mood_timer = r.randf_range(3.0, 20.0)
	target = world.random_free_target(r, height * 0.45, 45.0, 120.0)

	shake = Node3D.new()
	add_child(shake)
	model = model_scene.instantiate()
	model.scale = Vector3.ONE * height
	shake.add_child(model)
	position = Vector3(pos.x, world.dune_height(pos.x, pos.y), pos.y)
	rotation.y = yaw + yaw_offset
	if not bool(g.get("show_coat", true)):
		hide_named(model, ["Object_116", "CamelCoat"])

	skeleton = world.find_skeleton(model)
	player = world.find_player(model)
	if player != null:
		for a in ["Walk", "Idle_01", "Idle_02"]:
			world.loop_animation(player, a)
		tree = build_tree()
	pads = g["hoof_pads"]


func hide_named(n: Node, names: Array) -> void:
	if names.has(String(n.name)) and n is Node3D:
		(n as Node3D).visible = false
	for c in n.get_children():
		hide_named(c, names)


func build_tree() -> AnimationTree:
	var tr: AnimationTree = AnimationTree.new()
	player.get_parent().add_child(tr)
	tr.anim_player = tr.get_path_to(player)
	tr.root_node = tr.get_path_to(player.get_node(player.root_node))
	var bt: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	for a in ["Walk", "Idle_01", "Idle_02"]:
		var n: AnimationNodeAnimation = AnimationNodeAnimation.new()
		n.animation = a
		bt.add_node(a, n)
		var sk: AnimationNodeTimeSeek = AnimationNodeTimeSeek.new()
		bt.add_node("seek_" + a, sk)
		bt.connect_node("seek_" + a, 0, a)
	var walk_ts: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	bt.add_node("walk_ts", walk_ts)
	bt.connect_node("walk_ts", 0, "seek_Walk")
	var idle_ts: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	bt.add_node("idle_ts", idle_ts)
	var idle_mix: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	bt.add_node("idle_mix", idle_mix)
	bt.connect_node("idle_mix", 0, "seek_Idle_02")   # standing, chewing
	bt.connect_node("idle_mix", 1, "seek_Idle_01")   # head down, grazing
	bt.connect_node("idle_ts", 0, "idle_mix")
	var move_mix: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	bt.add_node("move_mix", move_mix)
	bt.connect_node("move_mix", 0, "idle_ts")
	bt.connect_node("move_mix", 1, "walk_ts")
	bt.connect_node("output", 0, "move_mix")
	tr.tree_root = bt
	tr.active = true
	# each camel starts its clips at its own moment and keeps its own idle tempo
	for a in ["Walk", "Idle_01", "Idle_02"]:
		tr.set("parameters/seek_" + a + "/seek_request", r.randf_range(0.0, player.get_animation(a).length))
	tr.set("parameters/idle_ts/scale", r.randf_range(0.7, 1.15))
	return tr


func startle(from: Vector2) -> void:
	startle_from = from
	startle_t = Engine.get_meta("tagant_film_t", Time.get_ticks_msec() * 0.001)   # film-safe clock (5 Nov)
	mood = "flee"
	mood_timer = r.randf_range(4.0, 7.0)


func tick(delta: float, threat_dir: Vector2, hesitation: float, quake: Vector3, Q: Dictionary) -> void:
	think(delta, threat_dir, hesitation)
	move(delta)
	animate(delta)
	ground()
	shake.position.y = absf(quake.x + quake.y) * float(Q["hop_m"])
	shake.rotation.x = quake.y * deg_to_rad(Q["deg"])
	shake.rotation.z = -quake.x * deg_to_rad(Q["deg"])
	world.set_instance_param(model, "root_y", position.y)


func think(delta: float, threat_dir: Vector2, hesitation: float) -> void:
	mood_timer -= delta
	var startled: bool = Engine.get_meta("tagant_film_t", Time.get_ticks_msec() * 0.001) - startle_t < 6.0
	if threat_dir != Vector2.ZERO:
		mood = "flee"
		mood_timer = maxf(mood_timer, 6.0)
	elif mood_timer <= 0.0:
		var roll: float = r.randf()
		if mood != "wander" and roll < 0.55:
			mood = "wander"
			target = world.random_free_target(r, height * 0.45, 45.0, 140.0)
			mood_timer = r.randf_range(25.0, 70.0)
		elif roll < 0.75:
			mood = "graze"
			mood_timer = r.randf_range(15.0, 45.0)
		else:
			mood = "stand"
			mood_timer = r.randf_range(8.0, 25.0)

	var want_speed: float = 0.0
	var want_dir: Vector2 = Vector2.ZERO
	match mood:
		"flee":
			if threat_dir != Vector2.ZERO:
				want_dir = threat_dir
			elif startled:
				want_dir = (pos - startle_from).normalized()
			want_speed = flee_speed if want_dir != Vector2.ZERO else 0.0
			if want_dir == Vector2.ZERO:
				mood_timer = 0.0
		"wander":
			var to: Vector2 = target - pos
			if to.length() < height:
				mood_timer = 0.0
			else:
				want_dir = to.normalized()
				want_speed = walk_speed * (1.0 - hesitation)
	# walk around everything in the world
	if want_dir != Vector2.ZERO:
		want_dir = world.steer(pos, want_dir, height * 0.45, self)
	else:
		var push: Vector2 = world.steer(pos, Vector2.ZERO, height * 0.45, self)
		if push.length() > 0.2:
			want_dir = push.normalized()
			want_speed = walk_speed * 0.6
	locomotion(delta, want_dir, want_speed)
	graze = move_toward(graze, 1.0 if mood == "graze" else 0.0, delta * 0.3)


# How a quadruped turns: only while stepping, along a turning circle about its own size,
# easing into and out of the turn. A big change of direction becomes a slow curving walk,
# never a pivot on the spot.
func locomotion(delta: float, want_dir: Vector2, want_speed: float) -> void:
	var fleeing: bool = mood == "flee"
	# the desire itself is smoothed: obstacles and moods change it abruptly, the animal does not
	var k_wish: float = 1.0 - exp(-delta * (2.0 if fleeing else 0.9))
	wish = wish.lerp(want_dir, k_wish)
	var err: float = 0.0
	if wish.length() > 0.08:
		err = wrapf(atan2(wish.x, wish.y) - yaw, -PI, PI)
		if absf(err) > 0.45:
			# a real turn: slow down on the outside of it, but keep stepping so it can curve round
			var sharp: float = clampf((absf(err) - 0.45) / 1.6, 0.0, 1.0)
			want_speed = maxf(want_speed * lerpf(1.0, 0.5, sharp), walk_speed * 0.4)
	var acc: float = (1.1 if fleeing else 0.5) if want_speed > speed else 0.45
	speed += (want_speed - speed) * (1.0 - exp(-delta * acc))
	if speed < 0.02:
		speed = 0.0
	var radius: float = height * (0.85 if fleeing else 1.0)
	var max_rate: float = speed / radius
	var target_rate: float = clampf(err * 0.7, -max_rate, max_rate)
	yaw_rate += (target_rate - yaw_rate) * (1.0 - exp(-delta * (1.5 if fleeing else 1.1)))
	yaw += yaw_rate * delta


func move(delta: float) -> void:
	var fwd: Vector2 = Vector2(sin(yaw), cos(yaw))
	pos += fwd * speed * delta
	pos = world.resolve(pos, height * 0.45, self)
	position.x = pos.x
	position.z = pos.y
	rotation.y = yaw + yaw_offset


func animate(_delta: float) -> void:
	if tree == null:
		return
	walk_amt = clampf(speed / maxf(0.2, walk_speed * 0.35), 0.0, 1.0)
	tree.set("parameters/move_mix/blend_amount", walk_amt)
	tree.set("parameters/idle_mix/blend_amount", graze)
	# one walk cycle per stride: no sliding hooves
	tree.set("parameters/walk_ts/scale", maxf(speed, 0.05 * walk_speed) / stride * cycle_s)


func ground() -> void:
	# hooves measured in Blender (height-normalised, Godot axes: model faces -Z)
	var b: Basis = Basis(Vector3.UP, rotation.y)
	var lowest: float = 1e9
	for pad in pads:
		var w: Vector3 = b * (Vector3(pad[0], 0.0, pad[2]) * height) + position
		lowest = minf(lowest, world.sand_height(w.x, w.z))
	position.y = lowest - foot_depth
