extends Control

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")

@onready var back_button = %BackButton
@onready var env_cards: HBoxContainer = %EnvCards
@onready var confirm_button = %ConfirmButton

var card_scene: PackedScene = preload("res://scenes/ui/env_card.tscn")
var card_lookup: Dictionary = {}

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_environment_cards()

	confirm_button.pressed.connect(_on_confirm_pressed)

	if not HighLevelNetworkHandler.session_ended.is_connected(_on_session_ended):
		HighLevelNetworkHandler.session_ended.connect(_on_session_ended)


# ---------------- HOVER LOGIC ----------------

func _setup_hover(card: Control) -> void:
	# Make it scale from its center
	card.pivot_offset = card.size / 2.0

	card.mouse_entered.connect(func():
		_hover_in(card)
	)
	card.mouse_exited.connect(func():
		_hover_out(card)
	)


func _hover_in(card: Control) -> void:
	var t = create_tween()
	t.tween_property(
		card,
		"scale",
		Vector2(1.04, 1.04), # how much to grow
		0.12 # duration (seconds)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hover_out(card: Control) -> void:
	var t = create_tween()
	t.tween_property(
		card,
		"scale",
		Vector2.ONE, # back to normal
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# ---------------- SELECTION / NAVIGATION ----------------

func _on_back_pressed() -> void:
	AvatarState.return_to_lobby(self )


func _build_environment_cards() -> void:
	card_lookup.clear()
	for child in env_cards.get_children():
		child.queue_free()

	for environment in EnvironmentCatalog.get_environments():
		var environment_id = String(environment.get("id", ""))
		var card = card_scene.instantiate()
		env_cards.add_child(card)
		card.set_environment_data(
			environment_id,
			String(environment.get("name", "")),
			String(environment.get("description", "")),
			EnvironmentCatalog.get_environment_thumbnail(environment_id)
		)
		card.pressed.connect(_on_card_selected.bind(environment_id))
		_setup_hover(card)
		card_lookup[environment_id] = card

	var selected_environment_id = AvatarState.environment_id
	if selected_environment_id.is_empty() and not EnvironmentCatalog.get_environment_ids().is_empty():
		selected_environment_id = EnvironmentCatalog.get_default_environment_id()

	if not selected_environment_id.is_empty():
		_on_card_selected(selected_environment_id)

func _on_card_selected(environment_id: String) -> void:
	AvatarState.environment_id = environment_id
	_highlight_selected(environment_id)
	print(AvatarState.environment_id)

func _highlight_selected(selected_environment_id: String) -> void:
	for environment_id in card_lookup.keys():
		var card: Button = card_lookup[environment_id]
		card.modulate = Color(1.15, 1.15, 1.15, 1) if String(environment_id) == selected_environment_id else Color(1, 1, 1, 1)


func _on_confirm_pressed() -> void:
	if AvatarState.environment_id.is_empty():
		print("No environment selected!")
		return

	AvatarState.return_to_lobby(self , "Environment saved for the next call.")

func _on_session_ended(message: String) -> void:
	AvatarState.return_to_home(self , message)
