extends HBoxContainer

signal tab_selected(idx)

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
	for btn: Button in get_children():
		btn.pressed.connect(_on_btn_pressed.bind(btn))
		
	
func _on_btn_pressed(btn: Button) -> void:
	var idx := btn.get_index()
	emit_signal("tab_selected", idx)
