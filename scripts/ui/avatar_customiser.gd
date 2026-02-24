extends Control

@onready var right_tabs: TabContainer = %RightTabs

@onready var body_tab:   Button = %BodyTab
@onready var skin_tab:   Button = %SkinTab
@onready var outfit_tab: Button = %OutfitTab
@onready var hair_tab:   Button = %HairTab
@onready var face_tab:   Button = %FaceTab

var bottom_tabs: Array[Button] = []
var main_preview: Node = null

#Hair Path
const HAIR_JSON_PATH := "res://Assets/Hair/hair_assets.json"
var hair_items: Array = []
@onready var hair_grid: GridContainer = %HairGrid

#Skin Path
const SKIN_JSON_PATH := "res://Assets/Skin/skin_assets.json"
var skin_items: Array = []
@onready var skin_grid: GridContainer = %SkinGrid


func _ready() -> void:
	main_preview = get_tree().current_scene

	bottom_tabs = [body_tab, skin_tab, outfit_tab, hair_tab, face_tab]

	body_tab.pressed.connect(   func(): _on_bottom_tab_pressed(1) )
	skin_tab.pressed.connect(   func(): _on_bottom_tab_pressed(2) )
	outfit_tab.pressed.connect( func(): _on_bottom_tab_pressed(3) )
	hair_tab.pressed.connect(   func(): _on_bottom_tab_pressed(0) )
	face_tab.pressed.connect(   func(): _on_bottom_tab_pressed(4) )
	#Load Hair Buttons
	_load_hair_items()
	_build_hair_buttons()
	
	#Load Skin Buttons
	_load_skin_items()
	_build_skin_buttons()

	_on_bottom_tab_pressed(1)
	print("Skin JSON exists:", ResourceLoader.exists(SKIN_JSON_PATH))
	print("SkinGrid:", skin_grid)
	print("Skin items:", skin_items.size())
	if skin_items.size() > 0:
		print("Skin first item has texture?:", skin_items[0].has("texture"), " keys=", skin_items[0].keys())


func _on_bottom_tab_pressed(target_index: int) -> void:
	right_tabs.current_tab = target_index

	for tab in bottom_tabs:
		tab.button_pressed = false

	match target_index:
		1: body_tab.button_pressed   = true
		2: skin_tab.button_pressed   = true
		3: outfit_tab.button_pressed = true
		0: hair_tab.button_pressed   = true
		4: face_tab.button_pressed   = true


# ------------ Hair -------------- #
func _load_hair_items() -> void: # Load hair json
	var f := FileAccess.open(HAIR_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open hair JSON: " + HAIR_JSON_PATH)
		return

	var data = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or !data.has("items"):
		push_error("hair_assets.json invalid. Expected { 'items': [ ... ] }")
		return

	hair_items = data["items"]

func _build_hair_buttons() -> void: # Build hair buttons
	if hair_grid == null:
		push_error("HairGrid not found. Add a GridContainer named HairGrid.")
		return

	# Clear old
	for c in hair_grid.get_children():
		c.queue_free()

	for item in hair_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var hair_id := String(item.get("id", "")).to_lower()
		var display_name := String(item.get("name", hair_id))
		var thumb_path := String(item.get("thumb", ""))

		if hair_id == "":
			continue

		# Wrapper so we can show image + label
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(170, 210)

		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(170, 170)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

		if thumb_path != "" and ResourceLoader.exists(thumb_path):
			btn.texture_normal = load(thumb_path)
		else:
			# If missing thumbnail, still create button (blank) + name
			push_warning("Missing thumbnail for: " + hair_id)

		btn.pressed.connect(func():
			_apply_hair(hair_id)
		)

		var label := Label.new()
		label.text = display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		box.add_child(btn)
		box.add_child(label)
		hair_grid.add_child(box)
		

func _apply_hair(hair_id: String) -> void:
	# Prefer public API
	if main_preview and main_preview.has_method("set_hair"):
		main_preview.set_hair(hair_id)
		return

	# Fallback to your current function name (not ideal, but works)
	if main_preview and main_preview.has_method("_apply_new_hair"):
		main_preview._apply_new_hair(hair_id)
		return

	push_error("Main scene has no set_hair(hair_id) or _apply_new_hair(hair_id).")

# ------------ Skin -------------- #
func _load_skin_items() -> void:
	var f := FileAccess.open(SKIN_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open skin JSON: " + SKIN_JSON_PATH)
		return

	var data = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or !data.has("items"):
		push_error("skin_assets.json invalid. Expected { 'items': [ ... ] }")
		return

	skin_items = data["items"]


func _build_skin_buttons() -> void:
	if skin_grid == null:
		push_error("SkinGrid not found. Add a GridContainer named SkinGrid.")
		return

	for c in skin_grid.get_children():
		c.queue_free()

	for item in skin_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var skin_id := String(item.get("id", "")).to_lower()
		var thumb_path := String(item.get("thumb", ""))

		if skin_id == "":
			continue

		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(100, 130)

		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(100, 130)

		if thumb_path != "" and ResourceLoader.exists(thumb_path):
			btn.texture_normal = load(thumb_path)

		btn.pressed.connect(func():
			_apply_skin(skin_id)
		)
		box.custom_minimum_size = Vector2(50, 50)
		box.add_child(btn)
		skin_grid.add_child(box)
		
func _apply_skin(skin_id: String) -> void:
	if main_preview and main_preview.has_method("set_skin"):
		main_preview.set_skin(skin_id)
		return

	# fallback: your current state setter
	if main_preview and main_preview.has_method("_on_option_selected"):
		main_preview._on_option_selected(skin_id)
		return

	push_error("Main scene has no set_skin(skin_id).")

# ---------- Save & continue ----------

func _on_save_avatar_pressed() -> void:
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("show_environment_page"):
		scene_root.show_environment_page()
	else:
		push_error("Current scene has no show_environment_page()")
