extends Button

@onready var leave_button: Button = self

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	leave_button.disabled = false

func _on_pressed() -> void:
	UIButtonAudio.play_click()
	leave_button.disabled = true
	GameState.end_lobby_for_clients("Therapist ended the session")
