extends Area3D

@onready var sofa = get_parent()

func _ready():
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body):
	if body.name == "XR_Origin":   # change to your XR node name
		var interactor = body.get_node("Interactor")
		interactor.current_sofa = sofa

func _on_exit(body):
	if body.name == "XR_Origin":
		var interactor = body.get_node("Interactor")
		interactor.current_sofa = null
