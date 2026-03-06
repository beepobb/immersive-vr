extends Node
class_name VoiceChat

@export var auto_enable_mic: bool = true
@export var input_gain: float = 1.5
@export var send_hz: int = 20
@export var debug_logs: bool = true

const MIC_BUS_NAME := "Mic"
const PLAYBACK_BUS_NAME := "Master"

var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _samples_per_packet: int = 960
var _send_timer: float = 0.0
var _mic_enabled: bool = false

var _players: Dictionary = {}
var _playbacks: Dictionary = {}

func _ready() -> void:
	var mix_rate := AudioServer.get_mix_rate()
	_samples_per_packet = int(mix_rate / max(1, send_hz))

	_setup_mic()

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	_log("VoiceChat ready")

func _process(delta: float) -> void:
	var mp := multiplayer.multiplayer_peer
	if mp == null:
		return

	if mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	# auto-enable mic once connected
	if auto_enable_mic and not _mic_enabled:
		_mic_enabled = true
		_log("Mic auto-enabled")

	_send_timer += delta
	if _send_timer < 1.0 / float(send_hz):
		return
	_send_timer = 0.0

	if _mic_enabled:
		_capture_and_send()

func _setup_mic() -> void:
	var mic_bus_index := AudioServer.get_bus_index(MIC_BUS_NAME)
	if mic_bus_index == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		mic_bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(mic_bus_index, MIC_BUS_NAME)

	if AudioServer.get_bus_effect_count(mic_bus_index) == 0:
		var cap := AudioEffectCapture.new()
		AudioServer.add_bus_effect(mic_bus_index, cap, 0)
		_capture = cap
	else:
		var effect := AudioServer.get_bus_effect(mic_bus_index, 0)
		if effect is AudioEffectCapture:
			_capture = effect as AudioEffectCapture
		else:
			var cap2 := AudioEffectCapture.new()
			AudioServer.add_bus_effect(mic_bus_index, cap2, 0)
			_capture = cap2

	_mic_player = AudioStreamPlayer.new()
	add_child(_mic_player)
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = MIC_BUS_NAME

	# don't hear yourself locally
	AudioServer.set_bus_mute(mic_bus_index, true)

	_mic_player.play()
	_log("Mic setup complete")

func _capture_and_send() -> void:
	if _capture == null:
		return

	var available := _capture.get_frames_available()
	if available <= 0:
		return

	var frames_to_get := min(available, _samples_per_packet)
	var frames := _capture.get_buffer(frames_to_get)
	if frames.is_empty():
		return

	var mono := PackedFloat32Array()
	mono.resize(frames.size())

	var i := 0
	for v in frames:
		var s := ((v.x + v.y) * 0.5) * input_gain
		mono[i] = clamp(s, -1.0, 1.0)
		i += 1

	var payload := _encode_pcm16(mono)
	var my_id := multiplayer.get_unique_id()

	# server speaks directly to all clients
	if my_id == 1:
		for pid in multiplayer.get_peers():
			var target := int(pid)
			if target == my_id:
				continue
			rpc_id(target, "_rpc_voice", my_id, payload)
	else:
		# client sends to server
		rpc_id(1, "_rpc_voice", my_id, payload)

@rpc("any_peer", "unreliable")
func _rpc_voice(speaker_id: int, payload: PackedByteArray) -> void:
	if payload.is_empty():
		return

	var mp := multiplayer.multiplayer_peer
	if mp == null:
		return

	var sender_id := multiplayer.get_remote_sender_id()
	var my_id := multiplayer.get_unique_id()

	# server relays client voice
	if my_id == 1:
		if sender_id != speaker_id:
			return

		# optional: server hears clients too
		_play_voice(speaker_id, payload)

		for pid in multiplayer.get_peers():
			var target := int(pid)
			if target == speaker_id:
				continue
			rpc_id(target, "_rpc_voice", speaker_id, payload)
		return

	# clients only accept relayed voice from server
	if sender_id != 1:
		return

	_play_voice(speaker_id, payload)

func _play_voice(speaker_id: int, payload: PackedByteArray) -> void:
	var samples := _decode_pcm16(payload)
	if samples.is_empty():
		return

	if not _playbacks.has(speaker_id):
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = AudioServer.get_mix_rate()
		gen.buffer_length = 0.2

		var player := AudioStreamPlayer.new()
		player.stream = gen
		player.bus = PLAYBACK_BUS_NAME
		add_child(player)
		player.play()

		var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
		_players[speaker_id] = player
		_playbacks[speaker_id] = playback

	var pb := _playbacks[speaker_id] as AudioStreamGeneratorPlayback
	if pb == null:
		return

	var out := PackedVector2Array()
	out.resize(samples.size())

	var i := 0
	for s in samples:
		out[i] = Vector2(s, s)
		i += 1

	pb.push_buffer(out)

func _on_connected_to_server() -> void:
	_log("Connected to server")

func _on_peer_disconnected(id: int) -> void:
	if not _players.has(id):
		return

	var p := _players[id] as AudioStreamPlayer
	if p != null and is_instance_valid(p):
		p.stop()
		p.queue_free()

	_players.erase(id)
	_playbacks.erase(id)

func _encode_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size() * 2)

	var w := 0
	for s in samples:
		var v := int(round(clamp(s, -1.0, 1.0) * 32767.0))
		var u := v & 0xFFFF
		out[w] = u & 0xFF
		out[w + 1] = (u >> 8) & 0xFF
		w += 2

	return out

func _decode_pcm16(payload: PackedByteArray) -> PackedFloat32Array:
	if payload.size() < 2:
		return PackedFloat32Array()

	var count := payload.size() / 2
	var out := PackedFloat32Array()
	out.resize(count)

	var j := 0
	var i := 0
	while i + 1 < payload.size():
		var lo := int(payload[i])
		var hi := int(payload[i + 1]) << 8
		var u := lo | hi
		var s := u if u < 32768 else (u - 65536)
		out[j] = float(s) / 32768.0
		i += 2
		j += 1

	return out

func _log(msg: String) -> void:
	if debug_logs:
		print("[VoiceChat] ", msg)
