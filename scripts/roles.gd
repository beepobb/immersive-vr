extends Node

enum Role {THERAPIST, PATIENT}
var user_role: Role = Role.PATIENT

func set_role(role: Role) -> void:
	user_role = role

func get_role_name(role: int = user_role) -> String:
	return "Therapist" if role == Role.THERAPIST else "Patient"
