extends Node3D

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")
const AvatarScene = preload("res://scenes/game/avatar_customisation/avatar_test.tscn")

@onready var environment_root: Node3D = %EnvironmentRoot
@onready var xr_origin: Node3D = get_node_or_null("XROrigin3D")
@onready var player_loader: Node = $"../PlayerLoader"

func _ready() -> void:
	_load_selected_environment()
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(del_player)
	# Wait until the whole scene tree is ready so MultiplayerSpawner sees these adds.
	call_deferred("_spawn_existing_players")

func _spawn_existing_players() -> void:
	add_player(1)
	for id in multiplayer.get_peers():
		add_player(id)
	
func _load_selected_environment() -> void:
	var selected_environment_id = GameState.environment_id
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

func add_player(id):
	if not multiplayer.is_server():
		return
	var node_name := str(id)
	if player_loader.has_node(node_name):
		return
	var scene = load("res://scenes/player/XROrigin.tscn")
	var player: XROrigin3D = scene.instantiate()
	player.name = node_name # important for syncing
	var spawn_pos := Vector3(randf_range(-3.0, 3.0), 0.0, 0)
	player.position = spawn_pos
	player_loader.add_child(player)

func del_player(id):
	print("delete player: " + str(id))
	
func _exit_tree() -> void:
	if not multiplayer.is_server():
		return
	multiplayer.peer_connected.disconnect(add_player)
	multiplayer.peer_disconnected.disconnect(del_player)
