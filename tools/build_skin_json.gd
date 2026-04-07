@tool
extends EditorScript

const SKIN_DIR := "res://Assets/Skin/Female"
const THUMB_DIR := "res://Assets/Skin/thumbs"
const OUTPUT_JSON := "res://Assets/Skin/skin_assets.json"

# Scan diffuse textures
const ALLOWED_EXTS := ["png"]

func _run() -> void:
	var items: Array = []
	_scan_dir_recursive(SKIN_DIR, items)

	items.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower())

	var manifest := {
		"version": 1,
		"type": "skin",
		"root": SKIN_DIR,
		"thumb_root": THUMB_DIR,
		"items": items
	}

	var f := FileAccess.open(OUTPUT_JSON, FileAccess.WRITE)
	if f == null:
		push_error("Could not write: " + OUTPUT_JSON)
		return

	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()

	print("Rebuilt skin JSON:", OUTPUT_JSON, " (items:", items.size(), ")")


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
			continue

		var ext := name.get_extension().to_lower()
		if not (ext in ALLOWED_EXTS):
			continue

		# Only include diffuse textures (avoid icons, etc.)
		var lower_name := name.to_lower()
		if not lower_name.contains("diffuse"):
			continue

		var base := name.get_basename()
		var id := _make_id_from_texture_base(base)
		var display := _pretty_name_from_id(id)

		var thumb_path := _derive_thumb_from_texture_base(base)
		if thumb_path == "" or not ResourceLoader.exists(thumb_path):
			thumb_path = _fallback_find_thumb(id) # last resort

		out_items.append({
			"id": id,
			"name": display,
			"texture": full,
			"thumb": thumb_path
		})

	dir.list_dir_end()


# --- ID + Name helpers ---

# Turn "Old caucasian_old_lightskinned_female_diffuse" into "old_caucasian_female"
func _make_id_from_texture_base(base: String) -> String:
	var t := base.to_lower()
	t = t.replace("-", "_").replace(" ", "_")
	var parts := t.split("_", false)

	var age := ""
	var race := ""
	var gender := ""

	for p in parts:
		if age == "" and (p == "old" or p == "middle" or p == "young"):
			age = p
		elif race == "" and (p == "african" or p == "asian" or p == "caucasian" or p == "causcasian"):
			# normalize misspelling
			race = "caucasian" if p == "causcasian" else p
		elif gender == "" and (p == "female" or p == "male"):
			gender = p

	# If race not found, try second token (your files start with "Old caucasian...")
	if race == "" and parts.size() >= 2:
		race = parts[1]
		if race == "causcasian":
			race = "caucasian"

	if age == "" and parts.size() >= 1:
		age = parts[0]

	if gender == "":
		gender = "female" # default for this folder

	return "%s_%s_%s" % [age, race, gender]


func _pretty_name_from_id(id: String) -> String:
	var parts := id.split("_")
	return (" ".join(parts)).capitalize()


# --- Thumb derivation ---

# Exact thumb name: "<age>_<race>_<gender>.png"
func _derive_thumb_from_texture_base(base: String) -> String:
	var id := _make_id_from_texture_base(base)
	return THUMB_DIR.path_join(id + ".png")


# Last-resort fallback: find any thumb containing age+race+gender
func _fallback_find_thumb(id: String) -> String:
	var tokens := id.split("_") # [age, race, gender]

	var dir := DirAccess.open(THUMB_DIR)
	if dir == null:
		return ""

	var best := ""
	var best_score := -1

	dir.list_dir_begin()
	while true:
		var n := dir.get_next()
		if n == "":
			break
		if dir.current_is_dir():
			continue
		if n.get_extension().to_lower() != "png":
			continue

		var lower := n.to_lower()
		var score := 0
		for tok in tokens:
			if lower.contains(tok):
				score += 1

		if score > best_score:
			best_score = score
			best = THUMB_DIR.path_join(n)

	dir.list_dir_end()
	return best if best_score >= 2 else ""
