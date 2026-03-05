extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	# Spawn for peers when they connect (server only)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# IMPORTANT: spawn the server's own player too
	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id())

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	# MultiplayerSpawner will usually handle despawn, but keep this for safety/logging if needed
	pass

func _spawn_player(id: int) -> void:
	if network_player == null:
		push_error("network_player is not assigned in the Inspector!")
		return

	var player: Node = network_player.instantiate()
	player.name = str(id)

	# MultiplayerSpawner provides spawn_path; this adds player under that path.
	get_node(spawn_path).call_deferred("add_child", player) 
