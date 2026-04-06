extends Node3D

signal accepted
signal declined

@onready var viewport_node = $DisclaimerPopup

var _is_closing := false

func _ready() -> void:
	scale = Vector3(0.92, 0.92, 0.92)
	visible = true
	_animate_in()

	var content = viewport_node.get_scene_instance()
	if content == null:
		push_error("Disclaimer content scene not found in viewport.")
		return

	if content.has_signal("accepted"):
		content.accepted.connect(_on_content_accepted)

	if content.has_signal("declined"):
		content.declined.connect(_on_content_declined)


func _on_content_accepted() -> void:
	if _is_closing:
		return
	_is_closing = true
	await _animate_out()
	emit_signal("accepted")
	queue_free()


func _on_content_declined() -> void:
	if _is_closing:
		return
	_is_closing = true
	await _animate_out()
	emit_signal("declined")
	queue_free()


func _animate_in() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.22)


func _animate_out() -> Signal:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.94, 0.94, 0.94), 0.18)
	return tween.finished
