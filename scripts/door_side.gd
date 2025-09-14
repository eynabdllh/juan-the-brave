extends Node2D
	
func _on_door_exit_body_entered(body: Node2D) -> void:	
	if body.has_method("player"):

		get_tree().change_scene_to_file("res://scenes/world.tscn")
		global.finish_changescenes()

func _on_door_exit_body_exited(body: Node2D) -> void:
	pass	
