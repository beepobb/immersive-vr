extends VBoxContainer

const PORT := 7001
@onready var host_button: Button = $Host
@onready var join_button: Button = $Join
@onready var status_label: Label = $StatusLabel

var connection_timer := Timer.new()

func _ready() -> void:
	UIButtonAudio.setup_buttons(self)
	# Add and configure a timer for connection fallback
	host_button.disabled = false
	join_button.disabled = false
	connection_timer.one_shot = true
	connection_timer.wait_time = 2.0 # seconds
	add_child(connection_timer)
	connection_timer.timeout.connect(_on_connection_timeout)
	
	# Connect multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _on_host_pressed() -> void:
	# prevent double click
	host_button.disabled = true
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 2)
	if err != OK:
		_set_status("Cannot start host: port in use.")
		return
	multiplayer.multiplayer_peer = peer
	Roles.set_role(Roles.Role.THERAPIST)
	_set_status("Hosting...")
	load_lobby()

func _on_join_pressed() -> void:
	# prevent double click
	join_button.disabled = true
	var ip := "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	Roles.set_role(Roles.Role.PATIENT)
	_set_status("Connecting to host...")
	connection_timer.start()

func _on_connected() -> void:
	connection_timer.stop()
	_set_status("Connected!")
	load_lobby()

func _on_connection_failed() -> void:
	connection_timer.stop()
	_set_status("Connection failed! No host found.")

func _on_connection_timeout() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_set_status("Failed to connect: no host available.")

func load_lobby() -> void:
	var scene_base := XRTools.find_xr_ancestor(self , "*", "XRToolsSceneBase")
	if not scene_base:
		print("ERROR: Could not find XRToolsSceneBase ancestor!")
		return
	scene_base.load_scene("res://scenes/game/lobby/lobby.tscn")

func _set_status(message: String) -> void:
	status_label.text = message
