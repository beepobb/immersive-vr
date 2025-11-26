extends Node3D

@onready var avatar: Node3D = $AvatarTest
@onready var hair_bob: Node3D = $AvatarTest/Armature/Skeleton3D/Human_bob02
@onready var hair_long: Node3D = $AvatarTest/Armature/Skeleton3D/Human_long02
@onready var hair_ponytail: Node3D = $AvatarTest/Armature/Skeleton3D/Human_ponytail01

@onready var avatar_customizer: Control = $CanvasLayer/AvatarCustomizer
@onready var select_environment: Control = $CanvasLayer.get_node_or_null("SelectEnvironment")

# floor platform from PreviewStage
@warning_ignore("shadowed_global_identifier")
@onready var floor: Node3D = $PreviewStage/Floor

var rotating: bool = false

func _ready() -> void:
	# Use saved hair if we already have one, otherwise default to ponytail
	var initial_style := AvatarState.hairstyle
	if initial_style == "" or initial_style == null:
		initial_style = "ponytail"
	set_hair(initial_style)

	# Avatar & floor visible on customizer page
	if avatar:
		avatar.visible = true
	if floor:
		floor.visible = true

	if avatar_customizer:
		avatar_customizer.visible = true

	if select_environment:
		select_environment.visible = false
	else:
		push_error("SelectEnvironment node not found under CanvasLayer!")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		rotating = event.pressed
	elif event is InputEventMouseMotion and rotating:
		var motion := event as InputEventMouseMotion
		var delta: float = motion.relative.x * -0.005
		if avatar:
			avatar.rotate_y(-delta)


func set_hair(style: String) -> void:
	# --- save choice globally so VR can use it later ---
	AvatarState.hair_style = style

	# Hide all first
	if hair_bob:
		hair_bob.visible = false
	if hair_long:
		hair_long.visible = false
	if hair_ponytail:
		hair_ponytail.visible = false

	match style:
		"bob":
			if hair_bob:
				hair_bob.visible = true
		"long":
			if hair_long:
				hair_long.visible = true
		"ponytail":
			if hair_ponytail:
				hair_ponytail.visible = true
				
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if avatar and floor:
		# keeps floor centered under avatar
		floor.global_transform.origin.x = avatar.global_transform.origin.x
		floor.global_transform.origin.z = avatar.global_transform.origin.z



func show_environment_page() -> void:
	# Hide avatar + floor + customizer UI, show Select Environment UI
	if avatar:
		avatar.visible = false
	if floor:
		floor.visible = false
	if avatar_customizer:
		avatar_customizer.visible = false
	if select_environment:
		select_environment.visible = true
	else:
		push_error("show_environment_page: select_environment is null")


func show_customizer_page() -> void:
	# Show avatar + floor + customizer UI, hide Select Environment UI
	if select_environment:
		select_environment.visible = false
	if avatar_customizer:
		avatar_customizer.visible = true
	if avatar:
		avatar.visible = true
	if floor:
		floor.visible = true
