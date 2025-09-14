extends Node

var player_current_attack = false	
var current_scene = "world"

var player_exit_doorside_pos = Vector2(195, 15)
var player_start_pos = Vector2(59, 90) 
var game_first_loadin = true

func go_to_door_side():
	current_scene = "door_side"
	get_tree().change_scene_to_file("res://scenes/door_side.tscn")

func go_to_world():
	current_scene = "world"
	get_tree().change_scene_to_file("res://scenes/world.tscn")
