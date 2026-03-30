extends CanvasLayer

@onready var end_call_button: Button = %EndCallButton

func _ready() -> void:
	var is_therapist = Roles.user_role == Roles.Role.THERAPIST
	end_call_button.visible = is_therapist
	end_call_button.pressed.connect(_on_end_call_pressed)

func _on_end_call_pressed() -> void:
	if Roles.user_role != Roles.Role.THERAPIST:
		return

	HighLevelNetworkHandler.stop_host()
