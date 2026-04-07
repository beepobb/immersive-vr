extends RefCounted
class_name AvatarAppearanceService

const HAIR_JSON_PATH := "res://assets/hair/hair_assets.json"
const OUTFIT_JSON_PATH := "res://assets/outfit/outfit_assets.json"
const SHOES_JSON_PATH := "res://assets/shoes/shoes_assets.json"

enum PartType {HAIR, OUTFIT, SHOES}

# parts spawned will be tagged with this for clean removal later
const META_PART_TYPE := "avatar_part_type"

var hair_map: Array = []
var outfit_map: Array = []
var shoes_map: Array = []
var hair_id_scene_map: Dictionary = {}
var outfit_id_scene_map: Dictionary = {}
var shoes_id_scene_map: Dictionary = {}

func load_manifests() -> void:
	hair_map = _load_manifest_array(HAIR_JSON_PATH, "hair")
	outfit_map = _load_manifest_array(OUTFIT_JSON_PATH, "outfit")
	shoes_map = _load_manifest_array(SHOES_JSON_PATH, "shoes")
	hair_id_scene_map = generate_id_scene_map(hair_map)
	outfit_id_scene_map = generate_id_scene_map(outfit_map)
	shoes_id_scene_map = generate_id_scene_map(shoes_map)

# used to apply option (replace current part with new part)
func replace_part(attachment_root: Node, current_part: Node, item_id: String, part_type: PartType) -> Node:
	if attachment_root == null:
		return current_part

	var key := item_id.strip_edges().to_lower()

	var scene_path := find_scene_path(key, part_type)
	if scene_path.is_empty():
		push_warning("AvatarAppearanceService: no scene found for id '%s'" % key)
		return current_part

	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("AvatarAppearanceService: failed to load scene %s" % scene_path)
		return current_part

	var next_part := packed.instantiate()
	if next_part == null:
		push_warning("AvatarAppearanceService: failed to instantiate scene %s" % scene_path)
		return current_part

	if current_part != null and is_instance_valid(current_part):
		current_part.queue_free()

	next_part.set_meta(META_PART_TYPE, int(part_type))
	attachment_root.add_child(next_part)
	_rebind_part_meshes_to_skeleton(next_part, attachment_root)
	return next_part

func _rebind_part_meshes_to_skeleton(part_root: Node, attachment_root: Node) -> void:
	var target_skeleton := attachment_root as Skeleton3D
	if target_skeleton == null:
		for child in attachment_root.find_children("*", "Skeleton3D", true, false):
			target_skeleton = child as Skeleton3D
			break

	if target_skeleton == null:
		return

	for node in part_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue

		var skeleton_path := mesh.get_path_to(target_skeleton)
		if skeleton_path.is_empty():
			continue

		mesh.skeleton = skeleton_path

func get_default_attachment_root(avatar: Node) -> Node:
	if avatar == null:
		return null

	var explicit_root = avatar.get_node_or_null("Human_rig/Skeleton3D")
	if explicit_root == null:
		explicit_root = avatar.get_node_or_null("AvatarRoot/AvatarTest/Human_rig/Skeleton3D")
	if explicit_root != null:
		return explicit_root

	for node in avatar.find_children("*", "Skeleton3D", true, false):
		return node

	return avatar

func clear_all_parts(attachment_root: Node) -> void:
	if attachment_root == null:
		return

	for child in attachment_root.get_children():
		if child.has_meta(META_PART_TYPE):
			child.queue_free()

func get_current_parts(avatar: Node) -> Array:
	var hair_node: Node
	var outfit_node: Node
	var shoe_node: Node
	var attachment_root = get_default_attachment_root(avatar)
	for child in attachment_root.get_children():
		if child != null and is_instance_valid(child):
			if child.has_meta(META_PART_TYPE):
				match child.get_meta(META_PART_TYPE):
					PartType.HAIR:
						hair_node = child
					PartType.OUTFIT:
						outfit_node = child
					PartType.SHOES:
						shoe_node = child
	return [hair_node, outfit_node, shoe_node]


func clear_part(attachment_root: Node, part: Node) -> void:
	if attachment_root == null:
		return
	
	if part.get_parent() != attachment_root:
		return

	if part.has_meta(META_PART_TYPE):
		part.queue_free()

func apply_skin_color(body_mesh: MeshInstance3D, color: Color) -> void:
	if body_mesh == null:
		return

	var material := body_mesh.get_active_material(0)
	var next_material: StandardMaterial3D
	if material is StandardMaterial3D:
		next_material = material.duplicate()
	else:
		next_material = StandardMaterial3D.new()

	next_material.albedo_color = color
	body_mesh.set_surface_override_material(0, next_material)

func find_scene_path(item_id: String, part_type: PartType) -> String:
	if part_type == PartType.HAIR:
		return hair_id_scene_map.get(item_id, "")
	if part_type == PartType.OUTFIT:
		return outfit_id_scene_map.get(item_id, "")
	if part_type == PartType.SHOES:
		return shoes_id_scene_map.get(item_id, "")
	return ""

func _load_manifest_array(json_path: String, label: String) -> Array:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s JSON: %s" % [label, json_path])
		return []

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	return data["items"]

func generate_id_scene_map(manifest: Array) -> Dictionary:
	var map: Dictionary = {}
	for i in range(manifest.size()):
		var item: Dictionary = manifest[i]
		var item_id: String = item.get("id")
		var scene: String = item.get("scene")
		map.set(item_id, scene)
	return map
