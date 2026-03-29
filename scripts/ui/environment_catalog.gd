extends Node

const DEFAULT_ENVIRONMENT_ID := "desert"

const ENVIRONMENTS := {
	"desert": {
		"name": "Desert",
		"description": "A minimalist therapy room with soft lighting and neutral tones that foster calm, focus, and open communication.",
		"thumbnail": "res://assets/ui/card/010001.jpg",
		"scene_path": "res://scenes/environment/sand.tscn",
	},
	"apartment": {
		"name": "Apartment",
		"description": "This is a cafe.",
		"thumbnail": "res://assets/ui/card/00012.jpg",
		"scene_path": "res://scenes/environment/apartment.tscn"
	}
}

static func get_environment_ids() -> Array[String]:
	var ids: Array[String] = []
	for environment_id in ENVIRONMENTS.keys():
		ids.append(String(environment_id))
	ids.sort()
	return ids

static func get_environments() -> Array[Dictionary]:
	var environments: Array[Dictionary] = []
	for environment_id in get_environment_ids():
		environments.append(get_environment(environment_id))
	return environments

static func get_environment(environment_id: String) -> Dictionary:
	var normalized_id = environment_id.strip_edges().to_lower()
	if normalized_id.is_empty() or not ENVIRONMENTS.has(normalized_id):
		normalized_id = DEFAULT_ENVIRONMENT_ID

	var environment = ENVIRONMENTS.get(normalized_id, {}).duplicate(true)
	environment["id"] = normalized_id
	return environment

static func get_environment_name(environment_id: String) -> String:
	return String(get_environment(environment_id).get("name", "Environment"))

static func get_environment_description(environment_id: String) -> String:
	return String(get_environment(environment_id).get("description", ""))

static func get_environment_thumbnail(environment_id: String) -> Texture2D:
	var thumbnail_path = String(get_environment(environment_id).get("thumbnail", ""))
	if thumbnail_path.is_empty():
		return null

	return load(thumbnail_path) as Texture2D

static func get_environment_scene_path(environment_id: String) -> String:
	return String(get_environment(environment_id).get("scene_path", ""))

static func get_default_environment_id() -> String:
	return DEFAULT_ENVIRONMENT_ID
