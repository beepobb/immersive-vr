extends XROrigin3D

var _is_local_player := false
var spawn_point: Node3D
# uncomment for facial tracking and delete all blendshapes in synchroniser
# var _face_blend_shape_values := PackedFloat32Array()
# var _face_sync_accumulator := 0.0

# const FACE_SYNC_INTERVAL_SECONDS := 1.0 / 30.0
# const FACE_MESH_PATH := "AvatarRoot/bernard/Armature/Skeleton3D/Ch31_Body"

# @onready var _face_mesh: MeshInstance3D = get_node_or_null(FACE_MESH_PATH)

# @export var face_blend_shape_values: PackedFloat32Array:
# 	set(value):
# 		_face_blend_shape_values = value
# 		if not _is_local_player:
# 			_apply_face_blend_shapes(value)
# 	get:
# 		return _face_blend_shape_values

func _enter_tree() -> void:
	# Authority is local-only state, so each peer must set it for this node.
	# Parent node is named with peer id by the server ("1", "2", ...).
	var owner_id := str(name).to_int()
	_is_local_player = owner_id == multiplayer.get_unique_id()
	# Set on root recursively so the sibling MultiplayerSynchronizer gets the same owner.
	set_multiplayer_authority(owner_id, true)
	_configure_local_player(_is_local_player)


func _configure_local_player(is_local_player: bool) -> void:
	var player_body := get_node_or_null("PlayerBody")
	if player_body and "enabled" in player_body:
		player_body.enabled = is_local_player

	for child in _get_descendants(self ):
		if child is XRToolsMovementProvider:
			child.enabled = is_local_player


func _get_descendants(node: Node) -> Array[Node]:
	var descendants: Array[Node] = []
	for child in node.get_children():
		descendants.append(child)
		descendants.append_array(_get_descendants(child))
	return descendants

func _ready():
	print("is_local: ", is_multiplayer_authority(), " peer_id: ", multiplayer.get_unique_id(), " role: ", Roles.get_role_text())
	for sp in get_node("../../SpawnPoints").get_children():
		if sp.is_in_group("therapist") and Roles.get_role_text() == "Therapist":
			print("therapist spawn point")
			spawn_point = sp
		elif sp.is_in_group("patient") and Roles.get_role_text() == "Patient":
			print("patient spawn point")
			spawn_point = sp
	global_position = spawn_point.global_position
		
	print(name, " is local: ", is_multiplayer_authority())
	var sync := get_node("MultiplayerSynchronizer")
	var local_peer_id := multiplayer.get_unique_id()
	_is_local_player = get_multiplayer_authority() == local_peer_id
	$XRCamera3D.current = _is_local_player
	print(
		"Player body auth=" + str(get_multiplayer_authority()) +
		" sync auth=" + str(sync.get_multiplayer_authority()) +
		" local_peer=" + str(local_peer_id) +
		" is_local=" + str(_is_local_player)
	)
	print("Set up audio for: " + str(local_peer_id))
	$AudioManager.setupAudio(get_multiplayer_authority(), local_peer_id)
	if not _is_local_player:
		if $RightController.button_pressed.is_connected(_on_right_controller_button_pressed):
			$RightController.button_pressed.disconnect(_on_right_controller_button_pressed)
		$RightController/in_call_control_viewport.visible = false
	# for makehuman
	#if in_call and is_local_player:
		#GameState.avatar = self
		#GameState.apply_to_avatar()
	if is_multiplayer_authority():
		print(name, " enable face modifier")
		$AvatarRoot/bernard/XRFaceModifier3D.set_process(true)
	else:
		$AvatarRoot/bernard/XRFaceModifier3D.set_process(false)
		# _apply_face_blend_shapes(_face_blend_shape_values)


# func _process(delta: float) -> void:
# 	if not _is_local_player:
# 		return
# 	if _face_mesh == null:
# 		return

# 	_face_sync_accumulator += delta
# 	if _face_sync_accumulator < FACE_SYNC_INTERVAL_SECONDS:
# 		return
# 	_face_sync_accumulator = 0.0

# 	var blend_shape_count := _face_mesh.get_blend_shape_count()
# 	if blend_shape_count <= 0:
# 		return

# 	var sampled_values := PackedFloat32Array()
# 	sampled_values.resize(blend_shape_count)

# 	var changed := _face_blend_shape_values.size() != blend_shape_count
# 	for i in blend_shape_count:
# 		var sampled_value := _face_mesh.get_blend_shape_value(i)
# 		sampled_values[i] = sampled_value
# 		if not changed and not is_equal_approx(_face_blend_shape_values[i], sampled_value):
# 			changed = true

# 	if changed:
# 		face_blend_shape_values = sampled_values


# func _apply_face_blend_shapes(values: PackedFloat32Array) -> void:
# 	if _face_mesh == null:
# 		return

# 	var blend_shape_count: int = min(_face_mesh.get_blend_shape_count(), values.size())
# 	for i in blend_shape_count:
# 		_face_mesh.set_blend_shape_value(i, values[i])
	
func _on_right_controller_button_pressed(action_name: String) -> void:
	if not _is_local_player:
		return
	if action_name == "ax_button":
		if $RightController/in_call_control_viewport.visible == false:
			$RightController/in_call_control_viewport.show()
			$LeftController/FunctionPointer.show()
		else:
			$RightController/in_call_control_viewport.hide()
			$LeftController/FunctionPointer.hide()
