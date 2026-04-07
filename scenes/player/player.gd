extends XROrigin3D

@export var in_call = false

var effect
var recording
var _recording_started := false
var _recording_saved := false

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

	# for makehuman
	#if in_call and is_local_player:
		#GameState.avatar = self
		#GameState.apply_to_avatar()

	_setup_recording(is_local_player)


func _exit_tree() -> void:
	_finalize_recording()


func _setup_recording(is_local_player: bool) -> void:
	if not in_call or not is_local_player:
		return
	if Roles.user_role != Roles.Role.PATIENT:
		return

	var idx := AudioServer.get_bus_index("Record")
	if idx == -1:
		push_error("Audio bus 'Record' was not found.")
		return

	effect = AudioServer.get_bus_effect(idx, 0)
	if effect == null:
		push_error("No AudioEffectRecord found on bus 'Record' at index 0.")
		return

	start_recording()
	if not multiplayer.server_disconnected.is_connected(stop_recording):
		multiplayer.server_disconnected.connect(stop_recording)
	
func start_recording():
	if effect == null:
		return
	recording = null
	_recording_saved = false
	if not effect.is_recording_active():
		effect.set_recording_active(true)
	_recording_started = true
	
func stop_recording():
	_finalize_recording()


func _finalize_recording() -> void:
	if effect == null:
		return
	if not _recording_started:
		return
	if _recording_saved:
		return

	if effect.is_recording_active():
		effect.set_recording_active(false)

	recording = effect.get_recording()
	if recording == null:
		push_warning("No recording captured at call end.")
		_recording_saved = true
		return

	save_recording()
	_recording_saved = true
		
func save_recording():
	if recording == null:
		push_warning("Recording is null; skipping save.")
		return
	var save_path = _build_patient_recording_path()
	recording.save_to_wav(save_path)
	print("Saved therapy recording to: %s" % ProjectSettings.globalize_path(save_path))


func _build_patient_recording_path() -> String:
	var now := Time.get_datetime_dict_from_system()
	var datetime_stamp := "%04d%02d%02d_%02d%02d%02d" % [
		now.year,
		now.month,
		now.day,
		now.hour,
		now.minute,
		now.second,
	]
	return "user://therapy_session_patient_%s.wav" % datetime_stamp


func _on_right_controller_button_pressed(name: String) -> void:
	if name == "ax_button":
		if $RightController/in_call_control_viewport.visible == false:
			$RightController/in_call_control_viewport.show()
		else:
			$RightController/in_call_control_viewport.hide()
