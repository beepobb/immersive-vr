extends Node3D

@onready var area = $Area3D
@onready var marker = $Area3D/Marker

func _ready():
	marker.visible = false

func _on_Area3D_body_entered(body):
	if body.name == "Player":   # or use group (better)
		marker.visible = true

func _on_Area3D_body_exited(body):
	if body.name == "Player":
		marker.visible = false
