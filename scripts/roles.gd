extends Node

enum Role {THERAPIST, PATIENT}
var user_role: Role = Role.PATIENT

func set_role(role: Role) -> void:
	user_role = role
	
func get_role_text() -> String:
	if user_role == Role.THERAPIST:
		return "Therapist"
	if user_role == Role.PATIENT:
		return "Patient"
	push_error("Role is invalid")
	return ""
