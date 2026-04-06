extends Button

@onready var customise_avatar_button: Button = self

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	customise_avatar_button.disabled = false
	customise_avatar_button.focus_mode = Control.FOCUS_NONE
	if not customise_avatar_button.mouse_exited.is_connected(_on_customise_mouse_exited):
		customise_avatar_button.mouse_exited.connect(_on_customise_mouse_exited)

func _on_pressed() -> void:
	UIButtonAudio.play_click()
	customise_avatar_button.disabled = true
	print("loading avatar_customisation scene")
	GameState.load_scene(GameState.AVATAR_CUSTOMISATION_SCENE_PATH)

func _on_customise_mouse_exited() -> void:
	customise_avatar_button.release_focus()
