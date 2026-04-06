extends Control

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")

signal selection_changed(index: int, env_data: Dictionary)

@export var start_index: int = 0

var environments: Array[Dictionary] = []
var current_index: int = 0
var is_animating: bool = false
var card_slots: Array[Button] = []
var slot_positions: Array[Vector2] = []

@onready var clarity_card: Button = $VBoxContainer/EnvCards/ClarityRoomCard
@onready var dialogue_card: Button = $VBoxContainer/EnvCards/DialogueCafeCard
@onready var water_card: Button = $VBoxContainer/EnvCards/WaterCard
@onready var park_card: Button = $VBoxContainer/EnvCards/ParkCard
@onready var desert_card: Button = $VBoxContainer/EnvCards/DesertCard

var slot_scales := [
	Vector2(0.72, 0.72),
	Vector2(0.88, 0.88),
	Vector2(1.08, 1.08),
	Vector2(0.88, 0.88),
	Vector2(0.72, 0.72)
]

# much darker side cards, fully clear center
var slot_modulates := [
	Color(0.32, 0.32, 0.32, 0.38),
	Color(0.45, 0.45, 0.45, 0.58),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(0.45, 0.45, 0.45, 0.58),
	Color(0.32, 0.32, 0.32, 0.38)
]

const TRANSITION_TIME := 0.28
const OUTSIDE_OFFSET := 120.0

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	card_slots = [
		clarity_card,
		dialogue_card,
		water_card,
		park_card,
		desert_card
	]

	if not _validate_nodes():
		return

	_build_environments_from_catalog()
	var saved_environment_id := String(GameState.environment_id)
	var saved_index := _index_of_environment(saved_environment_id)
	if saved_index >= 0:
		current_index = saved_index
	else:
		current_index = clamp(start_index, 0, max(0, environments.size() - 1))

	_store_slot_positions()
	_refresh_carousel(false)
	_emit_selection_changed()

func _validate_nodes() -> bool:
	for card in [
		clarity_card,
		dialogue_card,
		water_card,
		park_card,
		desert_card
	]:
		if card == null:
			push_error("Carousel card path is invalid.")
			return false
	return true

func _build_environments_from_catalog() -> void:
	environments.clear()

	for environment in EnvironmentCatalog.get_environments():
		var env_id := String(environment.get("id", ""))
		if env_id.is_empty():
			continue

		environments.append({
			"id": env_id,
			"name": String(environment.get("name", "")),
			"desc": String(environment.get("description", "")),
			"image": EnvironmentCatalog.get_environment_thumbnail(env_id),
			"scene_path": String(environment.get("scene_path", ""))
		})

	if environments.is_empty():
		push_error("Carousel has no environments. Check EnvironmentCatalog.ENVIRONMENTS.")

func _store_slot_positions() -> void:
	slot_positions.clear()
	for card in card_slots:
		if card == null:
			push_error("A card slot is null. Check your node paths.")
			continue
		slot_positions.append(card.position)

func _wrap_index(i: int) -> int:
	var count := environments.size()
	if count == 0:
		return 0
	return (i % count + count) % count

func _index_of_environment(environment_id: String) -> int:
	var target := environment_id.strip_edges().to_lower()
	if target.is_empty():
		return -1

	for i in range(environments.size()):
		if String(environments[i].get("id", "")).to_lower() == target:
			return i

	return -1

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

func _apply_card(card: Button, data: Dictionary, is_center: bool) -> void:
	card.call("set_data", data["name"], data["desc"], data["image"])
	card.call("set_center_style", is_center)
	card.call("set_selected_visual", is_center)
	card.call("set_hover_enabled", is_center) # only center reacts strongly
	card.set("base_scale", slot_scales[card_slots.find(card)])

func _apply_visual_state_immediate() -> void:
	for i in range(card_slots.size()):
		var card: Button = card_slots[i]
		card.visible = true
		card.position = slot_positions[i]
		card.scale = slot_scales[i]
		card.modulate = slot_modulates[i]
		card.mouse_filter = Control.MOUSE_FILTER_STOP if i == 2 else Control.MOUSE_FILTER_IGNORE

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
		card.visible = true
		card.mouse_filter = Control.MOUSE_FILTER_STOP if i == 2 else Control.MOUSE_FILTER_IGNORE
		tween.tween_property(card, "position", slot_positions[i], 0.22)
		tween.tween_property(card, "scale", slot_scales[i], 0.22)
		tween.tween_property(card, "modulate", slot_modulates[i], 0.22)

	card_slots[0].z_index = 0
	card_slots[1].z_index = 1
	card_slots[2].z_index = 3
	card_slots[3].z_index = 1
	card_slots[4].z_index = 0

func _animate_carousel(direction: int) -> void:
	is_animating = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	if direction == 1:
		tween.tween_property(card_slots[0], "position", slot_positions[0] + Vector2(-OUTSIDE_OFFSET, 0), TRANSITION_TIME)
		tween.tween_property(card_slots[0], "scale", slot_scales[0] * 0.92, TRANSITION_TIME)
		tween.tween_property(card_slots[0], "modulate", Color(0.25, 0.25, 0.25, 0.0), TRANSITION_TIME)

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
		tween.tween_property(card_slots[4], "modulate", Color(0.25, 0.25, 0.25, 0.0), TRANSITION_TIME)

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
	_emit_selection_changed()
	is_animating = false

func go_prev() -> void:
	if is_animating or environments.is_empty():
		return
	await _animate_carousel(-1)

func go_next() -> void:
	if is_animating or environments.is_empty():
		return
	await _animate_carousel(1)

func get_selected_environment() -> Dictionary:
	if environments.is_empty():
		return {}
	return environments[current_index]

func get_current_index() -> int:
	return current_index

func _emit_selection_changed() -> void:
	selection_changed.emit(current_index, get_selected_environment())
