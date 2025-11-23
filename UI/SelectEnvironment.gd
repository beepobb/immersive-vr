extends Control

@onready var back_button       = %BackButton
@onready var clarity_card  : Button = %ClarityRoomCard
@onready var dialogue_card : Button = %DialogueCafeCard
@onready var confirm_button    = %ConfirmButton

var selected_env : String = ""   # store chosen environment

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

	clarity_card.pressed.connect(_on_clarity_selected)
	dialogue_card.pressed.connect(_on_dialogue_selected)

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
	get_tree().change_scene_to_file("res://UI/AvatarCustomizer.tscn")


func _on_clarity_selected() -> void:
	selected_env = "ClarityRoom"
	# _highlight_selected(clarity_card)


func _on_dialogue_selected() -> void:
	selected_env = "DialogueCafe"
	# _highlight_selected(dialogue_card)


func _highlight_selected(selected_button: Button) -> void:
	clarity_card.modulate  = Color(1, 1, 1, 1)
	dialogue_card.modulate = Color(1, 1, 1, 1)

	selected_button.modulate = Color(1.2, 1.2, 1.2)


func _on_confirm_pressed() -> void:
	if selected_env == "":
		print("No environment selected!")
		return

	#get_tree().change_scene_to_file("res://VR/LoadEnvironment.tscn")
	get_tree().change_scene_to_file("res://VR/LoadEnvironment.tscn")
