extends Node3D

@export var left_controller: XRController3D
@export var right_controller: XRController3D
@export var left_pointer: XRToolsFunctionPointer
@export var right_pointer: XRToolsFunctionPointer

func _ready() -> void:
	left_controller.add_to_group("xr_controller")
	right_controller.add_to_group("xr_controller")
	left_pointer.add_to_group("xr_pointer")
	right_pointer.add_to_group("xr_pointer")
	
