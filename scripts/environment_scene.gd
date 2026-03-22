extends Node3D

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")
const AvatarScene = preload("res://scenes/ui/avatar_customisation/avatar_test.tscn")

@onready var environment_root: Node3D = %EnvironmentRoot
@onready var xr_origin: Node3D = get_node_or_null("XROrigin3D")

var spawned_remote_avatars: Array[Node3D] = []

func _ready() -> void:
	if not HighLevelNetworkHandler.session_ended.is_connected(_on_session_ended):
		HighLevelNetworkHandler.session_ended.connect(_on_session_ended)

	_load_selected_environment()
	_spawn_call_avatars()

func _load_selected_environment() -> void:
	var selected_environment_id = AvatarState.environment_id
	var selected_scene_path = EnvironmentCatalog.get_environment_scene_path(selected_environment_id)
	if selected_scene_path.is_empty():
		selected_scene_path = EnvironmentCatalog.get_environment_scene_path(EnvironmentCatalog.get_default_environment_id())

	for child in environment_root.get_children():
		child.queue_free()

	var selected_scene = load(selected_scene_path) as PackedScene
	if selected_scene == null:
		push_error("Unable to load environment scene: %s" % selected_scene_path)
		return

	var environment_instance = selected_scene.instantiate()
	environment_instance.position = Vector3(0.0, 0.25, 0.0)
	environment_root.add_child(environment_instance)

func _spawn_call_avatars() -> void:
	_spawn_local_avatar()
	_spawn_remote_avatars()

func _spawn_local_avatar() -> void:
	if xr_origin == null:
		push_warning("XROrigin3D not found. Local avatar cannot be spawned.")
		return

	var existing_avatar = xr_origin.get_node_or_null("LocalAvatar")
	if existing_avatar != null:
		existing_avatar.queue_free()

	var avatar_instance = AvatarScene.instantiate() as Node3D
	if avatar_instance == null:
		push_warning("Unable to instantiate local avatar scene.")
		return

	avatar_instance.name = "LocalAvatar"
	xr_origin.add_child(avatar_instance)
	AvatarState.apply_to_avatar(avatar_instance)

func _spawn_remote_avatars() -> void:
	_clear_remote_avatars()

	if HighLevelNetworkHandler.lobby_players_by_peer_id.is_empty():
		return

	var local_peer_id = multiplayer.get_unique_id()
	var remote_index = 0
	for peer_id in HighLevelNetworkHandler.lobby_players_by_peer_id.keys():
		var peer_id_int = int(peer_id)
		if peer_id_int == local_peer_id:
			continue

		var avatar_state = Dictionary(HighLevelNetworkHandler.lobby_players_by_peer_id[peer_id])
		var avatar_instance = AvatarScene.instantiate() as Node3D
		if avatar_instance == null:
			continue

		avatar_instance.name = "RemoteAvatar_%d" % peer_id_int
		avatar_instance.position = Vector3(1.5 + (remote_index * 0.9), 0.0, -0.75)
		add_child(avatar_instance)
		AvatarState.apply_to_avatar(avatar_instance, avatar_state)

		spawned_remote_avatars.append(avatar_instance)
		remote_index += 1

func _clear_remote_avatars() -> void:
	for avatar_node in spawned_remote_avatars:
		if is_instance_valid(avatar_node):
			avatar_node.queue_free()
	spawned_remote_avatars.clear()

func _on_session_ended(message: String) -> void:
	AvatarState.return_to_home(self , message)
