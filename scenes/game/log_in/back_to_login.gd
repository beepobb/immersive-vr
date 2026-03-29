extends Button

@onready var quit_dialog = get_tree().current_scene.get_node("PanelContainer/QuitDialog")


func _pressed():
	quit_dialog.popup_centered()
