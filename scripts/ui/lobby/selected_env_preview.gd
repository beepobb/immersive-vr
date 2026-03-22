extends PanelContainer

const EnvironmentCatalog = preload("res://scripts/ui/environment_catalog.gd")

@onready var environment_name_label: Label = %EnvironmentName
@onready var thumbnail_rect: TextureRect = %Thumbnail
@onready var description_label: RichTextLabel = %Description

var lobby_manager_ref = null

func _ready() -> void:
	if not HighLevelNetworkHandler.session_ended.is_connected(_on_session_ended):
		HighLevelNetworkHandler.session_ended.connect(_on_session_ended)

	_try_connect_lobby_manager()
	_apply_environment(AvatarState.environment_id)
	set_process(lobby_manager_ref == null)

func _process(_delta: float) -> void:
	if lobby_manager_ref != null:
		set_process(false)
		return

	_try_connect_lobby_manager()

func _try_connect_lobby_manager() -> void:
	lobby_manager_ref = get_tree().get_first_node_in_group("lobby_manager")
	if lobby_manager_ref == null:
		return

	if not lobby_manager_ref.update_lobby_ui.is_connected(_on_lobby_state_updated):
		lobby_manager_ref.update_lobby_ui.connect(_on_lobby_state_updated)
	_on_lobby_state_updated(lobby_manager_ref.get_lobby_state())

func _on_lobby_state_updated(lobby_state: Dictionary) -> void:
	_apply_environment(String(lobby_state.get("selected_environment_id", "")))

func _apply_environment(environment_id: String) -> void:
	var selected_environment_id = environment_id
	if selected_environment_id.is_empty():
		selected_environment_id = AvatarState.environment_id
	if selected_environment_id.is_empty():
		selected_environment_id = EnvironmentCatalog.get_default_environment_id()

	AvatarState.environment_id = selected_environment_id
	environment_name_label.text = "Environment: %s" % EnvironmentCatalog.get_environment_name(selected_environment_id)
	description_label.text = EnvironmentCatalog.get_environment_description(selected_environment_id)
	thumbnail_rect.texture = EnvironmentCatalog.get_environment_thumbnail(selected_environment_id)

func _on_session_ended(_message: String) -> void:
	_apply_environment(EnvironmentCatalog.get_default_environment_id())
