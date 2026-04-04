extends Control

@export var session_id: String = "Meeting #17"
@export var employee_id: String = "Unicorn123"

# Later, replace these with:
# session_label.text = SessionManager.current_session_id
# user_label.text = "Employee ID: %s" % PlayerData.employee_id

@onready var session_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/SessionLabel
@onready var user_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/UserLabel
@onready var time_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/TimeLabel
@onready var date_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer2/DateLabel

var session_start_unix: int = 0

func _ready() -> void:
	session_start_unix = int(Time.get_unix_time_from_system())

	session_label.text = session_id
	user_label.text = "Employee ID: %s" % employee_id

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
