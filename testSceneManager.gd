extends Node2D

@export var audioManager: PackedScene 
# Called when the node enters the scene tree for the first time.
func _ready():
	var s = audioManager.instantiate()
	s.setupAudio(1)
	add_child(s)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
