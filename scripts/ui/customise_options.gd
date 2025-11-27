extends Control

@onready var tab_container = $TabContainer

signal option_selected(option: String)

var _connected_buttons: Array = []

func _ready() -> void:
	_update_buttons()
	tab_container.tab_changed.connect(Callable(self, "_on_tab_changed"))

func _on_tab_changed(_tab_idx: int) -> void:
	_update_buttons()

func _update_buttons() -> void:
	# Disconnect previously connected buttons
	for btn in _connected_buttons:
		if btn.pressed.is_connected(Callable(self, "_on_option_pressed")):
			btn.pressed.disconnect(Callable(self, "_on_option_pressed"))
	_connected_buttons.clear()

	var current_tab_options = _get_current_tab_options(tab_container.current_tab)
	for btn in current_tab_options:
		# bind the button name (string) so handlers receive a simple identifier
		btn.pressed.connect(Callable(self, "_on_option_pressed"), [btn.name])
		_connected_buttons.append(btn)

func _on_option_pressed(option_name: String) -> void:
	emit_signal("option_selected", option_name)

func _get_current_tab_options(current_tab_idx: int) -> Array:
	var current_tab_options: Array[Button] = []
	var current_tab = tab_container.get_child(current_tab_idx)
	var current_tab_option_grid = current_tab.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/GridContainer")
	for option in current_tab_option_grid.get_children():
		if option is Button:
			current_tab_options.append(option)
	return current_tab_options
