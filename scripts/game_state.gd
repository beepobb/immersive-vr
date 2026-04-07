# GameState.gd
extends Node

const HOME_SCENE_PATH := "res://scenes/game/home.tscn"
const LOBBY_SCENE_PATH := "res://scenes/game/lobby/lobby.tscn"
const AVATAR_CUSTOMISATION_SCENE_PATH := "res://scenes/game/avatar_customisation/avatar_customisation.tscn"
const SELECT_ENVIRONMENT_SCENE_PATH := "res://scenes/game/select_environment/select_environment.tscn"
const IN_CALL_SCENE_PATH := "res://scenes/game/call/environment.tscn"
const CALL_SUMMARY_SCENE_PATH := "res://scenes/game/call/call_summary.tscn"

const DEFAULT_VISUAL_PRESETS := {
	"male": {
		"outfit": "male_elegantsuit_01",
		"hair": "culturalibre_hair_05",
		"shoes": "punkduck_running_shoes"
	},
	"female": {
		"outfit": "female_elegantsuit",
		"hair": "human_elvs_short_side_do_2",
		"shoes": "dressupdoc_maryjane"
	}
}

# game states
var peer_roles: Dictionary = {}
var peer_ready: Dictionary = {}

var avatar: Node3D

var entered_lobby: bool = false

# Basic avatar info
var gender: String = "female"

# Visual choices (fill out as you add more options)
var skin_tone: String = ""
var outfit: String = ""
var hair_style: String = ""
var shoes: String = ""

# Environment choice
var environment_id: String = "" # "clarity_room", "dialogue_cafe", etc.
var pending_notice: String = ""

signal roster_updated(players: Array)
signal environment_updated(environment_id: String)

var _appearance_service := AvatarAppearanceService.new()
var _manifests_loaded := false
var _lobby_network_connected := false

var recording
var recording_path: String

func reset() -> void:
	gender = "female"

	#TODO: shoes, hair, outfit, skin tone

func update_customisations(hair_id: String, outfit_id: String, shoe_id: String, skin_tone_id: String = "") -> void:
	hair_style = hair_id
	outfit = outfit_id
	shoes = shoe_id
	skin_tone = skin_tone_id

func set_default_options() -> void:
	var preset: Dictionary = DEFAULT_VISUAL_PRESETS.get(gender.to_lower(), {})
	hair_style = preset.get("hair")
	shoes = preset.get("shoes")
	outfit = preset.get("outfit")

func get_gender_default_presets(gender: String):
	if gender == "male":
		return DEFAULT_VISUAL_PRESETS["male"]
	if gender == "female":
		return DEFAULT_VISUAL_PRESETS["female"]

#TODO: remove state if unnecessary
func apply_to_avatar(state: Dictionary = {}) -> void:
	if avatar == null:
		return

	if not _manifests_loaded:
		_appearance_service.load_manifests()
		_manifests_loaded = true

	var attachment_root = _appearance_service.get_default_attachment_root(avatar)
	_appearance_service.clear_all_parts(attachment_root)

	if hair_style == "" or outfit == "" or shoes == "":
		set_default_options()

	var selected_hair := _resolve_state_string(state, ["hair_style", "hair"], hair_style)
	var selected_outfit := _resolve_state_string(state, ["outfit"], outfit)
	var selected_shoes := _resolve_state_string(state, ["shoes"], shoes)

	_appearance_service.replace_part(attachment_root, null, selected_hair, AvatarAppearanceService.PartType.HAIR)
	_appearance_service.replace_part(attachment_root, null, selected_outfit, AvatarAppearanceService.PartType.OUTFIT)
	_appearance_service.replace_part(attachment_root, null, selected_shoes, AvatarAppearanceService.PartType.SHOES)
	print("Appearance servicing")
	var skin_value = _resolve_state_value(state, ["skin_tone"], skin_tone)
	if skin_value is Color:
		var body_mesh := avatar.get_node_or_null("Human_rig / Skeleton3D / Human") as MeshInstance3D
		if body_mesh == null:
			for node in avatar.find_children(" * ", "MeshInstance3D", true, false):
				if String(node.name).to_lower() == "human":
					body_mesh = node as MeshInstance3D
					break
		_appearance_service.apply_skin_color(body_mesh, skin_value)
	elif skin_value is String:
		var skin_key := String(skin_value).strip_edges()
		if !skin_key.begins_with("#"):
			skin_key = "#" + skin_key
		var parsed_color := Color.from_string(skin_key, Color(0, 0, 0, 0))
		if parsed_color.a > 0.0:
			var mesh := avatar.get_node_or_null("Human_rig/Skeleton3D/Human") as MeshInstance3D
			if mesh == null:
				for node in avatar.find_children("*", "MeshInstance3D", true, false):
					if String(node.name).to_lower() == "human":
						mesh = node as MeshInstance3D
						break
			_appearance_service.apply_skin_color(mesh, parsed_color)
	
func _resolve_state_string(state: Dictionary, keys: Array, fallback: String) -> String:
	var value = _resolve_state_value(state, keys, fallback)
	return String(value)

func _resolve_state_value(state: Dictionary, keys: Array, fallback):
	for key in keys:
		if state.has(key):
			return state[key]
	return fallback

func set_notice(message: String) -> void:
	pending_notice = message

func consume_notice() -> String:
	var message := pending_notice
	pending_notice = ""
	return message

func load_scene(scene_path: String, notice: String = "") -> void:
	if not notice.is_empty():
		set_notice(notice)
	
	var staging = get_tree().get_first_node_in_group("xr_staging")
	
	if staging:
		staging.load_scene(scene_path)
	else:
		push_error("XRToolsStaging not found! Scene load aborted.")

func return_to_home(notice: String = "") -> void:
	load_scene(HOME_SCENE_PATH, notice)

func return_to_lobby(notice: String = "") -> void:
	load_scene(LOBBY_SCENE_PATH, notice)

func leave_lobby(notice: String = "") -> void:
	_cleanup_call_state()
	var peer := multiplayer.multiplayer_peer
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	return_to_home(notice)

func end_lobby_session(notice: String) -> void:
	if not multiplayer.is_server():
		return

	end_lobby_for_clients.rpc(notice)
	leave_lobby(notice)
	GameState.entered_lobby = false

@rpc("authority", "call_remote")
func end_lobby_for_clients(notice: String) -> void:
	leave_lobby(notice)

func end_call_session(notice: String) -> void:
	GameState.entered_lobby = false
	if not multiplayer.is_server():
		return

	_cleanup_call_state()
	await get_tree().process_frame
	await get_tree().process_frame
	var peer := multiplayer.multiplayer_peer
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	load_scene(CALL_SUMMARY_SCENE_PATH, notice)

func _cleanup_call_state() -> void:
	peer_roles.clear()
	peer_ready.clear()
	environment_id = ""
	pending_notice = ""

func set_environment_id(new_environment_id: String, broadcast: bool = false) -> void:
	environment_id = new_environment_id
	if not broadcast:
		environment_updated.emit(environment_id)

	if broadcast and multiplayer.is_server():
		sync_environment.rpc(environment_id)

func initialize_lobby_network(user_role: int) -> void:
	if not _lobby_network_connected:
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_lobby_network_connected = true

	if multiplayer.is_server():
		if peer_roles.is_empty():
			var host_id := multiplayer.get_unique_id()
			peer_roles[host_id] = user_role
			peer_ready[host_id] = true
		_broadcast_roster()
		return

	rpc_id(1, "register_role", int(user_role))

@rpc("any_peer")
func register_role(role: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	peer_roles[sender_id] = role
	if not peer_ready.has(sender_id):
		peer_ready[sender_id] = false
	_broadcast_roster()

@rpc("any_peer")
func request_roster() -> void:
	if not multiplayer.is_server():
		return

	var requester_id := multiplayer.get_remote_sender_id()
	sync_player_cards.rpc_id(requester_id, get_roster_payload())

@rpc("any_peer")
func request_environment() -> void:
	if not multiplayer.is_server():
		return

	var requester_id := multiplayer.get_remote_sender_id()
	sync_environment.rpc_id(requester_id, environment_id)

func submit_ready_state(ready_state: bool) -> void:
	var local_peer_id := multiplayer.get_unique_id()

	if multiplayer.is_server():
		peer_ready[local_peer_id] = ready_state
		_broadcast_roster()
		return

	rpc_id(1, "set_ready_state", ready_state)

@rpc("any_peer")
func set_ready_state(ready_state: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not peer_roles.has(sender_id):
		return

	peer_ready[sender_id] = ready_state
	_broadcast_roster()

@rpc("any_peer", "call_local")
func sync_player_cards(players: Array) -> void:
	roster_updated.emit(players)

@rpc("any_peer", "call_local")
func sync_environment(env_id) -> void:
	set_environment_id(String(env_id), false)

func get_roster_payload() -> Array:
	var payload: Array = []
	for peer_id in peer_roles.keys():
		var role_value := int(peer_roles[peer_id])
		payload.append({
			"id": int(peer_id),
			"name": "Player " + str(peer_id),
			"role": _role_to_text(role_value),
			"ready": bool(peer_ready.get(peer_id, false)),
		})
	return payload

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected:", peer_id)
	if multiplayer.is_server():
		_broadcast_roster()

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected:", peer_id)
	if not multiplayer.is_server():
		return
	peer_roles.erase(peer_id)
	peer_ready.erase(peer_id)
	_broadcast_roster()

func _broadcast_roster() -> void:
	if not multiplayer.is_server():
		return
	sync_player_cards.rpc(get_roster_payload())

func _role_to_text(role_value: int) -> String:
	if role_value == int(Roles.Role.THERAPIST):
		return "Therapist"
	return "Patient"

@rpc("authority", "call_remote")
func start_call() -> void:
	load_scene(IN_CALL_SCENE_PATH)

func start_call_for_clients():
	if !multiplayer.is_server():
		return
		
	print("Server starting call for clients...")
	
	for peer_id in multiplayer.get_peers():
		print("Calling peer:", peer_id)
		start_call.rpc_id(peer_id)
		
func rest_recording_meta():
	recording = null
	recording_path = ""
