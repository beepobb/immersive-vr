extends Control

signal prev_pressed
signal next_pressed

@onready var prev_button: Button = $BottomNavBar/PrevButton
@onready var next_button: Button = $BottomNavBar/NextButton
@onready var indicator_row: HBoxContainer = $BottomNavBar/MarginContainer/IndicatorRow

func _ready() -> void:
	UIButtonAudio.setup_buttons(self) 
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
