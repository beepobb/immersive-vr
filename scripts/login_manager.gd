extends Node3D

@export var log_in: PackedScene
@export var sign_up: PackedScene
@onready var viewport: XRToolsViewport2DIn3D = $"../Viewport2Din3D"

# TODO: need login state
# if not logged in show log in screen
# if sign up show sign up screen
	
func _ready() -> void:
	viewport.scene = log_in
