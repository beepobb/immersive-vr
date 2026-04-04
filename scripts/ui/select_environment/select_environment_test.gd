extends Control

signal environment_confirmed(environment_data: Dictionary)

@export var start_index: int = 0

var environments: Array[Dictionary] = []

var current_index: int = 0
var is_animating: bool = false
var card_slots: Array[Button] = []
var slot_positions: Array[Vector2] = []

@onready var env_cards: Control = $MarginContainer/VBoxContainer/Carousel/CenterContainer/EnvCards

@onready var clarity_card: Button = $MarginContainer/VBoxContainer/Carousel/CenterContainer/EnvCards/ClarityRoomCard
@onready var dialogue_card: Button = $MarginContainer/VBoxContainer/Carousel/CenterContainer/EnvCards/DialogueCafeCard
@onready var water_card: Button = $MarginContainer/VBoxContainer/Carousel/CenterContainer/EnvCards/WaterCard
@onready var park_card: Button = $MarginContainer/VBoxContainer/Carousel/CenterContainer/EnvCards/ParkCard
@onready var desert_card: Button = $MarginContainer/VBoxContainer/Carousel/CenterContainer/EnvCards/DesertCard

@onready var prev_button: Button = $MarginContainer/VBoxContainer/Footer/BottomNavBar/PrevButton
@onready var indicator_row: HBoxContainer = $MarginContainer/VBoxContainer/Footer/BottomNavBar/MarginContainer/IndicatorRow
@onready var next_button: Button = $MarginContainer/VBoxContainer/Footer/BottomNavBar/NextButton
@onready var confirm_button: Button = $MarginContainer/VBoxContainer/Footer/ConfirmButton

var slot_scales := [
	Vector2(0.62, 0.62),
	Vector2(0.82, 0.82),
	Vector2(1.0, 1.0),
	Vector2(0.82, 0.82),
	Vector2(0.62, 0.62)
]

var slot_modulates := [
	Color(1, 1, 1, 0.18),
	Color(1, 1, 1, 0.42),
	Color(1, 1, 1, 1.0),
	Color(1, 1, 1, 0.42),
	Color(1, 1, 1, 0.18)
]

const TRANSITION_TIME := 0.28
const OUTSIDE_OFFSET := 120.0

func _ready() -> void:
	card_slots = [
		clarity_card,
		dialogue_card,
		water_card,
		park_card,
		desert_card
	]

	_build_environments_from_cards()

	current_index = clamp(start_index, 0, max(0, environments.size() - 1))

	_store_slot_positions()
	_connect_signals()
	_setup_existing_indicators()
	_refresh_carousel(false)


func _build_environments_from_cards() -> void:
	environments.clear()

	var source_cards: Array[Button] = [
		clarity_card,
		dialogue_card,
		water_card,
		park_card,
		desert_card
	]

	for card in source_cards:
		environments.append({
			"id": String(card.name).to_lower(),
			"name": card.get("env_title"),
			"desc": card.get("env_description"),
			"image": card.get("env_photo")
		})


func _store_slot_positions() -> void:
	slot_positions.clear()
	for card in card_slots:
		if card == null:
			push_error("A card slot is null. Check your node paths.")
			continue
		slot_positions.append(card.position)


func _connect_signals() -> void:
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)

	for card in card_slots:
		card.pressed.connect(_on_card_pressed.bind(card))


func _wrap_index(i: int) -> int:
	var count := environments.size()
	if count == 0:
		return 0
	return (i % count + count) % count


func _refresh_carousel(animated: bool = true) -> void:
	if environments.is_empty():
		return

	for slot in range(card_slots.size()):
		var env_index := _wrap_index(current_index + slot - 2)
		var card: Button = card_slots[slot]
		var data: Dictionary = environments[env_index]
		var is_center := slot == 2

		_apply_card(card, data, is_center)

	if animated:
		_apply_visual_state_animated()
	else:
		_apply_visual_state_immediate()

	_update_indicators()


func _apply_card(card: Button, data: Dictionary, is_center: bool) -> void:
	card.call("set_data", data["name"], data["desc"], data["image"])
	card.call("set_center_style", is_center)
	card.call("set_selected_visual", is_center)
	card.call("set_hover_enabled", true)

	# reset base scale for hover logic after carousel scale changes
	card.set("base_scale", slot_scales[card_slots.find(card)])


func _apply_visual_state_immediate() -> void:
	for i in range(card_slots.size()):
		var card: Button = card_slots[i]
		card.position = slot_positions[i]
		card.scale = slot_scales[i]
		card.modulate = slot_modulates[i]

	card_slots[0].z_index = 0
	card_slots[1].z_index = 1
	card_slots[2].z_index = 3
	card_slots[3].z_index = 1
	card_slots[4].z_index = 0


func _apply_visual_state_animated() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	for i in range(card_slots.size()):
		var card: Button = card_slots[i]
		tween.tween_property(card, "position", slot_positions[i], 0.22)
		tween.tween_property(card, "scale", slot_scales[i], 0.22)
		tween.tween_property(card, "modulate", slot_modulates[i], 0.22)

	card_slots[0].z_index = 0
	card_slots[1].z_index = 1
	card_slots[2].z_index = 3
	card_slots[3].z_index = 1
	card_slots[4].z_index = 0


func _on_prev_pressed() -> void:
	if is_animating or environments.is_empty():
		return

	await _animate_carousel(-1)


func _on_next_pressed() -> void:
	if is_animating or environments.is_empty():
		return

	await _animate_carousel(1)


func _on_card_pressed(card: Button) -> void:
	if is_animating:
		return

	var slot: int = card_slots.find(card)
	if slot == -1:
		return

	if slot == 2:
		_on_confirm_pressed()
	elif slot < 2:
		_on_prev_pressed()
	else:
		_on_next_pressed()
	
func _animate_carousel(direction: int) -> void:
	is_animating = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	if direction == 1:
		tween.tween_property(card_slots[0], "position", slot_positions[0] + Vector2(-OUTSIDE_OFFSET, 0), TRANSITION_TIME)
		tween.tween_property(card_slots[0], "scale", slot_scales[0] * 0.92, TRANSITION_TIME)
		tween.tween_property(card_slots[0], "modulate", Color(1, 1, 1, 0.0), TRANSITION_TIME)

		tween.tween_property(card_slots[1], "position", slot_positions[0], TRANSITION_TIME)
		tween.tween_property(card_slots[1], "scale", slot_scales[0], TRANSITION_TIME)
		tween.tween_property(card_slots[1], "modulate", slot_modulates[0], TRANSITION_TIME)

		tween.tween_property(card_slots[2], "position", slot_positions[1], TRANSITION_TIME)
		tween.tween_property(card_slots[2], "scale", slot_scales[1], TRANSITION_TIME)
		tween.tween_property(card_slots[2], "modulate", slot_modulates[1], TRANSITION_TIME)

		tween.tween_property(card_slots[3], "position", slot_positions[2], TRANSITION_TIME)
		tween.tween_property(card_slots[3], "scale", slot_scales[2], TRANSITION_TIME)
		tween.tween_property(card_slots[3], "modulate", slot_modulates[2], TRANSITION_TIME)

		tween.tween_property(card_slots[4], "position", slot_positions[3], TRANSITION_TIME)
		tween.tween_property(card_slots[4], "scale", slot_scales[3], TRANSITION_TIME)
		tween.tween_property(card_slots[4], "modulate", slot_modulates[3], TRANSITION_TIME)

		card_slots[3].z_index = 3
		card_slots[2].z_index = 2
		card_slots[1].z_index = 1
		card_slots[4].z_index = 1
		card_slots[0].z_index = 0

	else:
		tween.tween_property(card_slots[4], "position", slot_positions[4] + Vector2(OUTSIDE_OFFSET, 0), TRANSITION_TIME)
		tween.tween_property(card_slots[4], "scale", slot_scales[4] * 0.92, TRANSITION_TIME)
		tween.tween_property(card_slots[4], "modulate", Color(1, 1, 1, 0.0), TRANSITION_TIME)

		tween.tween_property(card_slots[3], "position", slot_positions[4], TRANSITION_TIME)
		tween.tween_property(card_slots[3], "scale", slot_scales[4], TRANSITION_TIME)
		tween.tween_property(card_slots[3], "modulate", slot_modulates[4], TRANSITION_TIME)

		tween.tween_property(card_slots[2], "position", slot_positions[3], TRANSITION_TIME)
		tween.tween_property(card_slots[2], "scale", slot_scales[3], TRANSITION_TIME)
		tween.tween_property(card_slots[2], "modulate", slot_modulates[3], TRANSITION_TIME)

		tween.tween_property(card_slots[1], "position", slot_positions[2], TRANSITION_TIME)
		tween.tween_property(card_slots[1], "scale", slot_scales[2], TRANSITION_TIME)
		tween.tween_property(card_slots[1], "modulate", slot_modulates[2], TRANSITION_TIME)

		tween.tween_property(card_slots[0], "position", slot_positions[1], TRANSITION_TIME)
		tween.tween_property(card_slots[0], "scale", slot_scales[1], TRANSITION_TIME)
		tween.tween_property(card_slots[0], "modulate", slot_modulates[1], TRANSITION_TIME)

		card_slots[1].z_index = 3
		card_slots[2].z_index = 2
		card_slots[0].z_index = 1
		card_slots[3].z_index = 1
		card_slots[4].z_index = 0

	await tween.finished

	current_index = _wrap_index(current_index + direction)

	for slot in range(card_slots.size()):
		var env_index := _wrap_index(current_index + slot - 2)
		var card: Button = card_slots[slot]
		var data: Dictionary = environments[env_index]
		var is_center := slot == 2
		_apply_card(card, data, is_center)

	_apply_visual_state_immediate()
	_update_indicators()
	is_animating = false


func _on_confirm_pressed() -> void:
	if environments.is_empty():
		return

	var selected: Dictionary = environments[current_index]
	print("Selected environment: ", selected["name"])
	environment_confirmed.emit(selected)


func get_selected_environment() -> Dictionary:
	if environments.is_empty():
		return {}
	return environments[current_index]


func _setup_existing_indicators() -> void:
	for child in indicator_row.get_children():
		if child is Panel:
			var panel := child as Panel
			var style := StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 0.18)
			style.corner_radius_top_left = 99
			style.corner_radius_top_right = 99
			style.corner_radius_bottom_left = 99
			style.corner_radius_bottom_right = 99
			panel.add_theme_stylebox_override("panel", style)


func _update_indicators() -> void:
	for i in range(indicator_row.get_child_count()):
		var panel := indicator_row.get_child(i) as Panel
		if panel == null:
			continue

		var flat := StyleBoxFlat.new()
		if i == current_index:
			flat.bg_color = Color(1, 1, 1, 0.95)
		else:
			flat.bg_color = Color(1, 1, 1, 0.18)

		flat.corner_radius_top_left = 99
		flat.corner_radius_top_right = 99
		flat.corner_radius_bottom_left = 99
		flat.corner_radius_bottom_right = 99
		panel.add_theme_stylebox_override("panel", flat)
