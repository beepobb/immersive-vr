extends Node3D

signal accepted
signal declined

@onready var disclaimer_viewport = $DisclaimerPopup

func _ready() -> void:
	var content = disclaimer_viewport.get_scene_instance()
	if content == null:
		push_error("Disclaimer content scene not found in viewport.")
		return

	if content.has_signal("accepted"):
		content.accepted.connect(_on_content_accepted)

	if content.has_signal("declined"):
		content.declined.connect(_on_content_declined)

func _on_content_accepted() -> void:
	emit_signal("accepted")
	queue_free()

func _on_content_declined() -> void:
	emit_signal("declined")
	queue_free()
