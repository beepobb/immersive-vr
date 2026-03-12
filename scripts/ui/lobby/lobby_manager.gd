extends Node3D

const DEFAULT_ENVIRONMENT_ID = "res://scenes/environment/therapy_room.tscn"

signal update_lobby_ui(lobby_state)
signal start_call_requested(environment_id)

var player_ready = {} # {peer_id: bool}
var player_roles = {} # {peer_id: int}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		player_ready[1] = true
		player_roles[1] = Roles.user_role
		_emit_ui_update()
	else:
		_request_lobby_state.rpc_id(1)
		_submit_role_to_server.rpc_id(1, int(Roles.user_role))

func set_player_ready(is_ready: bool) -> void:
	if multiplayer.is_server():
		_apply_ready(multiplayer.get_unique_id(), is_ready)
		_broadcast_state()
		return

	_submit_ready_to_server.rpc_id(1, is_ready)

func get_lobby_state() -> Dictionary:
	var local_peer_id = multiplayer.get_unique_id()
	var max_players = max(HighLevelNetworkHandler.session_max_players, 2)

	return {
		"room_code": HighLevelNetworkHandler.current_room_code,
		"participant_count": player_ready.size(),
		"max_players": max_players,
		"player_ready": player_ready.duplicate(true),
		"player_roles": player_roles.duplicate(true),
		"local_peer_id": local_peer_id,
		"local_ready": player_ready.get(local_peer_id, false),
		"is_host": multiplayer.is_server(),
		"can_toggle_ready": not multiplayer.is_server() and local_peer_id > 0,
		"can_start_call": _can_start_call(),
	}

func start_call() -> void:
	if not _can_start_call():
		return

	_begin_call.rpc(_get_selected_environment())

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if not player_ready.has(peer_id):
		player_ready[peer_id] = false
	if not player_roles.has(peer_id):
		player_roles[peer_id] = Roles.Role.PATIENT

	_broadcast_state()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if player_ready.has(peer_id):
		player_ready.erase(peer_id)
	if player_roles.has(peer_id):
		player_roles.erase(peer_id)

	_broadcast_state()

func _can_start_call() -> bool:
	var max_players = max(HighLevelNetworkHandler.session_max_players, 2)
	if not multiplayer.is_server():
		return false
	if player_ready.size() < max_players:
		return false

	for peer_id in player_ready.keys():
		if int(peer_id) == 1:
			continue
		if not bool(player_ready[peer_id]):
			return false

	return true

func _get_selected_environment() -> String:
	if AvatarState.environment_id.is_empty():
		return DEFAULT_ENVIRONMENT_ID

	return AvatarState.environment_id

@rpc("any_peer", "call_remote")
func _submit_ready_to_server(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	_apply_ready(sender_peer_id, is_ready)
	_broadcast_state()

@rpc("any_peer", "call_remote")
func _submit_role_to_server(role: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	player_roles[sender_peer_id] = role
	_broadcast_state()

@rpc("any_peer", "call_remote")
func _request_lobby_state() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	_sync_lobby_state.rpc_id(sender_peer_id, player_ready, player_roles)

@rpc("authority", "call_remote")
func _sync_lobby_state(ready_state: Dictionary, role_state: Dictionary) -> void:
	player_ready = ready_state.duplicate(true)
	player_roles = role_state.duplicate(true)

	var my_peer_id = multiplayer.get_unique_id()
	if my_peer_id > 0 and not player_ready.has(my_peer_id):
		player_ready[my_peer_id] = false
	if my_peer_id > 0 and not player_roles.has(my_peer_id):
		player_roles[my_peer_id] = Roles.user_role

	if not player_ready.has(1):
		player_ready[1] = true
	if not player_roles.has(1):
		player_roles[1] = Roles.Role.THERAPIST

	_emit_ui_update()

@rpc("authority", "call_local")
func _begin_call(environment_id: String) -> void:
	start_call_requested.emit(environment_id)

func _apply_ready(peer_id: int, is_ready: bool) -> void:
	player_ready[peer_id] = is_ready

func _broadcast_state() -> void:
	_emit_ui_update()
	_sync_lobby_state.rpc(player_ready, player_roles)

func _emit_ui_update() -> void:
	update_lobby_ui.emit(get_lobby_state())
