extends Node3D

@export var static_player: PackedScene
@export var moving_player: PackedScene
@export var moving: bool = true
var player

func _ready() -> void:
	if moving:
		player = moving_player.instantiate()
	else:
		player = static_player.instantiate()
	
	player.name = "XROrigin3D" # to match scene_base.gd
	add_child(player)
