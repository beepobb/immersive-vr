extends Control

@onready var right_tabs: TabContainer = %RightTabs

@onready var body_tab: Button   = %BodyTab
@onready var skin_tab: Button   = %SkinTab
@onready var outfit_tab: Button = %OutfitTab
@onready var hair_tab: Button   = %HairTab
@onready var face_tab: Button   = %FaceTab

var bottom_tabs: Array[Button] = []


func _ready() -> void:
	bottom_tabs = [body_tab, skin_tab, outfit_tab, hair_tab, face_tab]

	body_tab.pressed.connect(  func(): _on_bottom_tab_pressed(1) )  # BodyPage
	skin_tab.pressed.connect(  func(): _on_bottom_tab_pressed(2) )  # SkinPage
	outfit_tab.pressed.connect(func(): _on_bottom_tab_pressed(3) )  # OutfitPage
	hair_tab.pressed.connect(  func(): _on_bottom_tab_pressed(0) )  # HairPage
	face_tab.pressed.connect(  func(): _on_bottom_tab_pressed(4) )  # FacePage

	_on_bottom_tab_pressed(1)  # start on BodyPage (optional)


func _on_bottom_tab_pressed(target_index: int) -> void:
	# switch page
	right_tabs.current_tab = target_index

	# update which bottom button looks active
	for tab in bottom_tabs:
		tab.button_pressed = false

	match target_index:
		1: body_tab.button_pressed   = true
		2: skin_tab.button_pressed   = true
		3: outfit_tab.button_pressed = true
		0: hair_tab.button_pressed   = true
		4: face_tab.button_pressed   = true
		
func _on_save_avatar_pressed() -> void:
	# TODO: save avatar data if needed
	get_tree().change_scene_to_file("res://UI/SelectEnvironment.tscn")
