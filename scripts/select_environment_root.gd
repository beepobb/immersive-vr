extends Node3D

@onready var header_viewport = $Header
@onready var carousel_viewport = $Carousel
@onready var indicator_bar_viewport = $IndicatorBar
@onready var confirm_button_viewport = $ConfirmButton

var header = null
var carousel = null
var indicator_bar = null
var confirm_button = null

var main: Node = null
var avatar_customisation: Node = null

var loaded_environment: Node = null
var disclaimer_popup: Node3D = null
var disclaimer_popup_scene := preload("res://scenes/game/disclaimer_popup.tscn")

@onready var back_button := $Header/Viewport/EnvHeader/HBoxContainer/BackButton
var selected_environment_id: String = ""

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	back_button.pressed.connect(_on_back_pressed)

	header = _find_content_root(header_viewport, "EnvHeader")
	carousel = _find_content_root(carousel_viewport, "Carousel")
	indicator_bar = _find_content_root(indicator_bar_viewport, "indicator_bar")
	confirm_button = _find_content_root(confirm_button_viewport, "ConfirmButton")

	if confirm_button is BaseButton and not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)

	if carousel != null and carousel.has_signal("selection_changed"):
		if not carousel.selection_changed.is_connected(_on_selection_changed):
			carousel.selection_changed.connect(_on_selection_changed)

	if carousel != null and carousel.has_signal("center_card_activated"):
		if not carousel.center_card_activated.is_connected(_on_environment_confirmed):
			carousel.center_card_activated.connect(_on_environment_confirmed)

	if header != null and header.has_signal("back_pressed"):
		if not header.back_pressed.is_connected(_on_back_pressed):
			header.back_pressed.connect(_on_back_pressed)

	if confirm_button != null and confirm_button.has_signal("confirm_pressed"):
		if not confirm_button.confirm_pressed.is_connected(_on_confirm_pressed):
			confirm_button.confirm_pressed.connect(_on_confirm_pressed)

	if indicator_bar != null and indicator_bar.has_signal("prev_pressed"):
		if not indicator_bar.prev_pressed.is_connected(_on_prev_pressed):
			indicator_bar.prev_pressed.connect(_on_prev_pressed)

	if indicator_bar != null and indicator_bar.has_signal("next_pressed"):
		if not indicator_bar.next_pressed.is_connected(_on_next_pressed):
			indicator_bar.next_pressed.connect(_on_next_pressed)

	if carousel != null and carousel.has_method("get_current_index") and indicator_bar != null and indicator_bar.has_method("set_active_index"):
		indicator_bar.set_active_index(carousel.get_current_index())

	if carousel != null and carousel.has_method("get_selected_environment"):
		var selected: Dictionary = carousel.get_selected_environment()
		_set_selected_environment(selected)


func _find_content_root(viewport_wrapper: Node, expected_name: String) -> Node:
	if viewport_wrapper == null:
		push_error("Viewport wrapper is null for: " + expected_name)
		return null

	var found = viewport_wrapper.find_child(expected_name, true, false)
	if found == null:
		push_error("Could not find content root: " + expected_name)
	return found


func _on_prev_pressed() -> void:
	if carousel != null and carousel.has_method("go_prev"):
		carousel.go_prev()


func _on_next_pressed() -> void:
	if carousel != null and carousel.has_method("go_next"):
		carousel.go_next()


func _on_selection_changed(index: int, env_data: Dictionary) -> void:
	if indicator_bar != null and indicator_bar.has_method("set_active_index"):
		indicator_bar.set_active_index(index)

	_set_selected_environment(env_data)

func _on_environment_confirmed(env_data: Dictionary) -> void:
	_set_selected_environment(env_data)
	_commit_selected_environment()


func _on_confirm_pressed() -> void:
	if selected_environment_id.is_empty() and carousel != null and carousel.has_method("get_selected_environment"):
		var selected: Dictionary = carousel.get_selected_environment()
		_set_selected_environment(selected)

	_commit_selected_environment()
	print(GameState.environment_id)

func _set_selected_environment(env_data: Dictionary) -> void:
	selected_environment_id = String(env_data.get("id", ""))


func _commit_selected_environment() -> void:
	if selected_environment_id.is_empty():
		print("No environment selected!")
		return

	GameState.set_environment_id(selected_environment_id, multiplayer.is_server())
	GameState.return_to_lobby("Environment saved for the next call.")

func _on_back_pressed() -> void:
	GameState.return_to_lobby()
