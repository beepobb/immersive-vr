extends Node3D

@export var static_player: PackedScene
@export var moving_player: PackedScene
@export var default_avatar: PackedScene
@export var moving: bool = true
@export var in_call: bool = false
var player: Node3D
var avatar: Node3D

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
	
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		local_peer_id = 1
	player.name = "XROrigin3D"
	player.position = Vector3.ZERO
	add_child(player)

func _trace_player_position(tag: String) -> void:
	if player == null:
		print("[%s] player is null" % tag)
		return

	print("[%s] local=%s global=%s" % [tag, str(player.position), str(player.global_position)])
