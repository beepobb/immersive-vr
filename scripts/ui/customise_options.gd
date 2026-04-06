extends Control

@onready var tab_container: TabContainer = $TabContainer

signal option_selected(option) # or Variant
var _outfit_built := false

var _connected_buttons: Array[BaseButton] = []
var _hair_built := false

var _shoes_built := false
var appearance_service = AvatarAppearanceService.new()
var _selected_by_tab: Dictionary = {}
var _button_base_modulate: Dictionary = {}

func _ready() -> void:
	UIButtonAudio.setup_buttons(self )
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

		
		btn.set_meta("tab_name", tab.name)
		btn.focus_mode = Control.FOCUS_NONE

		btn.add_theme_stylebox_override("normal", _make_rect_stylebox(col, false))
		btn.add_theme_stylebox_override("hover", _make_rect_stylebox(col.lightened(0.08), false))
		btn.add_theme_stylebox_override("pressed", _make_rect_stylebox(col.darkened(0.08), true))
		btn.add_theme_stylebox_override("focus", _make_rect_stylebox(col, true))
		grid.add_child(btn)
		_connect_button_effects(btn, tab.name)

func _make_rect_stylebox(color: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8

	if selected:
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color("4da3ff")
	else:
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(1, 1, 1, 0.15)

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
		btn.set_meta("tab_name", tab.name)
		btn.focus_mode = Control.FOCUS_NONE


		if thumb_path != "" and ResourceLoader.exists(thumb_path):
			var tex = load(thumb_path)
			btn.texture_normal = tex
			btn.texture_hover = tex
			btn.texture_pressed = tex
			btn.texture_disabled = tex


		box.add_child(btn)
		grid.add_child(box)

		_connect_button_effects(btn, tab.name)
	
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
			
## ----- THeme

func _apply_glass_tabs(tab_control: Control) -> void:
	var unselected := StyleBoxFlat.new()
	unselected.bg_color = Color(0.05, 0.07, 0.10, 0.25)
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

	var selected := unselected.duplicate()
	selected.bg_color = Color(0.08, 0.10, 0.14, 0.38)
	selected.border_color = Color(1, 1, 1, 0.18)

	var hovered := unselected.duplicate()
	hovered.bg_color = Color(0.08, 0.10, 0.14, 0.32)

	tab_control.add_theme_stylebox_override("tab_unselected", unselected)
	tab_control.add_theme_stylebox_override("tab_selected", selected)
	tab_control.add_theme_stylebox_override("tab_hovered", hovered)

	tab_control.add_theme_color_override("font_unselected_color", Color(1, 1, 1, 0.70))
	tab_control.add_theme_color_override("font_selected_color", Color(1, 1, 1, 0.92))
	tab_control.add_theme_color_override("font_hovered_color", Color(1, 1, 1, 0.85))

func _connect_button_effects(btn: BaseButton, tab_name: String) -> void:
	if !btn.mouse_entered.is_connected(_on_button_hovered):
		btn.mouse_entered.connect(_on_button_hovered.bind(btn, tab_name))

	if !btn.mouse_exited.is_connected(_on_button_unhovered):
		btn.mouse_exited.connect(_on_button_unhovered.bind(btn, tab_name))

	if !btn.button_down.is_connected(_on_button_down):
		btn.button_down.connect(_on_button_down.bind(btn, tab_name))

	_button_base_modulate[btn] = btn.modulate

func _on_button_hovered(btn: BaseButton, tab_name: String) -> void:
	UIButtonAudio.play_hover()

	if _selected_by_tab.get(tab_name, null) == btn:
		return

	var tween = create_tween()
	tween.parallel().tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
	tween.parallel().tween_property(btn, "modulate", Color(1, 1, 1, 0.95), 0.12)

func _on_button_unhovered(btn: BaseButton, tab_name: String) -> void:
	if _selected_by_tab.get(tab_name, null) == btn:
		return

	var tween = create_tween()
	tween.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	tween.parallel().tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.12)


func _on_button_down(btn: BaseButton, _tab_name: String) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.06)


func _set_button_selected(btn: BaseButton, selected: bool) -> void:
	if btn is TextureButton:
		var tween = create_tween()
		if selected:
			tween.parallel().tween_property(btn, "scale", Vector2(1.03, 1.03), 0.12)
			tween.parallel().tween_property(btn, "modulate", Color(0.75, 0.88, 1.0, 1.0), 0.12)
		else:
			tween.parallel().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
			tween.parallel().tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.12)

	elif btn is Button:
		var value = btn.get_meta("value", Color.WHITE)
		if selected:
			btn.add_theme_stylebox_override("normal", _make_rect_stylebox(value, true))
			btn.scale = Vector2(1.03, 1.03)
		else:
			btn.add_theme_stylebox_override("normal", _make_rect_stylebox(value, false))
			btn.scale = Vector2(1.0, 1.0)

func _on_option_pressed(option_value) -> void:
	UIButtonAudio.play_click()

	var current_tab := tab_container.get_current_tab_control()
	if current_tab == null:
		return

	var tab_name := current_tab.name
	var grid := current_tab.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/GridContainer")
	if grid == null:
		return

	var buttons: Array = []
	_collect_buttons_recursive(grid, buttons)

	var clicked_btn: BaseButton = null
	for btn in buttons:
		var value = btn.get_meta("value", btn.get_meta("id", btn.name))
		if value == option_value:
			clicked_btn = btn
			break

	var previous = _selected_by_tab.get(tab_name, null)
	if previous != null and is_instance_valid(previous) and previous != clicked_btn:
		_set_button_selected(previous, false)

	if clicked_btn != null:
		_selected_by_tab[tab_name] = clicked_btn
		_set_button_selected(clicked_btn, true)

	print("Option selected: ", option_value)
	emit_signal("option_selected", option_value)
