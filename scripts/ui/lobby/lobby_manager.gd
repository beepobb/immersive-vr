extends Node3D

signal update_lobby_ui(player_ready)

var player_ready = {} # {peer_id: bool}

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		player_ready[1] = true
		_emit_ui_update()
	else:
		_request_lobby_state.rpc_id(1)

func set_player_ready(is_ready: bool):
	if multiplayer.is_server():
		_apply_ready(multiplayer.get_unique_id(), is_ready)
		_broadcast_state()
		return

	_submit_ready_to_server.rpc_id(1, is_ready)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if not player_ready.has(peer_id):
		player_ready[peer_id] = false

	_broadcast_state()

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if player_ready.has(peer_id):
		player_ready.erase(peer_id)

	_broadcast_state()

@rpc("any_peer", "call_remote")
func _submit_ready_to_server(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	_apply_ready(sender_peer_id, is_ready)
	_broadcast_state()

@rpc("any_peer", "call_remote")
func _request_lobby_state() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id = multiplayer.get_remote_sender_id()
	_sync_lobby_state.rpc_id(sender_peer_id, player_ready)

@rpc("authority", "call_remote")
func _sync_lobby_state(ready_state: Dictionary) -> void:
	player_ready = ready_state.duplicate(true)

	var my_peer_id = multiplayer.get_unique_id()
	if my_peer_id > 0 and not player_ready.has(my_peer_id):
		player_ready[my_peer_id] = false

	if not player_ready.has(1):
		player_ready[1] = true

	_emit_ui_update()

func _apply_ready(peer_id: int, is_ready: bool) -> void:
	player_ready[peer_id] = is_ready

func _broadcast_state() -> void:
	_emit_ui_update()
	_sync_lobby_state.rpc(player_ready)

func _emit_ui_update() -> void:
	update_lobby_ui.emit(player_ready)
