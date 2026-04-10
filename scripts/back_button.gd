extends Button

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	GameState.return_to_lobby()
