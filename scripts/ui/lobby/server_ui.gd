extends VBoxContainer

# Target scene name
@export_file("*.tscn") var target_scene: String
var peer = ENetMultiplayerPeer.new()

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func start_server():
	multiplayer.multiplayer_peer = null
	peer.create_server(7001, 1)
	multiplayer.multiplayer_peer = peer
	print("Server created")
	
func start_client():
	multiplayer.multiplayer_peer = null
	peer.create_client("localhost", 7001)
	multiplayer.multiplayer_peer = peer
	
func _on_host_pressed() -> void:
	start_server()
	_load_lobby()

func _on_join_pressed() -> void:
	start_client()
	# Don't load lobby yet - wait for connected_to_server signal

func _on_peer_connected(peer_id: int) -> void:
	# When a peer connects to the server, let room_info know
	print("Peer connected: ", peer_id)

func _on_connected_to_server() -> void:
	# Client has connected to server - now load the lobby
	print("Connected to server!")
	_load_lobby()

func _load_lobby() -> void:
	# Skip if no target scene set
	if not target_scene or target_scene == "":
		print("ERROR: target_scene not set!")
		return
	
	print("Loading lobby: ", target_scene)
	# Find the XRToolsSceneBase this node is a child of
	var scene_base: XRToolsSceneBase = XRTools.find_xr_ancestor(self , "*", "XRToolsSceneBase")
	if not scene_base:
		print("ERROR: Could not find XRToolsSceneBase ancestor!")
		return
	
	# Start loading the target scene
	scene_base.load_scene(target_scene)
