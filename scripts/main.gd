extends Node3D

<< << << < HEAD
@export var DESKTOP_DEBUG := true # remove later
== == == =
const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")
>> >> >> > feature / multiplayer

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

	if (OS.get_name() == "Android"):
		OS.request_permissions()
		
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
	var selected_environment_id = AvatarState.environment_id
	if selected_environment_id.is_empty():
		selected_environment_id = EnvironmentCatalog.get_default_environment_id()

	var selected_environment = EnvironmentCatalog.get_environment_scene_path(selected_environment_id)
	if selected_environment.is_empty():
		selected_environment = EnvironmentCatalog.get_environment_scene_path(EnvironmentCatalog.get_default_environment_id())

	var default_room = get_node_or_null("therapy_room")
	if default_room:
		default_room.queue_free()

	_load_environment(selected_environment)

func _on_session_ended(message: String) -> void:
	AvatarState.return_to_home(self , message)
