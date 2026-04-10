extends Button

func _on_pressed() -> void:
	var avatar_customisation := _find_avatar_customisation_parent()
	if avatar_customisation != null and avatar_customisation.has_method("save_current_customisations"):
		avatar_customisation.save_current_customisations()
	else:
		push_warning("ConfirmButton: AvatarCustomisation not found, using current GameState values.")

	GameState.return_to_lobby("Avatar saved.")

func _find_avatar_customisation_parent() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("save_current_customisations"):
			return current
		current = current.get_parent()
	return null
