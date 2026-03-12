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

	if not HighLevelNetworkHandler.session_ended.is_connected(_on_session_ended):
		HighLevelNetworkHandler.session_ended.connect(_on_session_ended)

	if not AvatarState.environment_id.is_empty():
		_load_selected_environment()
	
func _load_environment(environment) -> void:
	var scene = load(environment).instantiate()
	scene.position = Vector3(0.0, 0.25, 0)
	get_tree().current_scene.add_child(scene)

func _load_selected_environment() -> void:
	var selected_environment = AvatarState.environment_id
	if selected_environment.is_empty():
		return

	if selected_environment == "res://scenes/environment/therapy_room.tscn" and has_node("therapy_room"):
		return

	var default_room = get_node_or_null("therapy_room")
	if default_room:
		default_room.queue_free()

	_load_environment(selected_environment)

func _on_session_ended(message: String) -> void:
	AvatarState.return_to_home(self , message)
