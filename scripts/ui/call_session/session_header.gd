extends Control

@export var session_id: String = "Session #17"
@export var number_of_people: int = 1

@onready var session_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/SessionLabel
@onready var people_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer2/People
@onready var time_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/TimeLabel
@onready var date_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer2/DateLabel

var session_start_unix: int = 0

func _ready() -> void:
	session_start_unix = int(Time.get_unix_time_from_system())

	session_label.text = "Session ID: %s" % session_id
	people_label.text = "No. of People: %d" % number_of_people

	var now := Time.get_datetime_dict_from_system()
	date_label.text = "Date: %02d %s %04d" % [
		now.day,
		_month_name(now.month),
		now.year
	]

	_update_elapsed_time()

func _process(_delta: float) -> void:
	_update_elapsed_time()

func _update_elapsed_time() -> void:
	var now := int(Time.get_unix_time_from_system())
	var elapsed := now - session_start_unix

	@warning_ignore("integer_division")
	var hours := int(elapsed / 3600)
	@warning_ignore("integer_division")
	var minutes := int((elapsed % 3600) / 60)
	var seconds := elapsed % 60

	time_label.text = "%02d:%02d:%02d" % [hours, minutes, seconds]

func _month_name(month: int) -> String:
	var months := [
		"", "January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]
	return months[month]
