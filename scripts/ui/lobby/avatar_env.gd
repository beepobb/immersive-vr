extends Button

@onready var customise_avatar_button: Button = self

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	customise_avatar_button.disabled = false

func _on_pressed() -> void:
	UIButtonAudio.play_click()
	customise_avatar_button.disabled = true
	print("loading avatar_customisation scene")
	GameState.load_scene(GameState.AVATAR_CUSTOMISATION_SCENE_PATH)
