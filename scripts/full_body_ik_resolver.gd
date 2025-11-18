class_name FullBodyIKResolver

extends SkeletonModifier3D

# Retrieve bone data from skeleton
@export var skeleton: Skeleton3D

@export_group("Bone Mappings")
@export var head_bone_name: String = "Head"
@export var neck_bone_name: String = "Neck"
@export var spine_bone_name: String = "Spine"
@export var left_shoulder_bone_name: String = "LeftShoulder"
@export var left_arm_bone_name: String = "LeftArm"
@export var left_forearm_bone_name: String = "LeftForeArm"
@export var left_hand_bone_name: String = "LeftHand"
@export var right_shoulder_bone_name: String = "RightShoulder"
@export var right_arm_bone_name: String = "RightArm"
@export var right_forearm_bone_name: String = "RightForeArm"
@export var right_hand_bone_name: String = "RightHand"
@export var hips_bone_name: String = "Hips"
@export var left_upleg_bone_name: String = "LeftUpLeg"
@export var left_leg_bone_name: String = "LeftLeg"
@export var left_foot_bone_name: String = "LeftFoot"
@export var right_upleg_bone_name: String = "RightUpLeg"
@export var right_leg_bone_name: String = "RightLeg"
@export var right_foot_bone_name: String = "RightFoot"

# Retrieve trackers' positions
# ==============================
# ===========Trackers===========
# ==============================
# HMD - head
# Left controller - left hand
# Right controller - right hand
# Vive tracker - waist
# Vive tracker - left ankle/toe
# Vive tracker - right ankle/toe
# Note: can track tip toe action if tracker is placed on toe instead of ankle
# For simplicity, we call it foot for now.
@export_group("Tracker Settings")
var tracker_head
var tracker_left_hand
var tracker_right_hand
var tracker_waist
var tracker_left_foot
var tracker_right_foot

func _process_modification_with_delta(delta: float) -> void:
	print(delta)
	
func _ready() -> void:
	if skeleton != null:
		var bone_count = skeleton.get_bone_count()
		print("Skeleton bone count: " + bone_count)
	else:
		print(skeleton)
		print("Skeleton is null")
	
func fabrik_solver(
	joint_positions: Array[Vector3], 
	target_position: Vector3, 
	joint_distances: Array[float], 
	tolerance: float = 0.01,
	max_iterations: int = 20) -> Array[Vector3]:
	# Input:
	# - joint positions, p_i where i = 1, ... , n
	# - target position, t
	# - distances between each joint, d_i = |p_i+1 - p_i|
	# Output:
	# - new joint positions, p_i for i = 1, ..., n

	var joint_count = joint_positions.size()
	# Sanity Check
	if joint_count < 2:
		return joint_positions

	# Root joint
	var root_joint_pos: Vector3 = joint_positions[0]
	var dist_btn_root_and_target: float = root_joint_pos.distance_to(target_position)
	
	# Total length of the joints
	var total_joint_distance: float = 0.0
	for dist in joint_distances:
		total_joint_distance += dist

	# Check whether target is within reach
	if dist_btn_root_and_target > total_joint_distance:
		# Target is unreachable
		for i in range(joint_count - 1):
			var curr_joint_pos: Vector3 = joint_positions[i]
			# Find the distance r_i between the target and the current joint
			var r: float = curr_joint_pos.distance_to(target_position)
			# Calculate lambda
			var lambda: float = joint_distances[i]/r
			# Find the new joint position (Update)
			joint_positions[i+1] = (1-lambda)*curr_joint_pos + lambda*target_position
	else:
		# Target is reachable
		# Set initial position of joint p_1
		var b: Vector3 = joint_positions[0]
		# Check whether the distance between the end effector p_n and the target t 
		# is greater than a tolerance
		var iteration = 0
		var dist_btn_ee_and_target: float = joint_positions[-1].distance_to(target_position)
		while dist_btn_ee_and_target > tolerance and iteration < max_iterations:
			iteration += 1
			# Stage 1: Forward Reaching
			# Set the end effector p_n as target t
			joint_positions[-1] = target_position
			for i in range(joint_count - 2, -1, -1):
				var curr_joint_pos: Vector3 = joint_positions[i]
				var next_joint_pos: Vector3 = joint_positions[i+1]
				# Find the distance r_i between the new joint position p_i+1and the joint p_i
				var r = next_joint_pos.distance_to(curr_joint_pos)
				# Prevent division by zero where next and curr joint positions are the same
				var lambda: float = joint_distances[i]/r if r > 0.0001 else 0.0
				# Find the new joint positions p_i (Update)
				joint_positions[i] = (1-lambda)*next_joint_pos + lambda*curr_joint_pos
			# Stage 2: Backward Reaching
			# Set the root p_i as its initial position
			joint_positions[0] = b

			for i in range(joint_count - 1):
				var curr_joint_pos: Vector3 = joint_positions[i]
				var next_joint_pos: Vector3 = joint_positions[i+1]
				# Find the distance r_i between the new joint position p_i
				# and the joint p_i+1
				var r: float = next_joint_pos.distance_to(curr_joint_pos)
				var lambda: float = joint_distances[i]/r if r > 0.0001 else 0.0
				# Find the new joint position (Update)
				joint_positions[i+1] = (1-lambda)*curr_joint_pos + lambda*next_joint_pos
			dist_btn_ee_and_target = joint_positions[-1].distance_to(target_position)
	return joint_positions

# func apply_orientational_constraints(motion_range: Dictionary, rotor: Basis) -> bool:
# 	# Input:
# 	# - rotor R expressing the rotation between the orientation frames at joints p_i and p_i+1
# 	# Output:
# 	# - the new re-oriented joint p'_i-1
# 	# Check whether the rotor rotor is within the motion range
# 	var euler_angles: Vector3 = rotor.get_euler()
	
