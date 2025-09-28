extends Node2D

func _on_door_exit_1_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Set the player's spawn point for map_2
		global.next_player_position = Vector2(23, 1237) # The entrance position in map_2
		global.go_to_map_2()
