extends Node

@onready var record_button: Button = $RecordButton
@onready var upload_button: Button = $UploadButton
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var output_label: RichTextLabel = $OutputLabel
@onready var mic_player: AudioStreamPlayer = $MicPlayer

const API_URL := "http://127.0.0.1:8000/transcribe"
const RECORD_PATH := "user://recorded_audio.wav"

var record_effect: AudioEffectRecord
var recording: AudioStreamWAV = null

func _ready() -> void:
	record_button.pressed.connect(_on_record_button_pressed)
	upload_button.pressed.connect(_on_upload_button_pressed)
	http_request.request_completed.connect(_on_request_completed)

	var bus_index := AudioServer.get_bus_index("Record")
	if bus_index == -1:
		output_label.text = "Audio bus 'Record' not found."
		return

	record_effect = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectRecord
	if record_effect == null:
		output_label.text = "AudioEffectRecord not found on bus 'Record'."
		return

	output_label.text = "Ready to record."

func _on_record_button_pressed() -> void:
	if record_effect == null:
		output_label.text = "Recording effect not ready."
		return

	if record_effect.is_recording_active():
		record_effect.set_recording_active(false)
		recording = record_effect.get_recording()

		if recording == null:
			output_label.text = "No recording captured."
			return

		recording.save_to_wav(RECORD_PATH)
		record_button.text = "Record"
		output_label.text = "Recording saved to " + RECORD_PATH
	else:
		recording = null
		mic_player.play()
		record_effect.set_recording_active(true)
		record_button.text = "Stop"
		output_label.text = "Recording..."

func _on_upload_button_pressed() -> void:
	if not FileAccess.file_exists(RECORD_PATH):
		output_label.text = "Recorded file not found: " + RECORD_PATH
		return

	var audio_bytes: PackedByteArray = FileAccess.get_file_as_bytes(RECORD_PATH)
	if audio_bytes.is_empty():
		output_label.text = "Failed to read recorded audio file."
		return

	var boundary := "----GodotBoundary7MA4YWxkTrZu0gW"
	var body := PackedByteArray()

	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(('Content-Disposition: form-data; name="file"; filename="recorded_audio.wav"\r\n').to_utf8_buffer())
	body.append_array(("Content-Type: audio/wav\r\n\r\n").to_utf8_buffer())
	body.append_array(audio_bytes)
	body.append_array(("\r\n").to_utf8_buffer())

	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(('Content-Disposition: form-data; name="diarize"\r\n\r\n').to_utf8_buffer())
	body.append_array(("true\r\n").to_utf8_buffer())

	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())

	var headers := PackedStringArray([
		"Accept: application/json",
		"Content-Type: multipart/form-data; boundary=" + boundary
	])

	var err := http_request.request_raw(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		output_label.text = "Request failed to start. Error code: " + str(err)
	else:
		output_label.text = "Uploading recording..."

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text := body.get_string_from_utf8()

	if response_code != 200:
		output_label.text = "HTTP " + str(response_code) + "\n" + response_text
		return

	var json := JSON.new()
	var parse_result := json.parse(response_text)
	if parse_result != OK:
		output_label.text = "Failed to parse JSON:\n" + response_text
		return

	var data: Dictionary = json.data
	output_label.text = _format_transcript(data)

func _format_transcript(data: Dictionary) -> String:
	var lines: Array[String] = []

	if data.has("speaker_segments"):
		for seg in data["speaker_segments"]:
			lines.append("%s: %s" % [seg.get("speaker", "UNKNOWN"), seg.get("text", "")])
	else:
		lines.append(data.get("text", ""))

	return "\n\n".join(lines)
	
#extends Control
#
#func _ready() -> void:
	#print("scene started")
