extends Control

@onready var right_tabs: TabContainer = %RightTabs

@onready var body_tab:   Button = %BodyTab
@onready var skin_tab:   Button = %SkinTab
@onready var outfit_tab: Button = %OutfitTab
@onready var hair_tab:   Button = %HairTab
@onready var shoes_tab:   Button = %ShoesTab

var bottom_tabs: Array[Button] = []
var main_preview: Node = null

#Hair Path
const HAIR_JSON_PATH := "res://assets/hair/hair_assets.json"
var hair_items: Array = []
@onready var hair_grid: GridContainer = %HairGrid

# Outfit Path
const OUTFIT_JSON_PATH := "res://assets/outfit/outfit_assets.json"
var outfit_items: Array = []
@onready var outfit_grid: GridContainer = %OutfitGrid

# Shoes Path
const SHOES_JSON_PATH := "res://assets/shoes/shoes_assets.json"
var shoes_items: Array = []
@onready var shoes_grid: GridContainer = %ShoesGrid


func _ready() -> void:
	print("AVATAR_CUSTOMISER READY RUNNING")
	main_preview = get_tree().current_scene

	bottom_tabs = [body_tab, skin_tab, outfit_tab, hair_tab, shoes_tab]

	body_tab.pressed.connect(   func(): _on_bottom_tab_pressed(1) )
	skin_tab.pressed.connect(   func(): _on_bottom_tab_pressed(2) )
	outfit_tab.pressed.connect( func(): _on_bottom_tab_pressed(3) )
	hair_tab.pressed.connect(   func(): _on_bottom_tab_pressed(0) )
	shoes_tab.pressed.connect(   func(): _on_bottom_tab_pressed(4) )
	#Load Hair Buttons
	_load_hair_items()
	_build_hair_buttons()
	
	# Load Outfit Buttons
	_load_outfit_items()
	_build_outfit_buttons()
	
	# Load Shoes Buttons
	_load_shoes_items()
	_build_shoes_buttons()
	
func _on_bottom_tab_pressed(target_index: int) -> void:
	right_tabs.current_tab = target_index

	for tab in bottom_tabs:
		tab.button_pressed = false

	match target_index:
		1: body_tab.button_pressed   = true
		2: skin_tab.button_pressed   = true
		3: outfit_tab.button_pressed = true
		0: hair_tab.button_pressed   = true
		4: shoes_tab.button_pressed   = true


# ------------ HAIR -------------- #
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

# ------------ OUTFIT -------------- #
func _load_outfit_items() -> void:
	var f := FileAccess.open(OUTFIT_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open outfit JSON: " + OUTFIT_JSON_PATH)
		return

	var data = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(data) != TYPE_DICTIONARY or !data.has("items"):
		push_error("outfit_assets.json invalid. Expected { 'items': [ ... ] }")
		return

	outfit_items = data["items"]
	
func _build_outfit_buttons() -> void:
	if outfit_grid == null:
		push_error("OutfitGrid not found.")
		return

	for c in outfit_grid.get_children():
		c.queue_free()

	for item in outfit_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var outfit_id := String(item.get("id", "")).to_lower()
		var display_name := String(item.get("name", outfit_id))
		var thumb_path := String(item.get("thumb", ""))

		if outfit_id == "":
			continue

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
			push_warning("Missing outfit thumbnail: " + outfit_id)

		btn.pressed.connect(func():
			_apply_outfit(outfit_id)
		)

		var label := Label.new()
		label.text = display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		box.add_child(btn)
		box.add_child(label)
		outfit_grid.add_child(box)
		
func _apply_outfit(outfit_id: String) -> void:
	if main_preview and main_preview.has_method("set_outfit"):
		main_preview.set_outfit(outfit_id)
		return

	if main_preview and main_preview.has_method("_apply_outfit"):
		main_preview._apply_outfit(outfit_id)
		return

	push_error("Main scene has no set_outfit(outfit_id)")
	

# ------------ SHOES -------------- #
func _load_shoes_items() -> void:
	print("Opening shoes JSON:", SHOES_JSON_PATH)

	var f := FileAccess.open(SHOES_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open shoes JSON: " + SHOES_JSON_PATH)
		return

	var text := f.get_as_text()
	f.close()

	print("Shoes JSON text length:", text.length())

	var data = JSON.parse_string(text)

	if typeof(data) != TYPE_DICTIONARY:
		push_error("Shoes JSON parsed, but not a dictionary.")
		print("Parsed type:", typeof(data))
		return

	if !data.has("items"):
		push_error("shoes_assets.json invalid. Missing 'items'")
		print("Parsed keys:", data.keys())
		return

	shoes_items = data["items"]
	print("Shoes items assigned:", shoes_items.size())
	
func _build_shoes_buttons() -> void:
	print("Building shoes buttons...")
	print("ShoesGrid node:", shoes_grid)

	if shoes_grid == null:
		push_error("ShoesGrid not found. Add a GridContainer named ShoesGrid.")
		return

	for c in shoes_grid.get_children():
		c.queue_free()

	print("ShoesGrid cleared. Child count now:", shoes_grid.get_child_count())

	for item in shoes_items:
		if typeof(item) != TYPE_DICTIONARY:
			print("Skipping non-dictionary shoes item:", item)
			continue

		var shoes_id := String(item.get("id", "")).to_lower()
		var display_name := String(item.get("name", shoes_id))
		var thumb_path := String(item.get("thumb", ""))

		print("Building shoe:", shoes_id, " thumb=", thumb_path)

		if shoes_id == "":
			print("Skipping shoes item with empty id")
			continue

		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(170, 210)

		var btn := TextureButton.new()
		btn.custom_minimum_size = Vector2(170, 170)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL

		if thumb_path != "" and ResourceLoader.exists(thumb_path):
			btn.texture_normal = load(thumb_path)
			print("Loaded thumbnail for:", shoes_id)
		else:
			push_warning("Missing thumbnail for shoes: " + shoes_id)

		btn.pressed.connect(func():
			print("Pressed shoes button:", shoes_id)
			_apply_shoes(shoes_id)
		)

		var label := Label.new()
		label.text = display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		box.add_child(btn)
		box.add_child(label)
		shoes_grid.add_child(box)

	print("Finished building shoes buttons. Final child count:", shoes_grid.get_child_count())
		
func _apply_shoes(shoes_id: String) -> void:
	if main_preview and main_preview.has_method("set_shoes"):
		main_preview.set_shoes(shoes_id)
		return

	if main_preview and main_preview.has_method("_apply_new_shoes"):
		main_preview._apply_new_shoes(shoes_id)
		return

	push_error("Main scene has no set_shoes(shoes_id)")
	
# ---------- Save & continue ----------

func _on_save_avatar_pressed() -> void:
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("show_environment_page"):
		scene_root.show_environment_page()
	else:
		push_error("Current scene has no show_environment_page()")
