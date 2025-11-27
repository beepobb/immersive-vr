extends Control

@onready var back_button       = %BackButton
@onready var clarity_card  : Button = %ClarityRoomCard
@onready var dialogue_card : Button = %DialogueCafeCard
@onready var confirm_button    = %ConfirmButton

var selected_env : String = ""   # store chosen environment
var selected_env_scene: String = ""
var logger = Logger.new()

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

	for card in [clarity_card, dialogue_card]:
		card.pressed.connect(func(c=card):
			_on_card_selected(c)
		)

	confirm_button.pressed.connect(_on_confirm_pressed)

	# --- Hover setup for both cards ---
	_setup_hover(clarity_card)
	_setup_hover(dialogue_card)


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
		Vector2(1.04, 1.04),   # how much to grow
		0.12                   # duration (seconds)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hover_out(card: Control) -> void:
	var t = create_tween()
	t.tween_property(
		card,
		"scale",
		Vector2.ONE,           # back to normal
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# ---------------- SELECTION / NAVIGATION ----------------

func _on_back_pressed() -> void:
	get_node("/root/MainPreview").show_customizer_page()


func _on_card_selected(card: Button) -> void:
	selected_env = card.env_title
	#_highlight_selected(clarity_card)
	match selected_env:
		"Clarity Room":
			selected_env_scene = "res://scenes/environment/therapy_room.tscn"
		"Dialogue Cafe":
			selected_env_scene = ""

func _highlight_selected(selected_button: Button) -> void:
	clarity_card.modulate  = Color(1, 1, 1, 1)
	dialogue_card.modulate = Color(1, 1, 1, 1)

	selected_button.modulate = Color(1.2, 1.2, 1.2)


func _on_confirm_pressed() -> void:
	if selected_env == "":
		print("No environment selected!")
		return
		
	# Save environment globally
	AvatarState.environment_id = selected_env
	
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	
