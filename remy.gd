@tool
extends Node3D

@export var skeleton: Skeleton3D
@export var marker: Marker3D
@export var marker_global: Marker3D
@export var bone_name: String = "mixamorig_Hips"
@export var amount: float
@export var persistent: bool = false
@onready var bone_idx: int = skeleton.find_bone(bone_name)

@export_enum("GLOBAL", "NO_OVERRIDE", "OVERRIDE", "GLOBAL_REST", "REST", "LOCAL") var choice = 0

func _ready():
	if Engine.is_editor_hint():
		print("READY RUNNING")
		set_process(true)
		skeleton.reset_bone_poses()
		skeleton.reset_bone_pose(skeleton.find_bone("mixamorig_LeftHand"))
		if bone_idx == -1:
			return
		marker.global_transform = skeleton.get_bone_global_pose(bone_idx)

func _process(delta):
	if not Engine.is_editor_hint():
		return

	if skeleton == null or marker == null:
		print("Null")
		return
	
	#match choice:
		#0: marker.transform = skeleton.get_bone_global_pose(bone_idx)
		#1: marker.transform = skeleton.get_bone_global_pose_no_override(bone_idx)
		#2: marker.transform = skeleton.get_bone_global_pose_override(bone_idx)
		#3: marker.transform = skeleton.get_bone_global_rest(bone_idx)
		#4: marker.transform = skeleton.get_bone_rest(bone_idx)
		#5: marker.transform = skeleton.get_bone_pose(bone_idx)
#
	#match choice:
		#0: marker_global.global_transform = skeleton.get_bone_global_pose(bone_idx)
		#1: marker_global.global_transform = skeleton.get_bone_global_pose_no_override(bone_idx)
		#2: marker_global.global_transform = skeleton.get_bone_global_pose_override(bone_idx)
		#3: marker_global.global_transform = skeleton.get_bone_global_rest(bone_idx)
		#4: marker_global.global_transform = skeleton.get_bone_rest(bone_idx)
		#5: marker_global.global_transform = skeleton.get_bone_pose(bone_idx)
		
	match choice:
		0: skeleton.set_bone_global_pose(bone_idx, marker.transform)
		1: return
		2: skeleton.set_bone_global_pose_override(bone_idx, marker.global_transform, amount, persistent)
		3: skeleton.set_bone_global_rest(bone_idx, marker.transform)
		4: skeleton.set_bone_rest(bone_idx, marker.transform)
		5: return

func reset_bone_pose() -> void:
	if not skeleton:
		push_error("No skeleton assigned")
		return
		
	if bone_idx == -1:
		push_error("Bone not found")
		return

	# Reset the bone to its rest transform
	skeleton.set_bone_pose(bone_idx, Transform3D.IDENTITY)
	skeleton.clear_bone_global_pose_override(bone_idx)
	print("Bone reset:", bone_name)
