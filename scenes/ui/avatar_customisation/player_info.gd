extends Control
class_name PlayerInfoUI

const DEFAULT_PRESETS := {
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

@export var avatar_customisation_path: NodePath

@export var outfit_json_path: String = "res://assets/outfit/outfit_assets.json"
@export var hair_json_path: String = "res://assets/hair/hair_assets.json"
@export var shoes_json_path: String = "res://assets/shoes/shoe_assets.json"

@export var apply_default_preset_on_ready: bool = true
@export var randomise_avatar_parts: bool = true

@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer

@onready var name_input: LineEdit = $MarginContainer/VBoxContainer/DisplayName/LineEdit
@onready var gender_option: OptionButton = $MarginContainer/VBoxContainer/Gender/OptionButton
@onready var age_option: OptionButton = $MarginContainer/VBoxContainer/Age/OptionButton
@onready var randomise_button: Button = $MarginContainer/VBoxContainer/ButtonMargin/RandomButton

var avatar_customisation: Node = null

var outfit_items: Array = []
var hair_items: Array = []
var shoes_items: Array = []

func _ready() -> void:
	randomize()

	if ClassDB.class_exists("UITheme"):
		UITheme.apply_glass_theme(self)

	_apply_layout_defaults()
	_resolve_avatar_customisation()

	outfit_items = _load_asset_items(outfit_json_path)
	hair_items = _load_asset_items(hair_json_path)
	shoes_items = _load_asset_items(shoes_json_path)

	if gender_option and not gender_option.item_selected.is_connected(_on_gender_selected):
		gender_option.item_selected.connect(_on_gender_selected)

	if randomise_button and not randomise_button.pressed.is_connected(_on_randomise_pressed):
		randomise_button.pressed.connect(_on_randomise_pressed)

	if apply_default_preset_on_ready:
		_apply_selected_gender_default_preset()

func _apply_layout_defaults() -> void:
	if vbox:
		vbox.add_theme_constant_override("separation", 18)

	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 18)
		margin_container.add_theme_constant_override("margin_right", 18)
		margin_container.add_theme_constant_override("margin_top", 18)
		margin_container.add_theme_constant_override("margin_bottom", 18)

func _resolve_avatar_customisation() -> void:
	if avatar_customisation_path != NodePath():
		avatar_customisation = get_node_or_null(avatar_customisation_path)

	if avatar_customisation == null:
		avatar_customisation = get_tree().get_first_node_in_group("avatar_customisation")

	if avatar_customisation == null:
		push_warning("PlayerInfoUI: avatar_customisation node not found. Set avatar_customisation_path or add it to group 'avatar_customisation'.")

func _on_gender_selected(index: int) -> void:
	if gender_option == null:
		return

	var gender_text := gender_option.get_item_text(index).strip_edges().to_lower()
	_apply_default_preset_for_gender(gender_text)

func _on_randomise_pressed() -> void:
	_randomise_name()
	_randomise_gender()
	_randomise_age()

	if randomise_avatar_parts:
		_apply_random_avatar_parts_for_selected_gender()
	else:
		var gender_text := _get_selected_option_text(gender_option).strip_edges().to_lower()
		_apply_default_preset_for_gender(gender_text)

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

func _apply_selected_gender_default_preset() -> void:
	if gender_option == null or gender_option.item_count == 0:
		return

	var selected_index := gender_option.get_selected()
	if selected_index < 0:
		selected_index = 0
		gender_option.select(selected_index)

	var gender_text := gender_option.get_item_text(selected_index).strip_edges().to_lower()
	_apply_default_preset_for_gender(gender_text)

func _apply_default_preset_for_gender(gender_text: String) -> void:
	var preset: Dictionary = DEFAULT_PRESETS.get(gender_text, {})
	if preset.is_empty():
		return

	_apply_outfit_by_id(str(preset.get("outfit", "")))
	_apply_hair_by_id(str(preset.get("hair", "")))
	_apply_shoes_by_id(str(preset.get("shoes", "")))

func _apply_random_avatar_parts_for_selected_gender() -> void:
	var gender_text := _get_selected_option_text(gender_option).strip_edges().to_lower()

	var random_outfit_id := _pick_random_asset_id(outfit_items, gender_text)
	var random_hair_id := _pick_random_asset_id(hair_items, gender_text)
	var random_shoes_id := _pick_random_asset_id(shoes_items, gender_text)

	if random_outfit_id.is_empty() or random_hair_id.is_empty() or random_shoes_id.is_empty():
		push_warning("PlayerInfoUI: one or more random avatar parts could not be selected. Falling back to default preset.")
		_apply_default_preset_for_gender(gender_text)
		return

	_apply_outfit_by_id(random_outfit_id)
	_apply_hair_by_id(random_hair_id)
	_apply_shoes_by_id(random_shoes_id)

func _apply_outfit_by_id(outfit_id: String) -> void:
	if outfit_id.is_empty():
		return

	if avatar_customisation == null:
		_resolve_avatar_customisation()

	if avatar_customisation == null:
		push_warning("PlayerInfoUI: cannot apply outfit '%s' because avatar_customisation was not found." % outfit_id)
		return

	if avatar_customisation.has_method("apply_outfit"):
		avatar_customisation.apply_outfit(outfit_id)
	else:
		push_warning("PlayerInfoUI: avatar_customisation node does not have method apply_outfit(outfit_id).")

func _apply_hair_by_id(hair_id: String) -> void:
	if hair_id.is_empty():
		return

	if avatar_customisation == null:
		_resolve_avatar_customisation()

	if avatar_customisation == null:
		push_warning("PlayerInfoUI: cannot apply hair '%s' because avatar_customisation was not found." % hair_id)
		return

	if avatar_customisation.has_method("apply_hair"):
		avatar_customisation.apply_hair(hair_id)
	else:
		push_warning("PlayerInfoUI: avatar_customisation node does not have method apply_hair(hair_id).")

func _apply_shoes_by_id(shoes_id: String) -> void:
	if shoes_id.is_empty():
		return

	if avatar_customisation == null:
		_resolve_avatar_customisation()

	if avatar_customisation == null:
		push_warning("PlayerInfoUI: cannot apply shoes '%s' because avatar_customisation was not found." % shoes_id)
		return

	if avatar_customisation.has_method("apply_shoes"):
		avatar_customisation.apply_shoes(shoes_id)
	else:
		push_warning("PlayerInfoUI: avatar_customisation node does not have method apply_shoes(shoes_id).")

func _load_asset_items(json_path: String) -> Array:
	var items: Array = []

	if json_path.is_empty():
		return items

	if not FileAccess.file_exists(json_path):
		push_warning("PlayerInfoUI: JSON not found at %s" % json_path)
		return items

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("PlayerInfoUI: failed to open JSON at %s" % json_path)
		return items

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("PlayerInfoUI: failed to parse JSON at %s" % json_path)
		return items

	var data = json.data

	if data is Array:
		items = data
	elif data is Dictionary:
		if data.has("items") and data["items"] is Array:
			items = data["items"]
		elif data.has("outfits") and data["outfits"] is Array:
			items = data["outfits"]
		elif data.has("hair") and data["hair"] is Array:
			items = data["hair"]
		elif data.has("shoes") and data["shoes"] is Array:
			items = data["shoes"]
		else:
			for key in data.keys():
				if data[key] is Array:
					items = data[key]
					break

	return items

func _pick_random_asset_id(source_items: Array, gender_text: String) -> String:
	if source_items.is_empty():
		return ""

	var filtered_items := _filter_items_by_gender(source_items, gender_text)

	if filtered_items.is_empty():
		filtered_items = source_items

	var picked = filtered_items[randi() % filtered_items.size()]
	return _extract_item_id(picked)

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

func _extract_item_id(item) -> String:
	if item is Dictionary:
		if item.has("id"):
			return str(item["id"])
		if item.has("name"):
			return str(item["name"])
	return ""

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
