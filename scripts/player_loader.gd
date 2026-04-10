extends Node3D

@export var static_player: PackedScene
@export var moving_player: PackedScene
@export var default_avatar: PackedScene
@export var moving: bool = true
@export var in_call: bool = false
var player: Node3D
var player_name: String
var spawn_point: Node3D

func _ready() -> void:
	if in_call:
		return
		
	if moving:
		player = moving_player.instantiate()
	else:
		player = static_player.instantiate()
	
	var has_network_peer := multiplayer.multiplayer_peer != null
	var local_peer_id := 0
	if has_network_peer:
		local_peer_id = multiplayer.get_unique_id()
	if has_network_peer and local_peer_id > 0:
		# player.gd reads name as peer id to decide local movement authority.
		player_name = str(local_peer_id)
	else:
		# XRToolsSceneBase offline fallback looks for PlayerLoader/XROrigin3D.
		player_name = "XROrigin3D"
	player.name = player_name
	add_child(player)
	
func _process(delta: float) -> void:
	# debug mode
	if GameState.in_debug and not in_call:
		get_node(player_name).position = Vector3(0,2.5,0)
		
func _trace_player_position(tag: String) -> void:
	if player == null:
		print("[%s] player is null" % tag)
		return

	print("[%s] local=%s global=%s" % [tag, str(player.position), str(player.global_position)])
