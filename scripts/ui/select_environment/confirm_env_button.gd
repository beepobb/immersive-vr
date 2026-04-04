extends Button

signal confirm_pressed

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	confirm_pressed.emit()
