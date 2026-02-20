extends CharacterBody3D

@export var speed := 4.0

func _ready():
	add_to_group("player")

func _physics_process(_delta):
	var dir := Vector3.ZERO

	if Input.is_action_pressed("ui_up"): dir.z -= 1
	if Input.is_action_pressed("ui_down"): dir.z += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_right"): dir.x += 1

	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	move_and_slide()
