extends Node

# =========================================================
# NO-UI VOICE CHAT (Godot 4.x)
# - ENet voice relay
# - Mic capture via AudioEffectCapture
# - Sends 16kHz mono PCM16
# - Plays back via AudioStreamGenerator per peer
#
# MULTI-INSTANCE FRIENDLY:
# - If you run multiple instances from Godot:
#     Instance #1 hosts, Instance #2+ joins 127.0.0.1
# - You can override with CLI:
#     --voice_host
#     --voice_client=IP
# =========================================================

const PORT: int = 7777
const MAX_CLIENTS: int = 16

const MIC_BUS_NAME: String = "MicCapture"
const CHUNK_SECONDS: float = 0.02
const TARGET_RATE: int = 16000

@export var voice_enabled: bool = true
@export var input_gain: float = 1.5
@export var debug_logs: bool = true
@export var debug_mic_every_sec: bool = true

# Default when auto-deciding client
@export var default_server_ip: String = "127.0.0.1"

var _capture: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null

var _mix_rate: int = 48000
var _chunk_frames: int = 960
var _network_ready: bool = false

var _debug_elapsed: float = 0.0
var _last_rms: float = 0.0

var _remote_players: Dictionary = {}   # peer_id -> AudioStreamPlayer
var _remote_playbacks: Dictionary = {} # peer_id -> AudioStreamGeneratorPlayback

func _ready() -> void:
	_wire_signals()

	await get_tree().process_frame

	# Audio input enabled?
	if not bool(ProjectSettings.get_setting("audio/driver/enable_input")):
		push_error("Enable Project Settings > Audio > Driver > Enable Input, then restart Godot.")
		# Still allow networking to run, but mic won't work.
	else:
		_force_select_input_device()
		_setup_mic()

	_mix_rate = int(AudioServer.get_mix_rate())
	_chunk_frames = max(1, int(round(float(_mix_rate) * CHUNK_SECONDS)))

	if debug_logs:
		print("Voice init | mix_rate=", _mix_rate, " chunk_frames=", _chunk_frames)

	_auto_start_network()

func _process(delta: float) -> void:
	if _capture == null:
		# Still print network state occasionally
		if debug_mic_every_sec:
			_debug_elapsed += delta
			if _debug_elapsed >= 1.0:
				_debug_elapsed = 0.0
				if debug_logs:
					print("No mic capture. net_ready=", _network_ready, " peers=", multiplayer.get_peers())
		return

	var sent_any: bool = false

	while _capture.get_frames_available() >= _chunk_frames:
		var frames: PackedVector2Array = _capture.get_buffer(_chunk_frames)
		if frames.is_empty():
			break

		_last_rms = _calc_rms(frames)

		if not voice_enabled:
			continue
		if not _network_ready:
			continue
		if multiplayer.multiplayer_peer == null:
			continue

		var payload: PackedByteArray = _encode(frames, _mix_rate, TARGET_RATE, input_gain)
		if payload.is_empty():
			continue

		_send(payload)
		sent_any = true

	if debug_mic_every_sec:
		_debug_elapsed += delta
		if _debug_elapsed >= 1.0:
			_debug_elapsed = 0.0
			if debug_logs:
				print(
					"MIC rms=", snappedf(_last_rms, 0.001),
					" sending=", sent_any,
					" net_ready=", _network_ready,
					" peers=", multiplayer.get_peers()
				)

# ============================
# AUTO START NETWORK
# ============================
func _auto_start_network() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()

	# Explicit CLI override
	for a in args:
		if a == "--voice_host":
			if debug_logs:
				print("CLI: host")
			host_game()
			return
		if a.begins_with("--voice_client="):
			var ip: String = a.split("=", false, 2)[1]
			if debug_logs:
				print("CLI: client -> ", ip)
			join_game(ip)
			return

	# Godot multiple instances: OS.get_process_id() differs, but not index.
	# Better: use feature tag set by Godot when running multiple instances:
	# It appends "--instance-id N" in args sometimes; we parse it.
	var instance_id: int = -1
	for a2 in args:
		if a2 == "--instance-id":
			# next arg should be the id
			# but cmdline comes as tokens; easiest safe fallback: ignore if missing
			pass
		if a2.begins_with("--instance-id="):
			instance_id = int(a2.split("=", false, 2)[1])
			break

	# If no instance-id provided, just default to HOST (single run)
	if instance_id == -1:
		if debug_logs:
			print("Auto: single instance -> HOST")
		host_game()
		return

	# Instance 1 hosts, others join
	if instance_id == 1:
		if debug_logs:
			print("Auto: instance 1 -> HOST")
		host_game()
	else:
		if debug_logs:
			print("Auto: instance ", instance_id, " -> CLIENT ", default_server_ip)
		join_game(default_server_ip)

# ============================
# HOST / JOIN
# ============================
func host_game() -> void:
	# If already hosting/joined, don't do it twice
	if multiplayer.multiplayer_peer != null:
		return

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		push_error("Couldn't create an ENet host. Host failed: " + str(err))
		return

	multiplayer.multiplayer_peer = peer
	_network_ready = true

	if debug_logs:
		print("Hosting on port ", PORT, " | my_peer_id=", multiplayer.get_unique_id())

func join_game(ip: String) -> void:
	# If already hosting/joined, don't do it twice
	if multiplayer.multiplayer_peer != null:
		return

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip, PORT)
	if err != OK:
		push_error("Join failed: " + str(err))
		return

	multiplayer.multiplayer_peer = peer
	_network_ready = false

	if debug_logs:
		print("Joining ", ip, ":", PORT)

# ============================
# SEND / RECEIVE
# ============================
func _send(payload: PackedByteArray) -> void:
	var mp: MultiplayerPeer = multiplayer.multiplayer_peer
	if mp == null:
		return
	if mp.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	if multiplayer.is_server():
		var sender_id: int = multiplayer.get_unique_id()
		for peer_id in multiplayer.get_peers():
			_voice_from_server.rpc_id(peer_id, sender_id, payload)
	else:
		_voice_to_server.rpc_id(1, payload)

@rpc("any_peer", "call_remote", "unreliable")
func _voice_to_server(payload: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	for peer_id in multiplayer.get_peers():
		if peer_id == sender_id:
			continue
		_voice_from_server.rpc_id(peer_id, sender_id, payload)

@rpc("authority", "call_remote", "unreliable")
func _voice_from_server(sender_id: int, payload: PackedByteArray) -> void:
	_play_remote(sender_id, payload)

# ============================
# PLAYBACK
# ============================
func _play_remote(sender_id: int, payload: PackedByteArray) -> void:
	var playback: AudioStreamGeneratorPlayback = _get_or_create_playback(sender_id)
	if playback == null:
		return

	var samples: PackedFloat32Array = _decode(payload)
	if samples.is_empty():
		return

	var free_frames: int = int(playback.get_frames_available())
	if free_frames <= 0:
		return

	var n: int = min(free_frames, samples.size())
	for i in range(n):
		var s: float = samples[i]
		playback.push_frame(Vector2(s, s))

	if debug_logs:
		print("Voice recv from ", sender_id, " bytes=", payload.size(), " pushed=", n)

func _get_or_create_playback(peer_id: int) -> AudioStreamGeneratorPlayback:
	if _remote_playbacks.has(peer_id):
		return _remote_playbacks[peer_id] as AudioStreamGeneratorPlayback

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "RemoteVoice_%s" % str(peer_id)
	player.bus = "Master"

	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = TARGET_RATE
	gen.buffer_length = 0.5

	player.stream = gen
	add_child(player)
	player.play()

	var pb: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback

	_remote_players[peer_id] = player
	_remote_playbacks[peer_id] = pb
	return pb

func _remove_remote(peer_id: int) -> void:
	if _remote_players.has(peer_id):
		var p: AudioStreamPlayer = _remote_players[peer_id] as AudioStreamPlayer
		if is_instance_valid(p):
			p.queue_free()
		_remote_players.erase(peer_id)

	if _remote_playbacks.has(peer_id):
		_remote_playbacks.erase(peer_id)

# ============================
# MIC SETUP
# ============================
func _setup_mic() -> void:
	var bus_idx: int = AudioServer.get_bus_index(MIC_BUS_NAME)
	if bus_idx == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, MIC_BUS_NAME)

	AudioServer.set_bus_volume_db(bus_idx, -80.0)
	AudioServer.set_bus_send(bus_idx, "Master")

	_capture = null
	var fx_count: int = AudioServer.get_bus_effect_count(bus_idx)
	for i in range(fx_count):
		var fx: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectCapture:
			_capture = fx as AudioEffectCapture
			break

	if _capture == null:
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(bus_idx, _capture, 0)

	_mic_player = AudioStreamPlayer.new()
	_mic_player.name = "MicInputPlayer"
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = MIC_BUS_NAME
	add_child(_mic_player)
	_mic_player.play()

func _force_select_input_device() -> void:
	var devices: PackedStringArray = AudioServer.get_input_device_list()
	if devices.is_empty():
		if debug_logs:
			print("No input devices visible to Godot.")
		return

	var preferred: String = ""
	for d in devices:
		var dev_name: String = String(d)
		var lower: String = dev_name.to_lower()
		if lower.find("macbook") != -1 or lower.find("built") != -1:
			preferred = dev_name
			break

	if preferred == "":
		preferred = String(devices[0])

	AudioServer.set_input_device(preferred)

	if debug_logs:
		print("Selected input device: ", AudioServer.get_input_device())

# ============================
# SIGNALS
# ============================
func _wire_signals() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_connected_to_server() -> void:
	_network_ready = true
	if debug_logs:
		print("Connected to server | my_peer_id=", multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	_network_ready = false
	if debug_logs:
		print("Connection failed")

func _on_server_disconnected() -> void:
	_network_ready = false
	if debug_logs:
		print("Server disconnected")
	for k in _remote_players.keys():
		_remove_remote(int(k))

func _on_peer_connected(id: int) -> void:
	if debug_logs:
		print("Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	if debug_logs:
		print("Peer disconnected: ", id)
	_remove_remote(id)

# ============================
# ENCODE / DECODE / RMS
# ============================
func _encode(frames: PackedVector2Array, src_rate: int, dst_rate: int, gain: float) -> PackedByteArray:
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

func _decode(payload: PackedByteArray) -> PackedFloat32Array:
	var count: int = int(payload.size() / 2)
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
