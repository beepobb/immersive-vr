class_name FullBodyIKResolver3D

extends SkeletonModifier3D

const EPS := 1e-6

# Retrieve bone data from skeleton
@export var skeleton: Skeleton3D

@export_group("Bone Mappings")
@export var head_bone_name: String = "Head"
@export var neck_bone_name: String = "Neck"
@export var spine_bone_name: String = "Spine"
@export var spine1_bone_name: String = "Spine1"
@export var spine2_bone_name: String = "Spine2"
@export var left_shoulder_bone_name: String = "LeftShoulder"
@export var left_arm_bone_name: String = "LeftArm"
@export var left_forearm_bone_name: String = "LeftForeArm"
@export var left_hand_bone_name: String = "LeftHand"
@export var right_shoulder_bone_name: String = "RightShoulder"
@export var right_arm_bone_name: String = "RightArm"
@export var right_forearm_bone_name: String = "RightForeArm"
@export var right_hand_bone_name: String = "RightHand"
@export var pelvis_bone_name: String = "Hips"
@export var left_upleg_bone_name: String = "LeftUpLeg"
@export var left_leg_bone_name: String = "LeftLeg"
@export var left_foot_bone_name: String = "LeftFoot"
@export var right_upleg_bone_name: String = "RightUpLeg"
@export var right_leg_bone_name: String = "RightLeg"
@export var right_foot_bone_name: String = "RightFoot"

# ==============================
# ===========Trackers===========
# ==============================
@export_group("Tracker Settings")
@export var tracker_head: XRCamera3D
@export var tracker_left_hand: XRController3D
@export var tracker_right_hand: XRController3D
@export var tracker_waist: XRController3D
@export var tracker_left_foot: XRController3D
@export var tracker_right_foot: XRController3D

#=====================================
# =========Cached Bone Ids============
#=====================================
var head_bone_id: int = -1
var neck_bone_id: int = -1
var spine_bone_id: int = -1
var spine1_bone_id: int = -1
var spine2_bone_id: int = -1
var left_shoulder_bone_id: int = -1
var left_arm_bone_id: int = -1
var left_forearm_bone_id: int = -1
var left_hand_bone_id: int = -1
var right_shoulder_bone_id: int = -1
var right_arm_bone_id: int = -1
var right_forearm_bone_id: int = -1
var right_hand_bone_id: int = -1
var pelvis_bone_id: int = -1
var left_upleg_bone_id: int = -1
var left_leg_bone_id: int = -1
var left_foot_bone_id: int = -1
var right_upleg_bone_id: int = -1
var right_leg_bone_id: int = -1
var right_foot_bone_id: int = -1

#====================================
#============Bone Chains=============
#====================================
var left_arm_chain: Array[int] = []
var right_arm_chain: Array[int] = []
var left_leg_chain: Array[int] = []
var right_leg_chain: Array[int] = []
var spine_chain: Array[int] = []

#======================================
#========Cached Joint Positions========
#======================================
var joint_positions_cached: Dictionary = {}

# Cached rest lengths (computed once)
var left_arm_rest_lengths: Array[float] = []
var right_arm_rest_lengths: Array[float] = []
var left_leg_rest_lengths: Array[float] = []
var right_leg_rest_lengths: Array[float] = []
var spine_rest_lengths: Array[float] = []

@export var character_root: Node3D
@export var enable_auto_scale: bool = false
@export var model_head_rest_height: float = 1.8 # if known (meters)

func _ready() -> void:
	if not skeleton:
		push_error("FullBodyIKResolver3D: skeleton is null. Assign a Skeleton3D in the inspector.")
		return

	_init_bone_ids()

	left_arm_chain = [
		left_shoulder_bone_id,
		left_arm_bone_id,
		left_forearm_bone_id,
		left_hand_bone_id
	]
	right_arm_chain = [
		right_shoulder_bone_id,
		right_arm_bone_id,
		right_forearm_bone_id,
		right_hand_bone_id
	]
	left_leg_chain = [
		left_upleg_bone_id,
		left_leg_bone_id,
		left_foot_bone_id
	]
	right_leg_chain = [
		right_upleg_bone_id,
		right_leg_bone_id,
		right_foot_bone_id
	]
	spine_chain = [
		spine_bone_id,
		spine1_bone_id,
		spine2_bone_id,
		neck_bone_id,
		head_bone_id
	]

	# compute rest lengths once
	left_arm_rest_lengths = compute_chain_rest_lengths(left_arm_chain)
	right_arm_rest_lengths = compute_chain_rest_lengths(right_arm_chain)
	left_leg_rest_lengths = compute_chain_rest_lengths(left_leg_chain)
	right_leg_rest_lengths = compute_chain_rest_lengths(right_leg_chain)
	spine_rest_lengths = compute_chain_rest_lengths(spine_chain)

func _process_modification_with_delta(_delta: float) -> void:
	if enable_auto_scale and character_root and model_head_rest_height > 0.001:
		var head_rest_global = get_bone_rest_global_transform(head_bone_id).origin
		var model_head_y = head_rest_global.y
		if model_head_y > EPS:
			var scale_factor = tracker_head.global_transform.origin.y / model_head_y
			character_root.scale = Vector3.ONE * scale_factor
			# disable after first application
			enable_auto_scale = false

	# Get tracker positions
	var head_tracker_pos: Vector3 = tracker_head.global_transform.origin
	var left_hand_tracker_pos: Vector3 = tracker_left_hand.global_transform.origin
	var right_hand_tracker_pos: Vector3 = tracker_right_hand.global_transform.origin
	var waist_tracker_basis: Basis = tracker_waist.global_transform.basis
	var waist_tracker_pos: Vector3 = tracker_waist.global_transform.origin
	var left_foot_tracker_pos: Vector3 = tracker_left_foot.global_transform.origin
	var right_foot_tracker_pos: Vector3 = tracker_right_foot.global_transform.origin

	if waist_tracker_basis.x.length() < EPS or waist_tracker_basis.y.length() < EPS or waist_tracker_basis.z.length() < EPS:
		waist_tracker_basis = Basis.IDENTITY

	var pelvis_transform: Transform3D = Transform3D(waist_tracker_basis, waist_tracker_pos)
	set_bone_global_transform_local_override(pelvis_bone_id, pelvis_transform, 1.0)

	# Get pole vectors
	var left_elbow_pole: Vector3 = get_pole_vector(
		skeleton.get_bone_global_pose(left_shoulder_bone_id).origin,
		spine2_bone_id,
		true)
	var right_elbow_pole: Vector3 = get_pole_vector(
		skeleton.get_bone_global_pose(right_shoulder_bone_id).origin,
		spine2_bone_id,
		false)
	var left_knee_pole: Vector3 = get_pole_vector(
		skeleton.get_bone_global_pose(left_upleg_bone_id).origin,
		pelvis_bone_id,
		true)
	var right_knee_pole: Vector3 = get_pole_vector(
		skeleton.get_bone_global_pose(right_upleg_bone_id).origin,
		pelvis_bone_id,
		false)

	# Resolve legs
	var left_leg_positions: Array[Vector3] = get_joint_positions(left_leg_chain)
	var right_leg_positions: Array[Vector3] = get_joint_positions(right_leg_chain)

	left_leg_positions = solve_two_bone_ik(
		left_leg_positions,
		left_leg_rest_lengths,
		left_foot_tracker_pos,
		left_knee_pole
	)

	right_leg_positions = solve_two_bone_ik(
		right_leg_positions,
		right_leg_rest_lengths,
		right_foot_tracker_pos,
		right_knee_pole
	)

	apply_joint_positions_local(left_leg_chain, left_leg_positions)
	apply_joint_positions_local(right_leg_chain, right_leg_positions)

	# Resolve spine
	var spine_joints = get_joint_positions(spine_chain)
	spine_joints = fabrik_solver(spine_joints, head_tracker_pos, spine_rest_lengths)

	# Cone constraints for spine
	for i in range(spine_chain.size() - 1):
		var parent_pos = spine_joints[i]
		var child_pos = spine_joints[i + 1]
		var forward_dir = (
			skeleton.get_bone_global_pose(spine_chain[i + 1]).origin
			- skeleton.get_bone_global_pose(spine_chain[i]).origin
		).normalized()
		spine_joints[i + 1] = apply_cone_constraint(child_pos, parent_pos, forward_dir, 45.0)

	apply_joint_positions_local(spine_chain, spine_joints)

	# Resolve arms
	var left_arm_positions: Array[Vector3] = get_joint_positions(left_arm_chain)
	var right_arm_positions: Array[Vector3] = get_joint_positions(right_arm_chain)

	left_arm_positions = solve_two_bone_ik(
		left_arm_positions,
		left_arm_rest_lengths,
		left_hand_tracker_pos,
		left_elbow_pole
	)

	right_arm_positions = solve_two_bone_ik(
		right_arm_positions,
		right_arm_rest_lengths,
		right_hand_tracker_pos,
		right_elbow_pole
	)

	apply_joint_positions_local(left_arm_chain, left_arm_positions)
	apply_joint_positions_local(right_arm_chain, right_arm_positions)

func get_bone_rest_global_transform(bone_idx: int) -> Transform3D:
	return skeleton.get_bone_global_rest_transform(bone_idx)


func compute_chain_rest_lengths(chain: Array[int]) -> Array[float]:
	var lengths := []
	for i in range(chain.size() - 1):
		var a = get_bone_rest_global_transform(chain[i]).origin
		var b = get_bone_rest_global_transform(chain[i + 1]).origin
		lengths.append(a.distance_to(b))
	return lengths

func _init_bone_ids():
	head_bone_id = skeleton.find_bone(head_bone_name)
	neck_bone_id = skeleton.find_bone(neck_bone_name)
	spine_bone_id = skeleton.find_bone(spine_bone_name)
	spine1_bone_id = skeleton.find_bone(spine1_bone_name)
	spine2_bone_id = skeleton.find_bone(spine2_bone_name)
	left_shoulder_bone_id = skeleton.find_bone(left_shoulder_bone_name)
	left_arm_bone_id = skeleton.find_bone(left_arm_bone_name)
	left_forearm_bone_id = skeleton.find_bone(left_forearm_bone_name)
	left_hand_bone_id = skeleton.find_bone(left_hand_bone_name)
	right_shoulder_bone_id = skeleton.find_bone(right_shoulder_bone_name)
	right_arm_bone_id = skeleton.find_bone(right_arm_bone_name)
	right_forearm_bone_id = skeleton.find_bone(right_forearm_bone_name)
	right_hand_bone_id = skeleton.find_bone(right_hand_bone_name)
	pelvis_bone_id = skeleton.find_bone(pelvis_bone_name)
	left_upleg_bone_id = skeleton.find_bone(left_upleg_bone_name)
	left_leg_bone_id = skeleton.find_bone(left_leg_bone_name)
	left_foot_bone_id = skeleton.find_bone(left_foot_bone_name)
	right_upleg_bone_id = skeleton.find_bone(right_upleg_bone_name)
	right_leg_bone_id = skeleton.find_bone(right_leg_bone_name)
	right_foot_bone_id = skeleton.find_bone(right_foot_bone_name)

func global_to_bone_local_transform(bone_idx: int, desired_global: Transform3D) -> Transform3D:
	var parent = skeleton.get_bone_parent(bone_idx)
	var parent_global = skeleton.get_bone_global_pose(parent) if parent != -1 else skeleton.global_transform
	return parent_global.affine_inverse() * desired_global

func set_bone_global_transform_local_override(bone_idx: int, desired_global: Transform3D, weight: float = 1.0) -> void:
	var local = global_to_bone_local_transform(bone_idx, desired_global)
	skeleton.set_bone_local_pose_override(bone_idx, local, weight, true)

func set_bone_global_transform_local_override_keep_rotation(bone_idx: int, desired_global_pos: Vector3, weight: float = 1.0) -> void:
	# keep bone rotation, only set position
	var cur_global = skeleton.get_bone_global_pose(bone_idx)
	var desired_global = Transform3D(cur_global.basis, desired_global_pos)
	set_bone_global_transform_local_override(bone_idx, desired_global, weight)

func apply_joint_positions_local(chain: Array[int], joint_positions: Array[Vector3]) -> void:
	for i in range(chain.size()):
		var bone_idx: int = chain[i]
		var target_pos: Vector3 = joint_positions[i]
		set_bone_global_transform_local_override_keep_rotation(bone_idx, target_pos, 1.0)

func get_joint_positions(chain: Array[int]) -> Array[Vector3]:
	var joint_positions: Array[Vector3] = []
	for bone_idx in chain:
		joint_positions.append(skeleton.get_bone_global_pose(bone_idx).origin)
	return joint_positions

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
			var lambda: float = joint_distances[i] / r
			# Find the new joint position (Update)
			joint_positions[i + 1] = (1 - lambda) * curr_joint_pos + lambda * target_position
	else:
		# Target is reachable
		# Set initial position of joint p_1
		var b: Vector3 = joint_positions[0]
		# Check whether the distance between the end effector p_n and the target t is greater
		# than a tolerance
		var iteration = 0
		var dist_btn_ee_and_target: float = joint_positions[-1].distance_to(target_position)
		while dist_btn_ee_and_target > tolerance and iteration < max_iterations:
			iteration += 1
			# Stage 1: Forward Reaching
			# Set the end effector p_n as target t
			joint_positions[-1] = target_position
			for i in range(joint_count - 2, -1, -1):
				var curr_joint_pos: Vector3 = joint_positions[i]
				var next_joint_pos: Vector3 = joint_positions[i + 1]
				# Find the distance r_i between the new joint position p_i+1and the joint p_i
				var r = next_joint_pos.distance_to(curr_joint_pos)
				# Prevent division by zero where next and curr joint positions are the same
				var lambda: float = joint_distances[i] / r if r > 0.0001 else 0.0
				# Find the new joint positions p_i (Update)
				joint_positions[i] = (1 - lambda) * next_joint_pos + lambda * curr_joint_pos
			# Stage 2: Backward Reaching
			# Set the root p_i as its initial position
			joint_positions[0] = b

			for i in range(joint_count - 1):
				var curr_joint_pos: Vector3 = joint_positions[i]
				var next_joint_pos: Vector3 = joint_positions[i + 1]
				# Find the distance r_i between the new joint position p_i
				# and the joint p_i+1
				var r: float = next_joint_pos.distance_to(curr_joint_pos)
				var lambda: float = joint_distances[i] / r if r > 0.0001 else 0.0
				# Find the new joint position (Update)
				joint_positions[i + 1] = (1 - lambda) * curr_joint_pos + lambda * next_joint_pos
			dist_btn_ee_and_target = joint_positions[-1].distance_to(target_position)
	return joint_positions

func get_bone_global_basis(bone_id: int) -> Basis:
	return skeleton.get_bone_global_pose(bone_id).basis

# For arm and leg
func get_pole_vector(
	pole_parent_pos: Vector3,
	reference_bone_id: int,
	left: bool = false,
	forward_offset: float = 0.3,
	lateral_offset: float = 0.1) -> Vector3:
	var pole_forward: Vector3 = get_bone_global_basis(reference_bone_id).z.normalized()
	var pole_right: Vector3 = get_bone_global_basis(reference_bone_id).x.normalized()
	if left:
		lateral_offset *= -1
	return pole_parent_pos + pole_forward * forward_offset + pole_right * lateral_offset

func apply_cone_constraint(
	bone_pos: Vector3,
	parent_pos: Vector3,
	direction: Vector3,
	max_angle_deg: float
	) -> Vector3:
	var current_dir = (bone_pos - parent_pos)
	if current_dir.length() < EPS:
		return bone_pos
	current_dir = current_dir.normalized()
	var angle = rad_to_deg(current_dir.angle_to(direction))
	if angle > max_angle_deg:
		var axis = current_dir.cross(direction)
		if axis.length() < EPS:
			# can't build axis, return original
			return bone_pos
		axis = axis.normalized()
		current_dir = direction.rotated(axis, deg_to_rad(max_angle_deg))
		return parent_pos + current_dir * (bone_pos - parent_pos).length()
	return bone_pos

func apply_hinge_constraint(bone_pos: Vector3, parent_pos: Vector3, hinge_axis: Vector3) -> Vector3:
	var dir = bone_pos - parent_pos
	if dir.length() < EPS:
		return bone_pos
	dir = dir.normalized()
	var projected = dir - dir.dot(hinge_axis) * hinge_axis
	if projected.length() < EPS:
		return bone_pos
	return parent_pos + projected.normalized() * (bone_pos - parent_pos).length()

func solve_two_bone_ik(
		joint_positions: Array[Vector3],
		joint_lengths: Array[float],
		target_pos: Vector3,
		pole_pos: Vector3,
	) -> Array[Vector3]:
		if joint_positions.size() != (joint_lengths.size() + 1):
			push_error("TwoBoneIK: size of joint_positions should be size of joint_lengths + 1")
			return [];
		if joint_positions.size() != 3:
			push_error("TwoBoneIK: joint_positions array is not size 3")
			return [];
		if joint_lengths.size() != 2:
			push_error("TwoBoneIK: joint_lengths array is not size 2")
			return [];

		var root: Vector3 = joint_positions[0]
		var new_mid: Vector3 = joint_positions[1]
		var a: float = joint_lengths[0]
		var b: float = joint_lengths[1]
		var root_to_target: Vector3 = target_pos - root
		var c: float = root_to_target.length()
		var total_chain_len: float = a + b
		var root_to_pole: Vector3 = pole_pos - root

		if c < EPS:
			var pole_dir = root_to_pole
			if pole_dir.length() < EPS:
				pole_dir = Vector3(0, 0, 1)
			pole_dir = pole_dir.normalized()
			var mid = root + pole_dir * a
			return [root, mid, target_pos]

		if c > total_chain_len:
			new_mid = root + root_to_target.normalized() * a
			return [root, new_mid, target_pos]

		# safe law of cosines
		var denom = 2.0 * a * c
		var cos_angle = 1.0
		if abs(denom) > EPS:
			cos_angle = (a * a + c * c - b * b) / denom
			cos_angle = clamp(cos_angle, -1.0, 1.0)
		var angle = acos(cos_angle)

		# plane normal robust
		var plane_normal = root_to_target.cross(root_to_pole)
		if plane_normal.length() < EPS:
			plane_normal = root_to_target.cross(Vector3.UP)
			if plane_normal.length() < EPS:
				plane_normal = root_to_target.cross(Vector3.RIGHT)
			if plane_normal.length() < EPS:
				plane_normal = Vector3(0, 1, 0)
		plane_normal = plane_normal.normalized()

		var rbasis = Basis(plane_normal, angle).orthonormalized()
		var dir_rotated = rbasis.xform(root_to_target.normalized())
		new_mid = root + dir_rotated * a
		return [root, new_mid, target_pos]
