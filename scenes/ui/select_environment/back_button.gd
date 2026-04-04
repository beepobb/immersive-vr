extends Button

func _ready() -> void:
	pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	var main = get_node_or_null("/root/Main")
	if main == null:
		push_error("BackButton: Could not find /root/Main")
		return

	var env_root = main.get_node_or_null("EnvironmentRoot")
	if env_root == null:
		push_error("BackButton: Could not find EnvironmentRoot")
		return

	var avatar_customisation = main.get_node_or_null("AvatarCustomisation")
	if avatar_customisation:
		avatar_customisation.show()

	for child in env_root.get_children():
		child.queue_free()

	var select_environment_root = get_node_or_null("/root/Main/SelectEnvironmentRoot")
	if select_environment_root:
		select_environment_root.queue_free()
