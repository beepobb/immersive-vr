extends CharacterBody3D

@onready var xr_origin: Node3D = $XROrigin3D

func _process(_delta):
	# Keep the body aligned to the XR origin position (roomscale)
	global_position.x = xr_origin.global_position.x
	global_position.z = xr_origin.global_position.z
