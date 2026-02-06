extends CharacterBody3D

@export var speed: float = 3.5

@export var interact_action: String = "interact"   # E
@export var stand_action: String = "stand_up"      # Q

@export var idle_animation: String = "Idle"
@export var sit_animation: String = "Stand_to_sit"
@export var stand_animation: String = "Sit_to_stand"
@export var walking_animation: String = "walking"

# Anchor bone
@export var hips_bone_name: String = "mixamorig8_Hips"

# Optional seat height tweak
@export var seat_y_offset: float = 0.0

# Set externally by sofa / chair
var can_sit: bool = false
var current_sit_point: Node3D = null

var is_sitting := false
var is_sitting_down := false
var is_standing_up := false

var locked_sit_transform: Transform3D

# --------------------------------------------------
# Avatar references (ALL avatar1)
# --------------------------------------------------

@onready var avatar1: Node3D = $avatar1
@onready var skeleton: Skeleton3D = avatar1.find_child("Skeleton3D", true, false)
@onready var anim_player: AnimationPlayer = avatar1.find_child("AnimationPlayer", true, false)
@onready var sit_hint: CanvasItem = get_tree().current_scene.get_node_or_null("UI/SitHint")

# --------------------------------------------------

func _ready():
	if sit_hint:
		sit_hint.visible = false

	if anim_player and anim_player.has_animation(idle_animation):
		anim_player.play(idle_animation)

# --------------------------------------------------

func _physics_process(_delta):

	# Lock body while seated / animating
	if is_sitting or is_sitting_down or is_standing_up:
		global_transform = locked_sit_transform
		velocity = Vector3.ZERO
		return

	# Movement
	var input_vec := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	var dir := Vector3(input_vec.x, 0, input_vec.y).normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	# Animations
	if anim_player:
		if dir.length() > 0.01:
			if anim_player.has_animation(walking_animation) and anim_player.current_animation != walking_animation:
				anim_player.play(walking_animation)
		else:
			if anim_player.has_animation(idle_animation) and anim_player.current_animation != idle_animation:
				anim_player.play(idle_animation)

# --------------------------------------------------

func _unhandled_input(event):

	if event.is_action_pressed(interact_action):
		if not is_sitting and not is_sitting_down and not is_standing_up and can_sit and current_sit_point:
			_sit_down()

	if event.is_action_pressed(stand_action):
		if is_sitting and not is_sitting_down and not is_standing_up:
			_stand_up()

# --------------------------------------------------
# HIP POSITION
# --------------------------------------------------

func _get_hips_world_pos() -> Vector3:
	if skeleton == null:
		return global_position

	var idx := skeleton.find_bone(hips_bone_name)
	if idx == -1:
		return global_position

	return (skeleton.global_transform * skeleton.get_bone_global_pose(idx)).origin

# --------------------------------------------------
# PLAY ANIMATION WHILE KEEPING HIPS FIXED
# --------------------------------------------------

func _play_keep_hips(animation_name: String) -> void:
	if anim_player == null or not anim_player.has_animation(animation_name):
		print("Missing animation:", animation_name)
		return

	var hips_before := _get_hips_world_pos()

	anim_player.play(animation_name)
	await get_tree().process_frame

	var hips_after := _get_hips_world_pos()
	var delta := hips_before - hips_after

	global_position += delta

# --------------------------------------------------

func _snap_to_sit_point():
	global_transform.origin = current_sit_point.global_transform.origin
	global_transform.basis = current_sit_point.global_transform.basis
	global_position.y += seat_y_offset

# --------------------------------------------------

func _sit_down():

	is_sitting_down = true
	is_sitting = false
	is_standing_up = false
	hide_sit_hint()

	_snap_to_sit_point()
	locked_sit_transform = global_transform

	await _play_keep_hips(sit_animation)

	locked_sit_transform = global_transform

	is_sitting_down = false
	is_sitting = true

# --------------------------------------------------

func _stand_up():

	is_sitting = false
	is_standing_up = true
	hide_sit_hint()

	global_transform = locked_sit_transform

	await _play_keep_hips(stand_animation)

	if anim_player and anim_player.has_animation(stand_animation):
		await anim_player.animation_finished

	is_standing_up = false

	if anim_player and anim_player.has_animation(idle_animation):
		anim_player.play(idle_animation)

	if can_sit:
		show_sit_hint()

# --------------------------------------------------

func show_sit_hint():
	if sit_hint and not is_sitting and not is_sitting_down and not is_standing_up:
		sit_hint.visible = true

func hide_sit_hint():
	if sit_hint:
		sit_hint.visible = false
