extends Node3D

@onready var area: Area3D = $SitPoint/Area3D
@onready var sit_point: Node3D = $SitPoint

# ✅ Add a Marker3D named "SeatTarget" under SitPoint:
# SitPoint
# ├─ Area3D
# └─ SeatTarget (Marker3D)
@onready var seat_target: Node3D = $SitPoint.get_node_or_null("SeatTarget")

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node):
	if body is CharacterBody3D:
		# pass sit point to player (prefer SeatTarget if it exists)
		var target := seat_target if seat_target != null else sit_point

		if "current_sit_point" in body:
			body.current_sit_point = target
		if "can_sit" in body:
			body.can_sit = true

		# show hint UI
		if body.has_method("show_sit_hint"):
			body.show_sit_hint()

func _on_body_exited(body: Node):
	if body is CharacterBody3D:
		if "current_sit_point" in body:
			body.current_sit_point = null
		if "can_sit" in body:
			body.can_sit = false

		# hide hint UI
		if body.has_method("hide_sit_hint"):
			body.hide_sit_hint()
