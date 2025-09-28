extends Node2D
		
func _on_door_exit_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Set the player's spawn point for the *next* scene (map_3)
		# This should be a position near the door in map_3
		global.next_player_position = Vector2(209, 20)
		global.go_to_world()
