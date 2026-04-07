extends VBoxContainer

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")

const STATUS_COLOR_DEFAULT := Color(1, 1, 1, 1)
const STATUS_COLOR_ALERT := Color(0.95, 0.25, 0.25, 1)

@onready var participant_label: Label = %Participants
@onready var player_list: GridContainer = %PlayerList
@onready var lobby_status_label: Label = %LobbyStatus
@onready var ip_label: Label = %IPLabel
@onready var start_call_button: Button = %StartCallButton
@onready var ready_button: Button = %ReadyButton
@export var player_card: PackedScene

var lobby_manager
var last_lobby_state := {}
var is_ready_local := false

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	GameState.roster_updated.connect(sync_player_cards)
	start_call_button.pressed.connect(_on_start_call_pressed)
	ready_button.pressed.connect(_on_ready_button_pressed)
	var ip = IP.get_local_addresses()
	for addr in ip:
		if addr.begins_with("192.") or addr.begins_with("10.") or addr.begins_with("172."):
			ip_label.text = "Local IP: " + addr
			break	
	setup_ui()
	if multiplayer.is_server():
		sync_player_cards(GameState.get_roster_payload())
	else:
		call_deferred("_request_initial_roster")

func _request_initial_roster() -> void:
	if multiplayer.is_server():
		return
	GameState.request_roster.rpc_id(1)

func setup_ui():
	match Roles.user_role:
		Roles.Role.THERAPIST:
			ready_button.hide()
		Roles.Role.PATIENT:
			start_call_button.hide()

@rpc("any_peer", "call_local")
func sync_player_cards(players: Array) -> void:
	for child in player_list.get_children():
		child.queue_free()

	for player_data in players:
		var player_id := int(player_data.get("id", 0))
		if player_id == 0:
			continue

		var player = player_card.instantiate()
		player.name = str(player_id)
		player.prepare_card(
			String(player_data.get("name", "Player " + str(player_id))),
			String(player_data.get("role", "Patient")),
			bool(player_data.get("ready", false))
		)
		if player_id == 1:
			player.get_node("MarginContainer/HBoxContainer2/Status").hide()
		player.set_meta("peer_id", player_id)
		player_list.add_child(player)

		if player_id == multiplayer.get_unique_id():
			is_ready_local = bool(player_data.get("ready", false))
			ready_button.text = "Cancel" if is_ready_local else "Ready"

	_update_participants_label(players)
	
	update_start_call_button_state(players)

func _update_participants_label(players: Array) -> void:
	var participants_count := 0
	for player_data in players:
		if int(player_data.get("id", 0)) != 0:
			participants_count += 1

	var max_participants := 2
	var current_label := participant_label.text.strip_edges()
	var separator_index := current_label.find("/")
	if separator_index >= 0:
		var configured_max := int(current_label.substr(separator_index + 1, current_label.length()))
		if configured_max > 0:
			max_participants = configured_max

	participant_label.text = "%d/%d" % [participants_count, max_participants]

func _on_ready_button_pressed() -> void:
	UIButtonAudio.play_click()

	var card = null
	var id = multiplayer.get_unique_id()
	for c in player_list.get_children():
		if c.has_meta("peer_id") and int(c.get_meta("peer_id")) == id:
			card = c
			break
	if card == null:
		return

	is_ready_local = not is_ready_local
	card.set_status(is_ready_local)
	ready_button.text = "Cancel" if is_ready_local else "Ready"

	GameState.submit_ready_state(is_ready_local)

func update_start_call_button_state(players: Array) -> void:
	var all_ready := true
	var has_eligible_players := false
	
	for player_data in players:
		var role := String(player_data.get("role", ""))
		if role == "Therapist":
			continue
		
		has_eligible_players = true
		if not bool(player_data.get("ready", false)):
			all_ready = false
			break
			
	start_call_button.disabled = not (has_eligible_players and all_ready)

func _on_start_call_pressed() -> void:
	UIButtonAudio.play_click()
	GameState.start_call_for_clients()
