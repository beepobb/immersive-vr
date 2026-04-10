extends Node3D

var avatarRoot: Node = null
var avatar: Skeleton3D = null
#@onready var avatarRoot: Node = $AvatarTest/Human_rig/Skeleton3D
#@onready var avatar: Skeleton3D = $AvatarTest/Human_rig/Skeleton3D
@onready var option_tabs = $AvatarCustomisationViewports/OptionTabs/Viewport/OptionTabs
@onready var customise_options = $AvatarCustomisationViewports/CustomiseOptions/Viewport/CustomiseOptions
@onready var save_avatar = $AvatarCustomisationViewports/SaveAvatar
@export var avatar_test_path: NodePath = NodePath("AvatarTest")
@export var default_outfit_id: String = ""

var avatar_test: Node3D = null
var current_avatar_supports_customisation: bool = true
var current_avatar_id: String = "default"

var current_tab: String
var appearance_service := AvatarAppearanceService.new()

var current_skin_tone: String = GameState.skin_tone

var _current_hair: Node = null
var current_hair_id: String = GameState.hair_style

@export var body_mesh_path: NodePath = NodePath("Human")

var _current_outfit: Node = null
var current_outfit_id: String = GameState.outfit

var _current_shoes: Node = null
var current_shoe_id: String = GameState.shoes

enum Options {SKIN, OUTFIT, HAIR, SHOES}

@onready var back_button: Button = $AvatarCustomisationViewports/Header/Viewport/AvatarCustomisationHeader/HBoxContainer/BackButton

func _ready():
	UIButtonAudio.setup_buttons(self )
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	back_button.connect("pressed", _on_back_button_pressed)
	# Desktop overlay first (DebugUI) - remove
	option_tabs = get_node_or_null("../DebugUI/Root/OptionTabs")
	customise_options = get_node_or_null("../DebugUI/Root/CustomiseOptions")
	
	# XR fallback
	if option_tabs == null:
		option_tabs = get_node_or_null("AvatarCustomisationViewports/OptionTabs/Viewport/OptionTabs")
	if customise_options == null:
		customise_options = get_node_or_null("AvatarCustomisationViewports/CustomiseOptions/Viewport/CustomiseOptions")

	if option_tabs == null or customise_options == null:
		push_error("UI nodes not found. Ensure DebugUI has OptionTabs+CustomiseOptions OR XR viewports are present.")
		return

	appearance_service.load_manifests()
	_refresh_avatar_references()
	GameState.apply_to_avatar()

	# set up signals
	option_tabs.tab_selected.connect(_on_tab_selected)
	customise_options.option_selected.connect(_on_option_selected)

	# Set current_tab immediately (avoid empty current_tab)
	var tab_container = customise_options.get_node("TabContainer")
	current_tab = tab_container.get_child(tab_container.current_tab).name

	var parts: Array = appearance_service.get_current_parts(avatarRoot)
	_current_hair = parts[0]
	_current_outfit = parts[1]
	_current_shoes = parts[2]

func _on_tab_selected(tab_index: int) -> void:
	if customise_options:
		var tab_container = customise_options.get_node("TabContainer")
		tab_container.current_tab = tab_index
		current_tab = tab_container.get_child(tab_index).name

func _is_fixed_demo_avatar(avatar_id: String) -> bool:
	return avatar_id.to_lower() in ["bernard", "megan"]

func set_demo_avatar(avatar_scene_path: String, avatar_id: String = "") -> void:
	if avatar_scene_path == "":
		push_warning("Empty avatar scene path.")
		return

	if not ResourceLoader.exists(avatar_scene_path):
		push_error("Avatar scene does not exist: " + avatar_scene_path)
		return

	var old_avatar: Node3D = get_node_or_null(avatar_test_path) as Node3D
	if old_avatar == null:
		push_error("AvatarTest node not found for replacement.")
		return

	var parent: Node = old_avatar.get_parent()
	if parent == null:
		push_error("AvatarTest has no parent.")
		return

	var old_transform: Transform3D = old_avatar.transform
	var old_name: String = old_avatar.name

	old_avatar.queue_free()
	await get_tree().process_frame

	var new_avatar_scene := load(avatar_scene_path) as PackedScene
	if new_avatar_scene == null:
		push_error("Failed to load avatar scene: " + avatar_scene_path)
		return

	var new_avatar: Node3D = new_avatar_scene.instantiate() as Node3D
	if new_avatar == null:
		push_error("Failed to instantiate avatar scene: " + avatar_scene_path)
		return

	new_avatar.name = old_name
	parent.add_child(new_avatar)
	new_avatar.transform = old_transform

	current_avatar_id = avatar_id.to_lower()
	current_avatar_supports_customisation = not _is_fixed_demo_avatar(current_avatar_id)
	
	GameState.update_selected_avatar(current_avatar_id, avatar_scene_path)
	
	_refresh_avatar_references()
	_update_customisation_ui_state()

	print("Avatar replaced with: ", current_avatar_id)
	
func _update_customisation_ui_state() -> void:
	if customise_options == null:
		return

	var tab_container: TabContainer = customise_options.get_node_or_null("TabContainer")
	if tab_container == null:
		return

	var hair_tab = tab_container.get_node_or_null("Hair")
	var outfit_tab = tab_container.get_node_or_null("Outfit")
	var shoes_tab = tab_container.get_node_or_null("Shoes")

	if hair_tab:
		hair_tab.visible = current_avatar_supports_customisation
	if outfit_tab:
		outfit_tab.visible = current_avatar_supports_customisation
	if shoes_tab:
		shoes_tab.visible = current_avatar_supports_customisation

	# If user was on one of those tabs, force them back to Demo
	if not current_avatar_supports_customisation:
		for i in range(tab_container.get_child_count()):
			if tab_container.get_child(i).name == "Demo":
				tab_container.current_tab = i
				current_tab = "Demo"
				break
				
func _refresh_avatar_references() -> void:
	avatar_test = get_node_or_null(avatar_test_path) as Node3D
	if avatar_test == null:
		push_error("AvatarTest node not found.")
		return

	avatarRoot = avatar_test.get_node_or_null("Human_rig/Skeleton3D")
	avatar = avatarRoot as Skeleton3D

	if avatarRoot == null or avatar == null:
		push_error("Could not find Human_rig/Skeleton3D in current avatar.")
		return

	GameState.avatar = avatarRoot

	var parts: Array = appearance_service.get_current_parts(avatarRoot)
	_current_hair = parts[0]
	_current_outfit = parts[1]
	_current_shoes = parts[2]
	
# ---------- SET SKIN ----------- #
func _apply_new_skin_color(color: Color) -> void:
	var body_mesh := avatar.get_node_or_null(body_mesh_path) as MeshInstance3D
	appearance_service.apply_skin_color(body_mesh, color)
	current_skin_tone = color.to_html()
	print("Skin: " + current_skin_tone)

func _apply_and_set_new_hair(hair_id: String) -> void:
	if not current_avatar_supports_customisation:
		print("Hair customisation disabled for avatar: ", current_avatar_id)
		return

	if not is_instance_valid(_current_hair):
		_current_hair = null

	_current_hair = appearance_service.replace_part(
		avatar,
		_current_hair,
		hair_id,
		AvatarAppearanceService.PartType.HAIR
	)

	current_hair_id = hair_id

func _apply_and_set_new_outfit(outfit_id: String) -> void:
	if not current_avatar_supports_customisation:
		print("Outfit customisation disabled for avatar: ", current_avatar_id)
		return

	if not is_instance_valid(_current_outfit):
		_current_outfit = null

	var key := outfit_id.to_lower()
	_current_outfit = appearance_service.replace_part(
		avatar,
		_current_outfit,
		key,
		AvatarAppearanceService.PartType.OUTFIT
	)

	current_outfit_id = outfit_id

	if not is_instance_valid(_current_shoes):
		_current_shoes = null
	
func _apply_and_set_new_shoes(shoes_id: String) -> void:
	if not current_avatar_supports_customisation:
		print("Shoes customisation disabled for avatar: ", current_avatar_id)
		return

	_current_shoes = appearance_service.replace_part(
		avatar,
		_current_shoes,
		shoes_id,
		AvatarAppearanceService.PartType.SHOES
	)

	current_shoe_id = shoes_id

func save_current_customisations() -> void:
	GameState.update_customisations(current_hair_id, current_outfit_id, current_shoe_id, current_skin_tone)

func _on_option_selected(option_value) -> void:
	print("Current tab = ", current_tab, " | option = ", option_value)

	if current_tab == "Demo":
		var avatar_id := String(option_value).to_lower()

		if avatar_id == "megan":
			set_demo_avatar("res://assets/Avatar/avatar w face bs/megan.tscn", "megan")
		elif avatar_id == "bernard":
			set_demo_avatar("res://assets/Avatar/avatar w face bs/bernard.tscn", "bernard")

	elif current_tab == "Skin":
		if option_value is Color:
			_apply_new_skin_color(option_value)
		else:
			push_warning("Skin option was not a Color: " + str(option_value))

	elif current_tab == "Outfit":
		if not current_avatar_supports_customisation:
			return
		var outfit_id := String(option_value).to_lower()
		_apply_and_set_new_outfit(outfit_id)

	elif current_tab == "Hair":
		if not current_avatar_supports_customisation:
			return
		var hair_id := String(option_value)
		_apply_and_set_new_hair(hair_id)

	elif current_tab == "Shoes":
		if not current_avatar_supports_customisation:
			return
		var shoes_id := String(option_value)
		_apply_and_set_new_shoes(shoes_id)

func _on_session_ended(message: String) -> void:
	GameState.return_to_home(message)

func apply_and_set_id(type: Options, id: String) -> void:
	match type:
		Options.HAIR:
			_apply_and_set_new_hair(id)
			current_hair_id = id
		Options.SHOES:
			_apply_and_set_new_shoes(id)
			current_shoe_id = id
		Options.OUTFIT:
			_apply_and_set_new_outfit(id)
			current_outfit_id = id

func _on_back_button_pressed() -> void:
	GameState.return_to_lobby()
