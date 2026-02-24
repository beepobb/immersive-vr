@tool
extends EditorScript

const HAIR_DIR := "res://Assets/Hair"
const THUMB_DIR := "res://Assets/Hair/thumbs"
const OUTPUT_JSON := "res://Assets/Hair/hair_assets.json"

func _run() -> void:
	var items: Array = []
	_scan_dir_recursive(HAIR_DIR, items)

	items.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())

	var manifest := {
		"version": 1,
		"type": "hair",
		"root": HAIR_DIR,
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

	print("✅ Rebuilt hair JSON:", OUTPUT_JSON, " (items:", items.size(), ")")


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
			if name.get_extension().to_lower() == "tscn":
				var base := name.get_basename() # human_elvs_keylth_hair_2
				var id := base.to_lower()

				var thumb_name := _derive_thumb_name(id) # elvs_keylth_hair.png
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

	# Remove leading "human_"
	if s.begins_with("human_"):
		s = s.substr(6)

	# Split → convert to Array so we can pop
	var parts := Array(s.split("_"))

	# Remove trailing number (_2, _01, etc.)
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
