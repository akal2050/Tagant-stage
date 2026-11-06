extends MultiMeshInstance3D

# Rocks that break off Dove Man, fall, bounce once or twice on the dune,
# settle at their own tilt and STAY — piles grow at his feet over time.
# Only the oldest rocks are recycled once the cap is reached.

const CAP: int = 2500

var world: Node3D
var r: RandomNumberGenerator = RandomNumberGenerator.new()
var points: Array = []          # emission points on shoulders / head / hands
var rocks: Array = []           # {p, v, spin_axis, spin, basis, size, resting}
var head: int = 0


func setup(w: Node3D, rock_mesh: Mesh, emit_points: Array) -> void:
	world = w
	r.randomize()
	points = emit_points
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = rock_mesh
	multimesh.instance_count = CAP
	multimesh.visible_instance_count = 0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.11, 0.075)
	mat.roughness = 0.97
	material_override = mat
	custom_aabb = AABB(Vector3(-250, -40, -250), Vector3(500, 260, 500))


# count rocks, released over `spread_s` seconds (a short avalanche, not a single puff)
func shed(count: int, spread_s: float = 1.5) -> void:
	for i in count:
		var delay: float = r.randf_range(0.0, spread_s)
		var p: Array = points[r.randi_range(0, points.size() - 1)]
		var start: Vector3 = Vector3(p[0], p[1], p[2])
		var out: Vector3 = Vector3(start.x, 0.0, start.z).normalized()
		var size: float = r.randf_range(0.25, 1.0)
		size = size * size * 1.6 + 0.2          # many small, few big (0.2 – 1.8 m)
		var rock: Dictionary = {
			"p": start, "v": out * r.randf_range(0.5, 3.0) + Vector3(0, r.randf_range(-1.0, 1.0), 0),
			"axis": Vector3(r.randf_range(-1, 1), r.randf_range(-1, 1), r.randf_range(-1, 1)).normalized(),
			"spin": r.randf_range(1.0, 5.0), "basis": Basis(Quaternion(Vector3(r.randf(), r.randf(), r.randf()).normalized(), r.randf_range(0, TAU))),
			"size": size, "resting": false, "wait": delay, "bounces": 0}
		if rocks.size() < CAP:
			rocks.append(rock)
		else:
			rocks[head] = rock
			head = (head + 1) % CAP
	multimesh.visible_instance_count = rocks.size()


func _process(delta: float) -> void:
	if world == null:
		return
	for i in rocks.size():
		var k: Dictionary = rocks[i]
		if k.get("done", false):
			continue
		if k["wait"] > 0.0:
			k["wait"] -= delta
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), k["p"]))
			continue
		if not k["resting"]:
			k["v"] += Vector3(0.0, -9.8, 0.0) * delta
			k["v"] *= 1.0 - 0.02 * delta
			k["p"] += k["v"] * delta
			k["basis"] = Basis(k["axis"], k["spin"] * delta) * k["basis"]
			var g: float = world.dune_height(k["p"].x, k["p"].z)
			var floor_y: float = g - k["size"] * 0.25
			if k["p"].y <= floor_y:
				k["p"].y = floor_y
				k["bounces"] += 1
				if k["bounces"] >= 3 or k["v"].length() < 2.0:
					k["resting"] = true
					k["v"] = Vector3.ZERO
				else:
					k["v"] = Vector3(k["v"].x * 0.35, absf(k["v"].y) * 0.18, k["v"].z * 0.35)
					k["spin"] *= 0.4
		multimesh.set_instance_transform(i, Transform3D(k["basis"].scaled(Vector3.ONE * k["size"]), k["p"]))
		if k["resting"]:
			k["done"] = true
