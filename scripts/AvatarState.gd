# AvatarState.gd
extends Node

# Basic avatar info
var display_name: String = ""
var gender: String = ""
var age_range: String = ""

# Visual choices (fill out as you add more options)
var body_type: String = "medium"
var skin_tone: String = "default"
var outfit: String = "default"
var hair_style: String = "ponytail"
var face_type: String = "default"

# Environment choice
var environment_id: String = ""   # "clarity_room", "dialogue_cafe", etc.

func reset() -> void:
	display_name = ""
	gender = ""
	age_range = ""
	body_type = "medium"
	skin_tone = "default"
	outfit = "default"
	hair_style = "ponytail"
	face_type = "default"
	environment_id = ""

func apply_to_avatar(avatar: Node3D) -> void:
	# Example: apply hair to a freshly instanced avatar in VR
	var hair_bob     = avatar.get_node_or_null("Armature/Skeleton3D/Human_bob02")
	var hair_long    = avatar.get_node_or_null("Armature/Skeleton3D/Human_long02")
	var hair_pony    = avatar.get_node_or_null("Armature/Skeleton3D/Human_ponytail01")

	if hair_bob:  hair_bob.visible = false
	if hair_long: hair_long.visible = false
	if hair_pony: hair_pony.visible = false

	match hair_style:
		"bob":
			if hair_bob: hair_bob.visible = true
		"long":
			if hair_long: hair_long.visible = true
		"ponytail":
			if hair_pony: hair_pony.visible = true

	# TODO: body_type, outfit, skin_tone, etc. in same pattern
