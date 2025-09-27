extends Node2D


func _on_door_exit_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Save where the player was in this scene, so the destination can restore
	if has_node("/root/global"):
		global.set_return_position_for("door_side_1", body.global_position)
	global.go_to_map_2()
