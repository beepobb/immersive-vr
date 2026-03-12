extends VBoxContainer

# Target scene name
@export_file("*.tscn") var target_scene: String

@onready var therapist_button: Button = %TherapistRoleButton
@onready var patient_button: Button = %PatientRoleButton
@onready var room_code_input: LineEdit = %RoomCodeInput
@onready var host_button: Button = $Host
@onready var join_button: Button = $Join
@onready var status_label: Label = %StatusLabel

var pending_room_code := ""
var join_attempt_id := 0

func _ready() -> void:
	therapist_button.pressed.connect(_on_therapist_role_pressed)
	patient_button.pressed.connect(_on_patient_role_pressed)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not HighLevelNetworkHandler.session_found.is_connected(_on_session_found):
		HighLevelNetworkHandler.session_found.connect(_on_session_found)
	if not HighLevelNetworkHandler.connection_error.is_connected(_on_connection_error):
		HighLevelNetworkHandler.connection_error.connect(_on_connection_error)
	if not HighLevelNetworkHandler.connection_closed.is_connected(_on_connection_closed):
		HighLevelNetworkHandler.connection_closed.connect(_on_connection_closed)
	if not HighLevelNetworkHandler.session_ended.is_connected(_on_session_ended):
		HighLevelNetworkHandler.session_ended.connect(_on_session_ended)

	_update_role_ui()
	status_label.text = AvatarState.consume_notice()

func _on_host_pressed() -> void:
	if Roles.user_role != Roles.Role.THERAPIST:
		_set_status("Only a therapist can create a room.")
		return

	join_attempt_id += 1
	pending_room_code = ""

	if not HighLevelNetworkHandler.start_host(1):
		_set_status("Unable to create a room on this network.")
		return

	room_code_input.text = HighLevelNetworkHandler.current_room_code
	_set_status("Room %s created. Share the code with the patient." % HighLevelNetworkHandler.current_room_code)
	_load_lobby()

func _on_join_pressed() -> void:
	var room_code = _normalize_room_code(room_code_input.text)
	if room_code.is_empty():
		_set_status("Enter the room code from the therapist.")
		return

	pending_room_code = room_code
	join_attempt_id += 1
	var attempt_id = join_attempt_id
	room_code_input.text = room_code

	if not HighLevelNetworkHandler.start_listening():
		_set_status("Unable to search for rooms on this network.")
		return

	_set_status("Searching for room %s..." % room_code)

	var known_session = HighLevelNetworkHandler.find_session_by_code(room_code)
	if not known_session.is_empty():
		_connect_to_session(known_session)
		return

	await get_tree().create_timer(5.0).timeout
	if attempt_id != join_attempt_id or pending_room_code != room_code:
		return

	pending_room_code = ""
	_set_status("Room %s was not found on the local network." % room_code)

func _on_connected_to_server() -> void:
	# Client has connected to server - now load the lobby
	print("Connected to server!")
	_set_status("Connected to room %s." % HighLevelNetworkHandler.current_room_code)
	_load_lobby()

func _on_session_found(session_info: Dictionary) -> void:
	if pending_room_code.is_empty():
		return

	if str(session_info.get("room_code", "")) != pending_room_code:
		return

	_connect_to_session(session_info)

func _on_connection_error(message: String) -> void:
	_set_status(message)
	pending_room_code = ""

func _on_connection_closed() -> void:
	if pending_room_code.is_empty():
		return

	_set_status("Connection closed.")
	pending_room_code = ""

func _on_session_ended(message: String) -> void:
	pending_room_code = ""
	_set_status(message)

func _connect_to_session(session_info: Dictionary) -> void:
	var participant_count = int(session_info.get("participant_count", 1))
	var max_players = int(session_info.get("max_players", 2))
	if participant_count >= max_players:
		pending_room_code = ""
		_set_status("Room %s is already full." % str(session_info.get("room_code", "")))
		return

	pending_room_code = ""
	_set_status("Connecting to room %s..." % str(session_info.get("room_code", "")))
	HighLevelNetworkHandler.connect_to_therapist(
		str(session_info.get("ip", "")),
		int(session_info.get("port", 7001)),
		str(session_info.get("room_code", ""))
	)

func _load_lobby() -> void:
	# Skip if no target scene set
	if not target_scene or target_scene == "":
		print("ERROR: target_scene not set!")
		return
	
	print("Loading lobby: ", target_scene)
	# Find the XRToolsSceneBase this node is a child of
	var scene_base: XRToolsSceneBase = XRTools.find_xr_ancestor(self , "*", "XRToolsSceneBase")
	if not scene_base:
		print("ERROR: Could not find XRToolsSceneBase ancestor!")
		return
	
	# Start loading the target scene
	scene_base.load_scene(target_scene)

func _set_status(message: String) -> void:
	status_label.text = message

func _normalize_room_code(room_code: String) -> String:
	return room_code.strip_edges().to_upper().replace(" ", "").replace("-", "")

func _on_therapist_role_pressed() -> void:
	Roles.set_role(Roles.Role.THERAPIST)
	_update_role_ui()

func _on_patient_role_pressed() -> void:
	Roles.set_role(Roles.Role.PATIENT)
	_update_role_ui()

func _update_role_ui() -> void:
	var is_therapist = Roles.user_role == Roles.Role.THERAPIST
	host_button.visible = is_therapist
	join_button.visible = true
	therapist_button.button_pressed = is_therapist
	patient_button.button_pressed = not is_therapist
