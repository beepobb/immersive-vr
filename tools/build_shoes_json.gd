@tool
extends EditorScript

const SHOES_DIR := "res://assets/shoes"
const THUMB_DIR := "res://assets/shoes/thumbs"
const OUTPUT_JSON := "res://assets/shoes/shoes_assets.json"

func _run() -> void:
	var items: Array = []
	_scan_dir_recursive(SHOES_DIR, items)

	items.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())

	var manifest := {
		"version": 1,
		"type": "shoes",
		"root": SHOES_DIR,
		"thumb_root": THUMB_DIR,
		"items": items
	}

	var json_text := JSON.stringify(manifest, "\t")

	var f := FileAccess.open(OUTPUT_JSON, FileAccess.WRITE)
	if f == null:
		push_error("Could not write: " + OUTPUT_JSON)
		return

	f.store_string(json_text)
	f.close()

	print("Rebuilt shoes JSON: ", OUTPUT_JSON, " (items: ", items.size(), ")")


func _scan_dir_recursive(path: String, out_items: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Cannot open dir: " + path)
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue

		var full := path.path_join(name)

		if dir.current_is_dir():
			_scan_dir_recursive(full, out_items)
		else:
			var ext := name.get_extension().to_lower()
			if ext == "tscn":
				var base := name.get_basename()
				var id := base.to_lower()

				var thumb_name := _derive_thumb_name(id)
				var thumb_path := THUMB_DIR.path_join(thumb_name)

				out_items.append({
					"id": id,
					"name": _pretty_name(id),
					"scene": full,
					"thumb": thumb_path if ResourceLoader.exists(thumb_path) else ""
				})

	dir.list_dir_end()


func _derive_thumb_name(scene_id: String) -> String:
	var s := scene_id

	if s.begins_with("human_"):
		s = s.substr(6)

	var parts := Array(s.split("_"))

	if parts.size() > 1 and parts[-1].is_valid_int():
		parts.remove_at(parts.size() - 1)

	s = "_".join(parts)
	return s + ".png"


func _pretty_name(id: String) -> String:
	var s := id

	if s.begins_with("human_"):
		s = s.substr(6)

	var parts := Array(s.split("_"))
	if parts.size() > 1 and parts[-1].is_valid_int():
		parts.remove_at(parts.size() - 1)

	s = " ".join(parts)
	return s.capitalize()
