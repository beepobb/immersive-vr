extends MultiplayerSpawner

@export var network_player: PackedScene
@onready var spawn_points = %SpawnPoints.get_children()

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	
func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	
	# Determine location: Host (1) gets Marker1, Client gets Marker2
	var points = get_tree().get_nodes_in_group("spawn_points")
	var point = points[0] if id == 1 else points[1]
	$/root/MultiplayerTest/Players.add_child(player)
	player.global_transform = point.global_transform # Snap to marker
