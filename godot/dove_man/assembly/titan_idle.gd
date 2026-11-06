extends SkeletonModifier3D
## The titan's idle, on top of whatever frame of its walk it is standing on (it only has a walk clip):
## it breathes (the chest rises and the back bends a little), the head looks slowly around,
## the tail swings in a travelling wave, the arms hang and drift. Nothing accumulates:
## the modifier rewrites the pose every frame from the clip.

var idle := 1.0          # 1 standing, lower while walking (then only the tail keeps swinging)
var spray := 0.0         # 1 while it hoses the crowd: head down into the stream, a pressure tremor
var clock := 0.0
var root_ref: Node3D     # the titan root: its axes give "up" and "side"
const SPINE := [11, 12, 13, 14, 15]
const NECK := [16, 17, 18, 19, 20]
const TAIL_FROM := 131
const TAIL_TO := 153
const ARMS := [53, 77]


func turn(sk: Skeleton3D, b: int, axis: Vector3, ang: float) -> void:
	if b < 0 or b >= sk.get_bone_count() or absf(ang) < 0.00001:
		return
	var g: Transform3D = sk.get_bone_global_pose(b)
	g.basis = Basis(axis, ang) * g.basis
	sk.set_bone_global_pose(b, g)


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or root_ref == null:
		return
	clock += delta
	var to_sk: Basis = sk.global_basis.inverse()
	var up: Vector3 = (to_sk * root_ref.global_basis.y).normalized()
	var side: Vector3 = (to_sk * root_ref.global_basis.x).normalized()
	var t := clock
	var breath: float = sin(t * 0.85)
	# breathing: the back bends and straightens
	for k in SPINE.size():
		turn(sk, SPINE[k], side, idle * 0.010 * breath)
	# the head looks around slowly; when it sprays it bows into the stream and trembles
	var look: float = idle * (0.045 * sin(t * 0.21) + 0.025 * sin(t * 0.53 + 1.3))
	var nod: float = idle * 0.014 * sin(t * 0.37) + spray * (0.05 + 0.012 * sin(t * 31.0))
	for k in NECK.size():
		turn(sk, NECK[k], up, look * (1.0 - spray * 0.6))
		turn(sk, NECK[k], side, nod)
	# the tail: a wave travelling from the hips to the tip, wider toward the tip
	var n: int = TAIL_TO - TAIL_FROM + 1
	var amp: float = 0.03 * (0.45 + 0.55 * idle) + spray * 0.012
	for i in n:
		var u: float = float(i) / float(n - 1)
		turn(sk, TAIL_FROM + i, up, amp * (0.35 + 0.65 * u) * sin(t * 0.75 - float(i) * 0.3))
	# the arms hang and drift
	for k in ARMS.size():
		turn(sk, ARMS[k], side, idle * 0.05 * sin(t * 0.6 + float(k) * 1.7))
