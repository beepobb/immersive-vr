extends PanelContainer

@export var customise_avatar_button: Button
@export var change_environment_button: Button

func _ready() -> void:
	change_environment_button.visible = Roles.user_role == Roles.Role.THERAPIST

func _on_change_environment_button_pressed() -> void:
	AvatarState.load_scene(self , AvatarState.SELECT_ENVIRONMENT_SCENE_PATH)

func _on_customise_avatar_button_pressed() -> void:
	AvatarState.load_scene(self , AvatarState.AVATAR_CUSTOMISATION_SCENE_PATH)
