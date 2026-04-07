extends Control

@export var circular_hall_scene_path: String = "res://scenes/environment/circular_hall.tscn"

# Store session start time when the call begins
# You should set this from your multiplayer/session manager before opening this scene
var session_start_unix: int = 0

@onready var meeting_label: Label = $Panel/LeftContent/VBoxContainer/MeetingLabel
@onready var session_ended_label: Label = $Panel/LeftContent/VBoxContainer/SessionEndedLabel
@onready var date_label: Label = $Panel/LeftContent/VBoxContainer/DateLabel

@onready var duration_value: Label = $Panel/RightPanel/MarginContainer/VBoxContainer/SummaryMargin/VBoxContainer/Row1/DurationValue
@onready var participants_value: Label = $Panel/RightPanel/MarginContainer/VBoxContainer/SummaryMargin/VBoxContainer/Row3/ParticipantsValue

@onready var download_button: Button = $Panel/RightPanel/MarginContainer/VBoxContainer/Spacer/DownloadButton
@onready var exit_button: Button = $Panel/RightPanel/MarginContainer/VBoxContainer/Spacer/ExitButton

func _ready() -> void:
	UIButtonAudio.setup_buttons(self)
	# Example static text
	meeting_label.text = "Meeting #17"
	session_ended_label.text = "Session Ended"

	# 1. Show today's date
	date_label.text = _get_formatted_today()

	# 2. Show session duration
	duration_value.text = _get_session_duration_text()

	# 3. Show participant count
	participants_value.text = str(_get_participant_count())

	if not exit_button.pressed.is_connected(_on_exit_button_pressed):
		exit_button.pressed.connect(_on_exit_button_pressed)

	if not download_button.pressed.is_connected(_on_download_button_pressed):
		download_button.pressed.connect(_on_download_button_pressed)


func _get_formatted_today() -> String:
	var dt := Time.get_datetime_dict_from_system()
	var day: int = dt["day"]
	var month: int = dt["month"]
	var year: int = dt["year"]

	var month_names := [
		"", "January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]

	return "%d %s %d" % [day, month_names[month], year]


func _get_session_duration_text() -> String:
	# If session_start_unix was never set, fallback to 00:00:00
	if session_start_unix <= 0:
		return "00:00:00"

	var now_unix: int = Time.get_unix_time_from_system()
	var elapsed: int = max(0, now_unix - session_start_unix)

	var hours: int = elapsed / 3600
	var minutes: int = (elapsed % 3600) / 60
	var seconds: int = elapsed % 60

	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _get_participant_count() -> int:
	# For Godot multiplayer
	# Count all connected peers + host
	if multiplayer.has_multiplayer_peer():
		var peer_ids := multiplayer.get_peers()
		return peer_ids.size() + 1

	# Fallback for offline testing
	return 1


func _on_exit_button_pressed() -> void:
	get_tree().change_scene_to_file(circular_hall_scene_path)


func _on_download_button_pressed() -> void:
	print("Download transcript clicked")
