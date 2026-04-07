extends Node3D

@export var bird_scene: PackedScene
@export var bird_count: int = 8
@export var radius: float = 12.0
@export var height: float = 8.0
@export var speed: float = 0.8
@export var height_variation: float = 2.0
@export var radius_variation: float = 3.0

var birds: Array = []
var angles: Array = []
var bird_radii: Array = []
var bird_heights: Array = []

func _ready() -> void:
	randomize()

	for i in range(bird_count):
		var bird = bird_scene.instantiate()
		add_child(bird)

		var angle = randf() * TAU
		var r = radius + randf_range(-radius_variation, radius_variation)
		var h = height + randf_range(-height_variation, height_variation)

		angles.append(angle)
		bird_radii.append(r)
		bird_heights.append(h)
		birds.append(bird)

		_play_bird_animation(bird)
		_update_bird_transform(i)

func _process(delta: float) -> void:
	for i in range(birds.size()):
		angles[i] += speed * delta * (1.0 + i * 0.03)
		_update_bird_transform(i)

func _update_bird_transform(index: int) -> void:
	var bird = birds[index]
	var angle = angles[index]
	var r = bird_radii[index]
	var h = bird_heights[index]

	# Current position
	var pos = Vector3(
		cos(angle) * r,
		h + sin(angle * 2.0 + index) * 0.5,
		sin(angle) * r
	)

	# NEXT position (this gives movement direction)
	var next_angle = angle + 0.01
	var next_pos = Vector3(
		cos(next_angle) * r,
		h + sin(next_angle * 2.0 + index) * 0.5,
		sin(next_angle) * r
	)

	bird.position = pos

	# Direction of motion
	var direction = (next_pos - pos).normalized()

	# Make bird face direction of movement
	bird.look_at(pos + direction, Vector3.UP)

	# 🔧 FIX MODEL ORIENTATION (IMPORTANT)
	# Try ONE of these depending on your model:
	bird.rotate_y(deg_to_rad(180))

func _play_bird_animation(bird: Node) -> void:
	if bird.has_node("AnimationPlayer"):
		var anim_player = bird.get_node("AnimationPlayer")
		var anim_list = anim_player.get_animation_list()

		if anim_list.size() > 0:
			var anim_name = anim_list[0]
			anim_player.play(anim_name)

			var anim_res = anim_player.get_animation(anim_name)
			if anim_res:
				anim_res.loop_mode = Animation.LOOP_LINEAR