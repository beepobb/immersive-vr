extends Node3D

@onready var hair_bob = $Armature/Skeleton3D/Hair_bob
@onready var hair_long = $Armature/Skeleton3D/Hair_long

func set_hairstyle(style: String) -> void:
	# Turn off all hair
	hair_bob.visible = false
	hair_long.visible = false

	match style:
		"bob":
			hair_bob.visible = true
		"long":
			hair_long.visible = true
