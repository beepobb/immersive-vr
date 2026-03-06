extends Control

# Track discovered servers to prevent duplicates
var discovered_servers: Dictionary = {} # Key: IP:port string, Value: {name, ip, port}
var server_buttons: Dictionary = {} # Key: IP:port string, Value: Button node

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	HighLevelNetworkHandler.connect("server_found", _on_server_found)
	HighLevelNetworkHandler.connect("server_lost", _on_server_lost)
	HighLevelNetworkHandler.connect("connection_closed", _on_connection_closed)
	HighLevelNetworkHandler.connect("connection_error", _on_connection_error)
	# Connect to multiplayer signals for session info
	multiplayer.peer_connected.connect(_update_session_info)
	multiplayer.peer_disconnected.connect(_update_session_info)
	# Hide IPList, buttons, and labels initially
	get_node("IPList").visible = false
	get_node("BackButton").visible = false
	get_node("TerminateServer").visible = false
	get_node("LeaveSession").visible = false
	get_node("ErrorLabel").visible = false
	get_node("SessionInfoLabel").visible = false
	# Set default port
	get_node("PortInput").text = "7001"
	
func _on_create_session_pressed() -> void:
	# Read port from input field
	var port_text = get_node("PortInput").text
	var port = int(port_text) if port_text.is_valid_int() else 7001
	# Validate port range
	if port < 1024 or port > 65535:
		get_node("ErrorLabel").text = "Port must be between 1024-65535"
		get_node("ErrorLabel").visible = true
		return
	
	HighLevelNetworkHandler.start_host(2, port)
	get_node("/root/MultiplayerTest/MultiplayerSpawner").spawn_player(1)
	# Hide the menu and port input after creating session
	get_node("VBoxContainer").visible = false
	get_node("PortInput").visible = false
	# Show terminate button for host
	get_node("TerminateServer").visible = true
	# Show session info
	get_node("SessionInfoLabel").visible = true
	_update_session_info()

func _on_join_session_pressed() -> void:
	print("UI: Join Session pressed - starting to listen for servers")
	# Clear previous discoveries
	discovered_servers.clear()
	server_buttons.clear()
	# Clear any existing buttons in IPList
	for child in get_node("IPList").get_children():
		child.queue_free()
	# Hide the create/join buttons and port input
	get_node("VBoxContainer").visible = false
	get_node("PortInput").visible = false
	# Show the empty IPList and back button
	get_node("IPList").visible = true
	get_node("BackButton").visible = true
	# Start listening for server broadcasts
	HighLevelNetworkHandler.start_listening()

# Called when a server broadcasts its presence
func _on_server_found(ip: String, server_name: String, port: int) -> void:
	var server_key = ip + ":" + str(port)
	
	# Check if we've already added this server
	if discovered_servers.has(server_key):
		return # Already in the list, skip
	
	print("UI: Server found - ", server_name, " at ", server_key)
	
	# Add to tracking dictionary
	discovered_servers[server_key] = {"name": server_name, "ip": ip, "port": port}
	
	# Create and add button
	var button: Button = Button.new()
	button.text = server_name + " (" + server_key + ")"
	button.pressed.connect(func(): _connect_to_server(ip, port))
	get_node("IPList").add_child(button)
	
	# Store button reference for later removal
	server_buttons[server_key] = button

# Called when a server times out (dies)
func _on_server_lost(server_key: String) -> void:
	print("UI: Server lost - ", server_key)
	
	# Remove from tracking
	if discovered_servers.has(server_key):
		discovered_servers.erase(server_key)
	
	# Remove button from UI
	if server_buttons.has(server_key):
		var button = server_buttons[server_key]
		if button:
			button.queue_free()
		server_buttons.erase(server_key)

# Called when user clicks a server button
func _connect_to_server(ip: String, port: int) -> void:
	print("UI: Connecting to server at ", ip, ":", port)
	# Hide error label when attempting connection
	get_node("ErrorLabel").visible = false
	# Hide IP list and back button after selecting a server
	get_node("IPList").visible = false
	get_node("BackButton").visible = false
	# Show leave button for client
	get_node("LeaveSession").visible = true
	# Show session info
	get_node("SessionInfoLabel").visible = true
	HighLevelNetworkHandler.connect_to_therapist(ip, port)
	# Start updating session info
	await get_tree().create_timer(0.5).timeout # Wait for connection
	_update_session_info()

# Called when terminate server button is pressed (host only)
func _on_terminate_server_pressed() -> void:
	print("UI: Terminating server")
	HighLevelNetworkHandler.stop_host()
	# Reset UI will happen via connection_closed signal

# Called when leave session button is pressed (client only)
func _on_leave_session_pressed() -> void:
	print("UI: Leaving session")
	HighLevelNetworkHandler.disconnect_client()
	# Reset UI will happen via connection_closed signal

# Called when back button is pressed (while browsing servers)
func _on_back_button_pressed() -> void:
	print("UI: Going back to main menu")
	# Stop listening for servers
	if HighLevelNetworkHandler.udp_listener.is_bound():
		HighLevelNetworkHandler.udp_listener.close()
	# Clear server lists
	discovered_servers.clear()
	server_buttons.clear()
	# Clear any buttons in IPList
	for child in get_node("IPList").get_children():
		child.queue_free()
	# Show main menu
	get_node("VBoxContainer").visible = true
	get_node("PortInput").visible = true
	get_node("IPList").visible = false
	get_node("BackButton").visible = false
	get_node("ErrorLabel").visible = false

# Called when connection is closed (either server stopped or client disconnected)
func _on_connection_closed() -> void:
	print("UI: Connection closed - resetting to main menu")
	# Clear server lists
	discovered_servers.clear()
	server_buttons.clear()
	# Clear any buttons in IPList
	for child in get_node("IPList").get_children():
		child.queue_free()
	# Close any active UDP listeners if still bound
	if HighLevelNetworkHandler.udp_listener.is_bound():
		HighLevelNetworkHandler.udp_listener.close()
	# Reset visibility
	get_node("VBoxContainer").visible = true
	get_node("PortInput").visible = true
	get_node("IPList").visible = false
	get_node("BackButton").visible = false
	get_node("TerminateServer").visible = false
	get_node("LeaveSession").visible = false
	get_node("ErrorLabel").visible = false
	get_node("SessionInfoLabel").visible = false

# Called when connection error occurs (e.g., server full)
func _on_connection_error(message: String) -> void:
	print("UI: Connection error - ", message)
	get_node("ErrorLabel").text = message
	get_node("ErrorLabel").visible = true
	# Show IP list and back button again if connection failed
	get_node("IPList").visible = true
	get_node("BackButton").visible = true
	get_node("LeaveSession").visible = false
	get_node("SessionInfoLabel").visible = false
	# Auto-hide error after 5 seconds
	get_tree().create_timer(5.0).timeout.connect(func(): get_node("ErrorLabel").visible = false)

# Update session info label
func _update_session_info(_id: int = 0) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	
	var is_host = multiplayer.is_server()
	var peer_count = multiplayer.get_peers().size()
	var port = HighLevelNetworkHandler.PORT
	
	if is_host:
		get_node("SessionInfoLabel").text = "Hosting on port %d\nConnected clients: %d" % [port, peer_count]
	else:
		get_node("SessionInfoLabel").text = "Connected to server\nPort: %d\nTotal clients: %d" % [port, peer_count + 1]
