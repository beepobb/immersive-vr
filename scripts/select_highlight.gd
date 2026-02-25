extends Node3D

@export var mesh: MeshInstance3D
@export var outline_material: Material
@export var selection_material: Material
@export var static_body: StaticBody3D
var pointer: XRToolsPointerEvent
var current_pointer_target: Object = null
@export var teleport_marker: Marker3D

signal teleport_requested(dest_global_transform: Transform3D)

func _ready():
	# Wait 1 frame so the instanced scene is fully in the tree
	await get_tree().process_frame
	add_to_group("interactable")
	
	var controllers := get_tree().get_nodes_in_group("xr_controller")
	var pointers := get_tree().get_nodes_in_group("xr_pointer")
	
	for c in controllers:
		if c.has_signal("button_pressed"):
			c.button_pressed.connect(_on_controller_button_pressed)
	
	# Connect Pointer to Pointer function
	for p in pointers:
		if p.has_signal("pointing_event"):
			p.pointing_event.connect(_on_pointing_event)

func _on_pointing_event(e: XRToolsPointerEvent) -> void:
	if e.target != static_body:
		return

	match e.event_type:
		XRToolsPointerEvent.Type.ENTERED:
			current_pointer_target = e.target # Track that we are looking at the sofa
			mesh.material_overlay = outline_material
		XRToolsPointerEvent.Type.EXITED:
			current_pointer_target = null # We stopped looking
			mesh.material_overlay = null
		XRToolsPointerEvent.Type.PRESSED:
			mesh.material_overlay = selection_material
			if teleport_marker:
				emit_signal("teleport_requested", teleport_marker.global_transform)
		XRToolsPointerEvent.Type.RELEASED:
			mesh.material_overlay = null

func _on_controller_button_pressed(button_name: String) -> void:
	pass
	## If the trigger is pressed AND the pointer is currently hitting this sofa
	#if button_name == "trigger_click" and current_pointer_target == static_body:
		#print("Sofa Selected!")
		#
