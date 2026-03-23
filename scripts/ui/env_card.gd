extends Button

@onready var env_title_label: Label = $TextureRect/InfoOverlay/MarginContainer/VBoxContainer/NameLabel
@onready var env_description_label: Label = $TextureRect/InfoOverlay/MarginContainer/VBoxContainer/DescLabel
@onready var env_photo_texture: TextureRect = $TextureRect

var environment_id: String

func set_environment_data(environment_id: String, environment_name: String, description: String, thumbnail: Texture2D) -> void:
	self.environment_id = environment_id
	if not is_node_ready():
		await ready
	env_title_label.text = environment_name
	env_description_label.text = description
	env_photo_texture.texture = thumbnail
