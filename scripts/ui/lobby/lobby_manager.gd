extends Node3D

@onready var avatarRoot: Node3D = get_node_or_null("../AvatarTest") as Node3D
@onready var lobby_ui_root: Node3D = get_node_or_null("../UI") as Node3D
@onready var disclaimer: Node3D = get_node_or_null("../DisclaimerViewports")

var disclaimer_popup: Node3D = null
var disclaimer_popup_scene := preload("res://scenes/game/disclaimer_viewport.tscn")

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	GameState.avatar = avatarRoot
	GameState.apply_to_avatar()
	GameState.initialize_lobby_network(int(Roles.user_role))

	if not GameState.entered_lobby:
		_set_lobby_mouse_input_enabled(false)
		avatarRoot.hide()
		lobby_ui_root.hide()
		disclaimer.show()
		if disclaimer.has_signal("accepted"):
			if not disclaimer.accepted.is_connected(_on_disclaimer_accepted):
				disclaimer.accepted.connect(_on_disclaimer_accepted)
		GameState.entered_lobby = true
	else:
		call_deferred("_hide_disclaimer_on_return")
		avatarRoot.show()
		lobby_ui_root.show()
		_set_lobby_mouse_input_enabled(true)

func _hide_disclaimer_on_return() -> void:
	if disclaimer != null and is_instance_valid(disclaimer):
		disclaimer.hide()

func _set_lobby_mouse_input_enabled(enabled: bool) -> void:
	if lobby_ui_root == null:
		return

	for node in _get_descendants(lobby_ui_root):
		if node is XRToolsViewport2DIn3D:
			node.enabled = enabled

func _get_descendants(root: Node) -> Array[Node]:
	var descendants: Array[Node] = []
	for child in root.get_children():
		descendants.append(child)
		descendants.append_array(_get_descendants(child))
	return descendants

func _on_disclaimer_accepted() -> void:
	print("Lobby disclaimer accepted")
	_set_lobby_mouse_input_enabled(true)
	disclaimer.hide()
	avatarRoot.show()
	lobby_ui_root.show()
