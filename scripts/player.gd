extends CharacterBody3D

@export var speed: float = 3.5

# Keyboard actions (fallback)
@export var interact_action: String = "interact"   # E
@export var stand_action: String = "stand_up"      # Q

# Animation names in your AnimationPlayer
@export var idle_animation: String = "Idle"
@export var sit_animation: String = "Stand_to_sit"
@export var stand_animation: String = "Sit_to_stand"
@export var walking_animation: String = "walking"

# Anchor bone
@export var hips_bone_name: String = "mixamorig8_Hips"

# Optional seat height tweak
@export var seat_y_offset: float = 0.0


# --- Set externally by sofa/chair ---
var can_sit: bool = false
var current_sit_point: Node3D = null
var current_sofa: Node = null   # <- sofa Node3D (has set_icon_visible)

# State
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

# Optional UI hint node
@onready var sit_hint: CanvasItem = get_tree().current_scene.get_node_or_null("UI/SitHint")

# --- XR controller refs ---
@onready var left_controller: XRController3D = XRHelpers.get_left_controller(self)
@onready var right_controller: XRController3D = XRHelpers.get_right_controller(self)

# Which stick drives movement (default: left controller)
var _move_controller: XRController3D


func _ready():
	# Start hidden
	if sit_hint:
		sit_hint.visible = false

	# Start idle
	if anim_player and anim_player.has_animation(idle_animation):
		anim_player.play(idle_animation)

	# Pick movement controller (left stick by default)
	_move_controller = left_controller if left_controller else right_controller

	# Listen for XR button presses (sit/stand)
	if left_controller:
		left_controller.button_pressed.connect(_on_xr_button_pressed)
	if right_controller:
		right_controller.button_pressed.connect(_on_xr_button_pressed)


# ----------------------------
# XR button handler
# ----------------------------
func _on_xr_button_pressed(button_name: String) -> void:
	# Debug once to learn the real names for your headset:
	# print("XR Pressed:", button_name)

	# Sit (trigger)
	if button_name == "trigger_click":
		_try_sit()

	# Stand (example mapping)
	if button_name == "primary_click":
		_try_stand()


# ----------------------------
# Keyboard fallback (optional)
# ----------------------------
func _unhandled_input(event):
	if event.is_action_pressed(interact_action):
		_try_sit()

	if event.is_action_pressed(stand_action):
		_try_stand()


# ----------------------------
# Movement + animation update
# ----------------------------
func _physics_process(_delta):
	# Lock body while seated / animating
	if is_sitting or is_sitting_down or is_standing_up:
		global_transform = locked_sit_transform
		velocity = Vector3.ZERO
		return

	# 1) Read VR thumbstick (preferred)
	var input_vec := Vector2.ZERO
	if _move_controller and _move_controller.get_is_active():
		# "primary" is the standard joystick action used by XRTools movement scripts
		input_vec = _move_controller.get_vector2("primary")

	# 2) Deadzone (prevents drift)
	var deadzone := 0.15
	if input_vec.length() < deadzone:
		input_vec = Vector2.ZERO

	# 3) Fallback to keyboard if no VR input
	if input_vec == Vector2.ZERO:
		input_vec = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		)

	# Convert stick to move direction
	# Note: thumbstick forward usually gives y = -1 so invert y.
	var dir := Vector3(input_vec.x, 0, -input_vec.y).normalized()

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


# ----------------------------
# Sit / Stand helpers
# ----------------------------
func _try_sit() -> void:
	if not is_sitting and not is_sitting_down and not is_standing_up and can_sit and current_sit_point:
		_sit_down()


func _try_stand() -> void:
	if is_sitting and not is_sitting_down and not is_standing_up:
		_stand_up()


# ----------------------------
# Hips world position (for keeping animation anchored)
# ----------------------------
func _get_hips_world_pos() -> Vector3:
	if skeleton == null:
		return global_position

	var idx := skeleton.find_bone(hips_bone_name)
	if idx == -1:
		return global_position

	return (skeleton.global_transform * skeleton.get_bone_global_pose(idx)).origin


# Play animation while keeping hips fixed in world space
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


func _snap_to_sit_point():
	global_transform.origin = current_sit_point.global_transform.origin
	global_transform.basis = current_sit_point.global_transform.basis
	global_position.y += seat_y_offset


# ----------------------------
# MAIN: sit down
# ----------------------------
func _sit_down():
	is_sitting_down = true
	is_sitting = false
	is_standing_up = false

	# Hide UI hint + hide 3D icon immediately
	hide_sit_hint()
	_set_sofa_icon(false)

	_snap_to_sit_point()
	locked_sit_transform = global_transform

	await _play_keep_hips(sit_animation)

	locked_sit_transform = global_transform
	is_sitting_down = false
	is_sitting = true


# ----------------------------
# MAIN: stand up
# ----------------------------
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

	# If still within sit area, show hint + show icon again
	if can_sit:
		show_sit_hint()
		_set_sofa_icon(true)
	else:
		_set_sofa_icon(false)


# ----------------------------
# Icon control (calls sofa method safely)
# ----------------------------
func _set_sofa_icon(v: bool) -> void:
	if current_sofa and current_sofa.has_method("set_icon_visible"):
		current_sofa.set_icon_visible(v)


# ----------------------------
# Hint UI
# ----------------------------
func show_sit_hint():
	if sit_hint and not is_sitting and not is_sitting_down and not is_standing_up:
		sit_hint.visible = true

func hide_sit_hint():
	if sit_hint:
		sit_hint.visible = false
