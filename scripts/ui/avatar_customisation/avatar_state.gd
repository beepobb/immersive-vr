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
var hair_style: String = "default"
var shoes: String = "default"

# Environment choice
var environment_id: String = ""   # "clarity_room", "dialogue_cafe", etc.

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
