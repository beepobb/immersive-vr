extends Node3D

var xr_interface: XRInterface
@export var mirror_player_scene_path: String
@export var player_spawn_path: NodePath

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialised successfully")
			
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		get_viewport().use_xr = NOTIFICATION_WM_CLOSE_REQUEST
	else:
		print("OpenXR not initialised, please check of your headset is connected")
		
	spawn_player()

func spawn_player():
	var mirror_player_scene = load(mirror_player_scene_path)
	
	if mirror_player_scene:
		var player_instance = mirror_player_scene.instantiate()
		
		# Add to the main scene
		var main_scene = get_tree().current_scene
		main_scene.add_child(player_instance)
		
		# Position the player at the spawn point if specified
		if not player_spawn_path.is_empty():
			var spawn_point = get_node_or_null(player_spawn_path)
			if spawn_point:
				player_instance.global_position = spawn_point.global_position
				player_instance.global_rotation = spawn_point.global_rotation
			else:
				# Fallback position if spawn point not found
				player_instance.global_position = Vector3(0, 1.7, 0)
	else:
		push_error("Failed to load player scene: " + mirror_player_scene_path)
