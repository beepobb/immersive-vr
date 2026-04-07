extends Node3D

@onready var input: AudioStreamPlayer = $Input
@export var outputPath: NodePath = NodePath("../AudioStreamPlayer3D")
@export var inputThreshold: float = 0.005

var effect: AudioEffectCapture
var playback: AudioStreamGeneratorPlayback
var receiveBuffer := PackedFloat32Array()
var receiveReadIndex: int = 0
var captureEnabled: bool = false

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

func _process(_delta: float) -> void:
	if captureEnabled:
		processMic()
	processVoice()

func processMic() -> void:
	if effect == null:
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

	var framesToPush: int = min(playback.get_frames_available(), availableSamples)
	for i in range(framesToPush):
		var sample = receiveBuffer[receiveReadIndex + i]
		playback.push_frame(Vector2(sample, sample))

	receiveReadIndex += framesToPush

@rpc("any_peer", "call_remote", "unreliable_ordered")
func sendData(data: PackedFloat32Array) -> void:
	receiveBuffer.append_array(data)
