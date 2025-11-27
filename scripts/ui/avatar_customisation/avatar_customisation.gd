extends Node3D

@onready var avatar: Node = $AvatarTest/Armature/Skeleton3D
@onready var option_tabs = $AvatarCustomisationViewports/OptionTabs/Viewport/OptionTabs
@onready var customise_options = $AvatarCustomisationViewports/CustomiseOptions/Viewport/CustomiseOptions
var current_tab: String
var _current_hair: Node = null

func _ready():
	if option_tabs:
		# connect using Callable so the signal calls the handler correctly
		option_tabs.tab_selected.connect(Callable(self, "_on_tab_selected"))
	else:
		push_warning("OptionTabs scene instance not found as child of viewport.")

	if customise_options:
		customise_options.option_selected.connect(Callable(self, "_on_option_selected"))
	else:
		push_warning("CustomiseOptions scene instance not found as child of viewport.")


func _on_tab_selected(tab_index: int) -> void:
	print("hello")
	if customise_options:
		var tab_container = customise_options.get_node("TabContainer")
		tab_container.current_tab = tab_index
		current_tab = tab_container.get_child(tab_index).name
	print("Tab selected: " + current_tab)

func _on_option_selected(option_name: String) -> void:
	if current_tab == "BodyType":
		AvatarState.body_type = option_name
	elif current_tab == "Skin":
		AvatarState.skin_tone = option_name
	elif current_tab == "Outfit":
		AvatarState.outfit = option_name
	elif current_tab == "Hair":
		print("Applying new hair: " + option_name)
		AvatarState.hair_style = option_name
		_apply_new_hair(option_name)
	elif current_tab == "Face":
		AvatarState.face_type = option_name
		
func _apply_new_hair(hair_name: String) -> void:
	# Remove previous hair instance if present
	if _current_hair and is_instance_valid(_current_hair):
		_current_hair.queue_free()
		_current_hair = null

	# Prepare candidate paths where hair scenes might live. Adjust these to match your project.
	var key = hair_name.strip_edges().to_lower().replace(" ", "_")
	var candidates := [
		"res://scenes/avatar_customisation/hair_%s.tscn".format(key),
		"res://scenes/avatar_customisation/hair/%s.tscn".format(key),
		"res://scenes/avatar/hair_%s.tscn".format(key),
		"res://scenes/avatar/hair/%s.tscn".format(key),
		"res://assets/Avatar/Hair/%s.tscn".format(hair_name),
	]

	var found_scene: PackedScene = null
	for path in candidates:
		var res = ResourceLoader.load(path)
		if res and typeof(res) == TYPE_OBJECT and res is PackedScene:
			found_scene = res
			break

	if not found_scene:
		var tried_paths := ""
		for path in candidates:
			tried_paths += path + ", "
		if tried_paths.length() > 2:
			tried_paths = tried_paths.substr(0, tried_paths.length() - 2)
		push_warning("Could not find hair scene for '%s'. Tried: %s" % [hair_name, tried_paths])
		return

	var inst = found_scene.instantiate()
	if not inst:
		push_warning("Failed to instance hair scene for '%s'.".format(hair_name))
		return

	inst.name = "Hair_%s".format(key)
	avatar.add_child(inst)
	_current_hair = inst
