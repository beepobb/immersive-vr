# AvatarState.gd
extends Node

const HOME_SCENE_PATH := "res://scenes/game/lobby/home.tscn"
const LOBBY_SCENE_PATH := "res://scenes/game/lobby/lobby.tscn"
const AVATAR_CUSTOMISATION_SCENE_PATH := "res://scenes/game/avatar_customisation/avatar_customisation.tscn"
const SELECT_ENVIRONMENT_SCENE_PATH := "res://scenes/game/environment/select_environment.tscn"
const IN_CALL_SCENE_PATH := "res://scenes/environment.tscn"

const DEFAULT_VISUAL_PRESETS := {
	"male": {
		"outfit": "male_elegantsuit",
		"hair": "culturalibre_hair_05",
		"shoes": "punkduck_running_shoes"
	},
	"female": {
		"outfit": "female_elegantsuit",
		"hair": "human_elvs_short_side_do_2",
		"shoes": "dressupdoc_maryjane"
	}
}

var avatar: Node3D

# Basic avatar info
var display_name: String = ""
var gender: String = "female"
var age_range: String = ""

# Visual choices (fill out as you add more options)
var skin_tone: String = ""
var outfit: String = ""
var hair_style: String = ""
var shoes: String = ""

# Environment choice
var environment_id: String = "" # "clarity_room", "dialogue_cafe", etc.
var pending_notice: String = ""

var _appearance_service := AvatarAppearanceService.new()
var _manifests_loaded := false

func reset() -> void:
	display_name = ""
	gender = "female"
	age_range = ""

	#TODO: shoes, hair, outfit, skin tone

func update_customisations(hair_id: String, outfit_id: String, shoe_id: String, skin_tone_id: String = "") -> void:
	hair_style = hair_id
	outfit = outfit_id
	shoes = shoe_id
	if skin_tone != "":
		skin_tone = skin_tone_id

func set_default_options() -> void:
	var preset: Dictionary = DEFAULT_VISUAL_PRESETS.get(gender.to_lower(), {})
	print(preset)
	hair_style = preset.get("hair")
	shoes = preset.get("shoes")
	outfit = preset.get("outfit")

#TODO: remove state if unnecessary
func apply_to_avatar(state: Dictionary = {}) -> void:
	if avatar == null:
		return

	if not _manifests_loaded:
		_appearance_service.load_manifests()
		_manifests_loaded = true

	var attachment_root = _appearance_service.get_default_attachment_root(avatar)
	_appearance_service.clear_all_parts(attachment_root)

	if hair_style == "" or outfit == "" or shoes == "":
		set_default_options()

	var selected_hair := _resolve_state_string(state, ["hair_style", "hair"], hair_style)
	var selected_outfit := _resolve_state_string(state, ["outfit"], outfit)
	var selected_shoes := _resolve_state_string(state, ["shoes"], shoes)

	_appearance_service.replace_part(attachment_root, null, selected_hair, AvatarAppearanceService.PartType.HAIR)
	_appearance_service.replace_part(attachment_root, null, selected_outfit, AvatarAppearanceService.PartType.OUTFIT)
	_appearance_service.replace_part(attachment_root, null, selected_shoes, AvatarAppearanceService.PartType.SHOES)

	var skin_value = _resolve_state_value(state, ["skin_tone"], skin_tone)
	if skin_value is Color:
		var body_mesh := avatar.get_node_or_null("Human_rig / Skeleton3D / Human") as MeshInstance3D
		if body_mesh == null:
			for node in avatar.find_children(" * ", "MeshInstance3D", true, false):
				if String(node.name).to_lower() == "human":
					body_mesh = node as MeshInstance3D
					break
		_appearance_service.apply_skin_color(body_mesh, skin_value)
	elif skin_value is String:
		var skin_key := String(skin_value).strip_edges()
		if skin_key.begins_with(" # "):
			var parsed_color := Color.from_string(skin_key, Color(0, 0, 0, 0))
			if parsed_color.a > 0.0:
				var mesh := avatar.get_node_or_null("Human_rig/Skeleton3D/Human") as MeshInstance3D
				if mesh == null:
					for node in avatar.find_children("*", "MeshInstance3D", true, false):
						if String(node.name).to_lower() == "human":
							mesh = node as MeshInstance3D
							break
				_appearance_service.apply_skin_color(mesh, parsed_color)

func _resolve_state_string(state: Dictionary, keys: Array, fallback: String) -> String:
	var value = _resolve_state_value(state, keys, fallback)
	return String(value)

func _resolve_state_value(state: Dictionary, keys: Array, fallback):
	for key in keys:
		if state.has(key):
			return state[key]
	return fallback

func set_notice(message: String) -> void:
	pending_notice = message

func consume_notice() -> String:
	var message := pending_notice
	pending_notice = ""
	return message

func load_scene(requester: Node, scene_path: String, notice: String = "") -> void:
	if not notice.is_empty():
		set_notice(notice)

	var scene_base = XRTools.find_xr_ancestor(requester, "*", "XRToolsSceneBase")
	if scene_base:
		scene_base.load_scene(scene_path)
		return

	requester.get_tree().change_scene_to_file(scene_path)

func return_to_home(requester: Node, notice: String = "") -> void:
	load_scene(requester, HOME_SCENE_PATH, notice)

func return_to_lobby(requester: Node, notice: String = "") -> void:
	load_scene(requester, LOBBY_SCENE_PATH, notice)
