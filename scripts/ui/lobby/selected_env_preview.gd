extends PanelContainer

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")

@onready var environment_name_label: Label = %EnvironmentName
@onready var thumbnail_rect: TextureRect = %Thumbnail
@onready var description_label: RichTextLabel = %Description
@onready var change_environment_button: Button = $MarginContainer/VBoxContainer/Button

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	change_environment_button.disabled = false
	change_environment_button.visible = Roles.user_role == Roles.Role.THERAPIST
	change_environment_button.connect("pressed", _on_change_environment_button_pressed)
	GameState.environment_updated.connect(update_env_preview)
	if multiplayer.is_server():
		update_env_preview(GameState.environment_id)
	else:
		GameState.request_environment.rpc_id(1)

func update_env_preview(environment_id: String) -> void:
	var selected_environment_id = environment_id
	if selected_environment_id.is_empty():
		selected_environment_id = GameState.environment_id
	if selected_environment_id.is_empty():
		selected_environment_id = EnvironmentCatalog.get_default_environment_id()

	GameState.environment_id = selected_environment_id
	environment_name_label.text = EnvironmentCatalog.get_environment_name(selected_environment_id)
	description_label.text = EnvironmentCatalog.get_environment_description(selected_environment_id)
	thumbnail_rect.texture = EnvironmentCatalog.get_environment_thumbnail(selected_environment_id)

func _on_change_environment_button_pressed() -> void:
	UIButtonAudio.play_click()
	change_environment_button.disabled = true
	print("hellos")
	GameState.load_scene(GameState.SELECT_ENVIRONMENT_SCENE_PATH)
