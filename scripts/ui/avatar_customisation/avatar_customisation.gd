extends Node3D

@onready var avatar: Node = $AvatarTest/Armature/Skeleton3D
#@onready var option_tabs = $AvatarCustomisationViewports/OptionTabs/Viewport/OptionTabs
#@onready var customise_options = $AvatarCustomisationViewports/CustomiseOptions/Viewport/CustomiseOptions
#@onready var save_avatar = $AvatarCustomisationViewports/SaveAvatar
var option_tabs: Node = null #remove
var customise_options: Node = null #remove
var save_avatar: Node = null  # remove

var current_tab: String

var _current_hair: Node = null
const HAIR_JSON_PATH := "res://Assets/Hair/hair_assets.json"
var hair_map: Dictionary = {}   # hair_id -> scene path

var skin_tex_map: Dictionary = {}  # skin_id -> texture path
const SKIN_JSON_PATH := "res://Assets/Skin/skin_assets.json"
@export var body_mesh_path: NodePath = NodePath("Human") 

enum Options {BODYTYPE, SKIN, OUTFIT, HAIR, FACE}

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

	_load_hair_manifest()
	_load_skin_manifest()

	option_tabs.tab_selected.connect(_on_tab_selected)
	customise_options.option_selected.connect(_on_option_selected)

	# Set current_tab immediately (avoid empty current_tab)
	var tab_container = customise_options.get_node("TabContainer")
	current_tab = tab_container.get_child(tab_container.current_tab).name

#func _ready():
	
	#_load_hair_manifest()

	#if option_tabs:
	#	option_tabs.tab_selected.connect(_on_tab_selected)

	#if customise_options:
	#	customise_options.option_selected.connect(_on_option_selected)


func _on_tab_selected(tab_index: int) -> void:
	if customise_options:
		var tab_container = customise_options.get_node("TabContainer")
		tab_container.current_tab = tab_index
		current_tab = tab_container.get_child(tab_index).name
# ---------- Load Hair ----------- #
func _load_hair_manifest() -> void:
	var f := FileAccess.open(HAIR_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open hair JSON: " + HAIR_JSON_PATH)
		return

	var data = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or !data.has("items"):
		push_error("hair_assets.json format invalid (expected { items: [...] }).")
		return

	hair_map.clear()
	for item in data["items"]:
		if typeof(item) == TYPE_DICTIONARY and item.has("id") and item.has("scene"):
			hair_map[String(item["id"]).to_lower()] = String(item["scene"])

	print("Hair map loaded:", hair_map.size())
# ---------- Load Skin ----------- #
func _load_skin_manifest() -> void:
	var f := FileAccess.open(SKIN_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open skin JSON: " + SKIN_JSON_PATH)
		return

	var data = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or !data.has("items"):
		push_error("skin_assets.json format invalid (expected { items: [...] }).")
		return

	skin_tex_map.clear()
	for item in data["items"]:
		if typeof(item) == TYPE_DICTIONARY and item.has("id") and item.has("texture"):
			skin_tex_map[String(item["id"]).to_lower()] = String(item["texture"])

	print("Skin texture map loaded:", skin_tex_map.size())
	
func set_skin_color(color: Color) -> void:
	var body_mesh := avatar.get_node_or_null(body_mesh_path) as MeshInstance3D
	if body_mesh == null:
		return

	var mat := body_mesh.get_active_material(0)
	var new_mat: StandardMaterial3D

	if mat is StandardMaterial3D:
		new_mat = mat.duplicate()
	else:
		new_mat = StandardMaterial3D.new()

	new_mat.albedo_color = color
	body_mesh.set_surface_override_material(0, new_mat)
	
 # ----------- Apply Skin ---------- #
func _apply_skin_texture(skin_id: String) -> void:
	var key := skin_id.to_lower()
	var tex_path := String(skin_tex_map.get(key, ""))
	if tex_path == "":
		push_warning("No texture found for skin id: " + skin_id)
		return

	var tex := load(tex_path) as Texture2D
	if tex == null:
		push_warning("Failed to load skin texture: " + tex_path)
		return

	var body_mesh := avatar.get_node_or_null(body_mesh_path) as MeshInstance3D
	if body_mesh == null:
		push_error("Body mesh not found. Set 'body_mesh_path' in Inspector.")
		return

	var mat := body_mesh.get_active_material(0)
	var new_mat: StandardMaterial3D = (mat.duplicate() as StandardMaterial3D) if mat is StandardMaterial3D else StandardMaterial3D.new()

	new_mat.albedo_texture = tex
	body_mesh.set_surface_override_material(0, new_mat)
	
func _on_option_selected(option_value) -> void:
	if current_tab == "BodyType":
		AvatarState.body_type = String(option_value)

	elif current_tab == "Skin":
		if option_value is Color:
			set_skin_color(option_value)
		else:
			# if something still sends a string by accident
			push_warning("Skin option was not a Color: " + str(option_value))

	elif current_tab == "Outfit":
		AvatarState.outfit = String(option_value)

	elif current_tab == "Hair":
		var hair_id := String(option_value)
		print("Applying new hair: " + hair_id)
		_apply_new_hair(hair_id)
		AvatarState.hair_style = hair_id

	elif current_tab == "Face":
		AvatarState.face_type = String(option_value)
	
 # ----------- Apply Hair ---------- #
func _apply_new_hair(hair_id: String) -> void:
	var scene_path := _find_res(hair_id, Options.HAIR)
	if scene_path == "":
		push_warning("No scene found for hair id: " + hair_id)
		return

	var ps: PackedScene = load(scene_path)
	if ps == null:
		push_warning("Failed to load hair scene: " + scene_path)
		return

	if _current_hair != null and is_instance_valid(_current_hair):
		_current_hair.queue_free()
		_current_hair = null

	_current_hair = ps.instantiate()
	avatar.add_child(_current_hair)

	AvatarState.hair_style = hair_id
	
	
func _find_res(res_key: String, option_type: Options) -> String:
	res_key = res_key.to_lower()

	if option_type == Options.HAIR and hair_map.has(res_key):
		return hair_map[res_key]

	return ""
