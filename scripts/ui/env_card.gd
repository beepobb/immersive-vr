extends Button

@onready var env_title_label: Label = $TextureRect/InfoOverlay/MarginContainer/VBoxContainer/NameLabel
@onready var env_description_label: Label = $TextureRect/InfoOverlay/MarginContainer/VBoxContainer/DescLabel
@onready var env_photo_texture: TextureRect = $TextureRect

@export var env_title: String
@export var env_description: String
@export var env_photo: Texture2D

func _ready():
	env_title_label.text = env_title
	env_description_label.text = env_description
	env_photo_texture.texture = env_photo
