extends Node3D

@onready var avatarRoot: Node = $AvatarTest/Human_rig/Skeleton3D
@onready var avatar: Skeleton3D = $AvatarTest/Human_rig/Skeleton3D
@onready var option_tabs = $AvatarCustomisationViewports/OptionTabs/Viewport/OptionTabs
@onready var customise_options = $AvatarCustomisationViewports/CustomiseOptions/Viewport/CustomiseOptions
@onready var save_avatar = $AvatarCustomisationViewports/SaveAvatar
@export var default_outfit_id: String = ""

var current_tab: String
var appearance_service := AvatarAppearanceService.new()

var current_skin_tone: String = AvatarState.skin_tone

var _current_hair: Node = null
var current_hair_id: String = AvatarState.hair_style

@export var body_mesh_path: NodePath = NodePath("Human")

var _current_outfit: Node = null
var current_outfit_id: String = AvatarState.outfit

var _current_shoes: Node = null
var current_shoe_id: String = AvatarState.shoes

enum Options {SKIN, OUTFIT, HAIR, SHOES}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

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
	AvatarState.avatar = avatarRoot
	AvatarState.apply_to_avatar()

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


#func _ready():
	
	#_load_hair_manifest()

	#if option_tabs:
	#	option_tabs.tab_selected.connect(_on_tab_selected)

	#if customise_options:
	#	customise_options.option_selected.connect(_on_option_selected)


	if not HighLevelNetworkHandler.session_ended.is_connected(_on_session_ended):
		HighLevelNetworkHandler.session_ended.connect(_on_session_ended)

func _on_tab_selected(tab_index: int) -> void:
	if customise_options:
		var tab_container = customise_options.get_node("TabContainer")
		tab_container.current_tab = tab_index
		current_tab = tab_container.get_child(tab_index).name
# ---------- SET SKIN ----------- #
func _apply_new_skin_color(color: Color) -> void:
	var body_mesh := avatar.get_node_or_null(body_mesh_path) as MeshInstance3D
	appearance_service.apply_skin_color(body_mesh, color)
	current_skin_tone = color.to_html()

func _apply_and_set_new_hair(hair_id: String) -> void:
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
	if not is_instance_valid(_current_outfit):
		_current_outfit = null
	var key := outfit_id.to_lower()
	_current_outfit = appearance_service.replace_part(
		avatar,
		_current_outfit,
		key,
		AvatarAppearanceService.PartType.OUTFIT
	)
	print("Outfit set applied:", key)

	current_outfit_id = outfit_id
	if not is_instance_valid(_current_shoes):
		_current_shoes = null
	
func _apply_and_set_new_shoes(shoes_id: String) -> void:
	_current_shoes = appearance_service.replace_part(
		avatar,
		_current_shoes,
		shoes_id,
		AvatarAppearanceService.PartType.SHOES
	)
	current_shoe_id = shoes_id

func save_current_customisations() -> void:
	AvatarState.update_customisations(current_hair_id, current_outfit_id, current_shoe_id, current_skin_tone)

func _on_option_selected(option_value) -> void:
	if current_tab == "Skin":
		if option_value is Color:
			_apply_new_skin_color(option_value)
		else:
			push_warning("Skin option was not a Color: " + str(option_value))

	elif current_tab == "Outfit":
		var outfit_id := String(option_value).to_lower()
		print("Applying outfit:", outfit_id)
		_apply_and_set_new_outfit(outfit_id)

	elif current_tab == "Hair":
		var hair_id := String(option_value)
		print("Applying new hair: " + hair_id)
		_apply_and_set_new_hair(hair_id)
	
	elif current_tab == "Shoes":
		var shoes_id := String(option_value)
		print("Applying new shoes: " + shoes_id)
		_apply_and_set_new_shoes(shoes_id)

func _on_session_ended(message: String) -> void:
	AvatarState.return_to_home(self , message)

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
