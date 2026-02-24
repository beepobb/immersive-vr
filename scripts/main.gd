extends Node3D

@export var DESKTOP_DEBUG := true  # remove later

var xr_interface: XRInterface
signal load_environment(environment)

func _ready():

	if DESKTOP_DEBUG:
		# Disable XR
		get_viewport().use_xr = false
		
		# Make mouse visible for UI clicking
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		print("Desktop debug: XR disabled, mouse visible")

		load_environment.connect(_load_environment)
		return

	# Normal XR flow
	xr_interface = XRServer.find_interface("OpenXR")

	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialised successfully")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
	else:
		print("OpenXR not initialised, please check if headset is connected")

	load_environment.connect(_load_environment)


func _load_environment(environment) -> void:
	var scene = load(environment).instantiate()
	scene.position = Vector3(0.0, 0.25, 0)
	get_tree().current_scene.add_child(scene)
