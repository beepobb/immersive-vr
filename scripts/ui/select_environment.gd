extends Control

@onready var back_button = %BackButton
@onready var clarity_card: Button = %ClarityRoomCard
@onready var dialogue_card: Button = %DialogueCafeCard
@onready var confirm_button = %ConfirmButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

	for card in [clarity_card, dialogue_card]:
		card.pressed.connect(_on_card_selected.bind(card))

	confirm_button.pressed.connect(_on_confirm_pressed)

	# --- Hover setup for both cards ---
	_setup_hover(clarity_card)
	_setup_hover(dialogue_card)

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


func _on_card_selected(card: Button) -> void:
	var selected_env: String = card.env_title
	var selected_env_scene: String = ""
	
	# _highlight_selected(clarity_card)
	match selected_env:
		"Clarity Room":
			selected_env_scene = "res://scenes/environment/therapy_room.tscn"
		"Dialogue Cafe":
			selected_env_scene = ""
	AvatarState.environment_id = selected_env_scene
	print(AvatarState.environment_id)

func _highlight_selected(selected_button: Button) -> void:
	clarity_card.modulate = Color(1, 1, 1, 1)
	dialogue_card.modulate = Color(1, 1, 1, 1)

	selected_button.modulate = Color(1.2, 1.2, 1.2)


func _on_confirm_pressed() -> void:
	if AvatarState.environment_id.is_empty():
		print("No environment selected!")
		return

	AvatarState.return_to_lobby(self , "Environment saved for the next call.")

func _on_session_ended(message: String) -> void:
	AvatarState.return_to_home(self , message)


func _on_clarity_room_card_pressed() -> void:
	print("Therapy Room pressed")
