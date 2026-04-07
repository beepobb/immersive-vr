extends Node3D

@export var static_player: PackedScene
@export var moving_player: PackedScene
@export var default_avatar: PackedScene
@export var moving: bool = true
@export var in_call: bool = false
var player: Node3D
var avatar: Node3D
@export var spawn_point = Vector3.ZERO

func _ready() -> void:
	if in_call:
		return
		#avatar = default_avatar.instantiate()
		#GameState.avatar = avatar
		#GameState.apply_to_avatar()
		#player.add_child(avatar)
		
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
		player.name = str(local_peer_id)
	else:
		# XRToolsSceneBase offline fallback looks for PlayerLoader/XROrigin3D.
		player.name = "XROrigin3D"
	add_child(player)
	player.global_position = spawn_point

func _trace_player_position(tag: String) -> void:
	if player == null:
		print("[%s] player is null" % tag)
		return

	print("[%s] local=%s global=%s" % [tag, str(player.position), str(player.global_position)])
