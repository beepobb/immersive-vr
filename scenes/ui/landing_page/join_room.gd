extends Control

@onready var time_label: Label = $Panel/HBoxContainer/MarginContainer/Left/TimeLabel
@onready var date_label: Label = $Panel/HBoxContainer/MarginContainer/Left/DdmyLabel

var last_second := -1

func _process(_delta: float) -> void:
	var dt = Time.get_datetime_dict_from_system()
	if dt.second == last_second:
		return
	
	last_second = dt.second
	_update_datetime(dt)

func _update_datetime(dt: Dictionary) -> void:
	var hour := str(dt.hour).pad_zeros(2)
	var minute := str(dt.minute).pad_zeros(2)
	time_label.text = "%s.%s" % [hour, minute]

	var days := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	var months := [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]

	date_label.text = "%s, %d %s %d" % [
		days[dt.weekday],
		dt.day,
		months[dt.month - 1],
		dt.year
	]
