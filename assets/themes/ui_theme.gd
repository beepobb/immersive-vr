extends RefCounted
class_name UITheme

static func apply_glass_theme(
	root: Control,
	corner_radius: int = 26,
	glass_alpha: float = 0.28,
	border_alpha: float = 0.35,
	input_alpha: float = 0.22,
	button_alpha: float = 0.25,
	text_color: Color = Color(0.95, 0.95, 0.98, 1.0),
	subtext_color: Color = Color(0.90, 0.90, 0.95, 0.75),
	accent_color: Color = Color(0.65, 0.80, 1.00, 1.0),
	panel_tint: Color = Color(1, 1, 1, 1)
) -> void:
	if root == null:
		return

	_apply_glass_panel(root, corner_radius, glass_alpha, border_alpha, panel_tint)
	_ensure_shadow_layer(root, corner_radius)
	_apply_labels(root, text_color, subtext_color)
	_apply_line_edits(root, input_alpha, accent_color, text_color, subtext_color)
	_apply_option_buttons(root, input_alpha, accent_color, text_color)
	_apply_buttons(root, button_alpha, text_color)

static func _apply_glass_panel(
	target: Control,
	corner_radius: int,
	glass_alpha: float,
	border_alpha: float,
	panel_tint: Color
) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(panel_tint.r, panel_tint.g, panel_tint.b, glass_alpha)
	sb.set_corner_radius_all(corner_radius)

	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, border_alpha)

	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18

	target.add_theme_stylebox_override("panel", sb)

static func _ensure_shadow_layer(root: Control, corner_radius: int) -> void:
	if root.has_node("__shadow"):
		return

	var shadow := Panel.new()
	shadow.name = "__shadow"
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.z_index = -10
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = -6
	shadow.offset_top = -8
	shadow.offset_right = 6
	shadow.offset_bottom = 10

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.20)
	sb.set_corner_radius_all(corner_radius + 2)
	shadow.add_theme_stylebox_override("panel", sb)

	root.add_child(shadow)
	root.move_child(shadow, 0)

static func _apply_labels(root: Control, text_color: Color, subtext_color: Color) -> void:
	for node in root.find_children("*", "Label", true, false):
		var lbl := node as Label
		if lbl == null:
			continue

		lbl.add_theme_color_override("font_color", text_color)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		lbl.add_theme_constant_override("shadow_offset_x", 0)
		lbl.add_theme_constant_override("shadow_offset_y", 1)

		if lbl.name.to_lower().contains("hint") or lbl.name.to_lower().contains("sub"):
			lbl.add_theme_color_override("font_color", subtext_color)

static func _apply_line_edits(
	root: Control,
	input_alpha: float,
	accent_color: Color,
	text_color: Color,
	subtext_color: Color
) -> void:
	for node in root.find_children("*", "LineEdit", true, false):
		var le := node as LineEdit
		if le == null:
			continue

		le.add_theme_stylebox_override("normal", _make_input_style(input_alpha, accent_color, false))
		le.add_theme_stylebox_override("focus", _make_input_style(input_alpha, accent_color, true))
		le.add_theme_stylebox_override("read_only", _make_input_style(input_alpha, accent_color, false))

		le.add_theme_color_override("font_color", text_color)
		le.add_theme_color_override("font_placeholder_color", subtext_color)
		le.caret_blink = true
		le.caret_blink_interval = 0.55

static func _apply_option_buttons(
	root: Control,
	input_alpha: float,
	accent_color: Color,
	text_color: Color
) -> void:
	for node in root.find_children("*", "OptionButton", true, false):
		var ob := node as OptionButton
		if ob == null:
			continue

		ob.add_theme_stylebox_override("normal", _make_input_style(input_alpha, accent_color, false))
		ob.add_theme_stylebox_override("hover", _make_input_style(input_alpha, accent_color, false))
		ob.add_theme_stylebox_override("pressed", _make_input_style(input_alpha, accent_color, true))
		ob.add_theme_stylebox_override("focus", _make_input_style(input_alpha, accent_color, true))
		ob.add_theme_color_override("font_color", text_color)

		var popup := ob.get_popup()
		if popup:
			popup.add_theme_stylebox_override("panel", _make_popup_style())

static func _apply_buttons(root: Control, button_alpha: float, text_color: Color) -> void:
	for node in root.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn == null:
			continue

		btn.add_theme_stylebox_override("normal", _make_button_style(button_alpha, false, false))
		btn.add_theme_stylebox_override("hover", _make_button_style(button_alpha, true, false))
		btn.add_theme_stylebox_override("pressed", _make_button_style(button_alpha, true, true))
		btn.add_theme_stylebox_override("focus", _make_button_style(button_alpha, true, false))

		btn.add_theme_color_override("font_color", text_color)
		btn.add_theme_color_override("font_focus_color", text_color)

static func _make_input_style(input_alpha: float, accent_color: Color, focused: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, input_alpha)
	sb.set_corner_radius_all(14)

	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10

	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1

	if focused:
		sb.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.85)
	else:
		sb.border_color = Color(1, 1, 1, 0.20)

	return sb

static func _make_popup_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.12, 0.92)
	sb.set_corner_radius_all(14)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func _make_button_style(button_alpha: float, hovered: bool, pressed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(16)

	var base := Color(1, 1, 1, button_alpha)
	if hovered:
		base.a = min(0.40, button_alpha + 0.10)
	if pressed:
		base.a = min(0.48, button_alpha + 0.18)

	sb.bg_color = base
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.22)

	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12

	return sb
