extends Node2D

func _ready():
	if global.game_first_loadin == true:
		$player.position.x = global.player_start_posx
		$player.position.y = global.player_start_posy
	else:
		$player.position.x = global.player_exit_doorside_posx
		$player.position.y = global.player_exit_doorside_posy
		
func _process(delta):
	change_scene()

func _on_door_side_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = true


func _on_door_side_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		global.transition_scene = false


func change_scene():
	if global.transition_scene == true:
		# Set this to false FIRST to prevent this code from running again next frame.
		global.transition_scene = false 
		
		if global.current_scene == "world":
			get_tree().change_scene_to_file("res://scenes/door_side.tscn")
			global.game_first_loadin = false
			global.finish_changescenes()
