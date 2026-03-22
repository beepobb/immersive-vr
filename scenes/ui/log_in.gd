extends Control

@onready var patient_btn: Button = $PanelContainer/HBoxContainer/MarginContainer/LeftSide/RoleButtons/Patient
@onready var therapist_btn: Button = $PanelContainer/HBoxContainer/MarginContainer/LeftSide/RoleButtons/Therapist
@onready var username_edit: LineEdit = $PanelContainer/HBoxContainer/MarginContainer/LeftSide/Username_input
@onready var password_edit: LineEdit = $PanelContainer/HBoxContainer/MarginContainer/LeftSide/Password_input
@onready var login_btn: Button = $PanelContainer/HBoxContainer/MarginContainer/LeftSide/LogIn
@onready var error_label: Label = $ErrorLabel  

var selected_role: String = ""  # "patient" or "therapist"

func _ready() -> void:
	# Connect signals (or connect via Inspector)
	patient_btn.pressed.connect(func(): _select_role("patient"))
	therapist_btn.pressed.connect(func(): _select_role("therapist"))
	login_btn.pressed.connect(_on_login_pressed)

	# Update login availability when typing
	username_edit.text_changed.connect(func(_t): _update_login_state())
	password_edit.text_changed.connect(func(_t): _update_login_state())

	_update_role_ui()
	_update_login_state()
	if error_label:
		error_label.text = ""

func _select_role(role: String) -> void:
	selected_role = role
	_update_role_ui()
	_update_login_state()
	if error_label:
		error_label.text = ""

func _update_role_ui() -> void:
	# Simple visual: disable the selected one (makes it look “active”)
	# Alternative: change theme overrides (see section 4 below)
	patient_btn.disabled = (selected_role == "patient")
	therapist_btn.disabled = (selected_role == "therapist")

func _update_login_state() -> void:
	var ok := selected_role != "" and username_edit.text.strip_edges() != "" and password_edit.text.strip_edges() != ""
	login_btn.disabled = not ok

func _on_login_pressed() -> void:
	var username := username_edit.text.strip_edges()
	var password := password_edit.text.strip_edges()

	if selected_role == "":
		_show_error("Please choose a role.")
		return
	if username == "" or password == "":
		_show_error("Please enter username and password.")
		return

	# TODO: Replace this with real auth later.
	# For now, route based on role:
	if selected_role == "patient":
		get_tree().change_scene_to_file("res://scenes/ui/landing_page/JoinRoom.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/landing_page/JoinRoom.tscn")

func _show_error(msg: String) -> void:
	if error_label:
		error_label.text = msg
	else:
		push_warning(msg)
