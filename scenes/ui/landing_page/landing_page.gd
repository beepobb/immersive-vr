extends Control

@onready var quit_dialog = $"PanelContainer/QuitDialog"

func _ready():
	quit_dialog.confirmed.connect(_on_quit_confirmed)
	quit_dialog.get_ok_button().text = "Yes"
	quit_dialog.get_cancel_button().text = "No"

func _on_quit_confirmed():
	get_tree().change_scene_to_file("res://scenes/ui/log_in.tscn")
	# or get_tree().quit()
