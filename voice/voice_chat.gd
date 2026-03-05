# res://voice/voice_chat.gd
extends Node
class_name VoiceChat

# ============================================================
# Voice Chat (Godot 4.5.x) - INTEGRATED WITH YOUR EXISTING ENET
# - DOES NOT create server/client peers
# - Reuses multiplayer.multiplayer_peer created by HighLevelNetworkExample
# - Client -> Server: send mic packets
# - Server -> Clients: relay packets to everyone except speaker
# - Capture: AudioStreamMicrophone + AudioEffectCapture
# - Playback: AudioStreamGenerator per speaker_id
# ============================================================

@export var voice_enabled: bool = true
@export var mic_enabled: bool = true              # controls SENDING only (client + server mic)
@export var auto_enable_mic_on_client_connect: bool = true

@export var input_gain: float = 1.5
@export var send_hz: int = 30
@export var max_packet_samples: int = 960
@export var debug_logs: bool = true
@export var debug_hud: bool = true

const MIC_BUS_NAME: String = "Mic"
const MIC_PLAYER_NAME: String = "MicPlayer"
const PLAYBACK_BUS_NAME: String = "Master"

var _mix_rate: float = 48000.0
var _samples_per_packet: int = 960
var _send_accum: float = 0.0

var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _mic_bus_index: int = -1

var _last_rms: float = 0.0
var _has_audio_input: bool = false

# speaker_id -> AudioStreamPlayer / GeneratorPlayback
var _players: Dictionary = {}
var _playbacks: Dictionary = {}

# HUD
var _hud_layer: CanvasLayer
var _hud_label: Label
var _hud_accum: float = 0.0
var _hud_interval: float = 0.2

func _ready() -> void:
	_mix_rate = float(AudioServer.get_mix_rate())
	_setup_audio_capture()
	_setup_packet_sizing()
	if debug_hud:
		_setup_hud()

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_log("VoiceChat ready. Waiting for HighLevelNetworkExample to set multiplayer.multiplayer_peer...")

func _process(delta: float) -> void:
	if debug_hud:
		_update_hud(delta)

	if not voice_enabled:
		return
	if not mic_enabled:
		return

	# IMPORTANT: HighLevelNetworkExample must have set this already
	if multiplayer.multiplayer_peer == null:
		return

	# If client, only send when actually connected
	if not multiplayer.is_server():
		var mp: MultiplayerPeer = multiplayer.multiplayer_peer
		if mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return

	_send_accum += delta
	var interval: float = 1.0 / float(max(1, send_hz))
	if _send_accum < interval:
		return
	_send_accum = 0.0

	_capture_and_send()

# ============================================================
# PUBLIC API
# ============================================================

func set_mic_enabled(enabled: bool) -> void:
	mic_enabled = enabled
	_log("mic_enabled=%s" % str(mic_enabled))

func set_voice_enabled(enabled: bool) -> void:
	voice_enabled = enabled
	_log("voice_enabled=%s" % str(voice_enabled))

# ============================================================
# AUDIO CAPTURE
# ============================================================

func _setup_packet_sizing() -> void:
	if send_hz <= 0:
		send_hz = 30
	_samples_per_packet = int(_mix_rate / float(send_hz))
	if _samples_per_packet < 160:
		_samples_per_packet = 160
	if _samples_per_packet > max_packet_samples:
		_samples_per_packet = max_packet_samples

	_log("mix_rate=%s, send_hz=%d, samples_per_packet=%d" % [str(_mix_rate), send_hz, _samples_per_packet])

func _setup_audio_capture() -> void:
	_mic_bus_index = AudioServer.get_bus_index(MIC_BUS_NAME)
	if _mic_bus_index == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		_mic_bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(_mic_bus_index, MIC_BUS_NAME)

	_capture = null
	var effect_count: int = AudioServer.get_bus_effect_count(_mic_bus_index)
	if effect_count == 0:
		var cap: AudioEffectCapture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(_mic_bus_index, cap, 0)
		_capture = cap
	else:
		var e0: AudioEffect = AudioServer.get_bus_effect(_mic_bus_index, 0)
		if e0 is AudioEffectCapture:
			_capture = e0 as AudioEffectCapture
		else:
			var cap2: AudioEffectCapture = AudioEffectCapture.new()
			AudioServer.add_bus_effect(_mic_bus_index, cap2, 0)
			_capture = cap2

	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = MIC_PLAYER_NAME
	add_child(_mic_player)

	var mic_stream := AudioStreamMicrophone.new()
	_mic_player.stream = mic_stream
	_mic_player.bus = MIC_BUS_NAME

	# Do not hear yourself (capture-only)
	AudioServer.set_bus_mute(_mic_bus_index, true)

	_mic_player.play()
	_log("Mic capture set. Ensure ProjectSettings: audio/driver/enable_input = true and OS mic permission is allowed.")

# ============================================================
# CAPTURE + SEND (NO PEER CREATION HERE)
# ============================================================

func _capture_and_send() -> void:
	if _capture == null:
		return

	var available: int = _capture.get_frames_available()
	if available <= 0:
		_last_rms = 0.0
		_has_audio_input = false
		return

	var frames_to_get: int = min(available, _samples_per_packet)
	var frames: PackedVector2Array = _capture.get_buffer(frames_to_get)
	if frames.is_empty():
		_last_rms = 0.0
		_has_audio_input = false
		return

	_has_audio_input = true

	# Mono + gain
	var mono: PackedFloat32Array = PackedFloat32Array()
	mono.resize(frames.size())

	var sum_sq: float = 0.0
	var i: int = 0
	for v in frames:
		var s: float = ((v.x + v.y) * 0.5) * input_gain
		s = clamp(s, -1.0, 1.0)
		mono[i] = s
		sum_sq += s * s
		i += 1

	_last_rms = sqrt(sum_sq / float(max(1, mono.size())))
	var payload: PackedByteArray = _encode_pcm16(mono)

	var my_id: int = multiplayer.get_unique_id()

	# If server: broadcast directly with speaker_id = my_id
	# If client: send to server (peer 1) with speaker_id = my_id
	if multiplayer.is_server():
		for pid in multiplayer.get_peers():
			var target: int = int(pid)
			if target == my_id:
				continue
			rpc_id(target, "_rpc_voice", my_id, payload)
	else:
		if my_id != 1:
			rpc_id(1, "_rpc_voice", my_id, payload)

# ============================================================
# RECEIVE + RELAY
# ============================================================

@rpc("any_peer", "unreliable")
func _rpc_voice(speaker_id: int, payload: PackedByteArray) -> void:
	if not voice_enabled:
		return
	if speaker_id <= 0:
		return
	if payload.is_empty():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()

	# Server: validate and relay
	if multiplayer.is_server():
		# Only accept if claimed speaker matches sender (prevents spoofing)
		if sender_id != speaker_id:
			_log("Dropped spoofed voice packet sender=%d speaker_id=%d" % [sender_id, speaker_id])
			return

		# Optional: server can also hear everyone (comment out if you don't want this)
		_play_voice(speaker_id, payload)

		for pid in multiplayer.get_peers():
			var target: int = int(pid)
			if target == speaker_id:
				continue
			rpc_id(target, "_rpc_voice", speaker_id, payload)
		return

	# Client: only accept packets from server (peer 1)
	if sender_id != 1:
		return

	_play_voice(speaker_id, payload)

func _play_voice(speaker_id: int, payload: PackedByteArray) -> void:
	var samples: PackedFloat32Array = _decode_pcm16(payload)
	if samples.is_empty():
		return

	_ensure_playback_for_speaker(speaker_id)

	var pb: AudioStreamGeneratorPlayback = _playbacks.get(speaker_id, null) as AudioStreamGeneratorPlayback
	if pb == null:
		return

	var out: PackedVector2Array = PackedVector2Array()
	out.resize(samples.size())

	var idx: int = 0
	for s in samples:
		out[idx] = Vector2(s, s)
		idx += 1

	pb.push_buffer(out)

func _ensure_playback_for_speaker(speaker_id: int) -> void:
	if _playbacks.has(speaker_id):
		return

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _mix_rate
	gen.buffer_length = 0.25

	var p := AudioStreamPlayer.new()
	p.bus = PLAYBACK_BUS_NAME
	p.stream = gen
	add_child(p)
	p.play()

	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback

	_players[speaker_id] = p
	_playbacks[speaker_id] = pb
	_log("Playback created for speaker %d" % speaker_id)

func _remove_playback_for_speaker(speaker_id: int) -> void:
	if not _players.has(speaker_id):
		return

	var p: AudioStreamPlayer = _players[speaker_id] as AudioStreamPlayer
	if p != null and is_instance_valid(p):
		p.stop()
		p.queue_free()

	_players.erase(speaker_id)
	_playbacks.erase(speaker_id)
	_log("Playback removed for speaker %d" % speaker_id)

# ============================================================
# PCM16 ENCODE/DECODE
# ============================================================

func _encode_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(samples.size() * 2)

	var w: int = 0
	for s in samples:
		var clamped: float = clamp(s, -1.0, 1.0)
		var v: int = int(round(clamped * 32767.0))
		if v < -32768:
			v = -32768
		if v > 32767:
			v = 32767

		var u: int = v & 0xFFFF
		out[w] = u & 0xFF
		out[w + 1] = (u >> 8) & 0xFF
		w += 2

	return out

func _decode_pcm16(payload: PackedByteArray) -> PackedFloat32Array:
	var nbytes: int = payload.size()
	if nbytes < 2:
		return PackedFloat32Array()

	var count: int = int(nbytes / 2)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)

	var j: int = 0
	var i: int = 0
	while i + 1 < nbytes:
		var lo: int = int(payload[i])
		var hi: int = int(payload[i + 1]) << 8
		var u: int = lo | hi
		var s: int = u if u < 32768 else (u - 65536)
		out[j] = float(s) / 32768.0
		i += 2
		j += 1

	return out

# ============================================================
# MULTIPLAYER EVENTS
# ============================================================

func _on_peer_disconnected(id: int) -> void:
	_remove_playback_for_speaker(id)

func _on_connected_to_server() -> void:
	_log("connected_to_server")
	if auto_enable_mic_on_client_connect:
		mic_enabled = true
		_log("auto_enable_mic_on_client_connect -> mic_enabled=true")

func _on_connection_failed() -> void:
	_log("connection_failed")

func _on_server_disconnected() -> void:
	_log("server_disconnected")

# ============================================================
# HUD
# ============================================================

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)

	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 12)
	_hud_label.text = "VoiceChat..."
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hud_layer.add_child(_hud_label)

func _update_hud(delta: float) -> void:
	_hud_accum += delta
	if _hud_accum < _hud_interval:
		return
	_hud_accum = 0.0

	var role_str: String = "SERVER" if multiplayer.is_server() else "CLIENT"
	var conn_str: String = "-"
	var peers_count: int = 0
	var uid_str: String = "-"

	if multiplayer.multiplayer_peer != null:
		uid_str = str(multiplayer.get_unique_id())
		peers_count = int(multiplayer.get_peers().size())

		var st: int = multiplayer.multiplayer_peer.get_connection_status()
		if st == MultiplayerPeer.CONNECTION_DISCONNECTED:
			conn_str = "DISCONNECTED"
		elif st == MultiplayerPeer.CONNECTION_CONNECTING:
			conn_str = "CONNECTING"
		elif st == MultiplayerPeer.CONNECTION_CONNECTED:
			conn_str = "CONNECTED"
		else:
			conn_str = str(st)

	var hint: String = ""
	if mic_enabled and (_has_audio_input == false or _last_rms <= 0.0001):
		hint = "\n(If RMS stays 0.000 -> ProjectSettings audio/driver/enable_input + OS mic permission)"

	_hud_label.text = (
		"VOICE (INTEGRATED)\n"
		+ "Role: %s\n" % role_str
		+ "UniqueID: %s\n" % uid_str
		+ "Conn: %s\n" % conn_str
		+ "Peers: %d\n" % peers_count
		+ "voice_enabled: %s\n" % str(voice_enabled)
		+ "mic_enabled: %s\n" % str(mic_enabled)
		+ "RMS: %.3f\n" % _last_rms
		+ hint
	)

# ============================================================
# LOG
# ============================================================

func _log(msg: String) -> void:
	if debug_logs:
		print("[VoiceChat] ", msg)
