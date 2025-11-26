extends Control

@onready var right_tabs: TabContainer = %RightTabs

@onready var body_tab:   Button = %BodyTab
@onready var skin_tab:   Button = %SkinTab
@onready var outfit_tab: Button = %OutfitTab
@onready var hair_tab:   Button = %HairTab
@onready var face_tab:   Button = %FaceTab

var bottom_tabs: Array[Button] = []
var main_preview: Node = null   # will hold MainPreview (Node3D)


func _ready() -> void:
	# Reference to MainPreview (the root of the running scene)
	main_preview = get_tree().current_scene

	bottom_tabs = [body_tab, skin_tab, outfit_tab, hair_tab, face_tab]

	body_tab.pressed.connect(   func(): _on_bottom_tab_pressed(1) )  # BodyPage
	skin_tab.pressed.connect(   func(): _on_bottom_tab_pressed(2) )  # SkinPage
	outfit_tab.pressed.connect( func(): _on_bottom_tab_pressed(3) )  # OutfitPage
	hair_tab.pressed.connect(   func(): _on_bottom_tab_pressed(0) )  # HairPage
	face_tab.pressed.connect(   func(): _on_bottom_tab_pressed(4) )  # FacePage

	_on_bottom_tab_pressed(1)  # start on BodyPage (optional)


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


# ---------- Hair buttons ----------

func _on_ButtonBob_pressed() -> void:
	if main_preview and main_preview.has_method("set_hair"):
		main_preview.set_hair("bob")


func _on_ButtonLong_pressed() -> void:
	if main_preview and main_preview.has_method("set_hair"):
		main_preview.set_hair("long")


func _on_ButtonPonytail_pressed() -> void:
	if main_preview and main_preview.has_method("set_hair"):
		main_preview.set_hair("ponytail")


# ---------- Save & continue ----------

func _on_save_avatar_pressed() -> void:
	@warning_ignore("shadowed_variable")
	var main_preview = get_tree().current_scene
	if main_preview and main_preview.has_method("show_environment_page"):
		main_preview.show_environment_page()
	else:
		push_error("Current scene has no show_environment_page()")
