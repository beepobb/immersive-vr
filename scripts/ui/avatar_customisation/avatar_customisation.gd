extends Node3D

@onready var avatar: Node = $AvatarTest/Human_rig/Skeleton3D
#@onready var option_tabs = $AvatarCustomisationViewports/OptionTabs/Viewport/OptionTabs
#@onready var customise_options = $AvatarCustomisationViewports/CustomiseOptions/Viewport/CustomiseOptions
#@onready var save_avatar = $AvatarCustomisationViewports/SaveAvatar
@export var default_outfit_id: String = ""
var option_tabs: Node = null #remove
var customise_options: Node = null #remove
var save_avatar: Node = null  # remove

var current_tab: String

const HAIR_JSON_PATH := "res://assets/hair/hair_assets.json"
var _current_hair: Node = null
var hair_map: Dictionary = {}   # hair_id -> scene path

@export var body_mesh_path: NodePath = NodePath("Human") 

const OUTFIT_JSON_PATH := "res://assets/outfit/outfit_assets.json"
var outfit_map: Dictionary = {}   # id -> scene path
var _current_outfit: Node = null

var _current_shoes: Node = null
const SHOES_JSON_PATH := "res://assets/shoes/shoes_assets.json"
var shoes_map: Dictionary = {}   # shoes_id -> scene path

enum Options {BODYTYPE, SKIN, OUTFIT, HAIR, SHOES}

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
	_load_outfit_manifest()
	_load_shoes_manifest()

	option_tabs.tab_selected.connect(_on_tab_selected)
	customise_options.option_selected.connect(_on_option_selected)
	for n in avatar.find_children("*", "MeshInstance3D", true, false):
		print(n.name)
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
	
# ---------- SET SKIN ----------- #
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
		var outfit_id := String(option_value).to_lower()
		print("Applying outfit:", outfit_id)
		_apply_outfit(outfit_id)
		AvatarState.outfit = outfit_id

	elif current_tab == "Hair":
		var hair_id := String(option_value)
		print("Applying new hair: " + hair_id)
		_apply_new_hair(hair_id)
		AvatarState.hair_style = hair_id
	
	elif current_tab == "Shoes":
		var shoes_id := String(option_value)
		print("Applying new shoes: " + shoes_id)
		_apply_new_shoes(shoes_id)
		AvatarState.shoes = shoes_id

	
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

func set_hair(hair_id: String) -> void:
	_apply_new_hair(hair_id)
	AvatarState.hair_style = hair_id
	
 # ----------- Load Outfit ---------- #
func _load_outfit_manifest() -> void:
	var f := FileAccess.open(OUTFIT_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open outfit JSON: " + OUTFIT_JSON_PATH)
		return

	var data = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or !data.has("items"):
		push_error("Outfit JSON format invalid (expected { items: [...] }).")
		return

	outfit_map.clear()

	for item in data["items"]:
		if typeof(item) == TYPE_DICTIONARY and item.has("id") and item.has("scene"):
			var id := String(item["id"]).to_lower()
			var scene_path := String(item["scene"])
			outfit_map[id] = scene_path

	print("Outfit sets loaded:", outfit_map.size())
	
 # ----------- Apply Outfit ---------- #
func _apply_outfit(outfit_id: String) -> void:
	var key := outfit_id.to_lower()
	var scene_path := String(outfit_map.get(key, ""))

	if scene_path == "":
		push_warning("Outfit id not found in map: " + key)
		return

	var ps := load(scene_path) as PackedScene
	if ps == null:
		push_warning("Failed to load outfit scene: " + scene_path)
		return

	var new_outfit := ps.instantiate()
	if new_outfit == null:
		push_warning("Failed to instantiate outfit scene: " + scene_path)
		return

	if _current_outfit != null and is_instance_valid(_current_outfit):
		_current_outfit.queue_free()
		_current_outfit = null

	_current_outfit = new_outfit
	avatar.add_child(_current_outfit)
	print("Outfit set applied:", key)
			
func set_outfit(outfit_id: String) -> void:
	_apply_outfit(outfit_id)
	AvatarState.outfit = outfit_id.to_lower()
	
# --------- LOAD SHOES ----------- #
func _load_shoes_manifest() -> void:
	var f := FileAccess.open(SHOES_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open shoes JSON: " + SHOES_JSON_PATH)
		return

	var data = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or !data.has("items"):
		push_error("shoes_assets.json format invalid (expected { items: [...] }).")
		return

	shoes_map.clear()
	for item in data["items"]:
		if typeof(item) == TYPE_DICTIONARY and item.has("id") and item.has("scene"):
			shoes_map[String(item["id"]).to_lower()] = String(item["scene"])

	print("Shoes map loaded:", shoes_map.size())
	
# ----------- APPLY SHOES -------------- #
func _apply_new_shoes(shoes_id: String) -> void:
	var scene_path := _find_res(shoes_id, Options.SHOES)
	if scene_path == "":
		push_warning("No scene found for shoes id: " + shoes_id)
		return

	var ps: PackedScene = load(scene_path)
	if ps == null:
		push_warning("Failed to load shoes scene: " + scene_path)
		return

	if _current_shoes != null and is_instance_valid(_current_shoes):
		_current_shoes.queue_free()
		_current_shoes = null

	_current_shoes = ps.instantiate()
	avatar.add_child(_current_shoes)
	AvatarState.shoes = shoes_id
	
func set_shoes(shoes_id: String) -> void:
	_apply_new_shoes(shoes_id)
	AvatarState.shoes = shoes_id.to_lower()

func _find_res(res_key: String, option_type: Options) -> String:
	res_key = res_key.to_lower()

	if option_type == Options.HAIR and hair_map.has(res_key):
		return hair_map[res_key]
	
	if option_type == Options.SHOES and shoes_map.has(res_key):
		return shoes_map[res_key]


	return ""
