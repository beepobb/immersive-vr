extends Node3D

@onready var header_viewport = $Header
@onready var carousel_viewport = $Carousel
@onready var indicator_bar_viewport = $IndicatorBar
@onready var confirm_button_viewport = $ConfirmButton

var header = null
var carousel = null
var indicator_bar = null
var confirm_button = null

var main: Node = null
var avatar_customisation: Node = null

var loaded_environment: Node = null
var disclaimer_popup: Node3D = null
var disclaimer_popup_scene := preload("res://scenes/ui/call_session/disclaimer_viewports.tscn")

func _ready() -> void:
	main = get_node_or_null("/root/Main")
	if main != null:
		avatar_customisation = main.get_node_or_null("AvatarCustomisation")
		if avatar_customisation:
			avatar_customisation.hide()

	header = _find_content_root(header_viewport, "EnvHeader")
	carousel = _find_content_root(carousel_viewport, "Carousel")
	indicator_bar = _find_content_root(indicator_bar_viewport, "indicator_bar")
	confirm_button = _find_content_root(confirm_button_viewport, "ConfirmButton")

	print("header = ", header)
	print("carousel = ", carousel)
	print("indicator_bar = ", indicator_bar)
	print("confirm_button = ", confirm_button)

	if carousel != null and carousel.has_signal("selection_changed"):
		if not carousel.selection_changed.is_connected(_on_selection_changed):
			carousel.selection_changed.connect(_on_selection_changed)

	if carousel != null and carousel.has_signal("center_card_activated"):
		if not carousel.center_card_activated.is_connected(_on_environment_confirmed):
			carousel.center_card_activated.connect(_on_environment_confirmed)

	if header != null and header.has_signal("back_pressed"):
		if not header.back_pressed.is_connected(_on_back_pressed):
			header.back_pressed.connect(_on_back_pressed)

	if confirm_button != null and confirm_button.has_signal("confirm_pressed"):
		if not confirm_button.confirm_pressed.is_connected(_on_confirm_pressed):
			confirm_button.confirm_pressed.connect(_on_confirm_pressed)

	if indicator_bar != null and indicator_bar.has_signal("prev_pressed"):
		if not indicator_bar.prev_pressed.is_connected(_on_prev_pressed):
			indicator_bar.prev_pressed.connect(_on_prev_pressed)

	if indicator_bar != null and indicator_bar.has_signal("next_pressed"):
		if not indicator_bar.next_pressed.is_connected(_on_next_pressed):
			indicator_bar.next_pressed.connect(_on_next_pressed)

	if carousel != null and carousel.has_method("get_current_index") and indicator_bar != null and indicator_bar.has_method("set_active_index"):
		indicator_bar.set_active_index(carousel.get_current_index())


func _find_content_root(viewport_wrapper: Node, expected_name: String) -> Node:
	if viewport_wrapper == null:
		push_error("Viewport wrapper is null for: " + expected_name)
		return null

	var found = viewport_wrapper.find_child(expected_name, true, false)
	if found == null:
		push_error("Could not find content root: " + expected_name)
	return found


func _on_prev_pressed() -> void:
	print("Root received prev_pressed")
	if carousel != null and carousel.has_method("go_prev"):
		carousel.go_prev()


func _on_next_pressed() -> void:
	print("Root received next_pressed")
	if carousel != null and carousel.has_method("go_next"):
		carousel.go_next()


func _on_selection_changed(index: int, env_data: Dictionary) -> void:
	if indicator_bar != null and indicator_bar.has_method("set_active_index"):
		indicator_bar.set_active_index(index)

	EnvironmentState.selected_environment_path = env_data.get("scene_path", "")
	print("Selected environment path: ", EnvironmentState.selected_environment_path)


func _on_confirm_pressed() -> void:
	if carousel != null and carousel.has_method("get_selected_environment"):
		var selected = carousel.get_selected_environment()
		if selected.is_empty():
			push_warning("No environment selected.")
			return

		EnvironmentState.selected_environment_path = selected.get("scene_path", "")
		_load_selected_environment()


func _on_environment_confirmed(env_data: Dictionary) -> void:
	EnvironmentState.selected_environment_path = env_data.get("scene_path", "")
	_load_selected_environment()


func _load_selected_environment() -> void:
	var env_path = EnvironmentState.selected_environment_path

	if env_path == "":
		push_warning("No environment path stored.")
		return

	print("Loading environment: ", env_path)

	var main_node = get_node_or_null("/root/Main")
	if main_node == null:
		push_error("Could not find /root/Main")
		return

	var env_root = main_node.get_node_or_null("EnvironmentRoot")
	if env_root == null:
		push_error("Could not find EnvironmentRoot")
		return

	for child in env_root.get_children():
		child.queue_free()

	var env_resource = load(env_path)
	if env_resource == null:
		push_error("Could not load environment: " + env_path)
		return

	var env_scene = env_resource.instantiate()
	env_root.add_child(env_scene)
	env_scene.position = Vector3.ZERO
	loaded_environment = env_scene

	hide()
	print("About to show disclaimer popup")
	_show_disclaimer_popup()

func _on_back_pressed() -> void:
	print("Back to avatar customisation")

	if avatar_customisation:
		avatar_customisation.show()

	queue_free()


func _show_disclaimer_popup() -> void:
	if disclaimer_popup_scene == null:
		push_error("Disclaimer viewport scene could not be loaded.")
		return

	if disclaimer_popup != null and is_instance_valid(disclaimer_popup):
		disclaimer_popup.queue_free()
		disclaimer_popup = null

	var popup = disclaimer_popup_scene.instantiate()

	var main_node = get_node_or_null("/root/Main")
	if main_node == null:
		push_error("Could not find /root/Main")
		return

	# Add directly under Main
	main_node.add_child(popup)
	disclaimer_popup = popup

	var cam = get_viewport().get_camera_3d()
	if cam == null:
		push_error("Could not find active Camera3D")
		return

	var forward = -cam.global_transform.basis.z.normalized()

	# Spawn in front of user
	popup.global_position = cam.global_position + (forward * 1.5) + Vector3(0, -0.05, 0)

	# Face the user
	popup.look_at(cam.global_position, Vector3.UP)
	popup.rotate_y(PI)

	# Optional: make sure it is visible enough
	popup.scale = Vector3.ONE

	print("Disclaimer popup spawned at: ", popup.global_position)

	if popup.has_signal("accepted"):
		if not popup.accepted.is_connected(_on_disclaimer_accepted):
			popup.accepted.connect(_on_disclaimer_accepted)

	if popup.has_signal("declined"):
		if not popup.declined.is_connected(_on_disclaimer_declined):
			popup.declined.connect(_on_disclaimer_declined)

func _on_disclaimer_accepted() -> void:
	print("Disclaimer accepted")

	if disclaimer_popup != null and is_instance_valid(disclaimer_popup):
		disclaimer_popup.queue_free()
		disclaimer_popup = null

	queue_free()


func _on_disclaimer_declined() -> void:
	print("Disclaimer declined")

	if disclaimer_popup != null and is_instance_valid(disclaimer_popup):
		disclaimer_popup.queue_free()
		disclaimer_popup = null

	if loaded_environment != null and is_instance_valid(loaded_environment):
		loaded_environment.queue_free()
		loaded_environment = null

	show()
