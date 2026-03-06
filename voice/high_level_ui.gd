extends Control

func _on_server_pressed() -> void:
	HighLevelNetworkExample.start_server()

func _on_client_pressed() -> void:
	HighLevelNetworkExample.start_client()
