extends MultiplayerSpawner

@export var network_player: PackedScene
@onready var spawn_points = %SpawnPoints.get_children()

func _ready() -> void:
	# No longer auto-start listening - let the UI control it
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(remove_player)
	HighLevelNetworkHandler.connect("cleanup_players", cleanup_all_players)
	
func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	
	# Determine location: Host (1) gets Marker1, Client gets Marker2
	var points = get_tree().get_nodes_in_group("spawn_points")
	var point = points[0] if id == 1 else points[1]
	$/root/MultiplayerTest/Players.add_child(player)
	player.global_transform = point.global_transform # Snap to marker

func remove_player(id: int) -> void:
	print("Removing player: ", id)
	var player_node = $/root/MultiplayerTest/Players.get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()
		print("Player ", id, " removed from tree")

func cleanup_all_players() -> void:
	print("Cleaning up all players")
	var players_container = $/root/MultiplayerTest/Players
	if players_container:
		for child in players_container.get_children():
			child.queue_free()
		print("All players removed from tree")
