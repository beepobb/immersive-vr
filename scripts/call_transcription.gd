extends RefCounted

const DOWNLOADS_DIR := "user://recordings"
const OUTPUT_DIR := "user://documents"
const API_URL := "http://127.0.0.1:8000/transcribe-docx"

const AUDIO_EXTENSIONS := ["wav"]

func _ready() -> void:
	print("Scene started.")
	process_latest_recording()


func process_latest_recording(input_file_path: String = "") -> void:
	var latest_file: String
	if input_file_path == "":
		latest_file = get_latest_audio_file(DOWNLOADS_DIR)

		if latest_file.is_empty():
			push_error("No audio file found in: " + DOWNLOADS_DIR)
			return
	else:
		latest_file = input_file_path
		print("Latest file: ", latest_file)

	var output_path := build_output_docx_path(latest_file)
	var ok := call_transcribe_docx(latest_file, output_path)

	if ok:
		print("Saved DOCX to: ", output_path)
	else:
		push_error("Failed to save DOCX.")


func get_latest_audio_file(folder_path: String) -> String:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		push_error("Could not open folder: " + folder_path)
		return ""

	var latest_file := ""
	var latest_mtime := -1

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var ext := file_name.get_extension().to_lower()
			if ext in AUDIO_EXTENSIONS:
				var full_path := folder_path.path_join(file_name)
				var modified_time := FileAccess.get_modified_time(full_path)

				if modified_time > latest_mtime:
					latest_mtime = modified_time
					latest_file = full_path

		file_name = dir.get_next()

	dir.list_dir_end()
	return latest_file


func build_output_docx_path(audio_path: String) -> String:
	var base_name := audio_path.get_file().get_basename()
	return OUTPUT_DIR.path_join(base_name + "_transcript.docx")


func call_transcribe_docx(input_audio_path: String, output_docx_path: String) -> bool:
	var output := []

	var abs_input := ProjectSettings.globalize_path(input_audio_path)
	var abs_output := ProjectSettings.globalize_path(output_docx_path)
	
	var output_dir := abs_output.get_base_dir()
	DirAccess.make_dir_recursive_absolute(output_dir)
	
	print("Input path: ", abs_input)
	print("Output path: ", abs_output)

	var args := [
		"-X", "POST",
		API_URL,
		"-H", "accept: application/vnd.openxmlformats-officedocument.wordprocessingml.document",
		"-F", "file=@" + abs_input,
		"-F", "diarize=true",
		"--output", abs_output
	]

	var exit_code := OS.execute("curl", args, output, true)

	if exit_code != 0:
		print("curl failed. Exit code: ", exit_code)
		print(output)
		return false

	return FileAccess.file_exists(output_docx_path)
