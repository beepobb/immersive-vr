extends Camera3D

@export var enabled: bool = true
@export var max_distance: float = 30.0
@export_flags_3d_physics var ui_collision_mask: int = 0xFFFFFFFF

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var hit: Dictionary = _raycast(mouse_pos)
	if hit.is_empty():
		return

	var collider: Object = hit.get("collider", null)
	if collider == null:
		return

	var viewport2d: Node = _find_viewport2d(collider as Node)
	if viewport2d == null:
		return

	var subvp: SubViewport = viewport2d.get_node("Viewport") as SubViewport
	if subvp == null:
		return

	var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
	var uv: Vector2 = _world_hit_to_uv(viewport2d as Node3D, hit_pos)

	var vp_size: Vector2i = subvp.size
	var pixel_pos: Vector2 = Vector2(uv.x * float(vp_size.x), uv.y * float(vp_size.y))

	# Duplicate returns Variant, so cast explicitly to InputEvent
	var forwarded: InputEvent = event.duplicate() as InputEvent
	if forwarded == null:
		return

	if forwarded is InputEventMouseButton:
		var e := forwarded as InputEventMouseButton
		e.position = pixel_pos
		e.global_position = pixel_pos
		subvp.push_input(e)
	elif forwarded is InputEventMouseMotion:
		var e := forwarded as InputEventMouseMotion
		e.position = pixel_pos
		e.global_position = pixel_pos
		subvp.push_input(e)

func _raycast(mouse_pos: Vector2) -> Dictionary:
	var from: Vector3 = project_ray_origin(mouse_pos)
	var to: Vector3 = from + project_ray_normal(mouse_pos) * max_distance

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_bodies = true
	q.collide_with_areas = true
	q.collision_mask = ui_collision_mask

	return space.intersect_ray(q)

func _find_viewport2d(node: Node) -> Node:
	var cur: Node = node
	while cur != null:
		# XRToolsViewport2DIn3D is a class_name in your code, so this should work
		if cur is XRToolsViewport2DIn3D:
			return cur
		cur = cur.get_parent()
	return null

func _world_hit_to_uv(panel: Node3D, hit_world: Vector3) -> Vector2:
	var local: Vector3 = panel.to_local(hit_world)

	# screen_size is defined in XRToolsViewport2DIn3D
	var size: Vector2 = (panel as XRToolsViewport2DIn3D).screen_size
	var half_w: float = size.x * 0.5
	var half_h: float = size.y * 0.5

	var u: float = clamp((local.x + half_w) / (2.0 * half_w), 0.0, 1.0)
	var v: float = clamp((half_h - local.y) / (2.0 * half_h), 0.0, 1.0)

	return Vector2(u, v)
