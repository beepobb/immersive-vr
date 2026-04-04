extends Control
class_name GenderSelectionUI

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

@export var outfit_json_path: String = "res://assets/outfit/outfit_assets.json"
@export var hair_json_path: String = "res://assets/hair/hair_assets.json"
@export var shoes_json_path: String = "res://assets/shoes/shoes_assets.json"

@onready var male_button: Button = $CenterContainer/VBoxContainer/Male
@onready var female_button: Button = $CenterContainer/VBoxContainer/Female
@onready var random_button: Button = $CenterContainer/VBoxContainer/Random

var avatar_customisation: Node = null

var outfit_items: Array = []
var hair_items: Array = []
var shoes_items: Array = []

func _ready() -> void:
	randomize()

	_resolve_avatar_customisation()

	outfit_items = _load_asset_items(outfit_json_path)
	hair_items = _load_asset_items(hair_json_path)
	shoes_items = _load_asset_items(shoes_json_path)

	if male_button and not male_button.pressed.is_connected(_on_male_pressed):
		male_button.pressed.connect(_on_male_pressed)

	if female_button and not female_button.pressed.is_connected(_on_female_pressed):
		female_button.pressed.connect(_on_female_pressed)

	if random_button and not random_button.pressed.is_connected(_on_random_pressed):
		random_button.pressed.connect(_on_random_pressed)

func _on_male_pressed() -> void:
	_apply_default_preset_for_gender("male")

func _on_female_pressed() -> void:
	_apply_default_preset_for_gender("female")

func _on_random_pressed() -> void:
	var genders: Array[String] = ["male", "female"]
	var gender_text: String = genders[randi() % genders.size()]
	_apply_random_avatar_parts_for_gender(gender_text)

func _resolve_avatar_customisation() -> void:
	avatar_customisation = null

	var node: Node = self
	while node != null:
		if node.has_method("set_outfit") and node.has_method("set_hair") and node.has_method("set_shoes"):
			avatar_customisation = node
			break
		node = node.get_parent()

	if avatar_customisation == null:
		push_warning("GenderSelectionUI: could not find AvatarCustomisation in parents.")
		return

	print("FOUND AVATAR NODE: ", avatar_customisation.name)

func _apply_default_preset_for_gender(gender_text: String) -> void:
	var preset: Dictionary = DEFAULT_PRESETS.get(gender_text, {})
	if preset.is_empty():
		push_warning("GenderSelectionUI: no preset found for gender '%s'" % gender_text)
		return

	_apply_outfit_by_id(str(preset.get("outfit", "")))
	_apply_hair_by_id(str(preset.get("hair", "")))
	_apply_shoes_by_id(str(preset.get("shoes", "")))

func _apply_random_avatar_parts_for_gender(gender_text: String) -> void:
	var random_outfit_id: String = _pick_random_asset_id(outfit_items, gender_text)
	var random_hair_id: String = _pick_random_asset_id(hair_items, gender_text)
	var random_shoes_id: String = _pick_random_asset_id(shoes_items, gender_text)

	if random_outfit_id.is_empty() or random_hair_id.is_empty() or random_shoes_id.is_empty():
		push_warning("GenderSelectionUI: random selection failed, falling back to default preset.")
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
		return

	avatar_customisation.set_outfit(outfit_id)

func _apply_hair_by_id(hair_id: String) -> void:
	if hair_id.is_empty():
		return

	if avatar_customisation == null:
		_resolve_avatar_customisation()

	if avatar_customisation == null:
		return

	avatar_customisation.set_hair(hair_id)

func _apply_shoes_by_id(shoes_id: String) -> void:
	if shoes_id.is_empty():
		return

	if avatar_customisation == null:
		_resolve_avatar_customisation()

	if avatar_customisation == null:
		return

	avatar_customisation.set_shoes(shoes_id)

func _load_asset_items(json_path: String) -> Array:
	var items: Array = []

	if json_path.is_empty():
		return items

	if not FileAccess.file_exists(json_path):
		push_warning("GenderSelectionUI: JSON not found at %s" % json_path)
		return items

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("GenderSelectionUI: failed to open JSON at %s" % json_path)
		return items

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("GenderSelectionUI: failed to parse JSON at %s" % json_path)
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

	return items

func _pick_random_asset_id(source_items: Array, gender_text: String) -> String:
	if source_items.is_empty():
		return ""

	var filtered_items: Array = _filter_items_by_gender(source_items, gender_text)

	if filtered_items.is_empty():
		filtered_items = source_items

	var picked = filtered_items[randi() % filtered_items.size()]
	return _extract_item_id(picked)

func _filter_items_by_gender(source_items: Array, gender_text: String) -> Array:
	var results: Array = []

	for item in source_items:
		if item is Dictionary:
			var item_gender: String = str(item.get("gender", "")).strip_edges().to_lower()
			var item_id: String = str(item.get("id", "")).strip_edges().to_lower()
			var item_name: String = str(item.get("name", "")).strip_edges().to_lower()

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
