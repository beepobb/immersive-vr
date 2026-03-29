extends Node3D

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")

signal update_lobby_ui(lobby_state)
signal start_call_requested(environment_id)

var players_by_peer_id: Dictionary = {} # {peer_id: {peer_id, role, ready}}
var selected_environment_id: String = ""

@onready var avatarRoot: Node3D = get_node_or_null("../AvatarTest") as Node3D

func _ready() -> void:
	add_to_group("lobby_manager")
	_restore_persisted_lobby_state()
	AvatarState.avatar = avatarRoot
	AvatarState.apply_to_avatar()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		_set_player_role(1, int(Roles.user_role))
		_set_player_ready(1, true)
		_set_player_avatar_state(1, _local_avatar_state())
		_reconcile_connected_peers()
		_broadcast_state()
	else:
		_request_lobby_state.rpc_id(1)
		_submit_role_to_server.rpc_id(1, int(Roles.user_role))
		_submit_avatar_state_to_server.rpc_id(1, _local_avatar_state())

func set_player_ready(is_ready: bool) -> void:
	if multiplayer.is_server():
		_set_player_ready(multiplayer.get_unique_id(), is_ready)
		_broadcast_state()
		return

	_submit_ready_to_server.rpc_id(1, is_ready)

func get_lobby_state() -> Dictionary:
	var local_peer_id = multiplayer.get_unique_id()
	var max_players = max(HighLevelNetworkHandler.session_max_players, 2)

	return {
		"room_code": HighLevelNetworkHandler.current_room_code,
		"selected_environment_id": selected_environment_id,
		"selected_environment_name": EnvironmentCatalog.get_environment_name(selected_environment_id),
		"participant_count": players_by_peer_id.size(),
		"max_players": max_players,
		"players_by_peer_id": players_by_peer_id.duplicate(true),
		"player_ready": _get_player_ready_state(),
		"player_roles": _get_player_role_state(),
		"local_peer_id": local_peer_id,
		"local_ready": _is_player_ready(local_peer_id),
		"is_host": multiplayer.is_server(),
		"can_toggle_ready": not multiplayer.is_server() and local_peer_id > 0,
		"can_start_call": _can_start_call(),
	}

func start_call() -> void:
	if not _can_start_call():
		return

	selected_environment_id = _get_selected_environment()
	_broadcast_state()
	_begin_call.rpc(selected_environment_id)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if not players_by_peer_id.has(peer_id):
		_set_player_ready(peer_id, false)
	if not players_by_peer_id.has(peer_id):
		_set_player_role(peer_id, Roles.Role.PATIENT)

	_broadcast_state()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if players_by_peer_id.has(peer_id):
		players_by_peer_id.erase(peer_id)

	_broadcast_state()

func _can_start_call() -> bool:
	var max_players = max(HighLevelNetworkHandler.session_max_players, 2)
	if not multiplayer.is_server():
		return false
	if players_by_peer_id.size() < max_players:
		return false

	for peer_id in players_by_peer_id.keys():
		if int(peer_id) == 1:
			continue
		if not _is_player_ready(int(peer_id)):
			return false

	return true

func _get_selected_environment() -> String:
	if AvatarState.environment_id.is_empty():
		return EnvironmentCatalog.get_default_environment_id()

	return AvatarState.environment_id

@rpc("any_peer", "call_remote")
func _submit_ready_to_server(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	_set_player_ready(sender_peer_id, is_ready)
	_broadcast_state()

@rpc("any_peer", "call_remote")
func _submit_role_to_server(role: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	_set_player_role(sender_peer_id, role)
	_broadcast_state()

@rpc("any_peer", "call_remote")
func _submit_avatar_state_to_server(avatar_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	_set_player_avatar_state(sender_peer_id, avatar_data)
	_broadcast_state()

@rpc("any_peer", "call_remote")
func _request_lobby_state() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	_sync_lobby_state.rpc_id(sender_peer_id, players_by_peer_id, selected_environment_id)

@rpc("authority", "call_remote")
func _sync_lobby_state(players_state: Dictionary, environment_id: String) -> void:
	players_by_peer_id = players_state.duplicate(true)
	_ensure_players_have_avatar_state()
	selected_environment_id = environment_id if not environment_id.is_empty() else EnvironmentCatalog.get_default_environment_id()
	AvatarState.environment_id = selected_environment_id

	var my_peer_id = multiplayer.get_unique_id()
	if my_peer_id > 0 and not players_by_peer_id.has(my_peer_id):
		players_by_peer_id[my_peer_id] = _make_player_state(my_peer_id, int(Roles.user_role), false)
	_set_player_avatar_state(my_peer_id, _local_avatar_state())

	if not players_by_peer_id.has(1):
		players_by_peer_id[1] = _make_player_state(1, Roles.Role.THERAPIST, true)

	_persist_lobby_state()
	_emit_ui_update()

@rpc("authority", "call_local")
func _begin_call(environment_id: String) -> void:
	start_call_requested.emit(environment_id)

func _broadcast_state() -> void:
	selected_environment_id = _get_selected_environment()
	_persist_lobby_state()
	_emit_ui_update()
	_sync_lobby_state.rpc(players_by_peer_id, selected_environment_id)

func _emit_ui_update() -> void:
	update_lobby_ui.emit(get_lobby_state())

func _restore_persisted_lobby_state() -> void:
	var avatar_environment_id := AvatarState.environment_id.strip_edges()
	var persisted_environment_id := HighLevelNetworkHandler.lobby_selected_environment_id.strip_edges()

	if not avatar_environment_id.is_empty():
		selected_environment_id = avatar_environment_id
	elif not persisted_environment_id.is_empty():
		selected_environment_id = persisted_environment_id
	else:
		selected_environment_id = EnvironmentCatalog.get_default_environment_id()

	if not HighLevelNetworkHandler.lobby_players_by_peer_id.is_empty():
		players_by_peer_id = HighLevelNetworkHandler.lobby_players_by_peer_id.duplicate(true)
	_ensure_players_have_avatar_state()

	AvatarState.environment_id = selected_environment_id
	_persist_lobby_state()

func _reconcile_connected_peers() -> void:
	var connected_peer_ids: Array = multiplayer.get_peers()
	var valid_peer_ids := {1: true}
	for peer_id in connected_peer_ids:
		var peer_id_int = int(peer_id)
		valid_peer_ids[peer_id_int] = true
		if not players_by_peer_id.has(peer_id_int):
			players_by_peer_id[peer_id_int] = _make_player_state(peer_id_int, _default_role_for_peer(peer_id_int), false)

	for peer_id in players_by_peer_id.keys().duplicate():
		if not valid_peer_ids.has(int(peer_id)):
			players_by_peer_id.erase(peer_id)

func _persist_lobby_state() -> void:
	HighLevelNetworkHandler.save_lobby_state(players_by_peer_id, selected_environment_id)

func _set_player_ready(peer_id: int, is_ready: bool) -> void:
	var player_state = players_by_peer_id.get(peer_id, _make_player_state(peer_id, _default_role_for_peer(peer_id), false))
	player_state["ready"] = is_ready
	players_by_peer_id[peer_id] = player_state

func _set_player_role(peer_id: int, role: int) -> void:
	var player_state = players_by_peer_id.get(peer_id, _make_player_state(peer_id, role, peer_id == 1))
	player_state["role"] = role
	players_by_peer_id[peer_id] = player_state

func _set_player_avatar_state(peer_id: int, avatar_data: Dictionary) -> void:
	if peer_id <= 0:
		return

	var player_state = players_by_peer_id.get(peer_id, _make_player_state(peer_id, _default_role_for_peer(peer_id), false))
	for key in _default_avatar_state().keys():
		player_state[key] = avatar_data.get(key, player_state.get(key, _default_avatar_state()[key]))
	players_by_peer_id[peer_id] = player_state

func _is_player_ready(peer_id: int) -> bool:
	if not players_by_peer_id.has(peer_id):
		return false
	return bool(Dictionary(players_by_peer_id[peer_id]).get("ready", false))

func _default_role_for_peer(peer_id: int) -> int:
	return Roles.Role.THERAPIST if peer_id == 1 else Roles.Role.PATIENT

func _make_player_state(peer_id: int, role: int, is_ready: bool) -> Dictionary:
	var player_state = {
		"peer_id": peer_id,
		"role": role,
		"ready": is_ready,
	}
	for key in _default_avatar_state().keys():
		player_state[key] = _default_avatar_state()[key]
	return player_state

func _local_avatar_state() -> Dictionary:
	return {
		"skin_tone": AvatarState.skin_tone,
		"outfit": AvatarState.outfit,
		"hair_style": AvatarState.hair_style
	}

func _default_avatar_state() -> Dictionary:
	return {
		"skin_tone": "",
		"outfit": "",
		"hair_style": ""
	}

func _ensure_players_have_avatar_state() -> void:
	var normalized_players := {}
	for peer_id in players_by_peer_id.keys():
		var peer_id_int = int(peer_id)
		var player_state: Dictionary = players_by_peer_id[peer_id]
		for key in _default_avatar_state().keys():
			if not player_state.has(key):
				player_state[key] = _default_avatar_state()[key]
		if not player_state.has("peer_id"):
			player_state["peer_id"] = peer_id_int
		if not player_state.has("role"):
			player_state["role"] = _default_role_for_peer(peer_id_int)
		if not player_state.has("ready"):
			player_state["ready"] = false
		normalized_players[peer_id_int] = player_state

	players_by_peer_id = normalized_players

func _get_player_ready_state() -> Dictionary:
	var ready_state := {}
	for peer_id in players_by_peer_id.keys():
		var peer_id_int = int(peer_id)
		ready_state[peer_id_int] = _is_player_ready(peer_id_int)
	return ready_state

func _get_player_role_state() -> Dictionary:
	var role_state := {}
	for peer_id in players_by_peer_id.keys():
		var peer_id_int = int(peer_id)
		var player_state: Dictionary = players_by_peer_id[peer_id]
		role_state[peer_id_int] = int(player_state.get("role", _default_role_for_peer(peer_id_int)))
	return role_state
