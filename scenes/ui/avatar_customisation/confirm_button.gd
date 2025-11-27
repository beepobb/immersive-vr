extends Button

func _on_pressed() -> void:
	var parent_ui = get_parent().get_parent().get_parent().get_parent()
	print("Current parent UI node: ", parent_ui.name)
	parent_ui.queue_free()
	var new_ui_scene = load("res://scenes/ui/render_ui.tscn").instantiate()
	new_ui_scene.get_child(0).scene = load("res://scenes/ui/select_environment.tscn")
	new_ui_scene.position = Vector3(0.0, 2.0, -1.5)
	get_tree().root.add_child(new_ui_scene)
