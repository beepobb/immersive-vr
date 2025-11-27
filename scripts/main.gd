extends Node3D

var xr_interface: XRInterface
signal load_environment(environment)

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialised successfully")
			
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		get_viewport().use_xr = NOTIFICATION_WM_CLOSE_REQUEST
	else:
		print("OpenXR not initialised, please check of your headset is connected")
	
	load_environment.connect(_load_environment)
	
func _load_environment(environment) -> void:
	var scene = load(environment).instantiate()
	scene.position = Vector3(0.0, 0.25, 0)
	get_tree().current_scene.add_child(scene)
