extends Node3D

const IP_ADDRESS: String = "localhost"
const PORT = 7001


var peer = ENetMultiplayerPeer.new()

func start_server():
	# Check if a peer already exists to avoid the "null host" error
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer = null 
		
	var error = peer.create_server(PORT, 2)
	if error != OK:
		print("Failed to host: ", error)
		return
	multiplayer.multiplayer_peer = peer

func start_client():
	# 1. Clear any existing connection first
	multiplayer.multiplayer_peer = null
	
	# 2. Create a FRESH instance of the peer
	peer = ENetMultiplayerPeer.new()
	
	# 3. Now attempt to create the client
	var error = peer.create_client(IP_ADDRESS, PORT)
	
	if error != OK:
		print("Failed to connect: ", error)
		return
		
	multiplayer.multiplayer_peer = peer
