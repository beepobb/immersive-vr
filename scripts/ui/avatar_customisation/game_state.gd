# GameState.gd
extends Node

const HOME_SCENE_PATH := "res://scenes/game/home.tscn"
const LOBBY_SCENE_PATH := "res://scenes/game/lobby/lobby.tscn"
const AVATAR_CUSTOMISATION_SCENE_PATH := "res://scenes/game/avatar_customisation/avatar_customisation.tscn"
const SELECT_ENVIRONMENT_SCENE_PATH := "res://scenes/game/select_environment/select_environment.tscn"
const IN_CALL_SCENE_PATH := "res://scenes/environment.tscn"
const IN_CALL_SCENE = preload(IN_CALL_SCENE_PATH)

const DEFAULT_VISUAL_PRESETS := {
	"male": {
		"outfit": "male_elegantsuit",
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

# Basic avatar info
var display_name: String = ""
var gender: String = "female"
var age_range: String = ""

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

func reset() -> void:
	display_name = ""
	gender = "female"
	age_range = ""

	#TODO: shoes, hair, outfit, skin tone

func update_customisations(hair_id: String, outfit_id: String, shoe_id: String, skin_tone_id: String = "") -> void:
	hair_style = hair_id
	outfit = outfit_id
	shoes = shoe_id
	if skin_tone != "":
		skin_tone = skin_tone_id

func set_default_options() -> void:
	var preset: Dictionary = DEFAULT_VISUAL_PRESETS.get(gender.to_lower(), {})
	hair_style = preset.get("hair")
	shoes = preset.get("shoes")
	outfit = preset.get("outfit")

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
		if skin_key.begins_with(" # "):
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

func load_scene(requester: Node, scene_path: String, notice: String = "") -> void:
	if not notice.is_empty():
		set_notice(notice)

	var scene_base = XRTools.find_xr_ancestor(requester, "*", "XRToolsSceneBase")
	if scene_base:
		scene_base.load_scene(scene_path)
		return

	requester.get_tree().call_deferred("change_scene_to_file", scene_path)

func return_to_home(requester: Node, notice: String = "") -> void:
	load_scene(requester, HOME_SCENE_PATH, notice)

func return_to_lobby(requester: Node, notice: String = "") -> void:
	load_scene(requester, LOBBY_SCENE_PATH, notice)

func end_call_session(notice: String = "Call ended.") -> void:
	if not multiplayer.is_server():
		return

	_cleanup_call_state()
	_broadcast_end_call_cleanup.rpc(notice)
	await get_tree().process_frame
	await get_tree().process_frame
	var peer := multiplayer.multiplayer_peer
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null

func _cleanup_call_state() -> void:
	peer_roles.clear()
	peer_ready.clear()
	environment_id = ""
	pending_notice = ""

@rpc("any_peer", "call_local")
func _broadcast_end_call_cleanup(notice: String) -> void:
	if not notice.is_empty():
		set_notice(notice)
	load_scene(self , HOME_SCENE_PATH, notice)

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

@rpc("any_peer", "call_local")
func start_call():
	get_tree().change_scene_to_packed(IN_CALL_SCENE)
