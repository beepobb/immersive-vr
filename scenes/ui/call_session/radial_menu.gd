extends Node3D

signal end_call_selected
signal help_selected
signal avatar_selected
signal settings_selected

@export var deadzone: float = 0.45
@export var xr_camera_path: NodePath

@onready var billboard: Node3D = $Billboard
@onready var center_text: Label3D = $Billboard/CenterText

@onready var end_call: Node3D = $Billboard/SliceContainer/EndCall
@onready var help: Node3D = $Billboard/SliceContainer/Help
@onready var avatar: Node3D = $Billboard/SliceContainer/Avatar
@onready var setting: Node3D = $Billboard/SliceContainer/Setting

@onready var xr_camera: Camera3D = get_node_or_null(xr_camera_path)

var is_open := false
var current_index := -1
var slices: Array[Node3D] = []
var labels := ["END CALL", "HELP", "AVATAR", "SETTINGS"]

func _ready() -> void:
	slices = [end_call, help, avatar, setting]
	visible = false
	center_text.text = ""
	_reset_visuals()

func _process(_delta: float) -> void:
	if visible and xr_camera:
		billboard.look_at(xr_camera.global_transform.origin, Vector3.UP, true)

func open_menu() -> void:
	is_open = true
	visible = true
	current_index = -1
	center_text.text = ""
	_reset_visuals()

func close_menu() -> void:
	is_open = false
	visible = false
	current_index = -1
	center_text.text = ""
	_reset_visuals()

func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func update_from_joystick(input_vector: Vector2) -> void:
	if not is_open:
		return

	if input_vector.length() < deadzone:
		_set_highlight(-1)
		return

	var angle := atan2(-input_vector.y, input_vector.x)
	var deg := wrapf(rad_to_deg(angle), 0.0, 360.0)

	var new_index := -1

	if deg >= 45.0 and deg < 135.0:
		new_index = 0
	elif deg >= 135.0 and deg < 225.0:
		new_index = 1
	elif deg >= 315.0 or deg < 45.0:
		new_index = 2
	else:
		new_index = 3

	_set_highlight(new_index)

func confirm_selection() -> void:
	if not is_open:
		return

	match current_index:
		0:
			end_call_selected.emit()
		1:
			help_selected.emit()
		2:
			avatar_selected.emit()
		3:
			settings_selected.emit()

	close_menu()

func _set_highlight(index: int) -> void:
	current_index = index

	for i in range(slices.size()):
		var slice := slices[i]
		var mesh := slice.get_node_or_null("SliceMesh") as MeshInstance3D

		if i == current_index:
			slice.scale = Vector3(1.12, 1.12, 1.12)
			center_text.text = labels[i]
			_apply_highlight(mesh, true)
		else:
			slice.scale = Vector3.ONE
			_apply_highlight(mesh, false)

	if current_index == -1:
		center_text.text = ""

func _reset_visuals() -> void:
	for slice in slices:
		slice.scale = Vector3.ONE
		var mesh := slice.get_node_or_null("SliceMesh") as MeshInstance3D
		_apply_highlight(mesh, false)

func _apply_highlight(mesh: MeshInstance3D, active: bool) -> void:
	if mesh == null:
		return

	var mat := mesh.get_active_material(0) as StandardMaterial3D
	if mat == null:
		return

	if active:
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.7, 1.0)
	else:
		mat.emission_enabled = false
