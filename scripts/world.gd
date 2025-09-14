extends Node2D

func _ready():
	if global.game_first_loadin == true:
		$player.position = global.player_start_pos
		global.game_first_loadin = false 
	else:
		$player.position = global.player_exit_doorside_pos

func _on_door_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		global.go_to_door_side()
