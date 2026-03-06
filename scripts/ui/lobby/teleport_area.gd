extends Area3D
 
# Target scene name
@export_file("*.tscn") var target_scene: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(_body: Node3D) -> void:
	# Skip if no target scene set
	if not target_scene or target_scene == "":
		return
	
	# Find the XRToolsSceneBase this node is a child of
	var scene_base: XRToolsSceneBase = XRTools.find_xr_ancestor(self, "*", "XRToolsSceneBase")
	if not scene_base:
		return
	
	# Start loading the target scene
	scene_base.load_scene(target_scene)
