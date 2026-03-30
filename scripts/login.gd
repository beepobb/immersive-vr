extends Panel



func _on_log_in_pressed() -> void:
	# Find the XRToolsSceneBase ancestor of the current node
	var scene_base : XRToolsSceneBase = XRTools.find_xr_ancestor(self, "*", "XRToolsSceneBase")
	if not scene_base:
		return

	# Request loading the next scene
	scene_base.load_scene("res://scenes/game/home.tscn")
