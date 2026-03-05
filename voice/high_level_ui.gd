# res://voice/high_level_ui.gd  (your button script)
extends Control

@onready var voice_chat: VoiceChat = $"VoiceChat" as VoiceChat

func _on_server_pressed() -> void:
	HighLevelNetworkExample.start_server()
	voice_chat.set_mic_enabled(true)

func _on_client_pressed() -> void:
	HighLevelNetworkExample.start_client()
	multiplayer.connected_to_server.connect(_on_client_connected_once, CONNECT_ONE_SHOT)

func _on_client_connected_once() -> void:
	voice_chat.set_mic_enabled(true)
	
