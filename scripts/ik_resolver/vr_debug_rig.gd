@tool
class_name VRDebugRig
extends Node3D

## Assign your IK Resolver node here
@export var target_ik_solver: FullBodyIKResolver3D

@export_group("Actions")
## Click this to spawn/reset the 6 markers in a T-Pose
@export var spawn_debug_markers: bool = false : set = _on_spawn_markers
## Click this to auto-assign these markers to your IK Resolver
@export var assign_to_ik: bool = false : set = _on_assign_to_ik

# Configuration for the visual markers
var _marker_colors = {
	"Head": Color.HOT_PINK,
	"Waist": Color.LIME_GREEN,
	"LeftHand": Color.CYAN,
	"RightHand": Color.CYAN,
	"LeftFoot": Color.ORANGE,
	"RightFoot": Color.ORANGE
}

func _on_spawn_markers(value):
	if not value: return
	
	# Create a holder node if it doesn't exist
	var container_name = "Debug_Trackers"
	var container = get_node_or_null(container_name)
	if not container:
		container = Node3D.new()
		container.name = container_name
		add_child(container)
		container.owner = get_tree().edited_scene_root
	
	# Define standard T-Pose positions (approximate meters)
	var positions = {
		"Head": Vector3(0, 1.7, 0),
		"Waist": Vector3(0, 1.0, 0),
		"LeftHand": Vector3(-0.5, 1.4, 0),  # Slightly forward/side
		"RightHand": Vector3(0.5, 1.4, 0),
		"LeftFoot": Vector3(-0.2, 0.1, 0),
		"RightFoot": Vector3(0.2, 0.1, 0)
	}
	
	for key in positions.keys():
		# Check if marker already exists
		if container.has_node(key):
			continue
			
		# Create visual marker (MeshInstance so you can click it!)
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.name = key
		
		# Give it a shape
		var mesh: Mesh = null
		if "Hand" in key or "Foot" in key:
			var box = BoxMesh.new()
			box.size = Vector3(0.1, 0.1, 0.1)
			mesh = box
		else:
			var sphere = SphereMesh.new()
			sphere.radius = 0.08
			sphere.height = 0.16
			mesh = sphere
			
		# Give it a material/color
		var mat = StandardMaterial3D.new()
		mat.albedo_color = _marker_colors.get(key, Color.WHITE)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Bright and visible
		mesh.material = mat
		
		mesh_inst.mesh = mesh
		mesh_inst.position = positions[key]
		
		container.add_child(mesh_inst)
		mesh_inst.owner = get_tree().edited_scene_root # Important for saving scene
		
	print("VR Debug Markers Created!")

func _on_assign_to_ik(value):
	if not value: return
	if not target_ik_solver:
		printerr("Please assign a Target IK Solver first!")
		return
		
	var container = get_node_or_null("Debug_Trackers")
	if not container:
		printerr("Click 'Spawn Debug Markers' first!")
		return
		
	# Auto-wire the nodes
	target_ik_solver.tracker_head = container.get_node("Head")
	target_ik_solver.tracker_waist = container.get_node("Waist")
	target_ik_solver.tracker_left_hand = container.get_node("LeftHand")
	target_ik_solver.tracker_right_hand = container.get_node("RightHand")
	target_ik_solver.tracker_left_foot = container.get_node("LeftFoot")
	target_ik_solver.tracker_right_foot = container.get_node("RightFoot")
	
	print("Debug Markers assigned to IK Solver successfully.")