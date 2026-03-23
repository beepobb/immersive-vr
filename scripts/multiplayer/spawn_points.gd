extends Node3D

func _ready() -> void:
	$Spawn1.add_to_group("spawn_points")
	$Spawn2.add_to_group("spawn_points")
