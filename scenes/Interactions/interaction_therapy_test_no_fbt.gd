extends Node3D

@export var player_body: Node3D            # XRToolsPlayerBody
@export var avatar_root: Node3D                     # e.g. $PlayerRoot/XROrigin3D/avatar1
@export var seat_marker: Marker3D                   # sofa SeatMarker

@export var anim_in: StringName = &"Stand_to_sit"
@export var anim_out: StringName = &"Sit_to_stand"

@onready var anim_player: AnimationPlayer = $PlayerRoot/XROrigin3D/avatar1/AnimationPlayer

var is_seated := false
var ignore_stand_until_msec := 0

func _ready():
	await get_tree().process_frame

	for interactable in get_tree().get_nodes_in_group("interactable"):
		interactable.teleport_requested.connect(_on_teleport_requested)

	for c in get_tree().get_nodes_in_group("xr_controller"):
		if c.has_signal("button_pressed"):
			c.button_pressed.connect(_on_controller_button_pressed)

func _on_teleport_requested(dest: Transform3D) -> void:
	if not player_body:
		push_error("player_body not set")
		return

	# Start ignoring stand IMMEDIATELY (same trigger press)
	ignore_stand_until_msec = Time.get_ticks_msec() + 350

	# Teleport body (XR Tools-friendly)
	var t := dest
	t.basis = t.basis.rotated(Vector3.UP, PI)
	player_body.global_transform = t

	# Sit anim
	_play_restart(anim_in)
	is_seated = true

	# After animation ends, snap avatar to seat marker to remove Mixamo drift
	await anim_player.animation_finished
	if seat_marker and avatar_root:
		avatar_root.global_transform = seat_marker.global_transform

func _on_controller_button_pressed(button_name: String) -> void:
	if button_name != "trigger_click":
		return

	if Time.get_ticks_msec() < ignore_stand_until_msec:
		return

	if is_seated:
		_play_restart(anim_out)
		is_seated = false

		await anim_player.animation_finished

		# Snap avatar back to the player (remove stand drift)
		if avatar_root and player_body:
			var t := avatar_root.global_transform
			t.origin = player_body.global_position
			avatar_root.global_transform = t

		# optional small cooldown so release/press doesn't re-trigger weirdly
		ignore_stand_until_msec = Time.get_ticks_msec() + 150

func _play_restart(name: StringName) -> void:
	if not anim_player:
		return
	anim_player.stop()
	anim_player.play(name)
	anim_player.seek(0.0, true)
