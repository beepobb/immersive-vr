extends VBoxContainer

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")

const STATUS_COLOR_DEFAULT := Color(1, 1, 1, 1)
const STATUS_COLOR_ALERT := Color(0.95, 0.25, 0.25, 1)

@onready var room_code_label: Label = %RoomCode
@onready var participant_label: Label = %Participants
@onready var player_list: GridContainer = %PlayerList
@onready var lobby_status_label: Label = %LobbyStatus
@onready var start_call_button: Button = %StartCallButton
@onready var ready_button: Button = %ReadyButton
@export var player_card: PackedScene

var lobby_manager
var last_lobby_state := {}

func _ready() -> void:
	lobby_manager = get_node_or_null("../../../../../LobbyManager")
	if lobby_manager == null:
		push_error("LobbyManager not found")
		return

	start_call_button.pressed.connect(_on_start_call_pressed)
	ready_button.pressed.connect(_on_ready_button_pressed)
	lobby_manager.update_lobby_ui.connect(_update_lobby_ui)
	lobby_manager.start_call_requested.connect(_on_start_call_requested)
	if not HighLevelNetworkHandler.session_ended.is_connected(_on_session_ended):
		HighLevelNetworkHandler.session_ended.connect(_on_session_ended)
	_update_lobby_ui(lobby_manager.get_lobby_state())

func _update_lobby_ui(lobby_state: Dictionary) -> void:
	last_lobby_state = lobby_state.duplicate(true)

	var participant_count = int(lobby_state.get("participant_count", 0))
	var max_players = int(lobby_state.get("max_players", 2))
	var local_ready = bool(lobby_state.get("local_ready", false))
	var is_host = bool(lobby_state.get("is_host", false))
	var room_code = str(lobby_state.get("room_code", ""))
	var can_start_call = bool(lobby_state.get("can_start_call", false))

	room_code_label.text = room_code if not room_code.is_empty() else "Pending"
	participant_label.text = "%d/%d" % [participant_count, max_players]
	start_call_button.visible = is_host
	start_call_button.disabled = not can_start_call
	ready_button.visible = not is_host
	ready_button.text = "Cancel Ready" if local_ready else "Mark Ready"

	_render_player_slots(lobby_state)
	_update_status_text(lobby_state)

func _render_player_slots(lobby_state: Dictionary) -> void:
	for child in player_list.get_children():
		child.queue_free()

	var players_by_peer_id: Dictionary = lobby_state.get("players_by_peer_id", {})
	if not players_by_peer_id.is_empty():
		_render_player_slots_from_players(players_by_peer_id, int(lobby_state.get("local_peer_id", 0)))
		return

	var ready_state: Dictionary = lobby_state.get("player_ready", {})
	var role_state: Dictionary = lobby_state.get("player_roles", {})
	var local_peer_id = int(lobby_state.get("local_peer_id", 0))
	var peer_ids = ready_state.keys()
	peer_ids.sort()

	for peer_id in peer_ids:
		var peer_id_int = int(peer_id)
		var role_value = int(role_state.get(peer_id, Roles.Role.THERAPIST if peer_id_int == 1 else Roles.Role.PATIENT))
		var role_name = Roles.get_role_name(role_value)
		var state_text = "Ready" if bool(ready_state[peer_id]) else "Not Ready"
		var player_name = "Player %d" % peer_id_int
		if peer_id_int == local_peer_id:
			player_name += " (You)"
		player_list.add_child(_build_player_card(player_name, role_name, state_text))

	#var max_players = int(lobby_state.get("max_players", 2))
	#while player_list.get_child_count() < max_players:
		#player_list.add_child(_build_player_card("Patient\nWaiting to join"))

func _render_player_slots_from_players(players_by_peer_id: Dictionary, local_peer_id: int) -> void:
	var peer_ids = players_by_peer_id.keys()
	peer_ids.sort()

	for peer_id in peer_ids:
		var peer_id_int = int(peer_id)
		var player_state: Dictionary = players_by_peer_id[peer_id]
		var role_value = int(player_state.get("role", Roles.Role.THERAPIST if peer_id_int == 1 else Roles.Role.PATIENT))
		var role_name = Roles.get_role_name(role_value)
		var state_text = "Ready" if bool(player_state.get("ready", false)) else "Not Ready"
		var player_name = "Player %d" % peer_id_int
		if peer_id_int == local_peer_id:
			player_name += " (You)"
		player_list.add_child(_build_player_card(player_name, role_name, state_text))

func _build_player_card(player_name: String, role: String, state: String) -> Panel:
	var player = player_card.instantiate()
	player.set_labels(player_name, role, state)
	return player

func _update_status_text(lobby_state: Dictionary) -> void:
	var participant_count = int(lobby_state.get("participant_count", 0))
	var max_players = int(lobby_state.get("max_players", 2))
	var local_ready = bool(lobby_state.get("local_ready", false))
	var is_host = bool(lobby_state.get("is_host", false))
	var can_start_call = bool(lobby_state.get("can_start_call", false))
	var status_color = STATUS_COLOR_DEFAULT

	if is_host:
		if participant_count < max_players:
			lobby_status_label.text = "Waiting for the patient to join the room."
		elif can_start_call:
			lobby_status_label.text = "Patient is ready. Start the call when you are ready."
		else:
			lobby_status_label.text = "Waiting for the patient to mark ready."
			status_color = STATUS_COLOR_ALERT

		lobby_status_label.add_theme_color_override("font_color", status_color)
		return

	if local_ready:
		lobby_status_label.text = "You are ready. Waiting for the therapist to start the call."
	else:
		lobby_status_label.text = "Mark ready when you are prepared to begin."
		status_color = STATUS_COLOR_ALERT

	lobby_status_label.add_theme_color_override("font_color", status_color)

func _on_ready_button_pressed() -> void:
	var local_ready = bool(last_lobby_state.get("local_ready", false))
	lobby_manager.set_player_ready(not local_ready)

func _on_start_call_pressed() -> void:
	lobby_manager.start_call()

func _on_start_call_requested(environment_id: String) -> void:
	AvatarState.environment_id = environment_id
	lobby_status_label.text = "Loading %s..." % EnvironmentCatalog.get_environment_name(environment_id)
	lobby_status_label.add_theme_color_override("font_color", STATUS_COLOR_DEFAULT)
	AvatarState.load_scene(self , AvatarState.IN_CALL_SCENE_PATH)

func _on_session_ended(message: String) -> void:
	AvatarState.return_to_home(self , message)
