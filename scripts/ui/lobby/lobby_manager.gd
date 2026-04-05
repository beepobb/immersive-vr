extends Node3D

@onready var avatarRoot: Node3D = get_node_or_null("../AvatarTest") as Node3D

func _ready() -> void:
	GameState.avatar = avatarRoot
	GameState.apply_to_avatar()
	GameState.initialize_lobby_network(int(Roles.user_role))
