extends Control

const DEFAULT_PRESETS := {
	"male": {
		"outfit": "male_elegantsuit_01",
		"hair": "culturalibre_hair_05",
		"shoes": "punkduck_running_shoes"
	},
	"female": {
		"outfit": "female_elegantsuit",
		"hair": "human_elvs_short_side_do_2",
		"shoes": "dressupdoc_maryjane"
	}
}

const HOVER_SCALE := 1.06
const NORMAL_SCALE := 1.0
const TWEEN_DURATION := 0.12

@export var outfit_json_path: String = "res://assets/outfit/outfit_assets.json"
@export var hair_json_path: String = "res://assets/hair/hair_assets.json"
@export var shoes_json_path: String = "res://assets/shoes/shoes_assets.json"

@onready var male_btn: Button = $CenterContainer/VBoxContainer/Male
@onready var female_btn: Button = $CenterContainer/VBoxContainer/Female
@onready var random_btn: Button = $CenterContainer/VBoxContainer/Random

var avatar_customisation: Node = null

var outfit_items: Array = []
var hair_items: Array = []
var shoes_items: Array = []

var selected_gender: String = "female"

func _ready() -> void:
	UIButtonAudio.setup_buttons(self) 
	randomize()

	_resolve_avatar_customisation()

	outfit_items = _load_asset_items(outfit_json_path)
	hair_items = _load_asset_items(hair_json_path)
	shoes_items = _load_asset_items(shoes_json_path)

	_connect_button_signals()
	_connect_hover_effects()

	call_deferred("_apply_startup_default")

func _connect_button_signals() -> void:
	if male_btn and not male_btn.pressed.is_connected(_on_male_pressed):
		male_btn.pressed.connect(_on_male_pressed)

	if female_btn and not female_btn.pressed.is_connected(_on_female_pressed):
		female_btn.pressed.connect(_on_female_pressed)

	if random_btn and not random_btn.pressed.is_connected(_on_random_pressed):
		random_btn.pressed.connect(_on_random_pressed)

func _connect_hover_effects() -> void:
	_connect_hover_for_button(male_btn)
	_connect_hover_for_button(female_btn)
	_connect_hover_for_button(random_btn)

func _connect_hover_for_button(btn: Button) -> void:
	if btn == null:
		return

	if not btn.mouse_entered.is_connected(func(): _on_button_mouse_entered(btn)):
		btn.mouse_entered.connect(func(): _on_button_mouse_entered(btn))

	if not btn.mouse_exited.is_connected(func(): _on_button_mouse_exited(btn)):
		btn.mouse_exited.connect(func(): _on_button_mouse_exited(btn))

func _on_button_mouse_entered(btn: Button) -> void:
	_animate_button_scale(btn, HOVER_SCALE)

func _on_button_mouse_exited(btn: Button) -> void:
	_animate_button_scale(btn, NORMAL_SCALE)

func _animate_button_scale(btn: Button, target_scale: float) -> void:
	if btn == null:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(target_scale, target_scale), TWEEN_DURATION)

func _apply_startup_default() -> void:
	selected_gender = "female"
	_apply_default_preset_for_gender(selected_gender)
	_update_button_states(selected_gender)

func _on_male_pressed() -> void:
	selected_gender = "male"
	print("Male selected")
	_apply_default_preset_for_gender(selected_gender)
	_update_button_states(selected_gender)

func _on_female_pressed() -> void:
	selected_gender = "female"
	print("Female selected")
	_apply_default_preset_for_gender(selected_gender)
	_update_button_states(selected_gender)

func _on_random_pressed() -> void:
	var genders: Array[String] = ["male", "female"]
	selected_gender = genders[randi() % genders.size()]
	print("Random selected: ", selected_gender)
	_apply_random_avatar_parts_for_gender(selected_gender)
	_update_button_states(selected_gender)

func _resolve_avatar_customisation() -> void:
	avatar_customisation = null

	var node: Node = self
	while node != null:
		if node.has_method("set_outfit") and node.has_method("set_hair") and node.has_method("set_shoes"):
			avatar_customisation = node
			break
		node = node.get_parent()

	if avatar_customisation == null:
		push_warning("male_female.gd: could not find AvatarCustomisation in parents.")
		return

	print("FOUND AVATAR NODE: ", avatar_customisation.name)

func _apply_default_preset_for_gender(gender_text: String) -> void:
	var preset: Dictionary = DEFAULT_PRESETS.get(gender_text, {})
	if preset.is_empty():
		push_warning("No preset found for gender '%s'" % gender_text)
		return

	_apply_outfit_by_id(str(preset.get("outfit", "")))
	_apply_hair_by_id(str(preset.get("hair", "")))
	_apply_shoes_by_id(str(preset.get("shoes", "")))

func _apply_random_avatar_parts_for_gender(gender_text: String) -> void:
	var random_outfit_id: String = _pick_random_asset_id(outfit_items, gender_text)
	var random_hair_id: String = _pick_random_asset_id(hair_items, gender_text)
	var random_shoes_id: String = _pick_random_asset_id(shoes_items, gender_text)

	if random_outfit_id.is_empty() or random_hair_id.is_empty() or random_shoes_id.is_empty():
		push_warning("Random selection failed. Falling back to default preset.")
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

func _update_button_states(selected: String) -> void:
	# Only affect Male & Female
	for btn in [male_btn, female_btn]:
		if btn:
			btn.modulate = Color(1, 1, 1, 0.65)

	match selected:
		"male":
			if male_btn:
				male_btn.modulate = Color(1, 1, 1, 1)
		"female":
			if female_btn:
				female_btn.modulate = Color(1, 1, 1, 1)

	# Ensure Random is always normal (no tint)
	if random_btn:
		random_btn.modulate = Color(1, 1, 1, 1)

func _load_asset_items(json_path: String) -> Array:
	var items: Array = []

	if json_path.is_empty():
		return items

	if not FileAccess.file_exists(json_path):
		push_warning("JSON not found at %s" % json_path)
		return items

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open JSON at %s" % json_path)
		return items

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("Failed to parse JSON at %s" % json_path)
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
