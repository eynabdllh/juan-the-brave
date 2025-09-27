extends Node2D
	
func _on_exit_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	print("[door_side_2] Player touched exit; routing to map_4")
	if has_node("/root/global"):
		global.set_return_position_for("door_side_2", body.global_position)
	global.go_to_map_3()
