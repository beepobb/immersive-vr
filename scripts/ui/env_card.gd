extends Button

@onready var env_title_label: Label = $InfoOverlay/MarginContainer/VBoxContainer/NameLabel
@onready var env_description_label: Label = $InfoOverlay/MarginContainer/VBoxContainer/DescLabel
@onready var env_photo_texture: TextureRect = $TextureRect
@onready var info_overlay: Control = $InfoOverlay
@onready var blue_overlay: ColorRect = $BlueOverlay

@export var env_title: String
@export var env_description: String
@export var env_photo: Texture2D

var is_selected_card: bool = false
var base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	base_scale = scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_content()

	blue_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blue_overlay.offset_left = 0
	blue_overlay.offset_top = 0
	blue_overlay.offset_right = 0
	blue_overlay.offset_bottom = 0
	blue_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blue_overlay.visible = false
	blue_overlay.color = Color(0.0, 0.478, 1.0, 0.541)

func _update_content() -> void:
	env_title_label.text = env_title
	env_description_label.text = env_description
	env_photo_texture.texture = env_photo

func set_data(title: String, description: String, photo: Texture2D) -> void:
	env_title = title
	env_description = description
	env_photo = photo
	_update_content()

func set_selected_visual(selected: bool) -> void:
	is_selected_card = selected

	if is_selected_card:
		blue_overlay.visible = true
		blue_overlay.color = Color(0.0, 0.48, 1.0, 0.35)
	else:
		blue_overlay.visible = false
		blue_overlay.color = Color(0.0, 0.48, 1.0, 0.0)

func set_center_style(is_center: bool) -> void:
	env_description_label.visible = is_center

	if is_center:
		info_overlay.modulate = Color(1, 1, 1, 1.0)
	else:
		info_overlay.modulate = Color(1, 1, 1, 0.9)

func set_hover_enabled(enabled: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	
	# Clear hover state when disabling interaction
	if not enabled:
		# Release focus to clear any hover styling
		release_focus()
		# Ensure button returns to normal state
		update_minimum_size()


func _on_mouse_entered() -> void:
	pass


func _on_mouse_exited() -> void:
	# Explicitly release focus to clear hover state
	release_focus()
