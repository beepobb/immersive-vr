extends Control

@onready var username_edit: LineEdit = $VBoxContainer/MarginContainer2/VBoxContainer/Username
@onready var password_edit: LineEdit = $VBoxContainer/MarginContainer2/VBoxContainer/Password
@onready var login_btn: Button = $VBoxContainer/MarginContainer2/VBoxContainer/LogIn
var error_label

func _ready() -> void:
	login_btn.pressed.connect(_on_login_pressed)

	# Update login availability when typing
	username_edit.text_changed.connect(func(_t): _update_login_state())
	password_edit.text_changed.connect(func(_t): _update_login_state())

	_update_login_state()

func _update_login_state() -> void:
	var ok := username_edit.text.strip_edges() != "" and password_edit.text.strip_edges() != ""
	# TODO

func _on_login_pressed() -> void:
	var username := username_edit.text.strip_edges()
	var password := password_edit.text.strip_edges()

	if username == "" or password == "":
		push_error("Please enter username and password.")
		return

	get_tree().change_scene_to_file("res://scenes/ui/landing_page/JoinRoom.tscn")

func _show_error(msg: String) -> void:
	if error_label:
		error_label.text = msg
	else:
		push_warning(msg)
