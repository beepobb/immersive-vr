extends PanelContainer

@onready var customise_avatar_button: Button = $MarginContainer/HBoxContainer/MarginContainer/CustomiseAvatarButton
@onready var change_environment_button: Button = $MarginContainer/HBoxContainer/MarginContainer2/ChangeEnvironmentButton

func _ready() -> void:
	change_environment_button.visible = Roles.user_role == Roles.Role.THERAPIST

func _on_change_environment_button_pressed() -> void:
	GameState.load_scene(self , GameState.SELECT_ENVIRONMENT_SCENE_PATH)

func _on_customise_avatar_button_pressed() -> void:
	GameState.load_scene(self , GameState.AVATAR_CUSTOMISATION_SCENE_PATH)
