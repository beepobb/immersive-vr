extends Node

var current_sofa = null

func _process(delta):
	if current_sofa and Input.is_action_just_pressed("interact"):
		current_sofa.sit()
