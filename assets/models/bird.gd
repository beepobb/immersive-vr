extends Node3D

@onready var anim = $AnimationPlayer

func _ready():
	anim.play("Armature|Take 001|Layer0")
