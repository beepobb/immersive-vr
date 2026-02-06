extends CharacterBody3D

@export var speed: float = 3.5
@export var interact_action: String = "interact"
@export var sit_animation: String = "Stand_to_Sit"
@export var stand_animation: String = "Stand_to_Sit"
@export var walking_animation: String = "walking"

# Set by the sofa/interaction script
var can_sit: bool = false
var current_sit_point: Node3D = null

var is_sitting: bool = false

@onready var avatar: Node3D = $Avatar
@onready var anim_player: AnimationPlayer = avatar.find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var sit_hint: CanvasItem = get_tree().current_scene.get_node_or_null("UI/SitHint")


func _ready():
	# Start with hint hidden (also ok to untick Visible in Inspector)
	if sit_hint:
		sit_hint.visible = false


func _physics_process(_delta):
	if is_sitting:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# --- Basic WASD movement (uses built-in ui actions) ---
	var input_vec := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	var dir := Vector3(input_vec.x, 0, input_vec.y).normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	move_and_slide()


func _unhandled_input(event):
	if event.is_action_pressed(interact_action):
		if is_sitting:
			_stand_up()
		elif can_sit and current_sit_point:
			_sit_down()


func _sit_down():
	is_sitting = true
	hide_sit_hint()

	# Snap player to sit point position + rotation
	global_transform.origin = current_sit_point.global_transform.origin
	global_transform.basis = current_sit_point.global_transform.basis

	# Play sit animation if available
	if anim_player and anim_player.has_animation(sit_animation):
		anim_player.play(sit_animation)
	else:
		print("No AnimationPlayer or sit animation not found:", sit_animation)


func _stand_up():
	is_sitting = false

	# Play idle animation if available
	if anim_player and anim_player.has_animation(idle_animation):
		anim_player.play(idle_animation)

	# If you're still in range of the sofa, show the hint again (optional)
	if can_sit:
		show_sit_hint()


# --- Called from big_sofa_interaction.gd ---
func show_sit_hint():
	if sit_hint and not is_sitting:
		sit_hint.visible = true


func hide_sit_hint():
	if sit_hint:
		sit_hint.visible = false
