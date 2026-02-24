extends Node
class_name VoiceChat

# ============================================================
# Voice Chat (Godot 4.5.x)
# - ENet host/client
# - Mic capture via AudioStreamMicrophone + AudioEffectCapture
# - Unreliable RPC audio packets
# - Simple on-screen HUD for debugging
# ============================================================

enum AutoStartMode { NONE, HOST, CLIENT }

@export var auto_start_mode: AutoStartMode = AutoStartMode.NONE
@export var server_ip: String = "127.0.0.1"
@export var server_port: int = 7777
@export var max_clients: int = 16

@export var voice_enabled: bool = true
@export var input_gain: float = 1.5
@export var debug_logs: bool = true
@export var debug_mic_rms: bool = true

@export var send_hz: int = 30                 # packets per second (20-50 ok)
@export var max_packet_samples: int = 960     # safety cap per packet (48kHz ~20ms)

const MIC_BUS_NAME: String = "Mic"
const MIC_PLAYER_NAME: String = "MicPlayer"
const PLAYBACK_BUS_NAME: String = "Master"

# ---------- Networking ----------
var _is_host: bool = false
var _peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

# ---------- Audio capture ----------
var _mic_player: AudioStreamPlayer = AudioStreamPlayer.new()
var _capture: AudioEffectCapture
var _mic_bus_index: int = -1
var _mix_rate: float = 48000.0

var _send_accum: float = 0.0
var _samples_per_packet: int = 960

var _last_rms: float = 0.0
var _has_audio_input: bool = false

# ---------- Audio playback per remote peer ----------
var _playbacks: Dictionary = {}          # int(peer_id) -> AudioStreamGeneratorPlayback
var _generators: Dictionary = {}         # int(peer_id) -> AudioStreamGenerator
var _players: Dictionary = {}            # int(peer_id) -> AudioStreamPlayer

# ---------- HUD ----------
var _hud_layer: CanvasLayer
var _hud_label: Label
var _hud_accum: float = 0.0
var _hud_interval: float = 0.2

func _ready() -> void:
	_mix_rate = float(AudioServer.get_mix_rate())
	_setup_hud()
	_print("VoiceChat booting... mix_rate=%s" % str(_mix_rate))

	# Signals (safe even before peer assigned)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_setup_audio_capture()

	# Packet sizing
	if send_hz <= 0:
		send_hz = 30
	_samples_per_packet = int(_mix_rate / float(send_hz))
	if _samples_per_packet < 160:
		_samples_per_packet = 160
	if _samples_per_packet > max_packet_samples:
		_samples_per_packet = max_packet_samples

	_print("samples_per_packet=%d (send_hz=%d)" % [_samples_per_packet, send_hz])

	# Auto start if set in Inspector
	match auto_start_mode:
		AutoStartMode.HOST:
			host()
		AutoStartMode.CLIENT:
			join(server_ip, server_port)
		_:
			pass

func _process(delta: float) -> void:
	_update_hud(delta)

	if not voice_enabled:
		return

	# Must have multiplayer peer assigned
	if multiplayer.multiplayer_peer == null:
		return

	# Client: only send when connected
	if not _is_host:
		var mp: MultiplayerPeer = multiplayer.multiplayer_peer
		if mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return

	_send_accum += delta
	var interval: float = 1.0 / float(send_hz)
	if _send_accum < interval:
		return
	_send_accum = 0.0

	_capture_and_send()

# ============================================================
# PUBLIC API
# ============================================================

func host() -> void:
	_is_host = true

	var err: Error = _peer.create_server(server_port, max_clients)
	if err != OK:
		_print("HOST FAILED: create_server(%d) -> %s" % [server_port, str(err)])
		return

	multiplayer.multiplayer_peer = _peer
	_print("HOST OK on 0.0.0.0:%d" % server_port)

func join(ip: String, port: int) -> void:
	_is_host = false

	var err: Error = _peer.create_client(ip, port)
	if err != OK:
		_print("CLIENT FAILED: create_client(%s:%d) -> %s" % [ip, port, str(err)])
		return

	multiplayer.multiplayer_peer = _peer
	_print("CLIENT connecting to %s:%d ..." % [ip, port])

# ============================================================
# AUDIO CAPTURE SETUP
# ============================================================

func _setup_audio_capture() -> void:
	# Ensure Mic bus exists
	_mic_bus_index = AudioServer.get_bus_index(MIC_BUS_NAME)
	if _mic_bus_index == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		_mic_bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(_mic_bus_index, MIC_BUS_NAME)

	# Ensure capture effect exists on Mic bus (slot 0)
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

	# Mic player that feeds into Mic bus
	_mic_player.name = MIC_PLAYER_NAME
	add_child(_mic_player)

	var mic_stream: AudioStreamMicrophone = AudioStreamMicrophone.new()
	_mic_player.stream = mic_stream
	_mic_player.bus = MIC_BUS_NAME

	# Do not hear ourselves
	AudioServer.set_bus_mute(_mic_bus_index, true)

	_mic_player.play()
	_print("Mic capture setup done. (Enable ProjectSettings: audio/driver/enable_input)")

# ============================================================
# CAPTURE + SEND
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

	# Convert to mono floats + gain
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

	var my_id: int = 0
	if multiplayer.multiplayer_peer != null:
		my_id = multiplayer.get_unique_id()

	if _is_host:
		# Send to all peers except self (extra safety)
		var peers: PackedInt32Array = _get_connected_peers()
		for pid in peers:
			var target: int = int(pid)
			if target == my_id:
				continue
			rpc_id(target, "_rpc_voice", payload)
	else:
		# Client sends to server (peer_id 1) — but never to self
		if my_id != 1:
			rpc_id(1, "_rpc_voice", payload)

# ============================================================
# RPC RECEIVE (UNRELIABLE)
# IMPORTANT: call_local allows local execution if an RPC ever targets self.
# ============================================================

@rpc("any_peer", "unreliable", "call_local")
func _rpc_voice(payload: PackedByteArray) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		return

	var samples: PackedFloat32Array = _decode_pcm16(payload)
	if samples.is_empty():
		return

	_ensure_playback_for_peer(sender_id)

	var playback: AudioStreamGeneratorPlayback = _playbacks.get(sender_id, null) as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var out: PackedVector2Array = PackedVector2Array()
	out.resize(samples.size())

	var idx: int = 0
	for s in samples:
		out[idx] = Vector2(s, s)
		idx += 1

	playback.push_buffer(out)

# ============================================================
# PLAYBACK PER PEER
# ============================================================

func _ensure_playback_for_peer(peer_id: int) -> void:
	if _playbacks.has(peer_id):
		return

	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = _mix_rate
	gen.buffer_length = 0.25

	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.bus = PLAYBACK_BUS_NAME
	p.stream = gen
	add_child(p)
	p.play()

	var pb: AudioStreamGeneratorPlayback = p.get_stream_playback() as AudioStreamGeneratorPlayback

	_generators[peer_id] = gen
	_players[peer_id] = p
	_playbacks[peer_id] = pb

	_print("Playback created for peer %d" % peer_id)

func _remove_playback_for_peer(peer_id: int) -> void:
	if not _players.has(peer_id):
		return

	var p: AudioStreamPlayer = _players[peer_id] as AudioStreamPlayer
	if p != null and is_instance_valid(p):
		p.stop()
		p.queue_free()

	_players.erase(peer_id)
	_generators.erase(peer_id)
	_playbacks.erase(peer_id)

	_print("Playback removed for peer %d" % peer_id)

# ============================================================
# ENCODING (PCM16)
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
# PEERS / SIGNALS
# ============================================================

func _get_connected_peers() -> PackedInt32Array:
	if multiplayer.multiplayer_peer == null:
		return PackedInt32Array()
	return multiplayer.get_peers()

func _on_peer_connected(id: int) -> void:
	_print("peer_connected: %d" % id)

func _on_peer_disconnected(id: int) -> void:
	_print("peer_disconnected: %d" % id)
	_remove_playback_for_peer(id)

func _on_connected_to_server() -> void:
	_print("connected_to_server")

func _on_connection_failed() -> void:
	_print("connection_failed")

func _on_server_disconnected() -> void:
	_print("server_disconnected")

# ============================================================
# HUD
# ============================================================

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)

	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 12)
	_hud_label.text = "VoiceChat booting..."
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hud_layer.add_child(_hud_label)

func _update_hud(delta: float) -> void:
	_hud_accum += delta
	if _hud_accum < _hud_interval:
		return
	_hud_accum = 0.0

	var role_str: String = "HOST" if _is_host else "CLIENT"
	var peers_count: int = 0
	var conn_str: String = "-"

	if multiplayer.multiplayer_peer != null:
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

	var rms_str: String = "%.3f" % _last_rms
	var hint: String = ""
	if debug_mic_rms and (_has_audio_input == false or _last_rms <= 0.0001):
		hint = "\n(If RMS stays 0.000 -> ProjectSettings audio/driver/enable_input + OS mic permission)"

	_hud_label.text = (
		"VOICE SCRIPT RUNNING\n"
		+ "Role: %s\n" % role_str
		+ "UniqueID: %s\n" % (str(multiplayer.get_unique_id()) if multiplayer.multiplayer_peer != null else "-")
		+ "Server: %s:%d\n" % [server_ip, server_port]
		+ "Conn: %s\n" % conn_str
		+ "Peers: %d\n" % peers_count
		+ "RMS: %s\n" % rms_str
		+ hint
	)

# ============================================================
# LOG
# ============================================================

func _print(msg: String) -> void:
	if debug_logs:
		print("[VoiceChat] ", msg)
