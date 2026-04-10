extends CanvasLayer

var original_parent
var original_transform
var ui_3d: Node3D

@onready var left_controller: Node3D = get_node("/root/Main/XROrigin3D/LeftController")
@onready var right_controller: Node3D = get_node("/root/Main/XROrigin3D/RightController")

# Optional: only needed if can switch between left and right
var isDockedLeft: bool = false
var isDockedRight: bool = false

@onready var debug_label: Label = $MarginContainer/VBoxContainer/DebugLabel

func _ready():
	# get its parent
	original_parent = get_parent().get_parent().get_parent().get_parent()
	ui_3d = get_parent().get_parent().get_parent()
	original_transform = ui_3d.transform
	debug_label.text = "Hello World!"

func _on_dock_left_pressed():
	if isDockedLeft: return
	dock_to(left_controller)
	isDockedLeft = true
	isDockedRight = false

func _on_dock_right_pressed():
	if isDockedRight: return
	dock_to(right_controller)
	isDockedRight = true
	isDockedLeft = false

	
func dock_to(controller: XRNode3D):
	# if original parent is not controller
	# assign it as child of given controller
	var current_parent = ui_3d.get_parent()
	if current_parent:
		current_parent.remove_child(ui_3d)
		
	ui_3d.transform = Transform3D.IDENTITY
	ui_3d.scale = Vector3(0.195, 0.195, 0.195)
	ui_3d.translate(Vector3(0, 0.8, -0.8))
	ui_3d.rotate_x(deg_to_rad(-20))
	
	controller.add_child(ui_3d)
	

func _on_return_pressed() -> void:
	# return is for returning to undock
	# so if is not docked cannot return
	if not (isDockedLeft or isDockedRight):
		return
	
	# find out which controller u are on by looking at parent
	var current_parent: XRController3D = ui_3d.get_parent()
	if current_parent == left_controller:
		isDockedLeft = false
	if current_parent == right_controller:
		isDockedRight = false
		
	current_parent.remove_child(ui_3d)
	ui_3d.transform = original_transform
	original_parent.add_child(ui_3d)
	
