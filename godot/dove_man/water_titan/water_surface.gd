extends Node3D
## Interior oil masses follow skeletal centers; original animation stays intact.
var model: Node3D
var skeleton: Skeleton3D
var body_materials: Array[ShaderMaterial] = []
var oil_material: ShaderMaterial
var blobs: Array = []
var water_clock := 0.0
var surface_fade := 1.0
var water_height := 52.0

func setup(subject: Node3D, height_m: float) -> void:
	model=subject
	water_height=height_m
	for candidate in model.find_children("*","Skeleton3D",true,false):
		skeleton=candidate
		break
	assert(skeleton!=null)
	var to_titan := global_transform.affine_inverse()
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var material:=ShaderMaterial.new()
		material.shader=load("res://dove_man/water_titan/water_body.gdshader")
		material.set_shader_parameter("mesh_to_titan",to_titan*mesh.global_transform)
		material.set_shader_parameter("titan_height",height_m)
		mesh.material_override=material
		body_materials.append(material)
	oil_material=ShaderMaterial.new()
	oil_material.shader=load("res://dove_man/water_titan/petrol_blob.gdshader")
	var sphere:=SphereMesh.new()
	sphere.radius=1.0
	sphere.height=2.0
	sphere.radial_segments=24
	sphere.rings=12
	var random:=RandomNumberGenerator.new()
	random.seed=92477
	# Measure clearance from internal skeletal anchors to the actual skinned shell.
	var shell:Array[Vector3]=[]
	for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var arrays:Array=mesh.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
		var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var influences:=int(bones.size()/vertices.size())
		for index in range(0,vertices.size(),3):
			var anchor:Dictionary={"vertex":vertices[index],"normal":normals[index],"skin":mesh.skin,"bones":[],"weights":[]}
			for influence in influences:
				anchor.bones.append(bones[index*influences+influence])
				anchor.weights.append(weights[index*influences+influence])
			shell.append(sample_surface(anchor).point)
	var size_targets:Array=[3.3,4.4,3.5,4.1,2.8,1.25,1.8,1.55,1.1]
	for bone in [11,12,13,14,15,101,116,102,117]:
		var center:=bone_center(bone)
		var clearance:=INF
		for point in shell:clearance=minf(clearance,center.distance_to(point))
		var radius:=minf(float(size_targets[blobs.size()]),clearance*0.66)
		var blob:=MeshInstance3D.new()
		blob.name="InteriorPetrol_%03d"%blobs.size()
		blob.mesh=sphere
		blob.material_override=oil_material
		blob.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blob)
		blob.set_instance_shader_parameter("variation",random.randf())
		var size:=Vector3(radius*0.88,radius,radius*0.92)
		var offset:=Vector3(random.randf_range(-0.3,0.3),random.randf_range(-0.2,0.2),random.randf_range(-0.3,0.3)) if bone<16 else Vector3.ZERO
		blobs.append({"node":blob,"bone":bone,"offset":offset,"floating":global_transform*(center+offset),"velocity":Vector3.ZERO,"phase":random.randf()*TAU,"size":size,"clearance":clearance,"radius":radius})
		print("INTERIOR_OIL bone=",bone," radius=",radius," clearance=",clearance)
	update_surface(0.0,1.0)

func update_surface(delta: float, visibility: float) -> void:
	water_clock+=delta
	surface_fade=visibility
	for material in body_materials: material.set_shader_parameter("water_clock",water_clock)
	if oil_material==null: return
	oil_material.set_shader_parameter("water_clock",water_clock)
	if skeleton==null: return
	skeleton.force_update_all_bone_transforms()
	for blob in blobs:
		var float_phase:float=water_clock*0.48+float(blob.phase)
		var center:=bone_center(int(blob.bone))
		var anchor:Vector3=center+blob.offset
		var target:Vector3=global_transform*anchor
		var floating:Vector3=blob.floating
		var velocity:Vector3=blob.velocity
		if floating.distance_to(target)>20.0:floating=target;velocity=Vector3.ZERO
		# A damped buoyant mass lags skeletal and whole-body motion in world space.
		var remaining:=minf(delta,0.25)
		while remaining>0.0:
			var step:=minf(remaining,0.016)
			var buoyancy:=Vector3(sin(float_phase*0.7)*0.65,0.8+sin(float_phase)*0.9,cos(float_phase*0.83)*0.55)
			velocity+=((target-floating)*4.2-velocity*2.1+buoyancy)*step
			floating+=velocity*step
			remaining-=step
		var local_point:Vector3=global_transform.affine_inverse()*floating
		# Bound the suspension inside the measured shell, including deformation.
		var room:=maxf(0.12,float(blob.clearance)-float(blob.radius)*1.28-0.25)
		local_point=center+(local_point-center).limit_length(minf(room,1.25))
		floating=global_transform*local_point
		blob.floating=floating
		blob.velocity=velocity.limit_length(8.0)
		blob.node.position=local_point
		var squash:=1.0+0.07*sin(float_phase*1.3)+minf(0.035,velocity.length()*0.006)
		var shape:Vector3=blob.size*Vector3(1.0/sqrt(squash),squash,1.0/sqrt(squash))
		blob.node.basis=Basis(Vector3.UP,float_phase*0.17).scaled(shape)
		blob.node.set_instance_shader_parameter("fade",visibility)

func bone_center(bone:int)->Vector3:
	return global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin

func sample_surface(anchor: Dictionary) -> Dictionary:
	var point:=Vector3.ZERO
	var normal:=Vector3.ZERO
	var skin: Skin=anchor.skin
	for index in anchor.bones.size():
		var weight: float=anchor.weights[index]
		if weight<0.00001: continue
		var bind: int=anchor.bones[index]
		var bone:=skin.get_bind_bone(bind)
		if bone<0: bone=skeleton.find_bone(skin.get_bind_name(bind))
		assert(bone>=0)
		var transform: Transform3D=skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(bind)
		point+=(transform*(anchor.vertex as Vector3))*weight
		normal+=(transform.basis*(anchor.normal as Vector3))*weight
	var to_surface:=global_transform.affine_inverse()*skeleton.global_transform
	return {"point":to_surface*point,"normal":(to_surface.basis.inverse().transposed()*normal).normalized()}
