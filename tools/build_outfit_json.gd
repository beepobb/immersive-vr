@tool
extends EditorScript

const OUTFIT_SCENE := "res://Assets/Outfit/outfit_export.tscn"
const OUTPUT_JSON  := "res://Assets/Outfit/outfit_assets.json"

const THUMB_DIR := "res://Assets/Outfit/thumbs"
const NAME_PREFIX := "Human_"

func _run() -> void:
	var ps := load(OUTFIT_SCENE) as PackedScene
	if ps == null:
		push_error("Cannot load: " + OUTFIT_SCENE)
		return

	var root := ps.instantiate()
	if root == null:
		push_error("Cannot instance: " + OUTFIT_SCENE)
		return

	var items: Array = []

	for child in root.get_children():
		if child is MeshInstance3D:
			var n := child.name
			if not n.begins_with(NAME_PREFIX):
				continue

			var id := _make_id(n)
			var pretty := _pretty_name(n)
			var thumb := _find_best_thumb_path(id)  # <--- uses id tokens

			items.append({
				"id": id,
				"name": pretty,
				"node_path": n,
				"thumb": thumb
			})

	items.sort_custom(func(a, b): return String(a["name"]).to_lower() < String(b["name"]).to_lower())

	var manifest := {
		"version": 1,
		"type": "outfit",
		"scene": OUTFIT_SCENE,
		"thumb_root": THUMB_DIR,
		"items": items
	}

	var f := FileAccess.open(OUTPUT_JSON, FileAccess.WRITE)
	if f == null:
		push_error("Could not write: " + OUTPUT_JSON)
		return

	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()

	print("Rebuilt outfit JSON:", OUTPUT_JSON, " (items:", items.size(), ")")
	root.queue_free()


func _make_id(node_name: String) -> String:
	var s := node_name
	if s.begins_with(NAME_PREFIX):
		s = s.substr(NAME_PREFIX.length())
	return s.to_lower().replace(" ", "_")


func _pretty_name(node_name: String) -> String:
	var s := node_name
	if s.begins_with(NAME_PREFIX):
		s = s.substr(NAME_PREFIX.length())
	return s.replace("_", " ").capitalize()


func _find_best_thumb_path(outfit_id: String) -> String:
	var expected := outfit_id.to_lower() + ".png"

	var dir := DirAccess.open(THUMB_DIR)
	if dir == null:
		push_warning("Cannot open thumb dir: " + THUMB_DIR)
		return ""

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue

		if name.to_lower() == expected:
			dir.list_dir_end()
			return THUMB_DIR.path_join(name)

	dir.list_dir_end()
	return ""
