extends PanelContainer

@onready var customise_avatar_button: Button = %CustomiseAvatarButton
@onready var change_environment_button: Button = %ChangeEnvironmentButton

func _ready() -> void:
	customise_avatar_button.pressed.connect(_on_customise_avatar_pressed)
	change_environment_button.pressed.connect(_on_change_environment_pressed)
	change_environment_button.visible = Roles.user_role == Roles.Role.THERAPIST

func _on_customise_avatar_pressed() -> void:
	AvatarState.load_scene(self , AvatarState.AVATAR_CUSTOMISATION_SCENE_PATH)

func _on_change_environment_pressed() -> void:
	if Roles.user_role != Roles.Role.THERAPIST:
		return

	AvatarState.load_scene(self , AvatarState.SELECT_ENVIRONMENT_SCENE_PATH)
