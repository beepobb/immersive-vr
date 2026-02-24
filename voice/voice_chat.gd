extends Node

const PORT: int = 7777
const MAX_CLIENTS: int = 16

const MIC_BUS_NAME: String = "MicCapture"
const CHUNK_SECONDS: float = 0.02
const TARGET_VOICE_RATE: int = 16000

@export var input_gain: float = 1.6
@export var voice_enabled: bool = true
@export var debug_mic: bool = true

var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null

var _mix_rate: int = 48000
var _chunk_frames_mix: int = 960

var _signals_connected: bool = false
var _voice_network_ready: bool = false

var _debug_elapsed: float = 0.0
var _last_rms: float = 0.0
var _last_sent_bytes: int = 0

# peer_id -> {"player": AudioStreamPlayer, "playback": AudioStreamGeneratorPlayback}
var _remote_streams: Dictionary = {}

func _ready() -> void:
	print("VOICE: starting...")

	if not _ensure_input_enabled():
		return

	await get_tree().process_frame

	_force_select_input_device()
	_setup_mic_capture_chain()
	_setup_mic_player()
	_wire_multiplayer_signals()

	_mix_rate = int(AudioServer.get_mix_rate())
	if _mix_rate <= 0:
		push_error("VOICE: Audio failed to init (dummy driver). Fix mac audio output first.")
		return

	_chunk_frames_mix = max(1, int(round(float(_mix_rate) * CHUNK_SECONDS)))

	print("VOICE: init OK | mix_rate=", _mix_rate,
		" chunk_frames=", _chunk_frames_mix,
		" input_device=", AudioServer.get_input_device()
	)

	_auto_network_start_from_args()

func _process(delta: float) -> void:
	if _capture_effect == null:
		return

	var sent_any: bool = false

	while _capture_effect.get_frames_available() >= _chunk_frames_mix:
		var frames: PackedVector2Array = _capture_effect.get_buffer(_chunk_frames_mix)
		if frames.is_empty():
			break

		_last_rms = _calc_rms(frames)

		if not voice_enabled:
			continue
		if not _voice_network_ready:
			continue
		if multiplayer.multiplayer_peer == null:
			continue

		var payload: PackedByteArray = _encode_pcm16_mono(frames, _mix_rate, TARGET_VOICE_RATE, input_gain)
		if payload.is_empty():
			continue

		_last_sent_bytes = payload.size()
		_send_voice_payload(payload)
		sent_any = true

	if debug_mic:
		_debug_elapsed += delta
		if _debug_elapsed >= 1.0:
			_debug_elapsed = 0.0
			print("VOICE: rms=", snappedf(_last_rms, 0.001),
				" sending=", sent_any,
				" bytes=", _last_sent_bytes,
				" net_ready=", _voice_network_ready,
				" conn=", _conn_status(),
				" is_server=", multiplayer.is_server(),
				" my_id=", multiplayer.get_unique_id()
			)

func _auto_network_start_from_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()

	if args.has("--host"):
		host_game()
		return

	for a in args:
		var s: String = String(a)
		if s.begins_with("--join="):
			var parts: PackedStringArray = s.split("=", false, 2)
			var ip: String = ""
			if parts.size() >= 2:
				ip = String(parts[1]).strip_edges()
			if ip == "":
				ip = "127.0.0.1"
			join_game(ip)
			return

	print("VOICE: No args. Run with --host or --join=IP")

func _conn_status() -> String:
	var p: MultiplayerPeer = multiplayer.multiplayer_peer
	if p == null:
		return "NO_PEER"
	return str(p.get_connection_status())

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("VOICE: Host failed: " + str(err))
		return

	multiplayer.multiplayer_peer = peer
	_voice_network_ready = true
	print("VOICE: Hosting on port ", PORT)

func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip, PORT)
	if err != OK:
		push_error("VOICE: Join failed: " + str(err))
		return

	multiplayer.multiplayer_peer = peer
	_voice_network_ready = false
	print("VOICE: Joining ", ip, ":", PORT)

func _send_voice_payload(payload: PackedByteArray) -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	if multiplayer.is_server():
		var sender_id: int = multiplayer.get_unique_id()
		for peer_id in multiplayer.get_peers():
			_voice_from_server.rpc_id(peer_id, sender_id, TARGET_VOICE_RATE, payload)
	else:
		_voice_to_server.rpc_id(1, TARGET_VOICE_RATE, payload)

@rpc("any_peer", "call_remote", "unreliable", 1)
func _voice_to_server(sample_rate: int, payload: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	for peer_id in multiplayer.get_peers():
		if peer_id == sender_id:
			continue
		_voice_from_server.rpc_id(peer_id, sender_id, sample_rate, payload)

@rpc("authority", "call_remote", "unreliable", 1)
func _voice_from_server(sender_id: int, sample_rate: int, payload: PackedByteArray) -> void:
	if sample_rate != TARGET_VOICE_RATE:
		return
	_play_remote_payload(sender_id, payload)

func _play_remote_payload(sender_id: int, payload: PackedByteArray) -> void:
	var playback: AudioStreamGeneratorPlayback = _get_or_create_remote_playback(sender_id)
	if playback == null:
		return

	var samples: PackedFloat32Array = _decode_pcm16_mono(payload)
	if samples.is_empty():
		return

	var free_frames: int = int(playback.get_frames_available())
	if free_frames <= 0:
		return

	var n: int = min(free_frames, samples.size())
	for i in range(n):
		var s: float = samples[i]
		playback.push_frame(Vector2(s, s))

func _get_or_create_remote_playback(peer_id: int) -> AudioStreamGeneratorPlayback:
	if _remote_streams.has(peer_id):
		return _remote_streams[peer_id]["playback"] as AudioStreamGeneratorPlayback

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "RemoteVoice_%s" % str(peer_id)
	player.bus = "Master"

	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = TARGET_VOICE_RATE
	generator.buffer_length = 0.4
	player.stream = generator

	add_child(player)
	player.play()

	var pb: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	_remote_streams[peer_id] = {"player": player, "playback": pb}
	print("VOICE: created remote playback for peer ", peer_id)
	return pb

func _remove_remote_stream(peer_id: int) -> void:
	if not _remote_streams.has(peer_id):
		return
	var player: AudioStreamPlayer = _remote_streams[peer_id]["player"] as AudioStreamPlayer
	if is_instance_valid(player):
		player.queue_free()
	_remote_streams.erase(peer_id)

func _setup_mic_capture_chain() -> void:
	var idx: int = AudioServer.get_bus_index(MIC_BUS_NAME)
	if idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, MIC_BUS_NAME)

	AudioServer.set_bus_volume_db(idx, -80.0)
	AudioServer.set_bus_send(idx, "Master")

	_capture_effect = null

	var effect_count: int = AudioServer.get_bus_effect_count(idx)
	for i in range(effect_count):
		var fx: AudioEffect = AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectCapture:
			_capture_effect = fx as AudioEffectCapture
			break

	if _capture_effect == null:
		_capture_effect = AudioEffectCapture.new()
		_capture_effect.buffer_length = 0.5
		AudioServer.add_bus_effect(idx, _capture_effect, 0)

func _setup_mic_player() -> void:
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicInputPlayer"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = MIC_BUS_NAME
	add_child(_mic_player)
	_mic_player.play()

func _wire_multiplayer_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	print("VOICE: peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("VOICE: peer disconnected: ", id)
	_remove_remote_stream(id)

func _on_connected_to_server() -> void:
	_voice_network_ready = true
	print("VOICE: connected as ", multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	_voice_network_ready = false
	print("VOICE: connection failed")

func _on_server_disconnected() -> void:
	_voice_network_ready = false
	print("VOICE: server disconnected")
	for k in _remote_streams.keys():
		_remove_remote_stream(int(k))

func _ensure_input_enabled() -> bool:
	var enabled: bool = bool(ProjectSettings.get_setting("audio/driver/enable_input"))
	if not enabled:
		push_error("VOICE: Enable Project Settings > Audio > Driver > Enable Input, then restart editor.")
		return false
	return true

func _force_select_input_device() -> void:
	var devices: PackedStringArray = AudioServer.get_input_device_list()
	if devices.is_empty():
		print("VOICE: No input devices visible (macOS mic permission likely).")
		return

	AudioServer.set_input_device(String(devices[0]))
	print("VOICE: Selected input device:", AudioServer.get_input_device())

func _encode_pcm16_mono(frames: PackedVector2Array, src_rate: int, dst_rate: int, gain: float) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	if frames.is_empty():
		return out

	var step: float = float(src_rate) / float(dst_rate)
	var idx: float = 0.0

	while int(idx) < frames.size():
		var f: Vector2 = frames[int(idx)]
		var mono: float = ((f.x + f.y) * 0.5) * gain
		mono = clamp(mono, -1.0, 1.0)

		var s16: int = int(round(mono * 32767.0))
		if s16 < 0:
			s16 += 65536

		out.append(s16 & 0xFF)
		out.append((s16 >> 8) & 0xFF)
		idx += step

	return out

func _decode_pcm16_mono(payload: PackedByteArray) -> PackedFloat32Array:
	var count: int = payload.size() >> 1
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)

	var j: int = 0
	for i in range(0, payload.size() - 1, 2):
		var u: int = int(payload[i]) | (int(payload[i + 1]) << 8)
		var s: int = u if u < 32768 else u - 65536
		out[j] = float(s) / 32768.0
		j += 1

	return out

func _calc_rms(frames: PackedVector2Array) -> float:
	if frames.is_empty():
		return 0.0
	var sum_sq: float = 0.0
	for f in frames:
		var m: float = (f.x + f.y) * 0.5
		sum_sq += m * m
	return sqrt(sum_sq / float(frames.size()))
