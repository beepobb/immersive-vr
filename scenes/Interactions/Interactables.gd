extends Node3D
class_name Interactable

@export var marker_path: NodePath
@onready var marker: Node3D = get_node("Area3D/Marker")

@onready var area: Area3D = $Area3D

var player_inside := false

func _ready():
	marker.visible = false
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	# Only react to the VR player
	if body.is_in_group("player"):
		player_inside = true
		marker.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		marker.visible = false
