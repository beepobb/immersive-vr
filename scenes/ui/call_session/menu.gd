extends Control

@onready var menu_button: Button = $MenuButton
@onready var dropdown_panel: PanelContainer = $PanelContainer

@onready var end_call_button: Button = $PanelContainer/VBoxContainer/EndCallButton
@onready var avatar_button: Button = $PanelContainer/VBoxContainer/AvatarButton
@onready var help_button: Button = $PanelContainer/VBoxContainer/HelpButton
@onready var settings_button: Button = $PanelContainer/VBoxContainer/SettingsButton

@onready var help_popup: Control = $HelpPopup
@onready var dim_background: ColorRect = $HelpPopup/ColorRect
@onready var help_texture: TextureRect = $HelpPopup/PanelContainer/TextureRect
@onready var exit_button: Button = $HelpPopup/PanelContainer/VBoxContainer/MarginContainer/ExitButton

func _ready() -> void:
	UIButtonAudio.setup_buttons(self) 
	dropdown_panel.hide()
	help_popup.hide()

	menu_button.pressed.connect(_on_menu_button_pressed)
	help_button.pressed.connect(_on_help_pressed)
	exit_button.pressed.connect(_on_exit_help_pressed)

func _on_menu_button_pressed() -> void:
	dropdown_panel.visible = not dropdown_panel.visible

func _on_help_pressed() -> void:
	dropdown_panel.hide()
	help_popup.show()

func _on_exit_help_pressed() -> void:
	help_popup.hide()
