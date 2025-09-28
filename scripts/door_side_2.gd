extends Node2D

func _ready():
	# Set the current scene for the camera system
	global.current_scene = "door_side_2"
	
	# Position the player where the previous door dictated
	if global.next_player_position != Vector2.ZERO:
		$player.position = global.next_player_position
		global.next_player_position = Vector2.ZERO # Reset after use
	else:
		# Fallback for testing
		$player.position = Vector2(262, 321)

func _on_door_exit_2_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Set the player's spawn point for the *next* scene (map_3)
		# This should be a position near the door in map_3
		global.next_player_position = Vector2(1347, 26)
		global.go_to_map_3()
