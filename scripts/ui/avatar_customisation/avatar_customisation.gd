extends Node3D

@onready var avatar: Node = $AvatarTest/Armature/Skeleton3D
@onready var option_tabs = $AvatarCustomisationViewports/OptionTabs/Viewport/OptionTabs
@onready var customise_options = $AvatarCustomisationViewports/CustomiseOptions/Viewport/CustomiseOptions
@onready var save_avatar = $AvatarCustomisationViewports/SaveAvatar

var current_tab: String
var _current_hair: Node = null

enum Options {BODYTYPE, SKIN, OUTFIT, HAIR, FACE}

func _ready():
	if option_tabs:
		option_tabs.tab_selected.connect(_on_tab_selected)
	else:
		push_warning("OptionTabs scene instance not found as child of viewport.")

	if customise_options:
		customise_options.option_selected.connect(_on_option_selected)
	else:
		push_warning("CustomiseOptions scene instance not found as child of viewport.")

func _on_tab_selected(tab_index: int) -> void:
	if customise_options:
		var tab_container = customise_options.get_node("TabContainer")
		tab_container.current_tab = tab_index
		current_tab = tab_container.get_child(tab_index).name

func _on_option_selected(option_name: String) -> void:
	if current_tab == "BodyType":
		AvatarState.body_type = option_name
	elif current_tab == "Skin":
		AvatarState.skin_tone = option_name
	elif current_tab == "Outfit":
		AvatarState.outfit = option_name
	elif current_tab == "Hair":
		print("Applying new hair: " + option_name)
		_apply_new_hair(option_name)
		AvatarState.hair_style = option_name
	elif current_tab == "Face":
		AvatarState.face_type = option_name

func _apply_new_hair(hair_name: String) -> void:
	var curr_hair_node: Node = null
	var curr_hair = AvatarState.hair_style
	
	# Find the current hair node by name
	for mesh in avatar.get_children():
		if mesh.name.to_lower().contains(curr_hair.to_lower()):
			curr_hair_node = mesh
			break
	
	var new_hair_node: PackedScene = null
	var new_hair_nodepath: NodePath = _find_res(hair_name, Options.HAIR)
	
	if !new_hair_nodepath.is_empty():
		new_hair_node = load(new_hair_nodepath)
	else:
		print("No valid path found for new hair: " + hair_name)
		return
	
	# If the current hair node is found and valid, remove it
	if curr_hair_node != null and is_instance_valid(curr_hair_node):
		avatar.remove_child(curr_hair_node)
		curr_hair_node.queue_free()  # Ensure it's properly freed
	
	# If the new hair node is valid, instantiate and add it
	if new_hair_node != null:
		var new_hair_instance = new_hair_node.instantiate()
		avatar.add_child(new_hair_instance)
		AvatarState.hair_style = hair_name  # Update the AvatarState
	else:
		print("Selected option does not have a valid mesh for: " + hair_name)
	
func _find_res(res_key: String, option_type: Options) -> NodePath:
	# TODO: use json to store the resources for each option
	res_key = res_key.to_lower()
	if res_key == "bob":
		return "res://assets/hair/Hair_bob.tscn"
	elif res_key == "long":
		return "res://assets/hair/Hair_long.tscn"
	return ""
