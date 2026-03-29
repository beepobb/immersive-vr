extends Control

@onready var tab_container: TabContainer = $TabContainer

signal option_selected(option) # or Variant
var _outfit_built := false

var _connected_buttons: Array[BaseButton] = []
var _hair_built := false

var _shoes_built := false
var appearance_service = AvatarAppearanceService.new()

func _ready() -> void:
	tab_container.tab_changed.connect(_on_tab_changed)
	appearance_service.load_manifests()
	_refresh_current_tab()
	_apply_glass_tabs(tab_container)

func _on_skin_color_changed(color: Color) -> void:
	emit_signal("option_selected", color)
	
func _on_tab_changed(_idx: int) -> void:
	call_deferred("_refresh_current_tab")

func _refresh_current_tab() -> void:
	var tab := tab_container.get_current_tab_control()
	if tab == null:
		return

	if tab.name == "Hair" and !_hair_built:
		_build_buttons_from_json(tab, appearance_service.hair_map)
		_hair_built = true

	if tab.name == "Outfit" and !_outfit_built:
		_build_buttons_from_json(tab, appearance_service.outfit_map)
		_outfit_built = true
		
	if tab.name == "Shoes" and !_shoes_built:
		_build_buttons_from_json(tab, appearance_service.shoes_map)
		_shoes_built = true

	if tab.name == "Skin":
		_build_skin_palette(tab) # build every time (simple + safe)

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

func _build_buttons_from_json(tab: Control, map: Array) -> void:
	var grid := tab.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/GridContainer")
	if grid == null:
		push_error("GridContainer not found in tab: " + tab.name)
		return

	for c in grid.get_children():
		c.queue_free()

	for item in map:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var id := String(item.get("id", "")).to_lower()
		if id == "":
			continue

		var thumb_path := String(item.get("thumb", ""))

		var box := VBoxContainer.new()
		var btn := TextureButton.new()

		# Hair tab sizing only (Skin handled separately in _build_skin_palette)
		grid.columns = 3 # increase to 4 if you want smaller tiles

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
	
func _update_buttons() -> void:
	# Disconnect previously connected buttons (SAFE)
	for btn in _connected_buttons:
		if !is_instance_valid(btn) or btn.is_queued_for_deletion():
			continue
		# Only disconnect if we previously connected it
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
			
func _clear_option_buttons(container: Node) -> void:
	for c in container.get_children():
		c.queue_free()

	_connected_buttons.clear() # IMPORTANT
## ----- THeme
func _apply_glass_tabs(tab_control: Control) -> void:
	# Unselected tab
	var unselected := StyleBoxFlat.new()
	unselected.bg_color = Color(0.05, 0.07, 0.10, 0.25) # translucent
	unselected.border_color = Color(1, 1, 1, 0.10)
	unselected.border_width_left = 1
	unselected.border_width_top = 1
	unselected.border_width_right = 1
	unselected.border_width_bottom = 1
	unselected.corner_radius_top_left = 14
	unselected.corner_radius_top_right = 14
	unselected.content_margin_left = 12
	unselected.content_margin_right = 12
	unselected.content_margin_top = 8
	unselected.content_margin_bottom = 8

	# Selected tab (slightly stronger)
	var selected := unselected.duplicate()
	selected.bg_color = Color(0.08, 0.10, 0.14, 0.38)
	selected.border_color = Color(1, 1, 1, 0.18)

	# Hover tab (optional)
	var hovered := unselected.duplicate()
	hovered.bg_color = Color(0.08, 0.10, 0.14, 0.32)

	# These keys work for TabBar in Godot 4.x.
	# If your node is TabContainer, still try these first; Godot will ignore unknown keys.
	tab_control.add_theme_stylebox_override("tab_unselected", unselected)
	tab_control.add_theme_stylebox_override("tab_selected", selected)
	tab_control.add_theme_stylebox_override("tab_hovered", hovered)

	# Optional: text colors
	tab_control.add_theme_color_override("font_unselected_color", Color(1, 1, 1, 0.70))
	tab_control.add_theme_color_override("font_selected_color", Color(1, 1, 1, 0.92))
	tab_control.add_theme_color_override("font_hovered_color", Color(1, 1, 1, 0.85))
	
func _on_option_pressed(option_value) -> void:
	print("Option selected: ", option_value)
	emit_signal("option_selected", option_value)
