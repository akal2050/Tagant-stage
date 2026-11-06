extends SkeletonModifier3D
## Lifts the neck and head and opens the jaw on top of whatever clip is playing.
## It runs after the animation every frame, so nothing accumulates: amount 0 = the clip untouched.

var amount := 0.0          # 0 silent .. 1 full voice
var mouth := 0.0           # 0 closed .. 1 open (follows the loudness of the voice)
var lifts: Array = []      # [{bone, axis, angle}]
var jaw := -1
var jaw_axis := Vector3.RIGHT
var jaw_angle := 0.0


func configure(sk: Skeleton3D, neck_bones: Array, neck_axis: Vector3, neck_total_rad: float, jaw_name: String, jaw_open_rad: float) -> void:
	lifts.clear()
	var found: Array = []
	for b in neck_bones:
		var i := sk.find_bone(b)
		if i >= 0:
			found.append(i)
	for i in found:
		lifts.append({"bone": i, "axis": neck_axis, "angle": neck_total_rad / float(found.size())})
	jaw = sk.find_bone(jaw_name)
	jaw_axis = neck_axis
	jaw_angle = jaw_open_rad


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or (amount < 0.002 and mouth < 0.002):
		return
	for l in lifts:
		var i: int = l["bone"]
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(l["axis"], float(l["angle"]) * amount))
	if jaw >= 0:
		sk.set_bone_pose_rotation(jaw, sk.get_bone_pose_rotation(jaw) * Quaternion(jaw_axis, jaw_angle * mouth))
