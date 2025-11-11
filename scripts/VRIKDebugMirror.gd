@tool
extends Node3D
class_name VRIKDebugMirror

## A debug visualization that mirrors the player's skeleton bone poses
## Place this in your scene to see how the skeleton tracks from an external view

@export_group("Player Settings")
@export var auto_find_player: bool = true
@export var player_skeleton_path: NodePath = NodePath("")

@export_group("Update Settings")
@export var update_rate: float = 60.0  # Updates per second (0 = every frame)

# Internal references
var player_skeleton: Skeleton3D = null
var skeleton_mirror: Skeleton3D = null
var skeleton_instance: Node3D = null
var update_timer: float = 0.0

func _ready():
	if Engine.is_editor_hint():
		return
	
	# Find our own skeleton mesh
	skeleton_instance = get_node_or_null("SkeletalMesh")
	if not skeleton_instance:
		push_error("[VRIKDebugMirror] No SkeletalMesh child found!")
		return
	
	# Find the Skeleton3D within our mesh
	skeleton_mirror = skeleton_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton_mirror:
		push_error("[VRIKDebugMirror] Could not find Skeleton3D in SkeletalMesh!")
		return
	
	# Wait a few frames for the scene to fully initialize
	for i in range(5):
		await get_tree().process_frame
	
	# Auto-find the player's skeleton if enabled
	if auto_find_player and player_skeleton_path.is_empty():
		print("[VRIKDebugMirror] Attempting to auto-find player skeleton...")
		player_skeleton = _find_player_skeleton()
		
		if player_skeleton:
			print("[VRIKDebugMirror] Auto-found player skeleton at: ", player_skeleton.get_path())
		else:
			push_warning("[VRIKDebugMirror] Could not auto-find player skeleton. Set player_skeleton_path manually.")
			return
	elif not player_skeleton_path.is_empty():
		player_skeleton = get_node_or_null(player_skeleton_path)
		if not player_skeleton:
			push_error("[VRIKDebugMirror] Could not find Skeleton3D at path: ", player_skeleton_path)
			return
	else:
		push_warning("[VRIKDebugMirror] No player skeleton configured.")
		return
	
	if player_skeleton:
		print("[VRIKDebugMirror] Successfully connected to player skeleton")
		print("[VRIKDebugMirror] Player skeleton bones: ", player_skeleton.get_bone_count())
		print("[VRIKDebugMirror] Mirror skeleton bones: ", skeleton_mirror.get_bone_count())
		
		# Connect to skeleton_updated signal to run AFTER IK has been applied
		player_skeleton.skeleton_updated.connect(Callable(self, "_on_skeleton_updated"))
		print("[VRIKDebugMirror] Connected to skeleton_updated signal")
	else:
		push_error("[VRIKDebugMirror] No player skeleton found!")
		return

func _find_player_skeleton() -> Skeleton3D:
	"""Recursively search the scene tree for a Skeleton3D node (the player's skeleton)"""
	var root = get_tree().root
	var skeleton_nodes = _find_nodes_by_type(root, Skeleton3D)
	
	if skeleton_nodes.is_empty():
		return null
	
	# If multiple found, prefer one that's under an XROrigin3D
	for node in skeleton_nodes:
		# Don't pick ourselves!
		if node == skeleton_mirror:
			continue
			
		var parent = node.get_parent()
		while parent:
			if parent is XROrigin3D:
				return node
			parent = parent.get_parent()
	
	# Otherwise return the first one found (that isn't us)
	for node in skeleton_nodes:
		if node != skeleton_mirror:
			return node
	
	return null

func _find_nodes_by_type(node: Node, node_type) -> Array:
	"""Recursively find all nodes of a specific type"""
	var result = []
	
	# Check if current node matches
	if is_instance_of(node, node_type):
		result.append(node)
	
	# Recursively check children
	for child in node.get_children():
		result.append_array(_find_nodes_by_type(child, node_type))
	
	return result

func _on_skeleton_updated():
	"""Called when the player skeleton has finished updating (AFTER IK is applied)"""
	if Engine.is_editor_hint():
		return
	
	if not player_skeleton or not skeleton_mirror:
		return
	
	# Rate limiting
	if update_rate > 0:
		update_timer += get_process_delta_time()
		var update_interval = 1.0 / update_rate
		if update_timer < update_interval:
			return
		update_timer = 0.0
	
	# Mirror all bone poses from player to debug skeleton
	_mirror_skeleton_poses()

func _process(_delta: float):
	# We now update via the skeleton_updated signal instead of _process
	pass

func _mirror_skeleton_poses():
	"""Copy all bone transforms from player skeleton to mirror skeleton"""
	var bone_count = min(player_skeleton.get_bone_count(), skeleton_mirror.get_bone_count())
	
	# Copy the base pose first
	for bone_idx in range(bone_count):
		var bone_pose = player_skeleton.get_bone_pose(bone_idx)
		skeleton_mirror.set_bone_pose(bone_idx, bone_pose)
	
	# Then check if player skeleton has SkeletonIK3D children and copy their overrides
	for child in player_skeleton.get_children():
		if child is SkeletonIK3D and child.is_running():
			var ik = child as SkeletonIK3D
			# Get the bone indices for this IK chain
			var root_idx = player_skeleton.find_bone(ik.root_bone)
			var tip_idx = player_skeleton.find_bone(ik.tip_bone)
			
			if root_idx >= 0 and tip_idx >= 0:
				# Copy the global pose override for bones in this IK chain
				# Walk from tip to root
				var current_idx = tip_idx
				var safety_counter = 0
				while current_idx >= 0 and safety_counter < 100:
					safety_counter += 1
					
					# Get the global pose (which includes the IK override)
					var global_pose = player_skeleton.get_bone_global_pose(current_idx)
					skeleton_mirror.set_bone_global_pose_override(current_idx, global_pose, 1.0, true)
					
					# Move to parent
					if current_idx == root_idx:
						break
					current_idx = player_skeleton.get_bone_parent(current_idx)
