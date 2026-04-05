extends Button

signal confirm_pressed

func _ready() -> void:
	UIButtonAudio.setup_buttons(self) 
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	confirm_pressed.emit()
