extends Control

var effect
var recording


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# We get the index of the "Record" bus.
	var idx = AudioServer.get_bus_index("Record")
	print(idx)
	# And use it to retrieve its first effect, which has been defined
	# as an "AudioEffectRecord" resource.
	effect = AudioServer.get_bus_effect(idx, 0)
	
func _on_record_button_pressed():
	if effect.is_recording_active():
		recording = effect.get_recording()
		$VBoxContainer/Play.disabled = false
		$VBoxContainer/Save.disabled = false
		effect.set_recording_active(false)
		$VBoxContainer/Record.text = "Record"
		$VBoxContainer/Status.text = ""
	else:
		$VBoxContainer/Play.disabled = true
		$VBoxContainer/Save.disabled = true
		effect.set_recording_active(true)
		$VBoxContainer/Record.text = "Stop"
		$VBoxContainer/Status.text = "Recording..."
		
func _on_play_button_pressed():
	print(recording)
	print(recording.format)
	print(recording.mix_rate)
	print(recording.stereo)
	var data = recording.get_data()
	print(data.size())
	$Player.stop()
	$Player.stream = null   # force refresh
	$Player.stream = recording
	$Player.volume_db = 20
	$Player.play()
	
func _on_save_button_pressed():
	var save_path = "blob"
	recording.save_to_wav(save_path)
	$VBoxContainer/Status.text = "Saved WAV file to: %s\n(%s)" % [save_path, ProjectSettings.globalize_path(save_path)]
