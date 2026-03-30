@tool
extends EditorScript

const OUTFIT_DIR := "res://Assets/Outfit"
const THUMB_DIR := "res://Assets/Outfit/thumbs"
const OUTPUT_JSON := "res://Assets/Outfit/outfit_assets.json"

func _run() -> void:
	var dir := DirAccess.open(OUTFIT_DIR)
	if dir == null:
		push_error("Cannot open outfit directory: " + OUTFIT_DIR)
		return

	var items: Array = []

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			if _should_skip_scene(file_name):
				file_name = dir.get_next()
				continue

			var id := file_name.get_basename().to_lower()
			var scene_path := OUTFIT_DIR.path_join(file_name)
			var thumb_path := _thumb_for_id(id)

			items.append({
				"id": id,
				"name": _display_name_from_id(id),
				"scene": scene_path,
				"thumb": thumb_path
			})

		file_name = dir.get_next()

	dir.list_dir_end()

	items.sort_custom(func(a, b):
		return String(a["id"]).to_lower() < String(b["id"]).to_lower()
	)

	var manifest := {
		"version": 4,
		"type": "outfit_set",
		"root": OUTFIT_DIR,
		"thumb_root": THUMB_DIR,
		"items": items
	}

	var f := FileAccess.open(OUTPUT_JSON, FileAccess.WRITE)
	if f == null:
		push_error("Could not write: " + OUTPUT_JSON)
		return

	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()

	print("Rebuilt outfit set JSON: ", OUTPUT_JSON, " (items: ", items.size(), ")")


func _should_skip_scene(file_name: String) -> bool:
	var base := file_name.get_basename().to_lower()

	if base == "outfit_export":
		return true

	if base == "thumbs":
		return true

	return false


func _thumb_for_id(id: String) -> String:
	var png_path := THUMB_DIR.path_join(id + ".png")
	if ResourceLoader.exists(png_path):
		return png_path

	var jpg_path := THUMB_DIR.path_join(id + ".jpg")
	if ResourceLoader.exists(jpg_path):
		return jpg_path

	var jpeg_path := THUMB_DIR.path_join(id + ".jpeg")
	if ResourceLoader.exists(jpeg_path):
		return jpeg_path

	return ""


func _display_name_from_id(id: String) -> String:
	var parts := id.split("_")
	var words: Array[String] = []

	for part in parts:
		if part.is_empty():
			continue
		words.append(part.capitalize())

	return " ".join(words)
