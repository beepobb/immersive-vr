extends Control

signal prev_pressed
signal next_pressed

@onready var prev_button: Button = $BottomNavBar/PrevButton
@onready var next_button: Button = $BottomNavBar/NextButton
@onready var indicator_row: HBoxContainer = $BottomNavBar/MarginContainer/IndicatorRow

func _ready() -> void:
	_setup_existing_indicators()

	if not prev_button.pressed.is_connected(_on_prev_pressed):
		prev_button.pressed.connect(_on_prev_pressed)

	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)


func _on_prev_pressed() -> void:
	print("Prev button pressed")
	prev_pressed.emit()


func _on_next_pressed() -> void:
	print("Next button pressed")
	next_pressed.emit()


func _setup_existing_indicators() -> void:
	for child in indicator_row.get_children():
		if child is Panel:
			var panel := child as Panel
			var style := StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 0.18)
			style.corner_radius_top_left = 99
			style.corner_radius_top_right = 99
			style.corner_radius_bottom_left = 99
			style.corner_radius_bottom_right = 99
			panel.add_theme_stylebox_override("panel", style)


func set_active_index(current_index: int) -> void:
	for i in range(indicator_row.get_child_count()):
		var panel := indicator_row.get_child(i) as Panel
		if panel == null:
			continue

		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(1, 1, 1, 0.95) if i == current_index else Color(1, 1, 1, 0.18)
		flat.corner_radius_top_left = 99
		flat.corner_radius_top_right = 99
		flat.corner_radius_bottom_left = 99
		flat.corner_radius_bottom_right = 99
		panel.add_theme_stylebox_override("panel", flat)
