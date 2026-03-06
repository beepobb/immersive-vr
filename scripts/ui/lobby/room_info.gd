extends VBoxContainer

@export var participant_label: Label

var lobby_manager

func _ready() -> void:
	lobby_manager = get_node_or_null("../../../../LobbyManager")
	if lobby_manager == null:
		push_error("LobbyManager not found")
		return

	lobby_manager.update_lobby_ui.connect(_update_lobby_ui)
	_update_lobby_ui(lobby_manager.player_ready)

func _update_lobby_ui(player_ready: Dictionary) -> void:
	var participant_count = player_ready.size()

	if participant_label:
		participant_label.text = "%d/2" % participant_count
