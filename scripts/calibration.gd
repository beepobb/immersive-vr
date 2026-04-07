extends Node3D

@export_group("Trackers") 
@export var hmd: XRCamera3D
@export var left_hand: XRController3D
@export var right_hand: XRController3D
@export var waist: XRController3D
@export var left_foot: XRController3D
@export var right_foot: XRController3D

@export_group("Calibration")
@export var avatar_scene: PackedScene = preload("res://assets/Remy.fbx")
@export var lfoot_bone_name: String = "mixamorig_LeftFoot"
@export var head_bone_name: String = "mixamorig_Head"
@export var eye_offset: float = 0.0
var fallback_avatar: PackedScene = preload("res://assets/Remy.fbx")
var fallback: bool = false
var player_eye_height: float = 0.0
var avatar_eye_height: float = 0.0
var avatar_loaded: bool = false

# ======= BODY AXES ========
var body_forward: Vector3
var body_right: Vector3
var body_up: Vector3 = Vector3.UP
var body_axes_initialised: bool = false

# Procedure:
# 1. Calibrate avatar to user height
# 2. Load the avatar scaled to user height
# 3. Compute yaw only body frame
# 4. Align avatar yaw to player yaw (so avatar face the same direction as player)
# 5. Compute extrinsics

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if (hmd == null):
		push_error("HMD not found. Aborting...")
# Called every frame. 'delta' is the elapsed time since the previous frame.
	await get_tree().process_frame
	load_player_scaled()
	
	#if (avatar_loaded and !body_axes_initialised):
		#save_body_axes()
	
func load_player_scaled() -> void:
	player_eye_height = hmd.global_position.y
	print(player_eye_height)
	
	var player = get_node_or_null("../XROrigin3D/AvatarRoot/Remy")
	# all avatar scene need skeleton3d node to be first child
	var player_skeleton: Skeleton3D = player.get_child(0)
	var lfoot_bone_idx: int = player_skeleton.find_bone(lfoot_bone_name)
	var head_bone_idx: int = player_skeleton.find_bone(head_bone_name)
	print(player)
	print(lfoot_bone_idx)
	
	if (lfoot_bone_idx == -1):
		push_warning("Left foot bone name is invalid. Using default avatar...")
		fallback = true
	if (head_bone_idx == -1):
		push_warning("Head bone name is invalid. Using default avatar...")
		fallback = true
		
	if (fallback):
		# Update player to use fallback avatar
		player = fallback_avatar.instantiate()
		# Update skeleton to use fallback avatar's skeleton
		player_skeleton= player.get_child(0) 
		lfoot_bone_idx = 62
		head_bone_idx = 5
		eye_offset = 0.15 # Tested with mixamo default character
		
	var lfoot_pos: Transform3D = player_skeleton.get_bone_global_pose(lfoot_bone_idx)
	var head_pos: Transform3D = player_skeleton.get_bone_global_pose(head_bone_idx)
	avatar_eye_height = head_pos.origin.y - lfoot_pos.origin.y + eye_offset
	print_debug(player_eye_height, avatar_eye_height)
	
	# Compute scale
	var avatar_scale: float = player_eye_height / avatar_eye_height
	print_debug("Scale: ", avatar_scale)
	
	# Load avatar into scene scaled to player height
	player.scale = Vector3.ONE * avatar_scale
	avatar_loaded = true
	
func save_body_axes() -> void:
	body_forward = -waist.global_basis.z # Forward is -Z in Godot
	body_forward.y = 0
	body_forward = body_forward.normalized()
	body_right = body_forward.cross(body_up).normalized()
	
	body_axes_initialised = true

func align_avatar_yaw_to_player() -> void:
	pass

func save_device_joint_offsets() -> void:
	pass
