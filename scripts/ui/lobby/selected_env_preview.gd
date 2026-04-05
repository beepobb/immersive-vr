extends PanelContainer

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")

@onready var environment_name_label: Label = %EnvironmentName
@onready var thumbnail_rect: TextureRect = %Thumbnail
@onready var description_label: RichTextLabel = %Description

func _ready() -> void:
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
	environment_name_label.text = "Environment: %s" % EnvironmentCatalog.get_environment_name(selected_environment_id)
	description_label.text = EnvironmentCatalog.get_environment_description(selected_environment_id)
	thumbnail_rect.texture = EnvironmentCatalog.get_environment_thumbnail(selected_environment_id)
