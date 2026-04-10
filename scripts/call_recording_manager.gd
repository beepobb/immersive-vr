extends RefCounted

const RECORD_BUS_NAME := "Record"
const RECORDINGS_DIR := "user://recordings"

var _effect: AudioEffectRecord
var _is_started: bool = false

func start_if_host(is_host_therapist: bool) -> void:
	if _is_started:
		return
	if not is_host_therapist:
		return

	_effect = _find_record_effect()
	if _effect == null:
		push_error("CallRecordingManager: AudioEffectRecord not found on Record bus")
		return

	_ensure_recordings_dir()
	_effect.set_recording_active(true)
	_is_started = true

func stop_and_save_if_host(is_host_therapist: bool) -> Dictionary:
	if not is_host_therapist:
		return {"recording": null, "path": ""}
	if not _is_started:
		return {"recording": null, "path": ""}
	if _effect == null:
		_is_started = false
		return {"recording": null, "path": ""}

	_effect.set_recording_active(false)
	var recording := _effect.get_recording()
	_is_started = false

	if recording == null:
		return {"recording": null, "path": ""}

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var wav_path := "%s/call_%s.wav" % [RECORDINGS_DIR, timestamp]
	var err := recording.save_to_wav(wav_path)
	if err != OK:
		push_error("CallRecordingManager: failed to save recording to %s (err=%d)" % [wav_path, err])
		return {"recording": recording, "path": ""}

	return {"recording": recording, "path": wav_path}

func reset() -> void:
	if _effect != null and _effect.is_recording_active():
		_effect.set_recording_active(false)
	_is_started = false
	_effect = null

func _find_record_effect() -> AudioEffectRecord:
	var bus_index := AudioServer.get_bus_index(RECORD_BUS_NAME)
	if bus_index < 0:
		return null

	var effect_count := AudioServer.get_bus_effect_count(bus_index)
	for i in range(effect_count):
		var effect := AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectRecord:
			return effect as AudioEffectRecord
	return null

func _ensure_recordings_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(RECORDINGS_DIR)
	if DirAccess.dir_exists_absolute(absolute_dir):
		return
	DirAccess.make_dir_recursive_absolute(absolute_dir)
