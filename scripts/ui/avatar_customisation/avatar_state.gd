# AvatarState.gd
extends Node

const HOME_SCENE_PATH := "res://scenes/ui/lobby/home.tscn"
const LOBBY_SCENE_PATH := "res://scenes/ui/lobby/lobby.tscn"
const AVATAR_CUSTOMISATION_SCENE_PATH := "res://scenes/ui/avatar_customisation/avatar_customisation_base.tscn"
const SELECT_ENVIRONMENT_SCENE_PATH := "res://scenes/ui/select_environment_base.tscn"
const IN_CALL_SCENE_PATH := "res://scenes/environment.tscn"

# Basic avatar info
var display_name: String = ""
var gender: String = ""
var age_range: String = ""

# Visual choices (fill out as you add more options)
var body_type: String = "medium"
var skin_tone: String = "default"
var outfit: String = "default"
var hair_style: String = "default"
var shoes: String = "default"

# Environment choice
var environment_id: String = ""   # "clarity_room", "dialogue_cafe", etc.
var pending_notice: String = ""

func reset() -> void:
	display_name = ""
	gender = ""
	age_range = ""
	body_type = "medium"
	skin_tone = "default"
	outfit = "default"
	hair_style = "default"
	shoes = "default"
	environment_id = ""

func apply_to_avatar(avatar: Node3D, state: Dictionary = {}) -> void:
	pass

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
