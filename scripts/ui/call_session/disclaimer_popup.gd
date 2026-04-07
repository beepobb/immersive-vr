extends Control

signal accepted
signal declined

@onready var accept_btn = $PanelContainer/VBoxContainer/HBoxContainer/AcceptButton

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	accept_btn.pressed.connect(_on_accept)

	_connect_button_fx(accept_btn)

func _on_accept() -> void:
	emit_signal("accepted")


func _connect_button_fx(button: Button) -> void:
	button.mouse_entered.connect(func(): _animate_button(button, Vector2(1.03, 1.03)))
	button.mouse_exited.connect(func(): _animate_button(button, Vector2.ONE))
	button.button_down.connect(func(): _animate_button(button, Vector2(0.97, 0.97)))
	button.button_up.connect(func(): _animate_button(button, Vector2(1.03, 1.03)))


func _animate_button(button: Control, target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", target_scale, 0.12)
