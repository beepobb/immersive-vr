extends Control

@onready var tab_container: TabContainer = $TabContainer
@onready var skin_picker := $TabContainer/Skin/MarginContainer/VBoxContainer/SkinColorPicker

signal option_selected(option) # or Variant
const OUTFIT_JSON_PATH := "res://Assets/Outfit/outfit_assets.json"
var _outfit_built := false

const HAIR_JSON_PATH := "res://Assets/Hair/hair_assets.json"
var _connected_buttons: Array[BaseButton] = []
var _hair_built := false

func _ready() -> void:
	tab_container.tab_changed.connect(_on_tab_changed)
	_refresh_current_tab()
	skin_picker.color_changed.connect(_on_skin_color_changed)

func _on_skin_color_changed(color: Color) -> void:
	emit_signal("option_selected", color)
	
func _on_tab_changed(_tab_idx: int) -> void:
	_refresh_current_tab()

func _refresh_current_tab() -> void:
	var tab := tab_container.get_current_tab_control()
	if tab == null:
		return

	if tab.name == "Hair" and !_hair_built:
		_build_buttons_from_json(tab, HAIR_JSON_PATH)
		_hair_built = true

	if tab.name == "Outfit" and !_outfit_built:
		_build_buttons_from_json(tab, OUTFIT_JSON_PATH)
		_outfit_built = true

	if tab.name == "Skin":
		_build_skin_palette(tab)  # build every time (simple + safe)

	_update_buttons()
	
func _build_skin_palette(tab: Control) -> void:
	var grid := tab.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/GridContainer")
	if grid == null:
		push_error("Skin GridContainer not found.")
		return

	for c in grid.get_children():
		c.queue_free()

	grid.columns = 3

	var skin_palette := SkinPalette.colors()

	for col in skin_palette:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 70)
		btn.size_flags_horizontal = 0
		btn.size_flags_vertical = 0
		btn.set_meta("value", col)

		btn.add_theme_stylebox_override("normal", _make_rect_stylebox(col))
		grid.add_child(btn)

func _make_rect_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	return sb

func _build_buttons_from_json(tab: Control, json_path: String) -> void:
	var grid := tab.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/GridContainer")
	if grid == null:
		push_error("GridContainer not found in tab: " + tab.name)
		return

	for c in grid.get_children():
		c.queue_free()

	var items := _load_items(json_path)
	if items.is_empty():
		push_warning("No items loaded from JSON: " + json_path)
		return

	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var id := String(item.get("id", "")).to_lower()
		if id == "":
			continue

		var thumb_path := String(item.get("thumb", ""))

		var box := VBoxContainer.new()
		var btn := TextureButton.new()

		# Hair tab sizing only (Skin handled separately in _build_skin_palette)
		grid.columns = 3   # increase to 4 if you want smaller tiles

		box.custom_minimum_size = Vector2(150, 150)
		btn.custom_minimum_size = Vector2(150, 150)

		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE

		btn.size_flags_horizontal = 0
		btn.size_flags_vertical = 0
		box.size_flags_horizontal = 0
		box.size_flags_vertical = 0

		btn.name = id
		btn.set_meta("id", id)

		if thumb_path != "" and ResourceLoader.exists(thumb_path):
			btn.texture_normal = load(thumb_path)

		box.add_child(btn)
		grid.add_child(box)
	
	

func _load_items(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open JSON: " + path)
		return []

	var data = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or !data.has("items"):
		push_error("JSON format invalid (expected { items: [...] }): " + path)
		return []

	return data["items"]

func _update_buttons() -> void:
	# Disconnect previously connected buttons
	for btn in _connected_buttons:
		if btn.pressed.is_connected(_on_option_pressed):
			btn.pressed.disconnect(_on_option_pressed)
	_connected_buttons.clear()

	var current_tab := tab_container.get_current_tab_control()
	if current_tab == null:
		return

	var grid := current_tab.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/GridContainer")
	if grid == null:
		return

	var buttons: Array = []
	_collect_buttons_recursive(grid, buttons)

	for btn in buttons:
		var option_value = btn.get_meta("value", btn.get_meta("id", btn.name))
		btn.pressed.connect(_on_option_pressed.bind(option_value))
		_connected_buttons.append(btn)

func _collect_buttons_recursive(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is BaseButton:
			out.append(child)
		else:
			_collect_buttons_recursive(child, out)

func _on_option_pressed(option_value) -> void:
	print("Option selected: ", option_value)
	emit_signal("option_selected", option_value)
