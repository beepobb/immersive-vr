extends Control

signal accepted
signal declined

@onready var accept_btn = $PanelContainer/VBoxContainer/HBoxContainer/AcceptButton
@onready var leave_btn = $PanelContainer/VBoxContainer/HBoxContainer/LeaveButton

func _ready():
	accept_btn.pressed.connect(_on_accept)
	leave_btn.pressed.connect(_on_leave)

func _on_accept():
	emit_signal("accepted")

func _on_leave():
	emit_signal("declined")
