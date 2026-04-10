extends Control

const AVATAR_CUSTOMISATION_SCRIPT = preload("res://scripts/ui/avatar_customisation/avatar_customisation.gd")

const HOVER_SCALE := 1.06
const NORMAL_SCALE := 1.0
const TWEEN_DURATION := 0.12

@export var randomise_avatar_parts: bool = true

@onready var male_btn: Button = $CenterContainer/VBoxContainer/Male
@onready var female_btn: Button = $CenterContainer/VBoxContainer/Female
@onready var random_btn: Button = $CenterContainer/VBoxContainer/Random
var appearance_service := AvatarAppearanceService.new()


var selected_gender: String = "female"

enum Gender {
	MALE,
	FEMALE
}

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	randomize() # check what this does

	_connect_button_signals()
	_connect_hover_effects()

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

func _on_male_pressed() -> void:
	selected_gender = "male"
	GameState.gender = selected_gender
	_apply_default_parts_for_selected_gender()
	_update_button_states(selected_gender)

func _on_female_pressed() -> void:
	selected_gender = "female"
	GameState.gender = selected_gender
	_apply_default_parts_for_selected_gender()
	_update_button_states(selected_gender)

func _on_random_pressed() -> void:
	var genders: Array[String] = ["male", "female"]
	selected_gender = genders[randi() % genders.size()]
	if randomise_avatar_parts:
		_apply_random_avatar_parts_for_selected_gender()
	_update_button_states(selected_gender)

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

func _apply_default_parts_for_selected_gender() -> void:
	var default_ids: Dictionary = GameState.get_gender_default_presets(GameState.gender)
	var avatar_customisation = find_parent("AvatarCustomisationBase")
	if avatar_customisation == null:
		return
	avatar_customisation.apply_and_set_id(AVATAR_CUSTOMISATION_SCRIPT.Options.OUTFIT, default_ids.get("outfit"))
	avatar_customisation.apply_and_set_id(AVATAR_CUSTOMISATION_SCRIPT.Options.HAIR, default_ids.get("hair"))
	avatar_customisation.apply_and_set_id(AVATAR_CUSTOMISATION_SCRIPT.Options.SHOES, default_ids.get("shoes"))

func _apply_random_avatar_parts_for_selected_gender() -> void:
	var gender_text = GameState.gender
	print(gender_text)
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

func _get_selected_option_text(option_button: OptionButton) -> String:
	if option_button == null or option_button.item_count == 0:
		return ""

	var index := option_button.get_selected()
	if index < 0:
		return ""

	return option_button.get_item_text(index)
