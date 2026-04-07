extends VBoxContainer

const PORT := 7001

@onready var ip_input: LineEdit = $MarginContainer2/VBoxContainer/IpInput
@onready var host_button: Button = $MarginContainer/HBoxContainer/Host
@onready var join_button: Button = $MarginContainer/HBoxContainer/Join
@onready var confirm_button: Button = $MarginContainer3/Confirm
@onready var status_label: Label = $StatusLabel
var get_input: bool = true
var usr_input: String
var connection_timer := Timer.new()
var keyboard: Node3D

func _ready() -> void:
	UIButtonAudio.setup_buttons(self)
	# Add and configure a timer for connection fallback
	ip_input.hide()
	host_button.show()
	host_button.disabled = false
	join_button.disabled = false
	connection_timer.one_shot = true
	connection_timer.wait_time = 2.0 # seconds
	add_child(connection_timer)
	connection_timer.timeout.connect(_on_connection_timeout)
	
	# Connect multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	keyboard = get_node_or_null("../../../VirtualKeyboard")
	if keyboard:
		keyboard.hide()
	
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
	if get_input:
		ip_input.show()
		get_input = false
	else:
		usr_input = ip_input.text
		if usr_input == "":
			return
		print(usr_input)
		join_button.disabled = true
		var peer = ENetMultiplayerPeer.new()
		peer.create_client(usr_input, PORT)
		multiplayer.multiplayer_peer = peer
		Roles.set_role(Roles.Role.PATIENT)
		_set_status("Connecting to " + usr_input)
		connection_timer.start()

func _on_connected() -> void:
	connection_timer.stop()
	_set_status("Connected!")
	load_lobby()

func _on_connection_failed() -> void:
	connection_timer.stop()
	_set_status("Connection failed! No host found.")
	join_button.disabled = false

func _on_connection_timeout() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_set_status("Failed to connect: no host available.")
	join_button.disabled = false
	
func load_lobby() -> void:
	var scene_base := XRTools.find_xr_ancestor(self , "*", "XRToolsSceneBase")
	if not scene_base:
		print("ERROR: Could not find XRToolsSceneBase ancestor!")
		return
	scene_base.load_scene("res://scenes/game/lobby/lobby.tscn")

func _set_status(message: String) -> void:
	status_label.text = message


func _on_ip_input_editing_toggled(toggled_on: bool) -> void:
	var root = get_parent().get_parent().get_parent()
	print(root)
	if toggled_on:
		print("in")
		keyboard.show()
	else:
		print("out")
		keyboard.hide()
