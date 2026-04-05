extends Node

var hover_sound: AudioStream = preload("res://tools/audio/ui_hover.ogg")
var click_sound: AudioStream = preload("res://tools/audio/ui_click.ogg")

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer

func _ready() -> void:
	hover_player = AudioStreamPlayer.new()
	hover_player.name = "HoverPlayer"
	add_child(hover_player)

	click_player = AudioStreamPlayer.new()
	click_player.name = "ClickPlayer"
	add_child(click_player)

	hover_player.bus = "Master"
	click_player.bus = "Master"

	if hover_sound:
		hover_player.stream = hover_sound
	if click_sound:
		click_player.stream = click_sound


func setup_buttons(root: Node) -> void:
	if root == null:
		return
	_connect_buttons_recursive(root)


func _connect_buttons_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			_connect_button(child)
		_connect_buttons_recursive(child)


func _connect_button(button: Button) -> void:
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover)

	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_button_hover() -> void:
	if hover_player and hover_player.stream:
		hover_player.play()


func _on_button_pressed() -> void:
	if click_player and click_player.stream:
		click_player.play()
