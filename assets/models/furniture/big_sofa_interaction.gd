extends Node3D

@onready var area: Area3D = $SitPoint/Area3D
@onready var sit_point: Node3D = $SitPoint

# Optional seat snap target under SitPoint named "SeatTarget"
@onready var seat_target: Node3D = $SitPoint.get_node_or_null("SeatTarget")

# Sprite3D indicator under SitPoint named "InteractIcon"
@onready var interact_icon: Sprite3D = $SitPoint.get_node("InteractIcon") as Sprite3D

# Optional: gentle floating animation for the icon
@export var float_icon := true
@export var icon_base_y := 1.2
@export var icon_float_amp := 0.05
@export var icon_float_speed := 0.005


func _ready():
	# Start hidden
	set_icon_visible(false)

	# Ensure billboard mode (faces the camera)
	if interact_icon:
		interact_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		interact_icon.position.y = icon_base_y

	# Connect detection
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _process(_delta):
	# Float icon only when visible
	if float_icon and interact_icon and interact_icon.visible:
		interact_icon.position.y = icon_base_y + sin(Time.get_ticks_msec() * icon_float_speed) * icon_float_amp


# Public helper so Player can hide/show the icon during sit/stand
func set_icon_visible(v: bool) -> void:
	if interact_icon:
		interact_icon.visible = v


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		# Use SeatTarget if it exists, otherwise SitPoint
		var target := seat_target if seat_target != null else sit_point

		# Pass sit target + sofa ref into player
		if "current_sit_point" in body:
			body.current_sit_point = target
		if "current_sofa" in body:
			body.current_sofa = self
		if "can_sit" in body:
			body.can_sit = true

		# Show 3D icon (only if player is not already sitting)
		if "is_sitting" in body and body.is_sitting:
			set_icon_visible(false)
		else:
			set_icon_visible(true)

		# Show UI hint (player controls actual hint visibility rules)
		if body.has_method("show_sit_hint"):
			body.show_sit_hint()


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody3D:
		# Clear player references
		if "current_sit_point" in body:
			body.current_sit_point = null
		if "can_sit" in body:
			body.can_sit = false
		if "current_sofa" in body:
			body.current_sofa = null

		# Hide icon & UI hint
		set_icon_visible(false)
		if body.has_method("hide_sit_hint"):
			body.hide_sit_hint()
