extends Node2D
	
func _on_door_exit_body_entered(body: Node2D) -> void:	
	if body.is_in_group("player"):

		global.go_to_world()
