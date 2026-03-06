extends Node3D

# --- Networking Constants ---
var PORT = 7001 # Changed to var to allow multiple servers on different ports
const BROADCAST_PORT = 5555
const BROADCAST_INTERVAL = 1.0
const SERVER_TIMEOUT = 3.0 # Seconds before considering a server dead

# --- Peers ---
var peer = ENetMultiplayerPeer.new()
var udp_broadcaster := PacketPeerUDP.new()
var udp_listener := PacketPeerUDP.new()

# --- Discovery Variables ---
var is_broadcasting := false
var broadcast_timer := 0.0
var server_last_seen := {} # Track when each server was last seen
signal server_found(ip: String, name: String, port: int)
signal server_lost(server_key: String)
signal connection_closed() # Emitted when server closes or client disconnected
signal cleanup_players() # Emitted when all players should be removed
signal connection_error(message: String) # Emitted when connection fails with error message

func _process(delta):
	# THERAPIST: Send "I am here" packets
	if is_broadcasting:
		broadcast_timer += delta
		if broadcast_timer >= BROADCAST_INTERVAL:
			_broadcast_presence()
			broadcast_timer = 0.0
			
	# PATIENT: Listen for "I am here" packets
	if udp_listener.get_available_packet_count() > 0:
		_listen_for_servers()
	
	# Check for timed-out servers
	if not is_broadcasting:
		_check_server_timeouts()

# --- THERAPIST LOGIC (Host) ---
func start_host(max_clients: int = 1, custom_port: int = 7001):
	multiplayer.multiplayer_peer = null # Reset
	PORT = custom_port # Set the port for this server
	# max_clients + 1 for total peer count (host + clients)
	var error = peer.create_server(PORT, max_clients + 1)
	if error != OK:
		printerr("Failed to host: ", error)
		return
	
	multiplayer.multiplayer_peer = peer
	
	# Setup UDP broadcaster
	udp_broadcaster.set_broadcast_enabled(true) # CRITICAL: Enable broadcast mode
	udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
	
	# Connect to multiplayer signals
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	is_broadcasting = true
	#print("Therapist started server on port ", PORT)
	#print("Broadcasting on port ", BROADCAST_PORT)

func _broadcast_presence():
	var local_ip = _get_local_ip()
	var data = {"name": "Therapist_Session", "ip": local_ip, "port": PORT}
	var packet = JSON.stringify(data).to_utf8_buffer()
	var result = udp_broadcaster.put_packet(packet)
	if result != OK:
		printerr("Failed to broadcast packet: ", result)
	else:
		print("Broadcasting presence from IP: ", local_ip, ":", PORT)

# --- PATIENT LOGIC (Client) ---
func start_listening():
	var error = udp_listener.bind(BROADCAST_PORT) # Start hearing the megaphone
	if error != OK:
		printerr("Failed to bind listener to port ", BROADCAST_PORT, ": ", error)
		return
	# Clear previous server tracking
	server_last_seen.clear()
	print("Patient is listening for sessions on port ", BROADCAST_PORT)

func _listen_for_servers():
	var packet = udp_listener.get_packet().get_string_from_utf8()
	print("Received packet: ", packet)
	var server_info = JSON.parse_string(packet)
	if server_info and server_info.has("ip") and server_info.has("name"):
		# Don't emit if we're the host (receiving our own broadcast)
		if is_broadcasting:
			return
		
		var ip = server_info["ip"]
		var port = server_info.get("port", 7001) # Default to 7001 if not specified
		var server_key = ip + ":" + str(port) # Use IP:port as unique key
		var is_new_server = not server_last_seen.has(server_key)
		
		# Update last seen timestamp
		server_last_seen[server_key] = Time.get_ticks_msec() / 1000.0
		
		# Only emit server_found for new servers
		if is_new_server:
			print("Found server: ", server_info["name"], " at ", server_key)
			server_found.emit(ip, server_info["name"], port)
	else:
		printerr("Invalid server info received: ", server_info)

func _check_server_timeouts():
	var current_time = Time.get_ticks_msec() / 1000.0
	var servers_to_remove = []
	
	for server_key in server_last_seen.keys():
		if current_time - server_last_seen[server_key] > SERVER_TIMEOUT:
			servers_to_remove.append(server_key)
	
	for server_key in servers_to_remove:
		print("Server timeout: ", server_key)
		server_last_seen.erase(server_key)
		server_lost.emit(server_key)

func connect_to_therapist(ip: String, port: int = 7001):
	multiplayer.multiplayer_peer = null
	var error = peer.create_client(ip, port)
	if error != OK:
		printerr("Failed to connect: ", error)
		connection_error.emit("Failed to connect to server")
		return
	multiplayer.multiplayer_peer = peer
	
	# Connect to multiplayer signals
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	is_broadcasting = false # Stop listening once connected
	udp_listener.close() # Close the UDP listener
	print("Attempting to connect to therapist at ", ip, ":", port)

# Helper to find your actual LAN IP
func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			return ip
	return "127.0.0.1"

# Clean up when stopping host
func stop_host():
	is_broadcasting = false
	udp_broadcaster.close()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	print("Host stopped")
	# Clean up all players
	cleanup_players.emit()
	connection_closed.emit()

# Clean up when disconnecting as client
func disconnect_client():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	print("Client disconnected")
	# Clean up all players
	cleanup_players.emit()
	connection_closed.emit()

# Multiplayer signal handlers
func _on_server_disconnected():
	print("Disconnected from server")
	# Clean up all players when disconnected from server
	cleanup_players.emit()
	connection_closed.emit()

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	# Note: Individual player removal is handled by MultiplayerSpawner's peer_disconnected

func _on_connection_failed():
	printerr("Connection failed - Server may be full or unreachable")
	# Clean up any players that might have spawned
	cleanup_players.emit()
	connection_error.emit("Server is full or unreachable")
	connection_closed.emit()

func _on_connected_to_server():
	print("Successfully connected to server")

# Clean up when exiting
func _exit_tree():
	if is_broadcasting:
		stop_host()
	if udp_listener.is_bound():
		udp_listener.close()

#const IP_ADDRESS: String = "localhost"
##const PORT = 7001
#
#
##var peer = ENetMultiplayerPeer.new()
#
#func start_server():
	## Check if a peer already exists to avoid the "null host" error
	#if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		#multiplayer.multiplayer_peer = null 
		#
	#var error = peer.create_server(PORT, 2)
	#if error != OK:
		#print("Failed to host: ", error)
		#return
	#multiplayer.multiplayer_peer = peer
#
#func start_client():
	## 1. Clear any existing connection first
	#multiplayer.multiplayer_peer = null
	#
	## 2. Create a FRESH instance of the peer
	#peer = ENetMultiplayerPeer.new()
	#
	## 3. Now attempt to create the client
	#var error = peer.create_client(IP_ADDRESS, PORT)
	#
	#if error != OK:
		#print("Failed to connect: ", error)
		#return
		#
	#multiplayer.multiplayer_peer = peer
