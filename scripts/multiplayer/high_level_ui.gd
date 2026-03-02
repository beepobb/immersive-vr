extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
func _on_server_pressed() -> void:
	HighLevelNetworkHandler.start_server()
	get_node("/root/MultiplayerTest/MultiplayerSpawner").spawn_player(1)


func _on_client_pressed() -> void:
	HighLevelNetworkHandler.start_client()
