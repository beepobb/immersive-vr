extends Node3D

@onready var input: AudioStreamPlayer = $Input
@export var outputPath: NodePath = NodePath("../AudioStreamPlayer3D")
@export var inputThreshold: float = 0.005

var effect: AudioEffectCapture
var playback: AudioStreamGeneratorPlayback
var receiveBuffer := PackedFloat32Array()
var receiveReadIndex: int = 0
var captureEnabled: bool = false
var recordTapPlayback: AudioStreamGeneratorPlayback

func setupAudio(owner_id: int, local_peer_id: int) -> void:
	# Keep authority aligned with the owning player node.
	set_multiplayer_authority(owner_id)

	captureEnabled = owner_id == local_peer_id

	if captureEnabled:
		input.stream = AudioStreamMicrophone.new()
		input.play()

		var record_bus := AudioServer.get_bus_index("Record")
		effect = AudioServer.get_bus_effect(record_bus, 0) as AudioEffectCapture

	var output_node := get_node_or_null(outputPath) as AudioStreamPlayer3D
	if output_node:
		playback = output_node.get_stream_playback() as AudioStreamGeneratorPlayback
	else:
		push_error("AudioManager: outputPath is invalid: %s" % str(outputPath))

	# On host therapist, tap remote playback samples into Record bus for full-call recording.
	if multiplayer.multiplayer_peer != null and multiplayer.is_server() and Roles.user_role == Roles.Role.THERAPIST:
		_setup_record_tap_player()

func _process(_delta: float) -> void:
	if captureEnabled:
		processMic()
	processVoice()

func processMic() -> void:
	if effect == null:
		return

	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	var stereoData := effect.get_buffer(effect.get_frames_available())
	if stereoData.is_empty():
		return

	var data := PackedFloat32Array()
	data.resize(stereoData.size())
	var maxAmplitude := 0.0

	for i in range(stereoData.size()):
		var value := (stereoData[i].x + stereoData[i].y) * 0.5
		maxAmplitude = max(maxAmplitude, abs(value))
		data[i] = value

	if maxAmplitude < inputThreshold:
		return

	sendData.rpc(data)

func processVoice() -> void:
	if playback == null:
		return

	var availableSamples: int = receiveBuffer.size() - receiveReadIndex
	if availableSamples <= 0:
		# Reset to avoid unbounded growth after consumption.
		receiveBuffer = PackedFloat32Array()
		receiveReadIndex = 0
		return

	var framesToPush: int = mini(playback.get_frames_available(), availableSamples)
	var tapFramesAvailable: int = framesToPush
	if recordTapPlayback != null:
		tapFramesAvailable = mini(tapFramesAvailable, recordTapPlayback.get_frames_available())
	var framesToProcess: int = mini(framesToPush, tapFramesAvailable)

	if framesToProcess <= 0:
		return

	for i in range(framesToProcess):
		var sample: float = receiveBuffer[receiveReadIndex + i]
		playback.push_frame(Vector2(sample, sample))
		if recordTapPlayback != null:
			recordTapPlayback.push_frame(Vector2(sample, sample))

	receiveReadIndex += framesToProcess

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sendData(data: PackedFloat32Array) -> void:
	receiveBuffer.append_array(data)

func _setup_record_tap_player() -> void:
	if recordTapPlayback != null:
		return

	var tap_player := AudioStreamPlayer.new()
	tap_player.bus = &"Record"
	var tap_stream := AudioStreamGenerator.new()
	tap_stream.mix_rate = AudioServer.get_mix_rate()
	tap_player.stream = tap_stream
	add_child(tap_player)
	tap_player.play()
	recordTapPlayback = tap_player.get_stream_playback() as AudioStreamGeneratorPlayback
