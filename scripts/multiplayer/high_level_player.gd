extends CharacterBody3D

const SPEED: float = 500.0

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int( ))
	
func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): return
	
	var xy_vel: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up") * SPEED
	velocity = Vector3(xy_vel.x, xy_vel.y, 0)
	
	move_and_slide()
