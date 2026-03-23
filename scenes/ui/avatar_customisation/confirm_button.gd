extends Button

func _on_pressed() -> void:
	AvatarState.return_to_lobby(self , "Avatar saved.")
