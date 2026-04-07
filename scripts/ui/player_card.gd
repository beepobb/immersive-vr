extends Panel

const STATUS_READY_COLOR := Color(0.38431373, 1.0, 0.24705882, 1.0)
const STATUS_ALERT_COLOR := Color(0.95, 0.25, 0.25, 1.0)
const STATUS_DEFAULT_COLOR := Color(1, 1, 1, 1)

@export var name_label: Label
@export var role_label: Label
@export var status_label: Label

func prepare_card(player_name: String, role: String, status: bool) -> void:
	name_label.text = player_name
	role_label.text = role
	set_status(status)

func set_status(status: bool):
	if status:
		status_label.text = "Ready"
		status_label.add_theme_color_override("font_color", STATUS_READY_COLOR)
	else:
		status_label.text = "Not Ready"
		status_label.add_theme_color_override("font_color", STATUS_ALERT_COLOR)
