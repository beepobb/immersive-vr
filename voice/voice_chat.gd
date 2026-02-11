extends Node

# ============================
# CONFIG
# ============================
const PORT: int = 7777
const MAX_CLIENTS: int = 16

const MIC_BUS_NAME: String = "MicCapture"
const CHUNK_SECONDS: float = 0.02          # 20ms
const TARGET_VOICE_RATE: int = 16000       # 16kHz mono PCM16

@export var input_gain: float = 1.6
@export var voice_enabled: bool = true
@export var debug_mic: bool = true

# ============================
# STATE
# ============================
var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null

var _mix_rate: int = 48000
var _chunk_frames_mix: int = 960

var _signals_connected: bool = false
var _voice_network_ready: bool = false

var _debug_elapsed: float = 0.0
var _last_rms: float = 0.0

# peer_id -> {"player": AudioStreamPlayer, "playback": AudioStreamGeneratorPlayback}
var _remote_streams: Dictionary = {}

# ============================
# LIFECYCLE
# ============================
func _ready() -> void:
	if not _ensure_input_enabled():
		return

	# Let audio/bus layout settle for a frame.
	await get_tree().process_frame

	_force_select_input_device()

	_setup_mic_capture_chain()
	_setup_mic_player()

	_wire_multiplayer_signals()

	_mix_rate = int(AudioServer.get_mix_rate())
	if _mix_rate <= 0:
		push_error("Audio failed to initialize (dummy driver). Fix CoreAudio first.")
		return

	_chunk_frames_mix = max(1, int(round(float(_mix_rate) * CHUNK_SECONDS)))

	print("Voice init OK | mix_rate=", _mix_rate,
		" chunk_frames=", _chunk_frames_mix,
		" input_device=", AudioServer.get_input_device(),
		" inputs=", AudioServer.get_input_device_list()
	)

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

		_send_voice_payload(payload)
		sent_any = true

	if debug_mic:
		_debug_elapsed += delta
		if _debug_elapsed >= 1.0:
			_debug_elapsed = 0.0
			print("MIC rms=", snappedf(_last_rms, 0.001),
				" avail=", _capture_effect.get_frames_available(),
				" sending=", sent_any
			)

# ============================
# HOST / JOIN
# ============================
func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("Host failed: " + str(err))
		return

	multiplayer.multiplayer_peer = peer
	_voice_network_ready = true
	print("Hosting on port ", PORT)

func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip, PORT)
	if err != OK:
		push_error("Join failed: " + str(err))
		return

	multiplayer.multiplayer_peer = peer
	_voice_network_ready = false
	print("Joining ", ip, ":", PORT)

# ============================
# SEND / RECEIVE VOICE
# ============================
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
		_voice_to_server.rpc_id(1, TARGET_VOICE_RATE, payload) # server is peer 1

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

	# Push as many frames as we have space for.
	var free_frames: int = int(playback.get_frames_available())
	if free_frames <= 0:
		return

	var sample_count: int = samples.size()
	var n: int = free_frames if free_frames < sample_count else sample_count

	for i in range(n):
		var s: float = samples[i]
		playback.push_frame(Vector2(s, s))

func _get_or_create_remote_playback(peer_id: int) -> AudioStreamGeneratorPlayback:
	if _remote_streams.has(peer_id):
		return _remote_streams[peer_id]["playback"] as AudioStreamGeneratorPlayback

	var player := AudioStreamPlayer.new()
	player.name = "RemoteVoice_%s" % str(peer_id)
	player.bus = "Master"

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = TARGET_VOICE_RATE
	generator.buffer_length = 0.4
	player.stream = generator

	add_child(player)
	player.play()

	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	_remote_streams[peer_id] = {"player": player, "playback": pb}
	return pb

func _remove_remote_stream(peer_id: int) -> void:
	if not _remote_streams.has(peer_id):
		return

	var player: AudioStreamPlayer = _remote_streams[peer_id]["player"] as AudioStreamPlayer
	if is_instance_valid(player):
		player.queue_free()

	_remote_streams.erase(peer_id)

# ============================
# MIC CAPTURE CHAIN
# ============================
func _setup_mic_capture_chain() -> void:
	var mic_bus_idx: int = AudioServer.get_bus_index(MIC_BUS_NAME)
	if mic_bus_idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		mic_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(mic_bus_idx, MIC_BUS_NAME)

	# Make mic bus silent; we just read capture effect.
	AudioServer.set_bus_volume_db(mic_bus_idx, -80.0)
	AudioServer.set_bus_send(mic_bus_idx, "Master")

	# Reuse existing capture effect if already present.
	_capture_effect = null
	var fx_count: int = AudioServer.get_bus_effect_count(mic_bus_idx)
	for i in range(fx_count):
		var fx: AudioEffect = AudioServer.get_bus_effect(mic_bus_idx, i)
		if fx is AudioEffectCapture:
			_capture_effect = fx as AudioEffectCapture
			break

	if _capture_effect == null:
		_capture_effect = AudioEffectCapture.new()
		_capture_effect.buffer_length = 0.5
		AudioServer.add_bus_effect(mic_bus_idx, _capture_effect, 0)

func _setup_mic_player() -> void:
	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicInputPlayer"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = MIC_BUS_NAME
	add_child(_mic_player)
	_mic_player.play()

# ============================
# MULTIPLAYER SIGNALS
# ============================
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
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	_remove_remote_stream(id)

func _on_connected_to_server() -> void:
	_voice_network_ready = true
	print("Connected to server as peer ", multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	_voice_network_ready = false
	print("Connection failed")

func _on_server_disconnected() -> void:
	_voice_network_ready = false
	print("Server disconnected")
	# Cleanup
	for k in _remote_streams.keys():
		_remove_remote_stream(int(k))

# ============================
# DEVICE / SETTINGS
# ============================
func _ensure_input_enabled() -> bool:
	var enabled: bool = bool(ProjectSettings.get_setting("audio/driver/enable_input"))
	if not enabled:
		push_error("Enable Project Settings > Audio > Driver > Enable Input, then restart editor.")
		return false
	return true

func _force_select_input_device() -> void:
	var devices: PackedStringArray = AudioServer.get_input_device_list()
	if devices.is_empty():
		print("No input devices visible to Godot.")
		return

	# Prefer built-in mic if present.
	var preferred: String = ""
	for d in devices:
		var device_name: String = String(d)
		var lower: String = device_name.to_lower()
		if lower.find("macbook") != -1 or lower.find("built") != -1:
			preferred = device_name
			break

	if preferred == "":
		preferred = String(devices[0])

	AudioServer.set_input_device(preferred)
	print("Selected input device:", AudioServer.get_input_device())

# ============================
# AUDIO UTILS
# ============================
func _encode_pcm16_mono(frames: PackedVector2Array, src_rate: int, dst_rate: int, gain: float) -> PackedByteArray:
	var out := PackedByteArray()
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
	var out := PackedFloat32Array()
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

# ============================
# OPTIONAL UI HOOKS
# (only used if you connect UI signals)
# ============================
func _on_host_pressed() -> void:
	host_game()

func _on_join_pressed() -> void:
	var ip_input := get_node_or_null("CanvasLayer/VBoxContainer/HBoxContainer/IpInput") as LineEdit
	var ip := "127.0.0.1"
	if ip_input != null and ip_input.text.strip_edges() != "":
		ip = ip_input.text.strip_edges()
	join_game(ip)

func _on_talk_toggled(toggled_on: bool) -> void:
	voice_enabled = toggled_on
