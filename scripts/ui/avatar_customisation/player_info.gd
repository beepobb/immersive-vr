extends Control
class_name PlayerInfoUI

const AVATAR_CUSTOMISATION_SCRIPT = preload("res://scripts/ui/avatar_customisation/avatar_customisation.gd")

@export var randomise_avatar_parts: bool = true

@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer

@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/DisplayName/LineEdit
@onready var gender_option: OptionButton = $MarginContainer/VBoxContainer/Gender/OptionButton
@onready var age_option: OptionButton = $MarginContainer/VBoxContainer/Age/OptionButton
@onready var randomise_button: Button = $MarginContainer/VBoxContainer/ButtonMargin/RandomButton

var appearance_service := AvatarAppearanceService.new()

func _ready() -> void:
	gender_option.select(0)
	if gender_option and not gender_option.item_selected.is_connected(_on_gender_selected):
		gender_option.item_selected.connect(_on_gender_selected)

	if randomise_button and not randomise_button.pressed.is_connected(_on_randomise_pressed):
		randomise_button.pressed.connect(_on_randomise_pressed)
		
func _on_gender_selected(index: int) -> void:
	if gender_option == null:
		return

	var gender_text := gender_option.get_item_text(index).strip_edges().to_lower()
	GameState.gender = gender_text


func _on_randomise_pressed() -> void:
	_randomise_name()
	_randomise_gender()
	_randomise_age()

	if randomise_avatar_parts:
		_apply_random_avatar_parts_for_selected_gender()

func _randomise_name() -> void:
	if name_input == null:
		return

	var sample_names := [
		"Alex",
		"Jamie",
		"Taylor",
		"Jordan",
		"Casey",
		"Riley",
		"Morgan",
		"Skyler",
		"Avery",
		"Quinn"
	]

	name_input.text = sample_names[randi() % sample_names.size()]

func _randomise_gender() -> void:
	if gender_option == null or gender_option.item_count == 0:
		return

	var index := randi() % gender_option.item_count
	gender_option.select(index)

func _randomise_age() -> void:
	if age_option == null or age_option.item_count == 0:
		return

	var index := randi() % age_option.item_count
	age_option.select(index)

func _apply_random_avatar_parts_for_selected_gender() -> void:
	var gender_text = GameState.gender
	appearance_service.load_manifests()

	var random_outfit_id := _pick_random_asset_id(appearance_service.outfit_map, gender_text)
	var random_hair_id := _pick_random_asset_id(appearance_service.hair_map, gender_text)
	var random_shoes_id := _pick_random_asset_id(appearance_service.shoes_map, gender_text)
	var avatar_customisation = find_parent("AvatarCustomisationBase")
	if avatar_customisation == null:
		return
		
	avatar_customisation.apply_and_set_id(AVATAR_CUSTOMISATION_SCRIPT.Options.OUTFIT, random_outfit_id)
	avatar_customisation.apply_and_set_id(AVATAR_CUSTOMISATION_SCRIPT.Options.HAIR, random_hair_id)
	avatar_customisation.apply_and_set_id(AVATAR_CUSTOMISATION_SCRIPT.Options.SHOES, random_shoes_id)

func _pick_random_asset_id(source_items: Array, gender_text: String) -> String:
	if source_items.is_empty():
		return ""

	var filtered_items := _filter_items_by_gender(source_items, gender_text)

	if filtered_items.is_empty():
		filtered_items = source_items

	var picked = filtered_items[randi() % filtered_items.size()]
	return picked.get("id")

func _filter_items_by_gender(source_items: Array, gender_text: String) -> Array:
	var results: Array = []

	for item in source_items:
		if item is Dictionary:
			var item_gender := str(item.get("gender", "")).strip_edges().to_lower()
			var item_id := str(item.get("id", "")).strip_edges().to_lower()
			var item_name := str(item.get("name", "")).strip_edges().to_lower()

			if item_gender != "":
				if item_gender == gender_text:
					results.append(item)
			else:
				if gender_text == "male":
					if item_id.contains("male") or item_name.contains("male"):
						results.append(item)
				elif gender_text == "female":
					if item_id.contains("female") or item_name.contains("female"):
						results.append(item)

	return results

func get_player_info() -> Dictionary:
	return {
		"display_name": name_input.text if name_input else "",
		"gender": _get_selected_option_text(gender_option),
		"age": _get_selected_option_text(age_option)
	}

func _get_selected_option_text(option_button: OptionButton) -> String:
	if option_button == null or option_button.item_count == 0:
		return ""

	var index := option_button.get_selected()
	if index < 0:
		return ""

	return option_button.get_item_text(index)
