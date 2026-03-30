extends Node

const BROADCAST_PORT = 5555

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var udp_broadcaster: PacketPeerUDP = PacketPeerUDP.new()
var udp_listener: PacketPeerUDP = PacketPeerUDP.new()

var broadcast_timer: Timer = Timer.new()
var server_list: Array[String] = []

signal cleanup_players()
signal server_found(server_name: String)

func _ready() -> void:
    add_child(broadcast_timer)
    broadcast_timer.wait_time = 1.0
    broadcast_timer.timeout.connect(_on_broadcast_timer_timeout)

func start_host(max_clients: int = 2, port: int = 7001) -> void:
    peer = ENetMultiplayerPeer.new() # Create a fresh instance here
    var error = peer.create_server(port, max_clients)
    if error != OK:
        print("Failed to host: ", error)
        return
    multiplayer.multiplayer_peer = peer
    udp_broadcaster.set_broadcast_enabled(true)
    udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)

    broadcast_timer.start()
    # multiplayer.peer_connected.connect(_on_peer_connected)

func join_session(ip: String, port: int) -> void:
    peer = ENetMultiplayerPeer.new() # Create a fresh instance here
    var error = peer.create_client(ip, port)
    if error != OK:
        print("Failed to join: ", error)
        return
    multiplayer.multiplayer_peer = peer

    if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
        multiplayer.server_disconnected.connect(_on_server_disconnected)
    
    udp_listener.close()

func stop_host():
    broadcast_timer.stop()
    if udp_broadcaster:
        udp_broadcaster.close()
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null

    cleanup_players.emit()

func leave_session():
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    
    # Clean up players
    cleanup_players.emit()

func _on_server_disconnected():
    cleanup_players.emit()

func _on_broadcast_timer_timeout() -> void:
    if udp_broadcaster and udp_broadcaster.is_bound():
        var data = {
            "name": "VR Therapy Session"
        }
        udp_broadcaster.put_packet(JSON.stringify(data).to_utf8_buffer())
    
func start_listening() -> void:
    var error = udp_listener.bind(BROADCAST_PORT) # Start hearing the megaphone
    if error != OK:
        printerr("Failed to bind listener to port ", BROADCAST_PORT, ": ", error)
        return
    server_list.clear()

func listen_for_servers() -> void:
    var packet = udp_listener.get_packet().get_string_from_utf8()
    var server_info = JSON.parse_string(packet)
    if server_info.has("name"):
        var server_name = server_info["name"]
        server_list.append(server_name)
        server_found.emit(server_name)
    else:
        printerr("Invalid server info received")