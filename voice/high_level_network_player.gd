extends CharacterBody2D

const SPEED: float = 500.0
const VOICE_SEND_INTERVAL: float = 0.25

@onready var voice_player: AudioStreamPlayer = $VoicePlayer
@onready var voice_send_timer: Timer = $VoiceSendTimer

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	voice_send_timer.wait_time = VOICE_SEND_INTERVAL

	if !voice_send_timer.timeout.is_connected(_on_voice_send_timer_timeout):
		voice_send_timer.timeout.connect(_on_voice_send_timer_timeout)

func _physics_process(_delta: float) -> void:
	if !is_multiplayer_authority():
		return

	velocity = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * SPEED
	move_and_slide()

func _on_voice_send_timer_timeout() -> void:
	pass
