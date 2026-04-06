extends CanvasLayer

@onready var end_call_button: Button = %EndCallButton

func _ready() -> void:
	var is_therapist = Roles.user_role == Roles.Role.THERAPIST
	end_call_button.visible = is_therapist
	end_call_button.pressed.connect(_on_end_call_pressed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_end_call_pressed() -> void:
	if not multiplayer.is_server():
		return
	end_call_button.disabled = true
	GameState.end_call_session("Call session ended by therapist")
	
func _on_server_disconnected():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	GameState.return_to_home("The host ended the call.")
