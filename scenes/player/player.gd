extends XROrigin3D

func _enter_tree() -> void:
	# Authority is local-only state, so each peer must set it for this node.
	# Parent node is named with peer id by the server ("1", "2", ...).
	var owner_id := str(name).to_int()
	# Set on root recursively so the sibling MultiplayerSynchronizer gets the same owner.
	set_multiplayer_authority(owner_id, true)
	_configure_local_player(owner_id == multiplayer.get_unique_id())


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
	var is_local_player := get_multiplayer_authority() == local_peer_id
	$XRCamera3D.current = is_local_player
	print(
		"Player body auth=" + str(get_multiplayer_authority()) +
		" sync auth=" + str(sync.get_multiplayer_authority()) +
		" local_peer=" + str(local_peer_id) +
		" is_local=" + str(is_local_player)
	)
