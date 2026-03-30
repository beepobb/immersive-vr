extends Node3D

@export var static_player: PackedScene
@export var moving_player: PackedScene
@export var default_avatar: PackedScene
@export var moving: bool = true
@export var in_call: bool = false
var player: Node3D
var avatar: Node3D

func _ready() -> void:
	if moving:
		player = moving_player.instantiate()
	else:
		player = static_player.instantiate()
	
	if in_call:
		avatar = default_avatar.instantiate()
		AvatarState.avatar = avatar
		AvatarState.apply_to_avatar()
		player.add_child(avatar)
	
		
	player.name = "XROrigin3D" # to match scene_base.gd
	player.position = Vector3.ZERO
	add_child(player)

func _trace_player_position(tag: String) -> void:
	if player == null:
		print("[%s] player is null" % tag)
		return

	print("[%s] local=%s global=%s" % [tag, str(player.position), str(player.global_position)])
