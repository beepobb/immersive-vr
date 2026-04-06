extends Node

const DEFAULT_ENVIRONMENT_ID := "desert"

const ENVIRONMENTS := {
	"sphere_room": {
		"name": "Horizon Sanctuary",
		"description": "A spacious circular sanctuary surrounded by panoramic mountain views. Designed for grounding, focus, and peaceful dialogue.",
		"thumbnail": "res://assets/ui/card/open_room.jpg",
		"scene_path": "res://scenes/environment/circular_hall.tscn",
	},
	"therapy_room": {
		"name": "Clarity Room",
		"description": "A minimalist therapy room with soft lighting and neutral tones that foster calm, focus, and open communication.",
		"thumbnail": "res://assets/ui/card/therapy_room.jpg",
		"scene_path": "res://scenes/environment/meta_env_06.tscn",
	},
	"water_house": {
		"name": "Floating Haven",
		"description": "A modern home surrounded by calm waters. Offers a serene, private escape with a soothing atmosphere.",
		"thumbnail": "res://assets/ui/card/water_house.jpg",
		"scene_path": "res://scenes/environment/apartment.scn",
	},
	"park": {
		"name": "Tranquil Park",
		"description": "A gentle outdoor park with greenery and winding paths. Ideal for relaxed, natural conversations in a refreshing setting.",
		"thumbnail": "res://assets/ui/card/park.jpg",
		"scene_path": "res://scenes/environment/meta_env_06.tscn",
	},
	"desert": {
		"name": "Desert Serenity",
		"description": "A quiet, open desert space with warm sunlight and soft sands. Perfect for calm reflection and uninterrupted conversations.",
		"thumbnail": "res://assets/ui/card/desert.jpg",
		"scene_path": "res://scenes/environment/sand.scn",
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
