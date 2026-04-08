extends XROrigin3D

@export var in_call = false
var _is_local_player := false

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
	if is_multiplayer_authority():
		hide_all_meshes($AvatarRoot/bernard/Armature/Skeleton3D)
	# for makehuman
	#if in_call and is_local_player:
		#GameState.avatar = self
		#GameState.apply_to_avatar()
func hide_all_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			child.visible = false
		
		# Recurse into children
		hide_all_meshes(child)
		
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
