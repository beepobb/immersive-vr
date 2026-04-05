extends Control

signal prev_pressed
signal next_pressed

@onready var prev_button: Button = $BottomNavBar/PrevButton
@onready var next_button: Button = $BottomNavBar/NextButton
@onready var indicator_row: HBoxContainer = $BottomNavBar/MarginContainer/IndicatorRow

var indicators: Array[Panel] = []

var active_color: Color = Color("ffffffd2")
var inactive_color: Color = Color(0x4d4d51f4)

func _ready() -> void:
	UIButtonAudio.setup_buttons(self)

	if not prev_button.pressed.is_connected(_on_prev_pressed):
		prev_button.pressed.connect(_on_prev_pressed)

	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)

	_collect_indicators()
	set_active_index(0)

func _collect_indicators() -> void:
	indicators.clear()

	for child in indicator_row.get_children():
		if child is Panel:
			indicators.append(child)

func set_active_index(index: int) -> void:
	if indicators.is_empty():
		_collect_indicators()

	for i in range(indicators.size()):
		var bar := indicators[i]

		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6

		if i == index:
			sb.bg_color = active_color
		else:
			sb.bg_color = inactive_color

		bar.add_theme_stylebox_override("panel", sb)

func _on_prev_pressed() -> void:
	print("Prev button pressed")
	prev_pressed.emit()

func _on_next_pressed() -> void:
	print("Next button pressed")
	next_pressed.emit()
