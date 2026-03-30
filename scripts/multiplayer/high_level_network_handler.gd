extends Node3D

# --- Networking Constants ---
const DEFAULT_PORT = 7001
const DEFAULT_REMOTE_CLIENTS = 1
const DEFAULT_MAX_PLAYERS = 2
const BROADCAST_PORT = 5555
const BROADCAST_INTERVAL = 1.0
const SERVER_TIMEOUT = 3.0 # Seconds before considering a server dead
const ROOM_CODE_LENGTH = 6
const ROOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var PORT = DEFAULT_PORT

# --- Peers ---
var peer = ENetMultiplayerPeer.new()
var udp_broadcaster := PacketPeerUDP.new()
var udp_listener := PacketPeerUDP.new()

# --- Discovery Variables ---
var is_broadcasting := false
var broadcast_timer := 0.0
var server_last_seen := {} # Track when each server was last seen
var discovered_sessions := {} # {room_code: session_info}
var session_max_players := DEFAULT_MAX_PLAYERS
var current_room_code := ""
var lobby_players_by_peer_id: Dictionary = {}
var lobby_selected_environment_id: String = ""

signal server_found(ip: String, name: String, port: int)
signal server_lost(server_key: String)
signal session_found(session_info: Dictionary)
signal session_lost(room_code: String)
signal connection_closed() # Emitted when server closes or client disconnected
signal cleanup_players() # Emitted when all players should be removed
signal connection_error(message: String) # Emitted when connection fails with error message
signal session_state_changed(session_state: Dictionary)
signal session_ended(message: String)

func save_lobby_state(players_state: Dictionary, environment_id: String) -> void:
	lobby_players_by_peer_id = players_state.duplicate(true)
	lobby_selected_environment_id = environment_id

func clear_lobby_state() -> void:
	lobby_players_by_peer_id.clear()
	lobby_selected_environment_id = ""

func _process(delta: float) -> void:
	# THERAPIST: Send "I am here" packets
	if is_broadcasting:
		broadcast_timer += delta
		if broadcast_timer >= BROADCAST_INTERVAL:
			_broadcast_presence()
			broadcast_timer = 0.0
			
	# PATIENT: Listen for "I am here" packets
	if udp_listener.is_bound() and udp_listener.get_available_packet_count() > 0:
		_listen_for_servers()
	
	# Check for timed-out servers
	if not is_broadcasting:
		_check_server_timeouts()

# --- THERAPIST LOGIC (Host) ---
func start_host(max_clients: int = DEFAULT_REMOTE_CLIENTS, custom_port: int = DEFAULT_PORT) -> bool:
	_reset_multiplayer_peer()
	_disconnect_udp_listener()
	_connect_multiplayer_signals()

	PORT = custom_port
	session_max_players = max(1, max_clients) + 1
	current_room_code = _generate_room_code()
	discovered_sessions.clear()
	server_last_seen.clear()
	peer = ENetMultiplayerPeer.new()

	var error = peer.create_server(PORT, max_clients)
	if error != OK:
		printerr("Failed to host: ", error)
		_reset_session_details()
		_emit_session_state_changed()
		return false
	
	multiplayer.multiplayer_peer = peer
	
	# Setup UDP broadcaster
	udp_broadcaster.close()
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true) # CRITICAL: Enable broadcast mode
	udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
	
	is_broadcasting = true
	broadcast_timer = 0.0
	_emit_session_state_changed()
	#print("Therapist started server on port ", PORT)
	#print("Broadcasting on port ", BROADCAST_PORT)
	return true

func _broadcast_presence() -> void:
	var local_ip = _get_local_ip()
	var data = {
		"name": "Therapist Session",
		"ip": local_ip,
		"port": PORT,
		"room_code": current_room_code,
		"max_players": session_max_players,
		"participant_count": get_connected_player_count(),
	}
	var packet = JSON.stringify(data).to_utf8_buffer()
	var result = udp_broadcaster.put_packet(packet)
	if result != OK:
		printerr("Failed to broadcast packet: ", result)
	# else:
	# 	print("Broadcasting room ", current_room_code, " from IP: ", local_ip, ":", PORT)

# --- PATIENT LOGIC (Client) ---
func start_listening() -> bool:
	_disconnect_udp_listener()
	udp_listener = PacketPeerUDP.new()
	discovered_sessions.clear()
	server_last_seen.clear()

	var error = udp_listener.bind(BROADCAST_PORT) # Start hearing the megaphone
	if error != OK:
		printerr("Failed to bind listener to port ", BROADCAST_PORT, ": ", error)
		return false

	print("Patient is listening for sessions on port ", BROADCAST_PORT)
	_emit_session_state_changed()
	return true

func _listen_for_servers() -> void:
	var packet = udp_listener.get_packet().get_string_from_utf8()
	print("Received packet: ", packet)
	var server_info = JSON.parse_string(packet)
	if server_info and server_info.has("ip") and server_info.has("name"):
		# Don't emit if we're the host (receiving our own broadcast)
		if is_broadcasting:
			return
		
		var ip = str(server_info["ip"])
		var port = int(server_info.get("port", DEFAULT_PORT))
		var room_code = _normalize_room_code(str(server_info.get("room_code", "")))
		if room_code.is_empty():
			return

		var server_key = ip + ":" + str(port)
		var is_new_server = not discovered_sessions.has(room_code)
		var session_info = {
			"name": str(server_info["name"]),
			"ip": ip,
			"port": port,
			"room_code": room_code,
			"max_players": int(server_info.get("max_players", DEFAULT_MAX_PLAYERS)),
			"participant_count": int(server_info.get("participant_count", 1)),
			"server_key": server_key,
		}
		
		# Update last seen timestamp
		server_last_seen[room_code] = Time.get_ticks_msec() / 1000.0
		discovered_sessions[room_code] = session_info
		
		# Only emit server_found for new servers
		if is_new_server:
			print("Found server: ", server_info["name"], " at ", server_key, " with room code ", room_code)
			server_found.emit(ip, str(server_info["name"]), port)

		session_found.emit(session_info)
		_emit_session_state_changed()
	else:
		printerr("Invalid server info received: ", server_info)

func _check_server_timeouts() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var rooms_to_remove: Array[String] = []
	
	for room_code in server_last_seen.keys():
		if current_time - server_last_seen[room_code] > SERVER_TIMEOUT:
			rooms_to_remove.append(room_code)
	
	for room_code in rooms_to_remove:
		var session_info = discovered_sessions.get(room_code, {})
		var server_key = str(session_info.get("server_key", room_code))
		print("Server timeout: ", server_key)
		server_last_seen.erase(room_code)
		discovered_sessions.erase(room_code)
		server_lost.emit(server_key)
		session_lost.emit(room_code)

	if not rooms_to_remove.is_empty():
		_emit_session_state_changed()

func connect_to_therapist(ip: String, port: int = DEFAULT_PORT, room_code: String = "") -> bool:
	_reset_multiplayer_peer()
	_connect_multiplayer_signals()
	peer = ENetMultiplayerPeer.new()

	var error = peer.create_client(ip, port)
	if error != OK:
		printerr("Failed to connect: ", error)
		connection_error.emit("Failed to connect to server")
		return false

	multiplayer.multiplayer_peer = peer
	current_room_code = _normalize_room_code(room_code)
	var discovered_session = _find_session_by_server(ip, port)
	if current_room_code.is_empty() and not discovered_session.is_empty():
		current_room_code = str(discovered_session.get("room_code", ""))
	session_max_players = int(discovered_session.get("max_players", DEFAULT_MAX_PLAYERS))
	is_broadcasting = false # Stop listening once connected
	_disconnect_udp_listener()
	_emit_session_state_changed()
	print("Attempting to connect to therapist at ", ip, ":", port)
	return true

func find_session_by_code(room_code: String) -> Dictionary:
	var normalized_code = _normalize_room_code(room_code)
	return discovered_sessions.get(normalized_code, {}).duplicate(true)

func get_connected_player_count() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 0

	return multiplayer.get_peers().size() + 1

func get_session_state() -> Dictionary:
	return {
		"room_code": current_room_code,
		"max_players": session_max_players,
		"participant_count": get_connected_player_count(),
		"is_host": multiplayer.is_server(),
		"is_connected": multiplayer.has_multiplayer_peer(),
		"discovered_room_count": discovered_sessions.size(),
	}

# Helper to find your actual LAN IP
func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"

# Clean up when stopping host
func stop_host() -> void:
	is_broadcasting = false
	udp_broadcaster.close()
	_reset_multiplayer_peer()
	_reset_session_details()
	print("Host stopped")
	# Clean up all players
	cleanup_players.emit()
	_emit_session_state_changed()
	session_ended.emit("The therapist ended the session.")
	connection_closed.emit()

# Clean up when disconnecting as client
func disconnect_client() -> void:
	_reset_multiplayer_peer()
	_reset_session_details()
	print("Client disconnected")
	# Clean up all players
	cleanup_players.emit()
	_emit_session_state_changed()
	session_ended.emit("You left the session.")
	connection_closed.emit()

# Multiplayer signal handlers
func _on_server_disconnected() -> void:
	print("Disconnected from server")
	_reset_session_details()
	# Clean up all players when disconnected from server
	cleanup_players.emit()
	_emit_session_state_changed()
	session_ended.emit("The therapist left, so the session has ended.")
	connection_closed.emit()

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	_emit_session_state_changed()

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	_emit_session_state_changed()
	# Note: Individual player removal is handled by MultiplayerSpawner's peer_disconnected

func _on_connection_failed() -> void:
	printerr("Connection failed - Server may be full or unreachable")
	_reset_session_details()
	# Clean up any players that might have spawned
	cleanup_players.emit()
	_emit_session_state_changed()
	session_ended.emit("The session is no longer available.")
	connection_error.emit("Server is full or unreachable")
	connection_closed.emit()

func _on_connected_to_server() -> void:
	print("Successfully connected to server")
	_emit_session_state_changed()

# Clean up when exiting
func _exit_tree() -> void:
	if is_broadcasting:
		stop_host()
	if udp_listener.is_bound():
		udp_listener.close()

func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)

func _disconnect_udp_listener() -> void:
	if udp_listener.is_bound():
		udp_listener.close()

func _reset_multiplayer_peer() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func _reset_session_details() -> void:
	is_broadcasting = false
	broadcast_timer = 0.0
	current_room_code = ""
	session_max_players = DEFAULT_MAX_PLAYERS
	clear_lobby_state()

func _generate_room_code() -> String:
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	var code := ""
	for _index in ROOM_CODE_LENGTH:
		code += ROOM_CODE_CHARS[generator.randi_range(0, ROOM_CODE_CHARS.length() - 1)]
	return code

func _normalize_room_code(room_code: String) -> String:
	return room_code.strip_edges().to_upper().replace(" ", "").replace("-", "")

func _find_session_by_server(ip: String, port: int) -> Dictionary:
	for session_info in discovered_sessions.values():
		if str(session_info.get("ip", "")) == ip and int(session_info.get("port", DEFAULT_PORT)) == port:
			return session_info.duplicate(true)
	return {}

func _emit_session_state_changed() -> void:
	session_state_changed.emit(get_session_state())
