extends PanelContainer

@onready var time_label: Label = $MarginContainer/HBoxContainer/HBoxContainer/TimeLabel
@onready var date_label: Label = $MarginContainer/HBoxContainer/DateLabel
var session_start_unix: int = 0

func _ready() -> void:
	session_start_unix = int(Time.get_unix_time_from_system())

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
